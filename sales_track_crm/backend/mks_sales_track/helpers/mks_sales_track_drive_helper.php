<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - recordings on Google Drive, retention and the cleanup run.
 *
 * Loaded on demand by Settings, the recording stream and the cron run.
 *
 * One Google Workspace account is connected once, through OAuth with the
 * drive.file scope: Sales Track can only see the folders and files it created
 * itself. The refresh token is stored encrypted with the CRM's key; access
 * tokens are refreshed and cached the same way.
 *
 * Uploads are resumable and verified (size and MD5) before the server copy is
 * scheduled for deletion. Playback streams from Drive through the CRM, so the
 * same permission checks apply and nobody needs access to the Drive itself.
 */

/** Option: the connection (encrypted refresh token, account, when). */
define('MKS_ST_DRIVE_OPTION', 'mks_sales_track_drive');

/** Option: the cached access token. */
define('MKS_ST_DRIVE_TOKEN_OPTION', 'mks_sales_track_drive_token');

/** Option: folder ids by path, so each folder is looked up once. */
define('MKS_ST_DRIVE_FOLDERS_OPTION', 'mks_sales_track_drive_folders');

/** Option: the last run's outcome, for Settings. */
define('MKS_ST_DRIVE_STATUS_OPTION', 'mks_sales_track_drive_status');

/** Uploads per cron run, and attempts before a recording is left alone. */
define('MKS_ST_DRIVE_BATCH', 20);
define('MKS_ST_DRIVE_MAX_ATTEMPTS', 5);

/* =========================================================================
 * CONNECTION
 * ====================================================================== */

/**
 * @return string the address Google sends the administrator back to
 */
function mks_st_drive_redirect_uri()
{
    return admin_url(MKS_SALES_TRACK_MODULE_NAME . '/drive_callback');
}

/**
 * The OAuth client from Settings, or null when it is incomplete.
 *
 * @return array|null id, secret
 */
function mks_st_drive_client()
{
    $id  = trim((string) mks_st_setting('drive_client_id', ''));
    $raw = (string) get_option('mks_sales_track_drive_secret');

    if ($id === '' || $raw === '') {
        return null;
    }

    $CI     = &get_instance();
    $secret = $CI->encryption->decrypt($raw);

    return is_string($secret) && $secret !== '' ? ['id' => $id, 'secret' => $secret] : null;
}

/**
 * Where to send the administrator to approve access.
 *
 * @param  string $state
 *
 * @return string|null
 */
function mks_st_drive_auth_url($state)
{
    $client = mks_st_drive_client();

    if ($client === null) {
        return null;
    }

    return mks_st_google_url('accounts') . '/o/oauth2/v2/auth?' . http_build_query([
        'client_id'     => $client['id'],
        'redirect_uri'  => mks_st_drive_redirect_uri(),
        'response_type' => 'code',
        'scope'         => 'https://www.googleapis.com/auth/drive.file openid email',
        'access_type'   => 'offline',
        'prompt'        => 'consent',
        'state'         => $state,
    ]);
}

/**
 * Finish the connection with the code Google sent back.
 *
 * @param  string $code
 *
 * @return true|string true, or an error message
 */
function mks_st_drive_connect($code)
{
    $client = mks_st_drive_client();

    if ($client === null) {
        return 'client_missing';
    }

    $reply = mks_st_google_request('POST', mks_st_google_url('oauth') . '/token', ['Content-Type: application/x-www-form-urlencoded'], http_build_query([
        'code'          => (string) $code,
        'client_id'     => $client['id'],
        'client_secret' => $client['secret'],
        'redirect_uri'  => mks_st_drive_redirect_uri(),
        'grant_type'    => 'authorization_code',
    ]));

    if ($reply['status'] !== 200 || empty($reply['json']['refresh_token'])) {
        return mks_st_google_error($reply);
    }

    $account = '';
    $who     = mks_st_google_request('GET', mks_st_google_url('apis') . '/oauth2/v2/userinfo', ['Authorization: Bearer ' . $reply['json']['access_token']]);

    if ($who['status'] === 200 && !empty($who['json']['email'])) {
        $account = (string) $who['json']['email'];
    }

    $CI = &get_instance();

    mks_st_option_put(MKS_ST_DRIVE_OPTION, json_encode([
        'refresh' => $CI->encryption->encrypt($reply['json']['refresh_token']),
        'account' => $account,
        'since'   => date('Y-m-d H:i:s'),
    ]), 0);

    mks_st_drive_cache_token($reply['json']['access_token'], isset($reply['json']['expires_in']) ? (int) $reply['json']['expires_in'] : 3600);
    mks_st_option_put(MKS_ST_DRIVE_FOLDERS_OPTION, '', 0);

    return true;
}

/**
 * Forget the connection, and ask Google to revoke it.
 *
 * @return void
 */
function mks_st_drive_disconnect()
{
    $refresh = mks_st_drive_refresh_token();

    if ($refresh !== null) {
        mks_st_google_request('POST', mks_st_google_url('oauth') . '/revoke', ['Content-Type: application/x-www-form-urlencoded'], http_build_query(['token' => $refresh]));
    }

    foreach ([MKS_ST_DRIVE_OPTION, MKS_ST_DRIVE_TOKEN_OPTION, MKS_ST_DRIVE_FOLDERS_OPTION] as $option) {
        mks_st_option_put($option, '', 0);
    }
}

/**
 * What Settings shows about the connection.
 *
 * @return array connected, account, since, client
 */
function mks_st_drive_state()
{
    $stored = json_decode((string) get_option(MKS_ST_DRIVE_OPTION), true);
    $status = json_decode((string) get_option(MKS_ST_DRIVE_STATUS_OPTION), true);

    return [
        'connected' => is_array($stored) && !empty($stored['refresh']),
        'account'   => is_array($stored) && isset($stored['account']) ? (string) $stored['account'] : '',
        'since'     => is_array($stored) && isset($stored['since']) ? (string) $stored['since'] : '',
        'client'    => mks_st_drive_client() !== null,
        'status'    => is_array($status) ? $status : [],
    ];
}

/**
 * @return string|null
 */
function mks_st_drive_refresh_token()
{
    $stored = json_decode((string) get_option(MKS_ST_DRIVE_OPTION), true);

    if (!is_array($stored) || empty($stored['refresh'])) {
        return null;
    }

    $CI    = &get_instance();
    $token = $CI->encryption->decrypt($stored['refresh']);

    return is_string($token) && $token !== '' ? $token : null;
}

/**
 * @return void
 */
function mks_st_drive_cache_token($token, $lifetime)
{
    $CI = &get_instance();

    mks_st_option_put(MKS_ST_DRIVE_TOKEN_OPTION, json_encode([
        'token'   => $CI->encryption->encrypt($token),
        'expires' => time() + (int) $lifetime,
    ]), 0);
}

/**
 * A live access token, refreshed when needed.
 *
 * @return array token, error
 */
function mks_st_drive_access_token()
{
    $CI     = &get_instance();
    $cached = json_decode((string) get_option(MKS_ST_DRIVE_TOKEN_OPTION), true);

    if (is_array($cached) && isset($cached['token'], $cached['expires']) && $cached['expires'] > time() + 60) {
        $token = $CI->encryption->decrypt($cached['token']);

        if (is_string($token) && $token !== '') {
            return ['token' => $token, 'error' => ''];
        }
    }

    $client  = mks_st_drive_client();
    $refresh = mks_st_drive_refresh_token();

    if ($client === null || $refresh === null) {
        return ['token' => '', 'error' => 'not_connected'];
    }

    $reply = mks_st_google_request('POST', mks_st_google_url('oauth') . '/token', ['Content-Type: application/x-www-form-urlencoded'], http_build_query([
        'client_id'     => $client['id'],
        'client_secret' => $client['secret'],
        'refresh_token' => $refresh,
        'grant_type'    => 'refresh_token',
    ]));

    if ($reply['status'] !== 200 || empty($reply['json']['access_token'])) {
        return ['token' => '', 'error' => mks_st_google_error($reply)];
    }

    mks_st_drive_cache_token($reply['json']['access_token'], isset($reply['json']['expires_in']) ? (int) $reply['json']['expires_in'] : 3600);

    return ['token' => $reply['json']['access_token'], 'error' => ''];
}

/* =========================================================================
 * HTTP
 * ====================================================================== */

/**
 * One request to Google. A file handle in $upload is streamed as the body,
 * so large recordings never have to fit in memory.
 *
 * @param  string        $method
 * @param  string        $url
 * @param  array         $headers
 * @param  string|null   $body
 * @param  resource|null $upload
 * @param  int           $uploadSize
 *
 * @return array status, json, headers, error
 */
function mks_st_google_request($method, $url, array $headers, $body = null, $upload = null, $uploadSize = 0)
{
    if (!function_exists('curl_init')) {
        return ['status' => 0, 'json' => null, 'headers' => [], 'error' => 'curl_missing'];
    }

    $responseHeaders = [];
    $curl            = curl_init($url);

    curl_setopt_array($curl, [
        CURLOPT_CUSTOMREQUEST  => $method,
        CURLOPT_HTTPHEADER     => $headers,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_TIMEOUT        => $upload ? 600 : 30,
        CURLOPT_HEADERFUNCTION => function ($ch, $line) use (&$responseHeaders) {
            $parts = explode(':', $line, 2);

            if (count($parts) === 2) {
                $responseHeaders[strtolower(trim($parts[0]))] = trim($parts[1]);
            }

            return strlen($line);
        },
    ]);

    if ($upload) {
        curl_setopt_array($curl, [CURLOPT_UPLOAD => true, CURLOPT_INFILE => $upload, CURLOPT_INFILESIZE => (int) $uploadSize]);
    } elseif ($body !== null) {
        curl_setopt($curl, CURLOPT_POSTFIELDS, $body);
    }

    $raw    = curl_exec($curl);
    $status = (int) curl_getinfo($curl, CURLINFO_HTTP_CODE);
    $error  = $raw === false ? curl_error($curl) : '';

    curl_close($curl);

    return ['status' => $status, 'json' => json_decode((string) $raw, true), 'headers' => $responseHeaders, 'error' => $error];
}

/**
 * A readable error from a Google reply.
 *
 * @param  array $reply
 *
 * @return string
 */
function mks_st_google_error(array $reply)
{
    $json = $reply['json'];

    if (is_array($json)) {
        if (isset($json['error_description'])) {
            return mks_st_clean_line($json['error_description'], 200);
        }

        if (isset($json['error']['message'])) {
            return mks_st_clean_line($json['error']['message'], 200);
        }

        if (isset($json['error']) && is_string($json['error'])) {
            return mks_st_clean_line($json['error'], 200);
        }
    }

    return $reply['error'] !== '' ? mks_st_clean_line($reply['error'], 200) : 'HTTP ' . $reply['status'];
}

/* =========================================================================
 * FOLDERS AND FILES
 * ====================================================================== */

/**
 * Where a recording goes: root / year / month / rep.
 *
 * @param  array $event
 *
 * @return string[]
 */
function mks_st_drive_path(array $event)
{
    $root = trim((string) mks_st_setting('drive_folder', 'Sales Track')) ?: 'Sales Track';
    $at   = strtotime($event['occurred_at']);

    return [$root, date('Y', $at), date('m', $at), mks_st_staff_name($event['staff_id'])];
}

/**
 * The file name on Drive: when, which way, and the number.
 *
 * @param  array  $event
 * @param  string $ext
 *
 * @return string
 */
function mks_st_drive_file_name(array $event, $ext)
{
    $direction = ['incoming' => 'in', 'outgoing' => 'out', 'missed' => 'missed', 'rejected' => 'rejected'];
    $number    = preg_replace('/[^\d+]/', '', (string) ($event['number'] ?: $event['number_raw']));

    return date('Y-m-d_Hi', strtotime($event['occurred_at'])) . '_' . (isset($direction[$event['direction']]) ? $direction[$event['direction']] : 'call')
        . ($number !== '' ? '_' . $number : '') . '_' . (int) $event['id'] . '.' . preg_replace('/[^a-z0-9]/', '', strtolower($ext));
}

/**
 * A Drive query string literal.
 *
 * @param  string $value
 *
 * @return string
 */
function mks_st_drive_quote($value)
{
    return "'" . str_replace(["\\", "'"], ["\\\\", "\\'"], (string) $value) . "'";
}

/**
 * The id of a folder path, creating what is missing. Ids are cached.
 *
 * @param  string[] $path
 * @param  string   $token
 *
 * @return string|false
 */
function mks_st_drive_folder(array $path, $token)
{
    $cache  = json_decode((string) get_option(MKS_ST_DRIVE_FOLDERS_OPTION), true);
    $cache  = is_array($cache) ? $cache : [];
    $parent = 'root';
    $key    = '';

    foreach ($path as $name) {
        $key .= '/' . $name;

        if (isset($cache[$key])) {
            $parent = $cache[$key];

            continue;
        }

        $q     = 'name = ' . mks_st_drive_quote($name) . " and mimeType = 'application/vnd.google-apps.folder' and " . mks_st_drive_quote($parent) . ' in parents and trashed = false';
        $found = mks_st_google_request('GET', mks_st_google_url('apis') . '/drive/v3/files?' . http_build_query(['q' => $q, 'fields' => 'files(id)', 'spaces' => 'drive']),
            ['Authorization: Bearer ' . $token]);

        if ($found['status'] === 200 && !empty($found['json']['files'][0]['id'])) {
            $parent = (string) $found['json']['files'][0]['id'];
        } else {
            $made = mks_st_google_request('POST', mks_st_google_url('apis') . '/drive/v3/files?fields=id',
                ['Authorization: Bearer ' . $token, 'Content-Type: application/json; charset=UTF-8'],
                json_encode(['name' => $name, 'mimeType' => 'application/vnd.google-apps.folder', 'parents' => [$parent]]));

            if ($made['status'] !== 200 || empty($made['json']['id'])) {
                return false;
            }

            $parent = (string) $made['json']['id'];
        }

        $cache[$key] = $parent;
    }

    mks_st_option_put(MKS_ST_DRIVE_FOLDERS_OPTION, json_encode(array_slice($cache, -500, null, true)), 0);

    return $parent;
}

/**
 * Upload one recording and verify it arrived whole.
 *
 * @param  array  $event
 * @param  string $token
 *
 * @return true|string true, or the error
 */
function mks_st_drive_upload(array $event, $token)
{
    $path = mks_st_recording_path($event['recording_file']);

    if ($path === false) {
        return 'file_missing';
    }

    $folder = mks_st_drive_folder(mks_st_drive_path($event), $token);

    if ($folder === false) {
        return 'folder_failed';
    }

    $size = filesize($path);
    $mime = (string) ($event['recording_mime'] ?: 'application/octet-stream');
    $name = mks_st_drive_file_name($event, pathinfo($path, PATHINFO_EXTENSION));

    $start = mks_st_google_request('POST', mks_st_google_url('apis') . '/upload/drive/v3/files?uploadType=resumable&fields=id,size,md5Checksum',
        ['Authorization: Bearer ' . $token, 'Content-Type: application/json; charset=UTF-8', 'X-Upload-Content-Type: ' . $mime, 'X-Upload-Content-Length: ' . $size],
        json_encode(['name' => $name, 'parents' => [$folder], 'description' => 'Sales Track call #' . (int) $event['id']]));

    if ($start['status'] !== 200 || empty($start['headers']['location'])) {
        return mks_st_google_error($start);
    }

    $handle = fopen($path, 'rb');
    $put    = mks_st_google_request('PUT', $start['headers']['location'], ['Authorization: Bearer ' . $token, 'Content-Type: ' . $mime], null, $handle, $size);
    fclose($handle);

    if (!in_array($put['status'], [200, 201], true) || empty($put['json']['id'])) {
        return mks_st_google_error($put);
    }

    if ((int) $put['json']['size'] !== (int) $size || (isset($put['json']['md5Checksum']) && $put['json']['md5Checksum'] !== md5_file($path))) {
        return 'verify_failed';
    }

    $CI = &get_instance();
    $CI->db->where('id', (int) $event['id'])->update(mks_st_events_table(), [
        'drive_file_id'  => (string) $put['json']['id'],
        'drive_at'       => date('Y-m-d H:i:s'),
        'drive_attempts' => 0,
    ]);

    return true;
}

/**
 * Stream a recording from Drive to the browser, passing Range through so the
 * player can seek. Sends headers and body itself.
 *
 * @param  array  $event
 * @param  string $mime
 * @param  string|null $downloadName
 *
 * @return bool false when Drive could not be reached
 */
function mks_st_drive_stream(array $event, $mime, $downloadName = null)
{
    $access = mks_st_drive_access_token();

    if ($access['token'] === '') {
        return false;
    }

    if (session_status() === PHP_SESSION_ACTIVE) {
        session_write_close();
    }

    $headers = ['Authorization: Bearer ' . $access['token']];
    $range   = isset($_SERVER['HTTP_RANGE']) ? (string) $_SERVER['HTTP_RANGE'] : '';

    if (preg_match('/^bytes=\d*-\d*$/', $range)) {
        $headers[] = 'Range: ' . $range;
    }

    while (ob_get_level() > 0) {
        ob_end_clean();
    }

    $sent = false;
    $curl = curl_init(mks_st_google_url('apis') . '/drive/v3/files/' . rawurlencode($event['drive_file_id']) . '?alt=media');

    curl_setopt_array($curl, [
        CURLOPT_HTTPHEADER     => $headers,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_TIMEOUT        => 600,
        CURLOPT_HEADERFUNCTION => function ($ch, $line) use (&$sent, $mime, $downloadName) {
            if (preg_match('#^HTTP/\S+\s+(\d+)#', $line, $m)) {
                http_response_code((int) $m[1] === 206 ? 206 : ((int) $m[1] === 200 ? 200 : 502));
            } elseif (preg_match('/^(content-length|content-range):\s*(.+)$/i', trim($line), $m)) {
                header(ucwords(strtolower($m[1]), '-') . ': ' . $m[2]);
            } elseif (trim($line) === '' && !$sent) {
                header('Content-Type: ' . $mime);
                header('Accept-Ranges: bytes');
                header('Cache-Control: private, max-age=0');
                header('X-Content-Type-Options: nosniff');

                if ($downloadName !== null) {
                    header('Content-Disposition: attachment; filename="' . $downloadName . '"');
                }

                $sent = true;
            }

            return strlen($line);
        },
        CURLOPT_WRITEFUNCTION  => function ($ch, $chunk) {
            echo $chunk;
            flush();

            return strlen($chunk);
        },
    ]);

    $ok = curl_exec($curl) !== false;
    curl_close($curl);

    return $ok;
}

/* =========================================================================
 * THE CLEANUP RUN
 * ====================================================================== */

/**
 * Called from the cron run: upload new recordings to Drive, delete server
 * copies whose time is up, and apply retention. Best Pitches are never
 * deleted.
 *
 * @return array uploaded, failed, cleared, expired
 */
function mks_st_storage_run()
{
    $CI    = &get_instance();
    $table = mks_st_events_table();
    $out   = ['uploaded' => 0, 'failed' => 0, 'cleared' => 0, 'expired' => 0, 'error' => ''];
    $state = mks_st_drive_state();

    if (mks_st_setting('storage_mode') === 'drive' && $state['connected']) {
        $access = mks_st_drive_access_token();

        if ($access['token'] === '') {
            $out['error'] = $access['error'];
        } else {
            $queue = $CI->db->query('SELECT * FROM ' . $table . " WHERE recording_status = 'stored' AND drive_file_id IS NULL"
                . ' AND recording_file IS NOT NULL AND drive_attempts < ' . MKS_ST_DRIVE_MAX_ATTEMPTS
                . " AND source <> 'demo' ORDER BY recording_at ASC LIMIT " . MKS_ST_DRIVE_BATCH)->result_array();

            foreach ($queue as $event) {
                $result = mks_st_drive_upload($event, $access['token']);

                if ($result === true) {
                    $out['uploaded']++;
                } else {
                    $out['failed']++;
                    $out['error'] = $result;
                    $CI->db->where('id', (int) $event['id'])->update($table, ['drive_attempts' => (int) $event['drive_attempts'] + 1]);
                }
            }
        }

        // Server copies of recordings safely on Drive, once their time is up.
        $keep    = (int) mks_st_setting('drive_keep_days', 7);
        $cleared = $CI->db->query('SELECT id, recording_file FROM ' . $table . ' WHERE drive_file_id IS NOT NULL AND recording_file IS NOT NULL'
            . ' AND drive_at <= ' . $CI->db->escape(date('Y-m-d H:i:s', time() - $keep * 86400)) . ' LIMIT 200')->result_array();

        foreach ($cleared as $event) {
            mks_st_recording_unlink($event['recording_file']);
            $CI->db->where('id', (int) $event['id'])->update($table, ['recording_file' => null]);
            $out['cleared']++;
        }
    }

    // Retention for recordings kept on this server. Drive copies stay.
    $days = (int) mks_st_setting('recording_keep_days', 90);

    if ($days > 0) {
        $old = $CI->db->query('SELECT id, recording_file FROM ' . $table . " WHERE recording_status = 'stored' AND drive_file_id IS NULL"
            . ' AND best_pitch < 2 AND occurred_at < ' . $CI->db->escape(date('Y-m-d H:i:s', time() - $days * 86400)) . ' LIMIT 500')->result_array();

        foreach ($old as $event) {
            if ($event['recording_file'] !== null) {
                mks_st_recording_unlink($event['recording_file']);
            }

            $CI->db->where('id', (int) $event['id'])->update($table, [
                'recording_status' => 'expired',
                'recording_file'   => null,
                'recording_size'   => null,
            ]);
            $out['expired']++;
        }
    }

    if ($out['uploaded'] + $out['failed'] + $out['cleared'] + $out['expired'] > 0 || $out['error'] !== '') {
        $previous = json_decode((string) get_option(MKS_ST_DRIVE_STATUS_OPTION), true);
        $previous = is_array($previous) ? $previous : [];

        mks_st_option_put(MKS_ST_DRIVE_STATUS_OPTION, json_encode([
            'at'       => date('Y-m-d H:i:s'),
            'uploaded' => (isset($previous['uploaded']) ? (int) $previous['uploaded'] : 0) + $out['uploaded'],
            'error'    => $out['error'],
        ]), 0);
    }

    return $out;
}
