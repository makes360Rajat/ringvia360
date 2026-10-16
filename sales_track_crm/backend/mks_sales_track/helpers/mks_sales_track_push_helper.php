<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - push to phones through Firebase Cloud Messaging.
 *
 * Loaded on demand: by Settings when a key is saved, and by the API and the
 * screens when a command goes to a phone. Nothing here runs on an ordinary
 * page load.
 *
 * The CRM talks to FCM's HTTP v1 API as a Google service account: it signs a
 * short JWT with the account's private key (RS256), exchanges it for an access
 * token at Google's token endpoint, and posts data messages to each phone's
 * registration token. The key is stored encrypted with the CRM's own
 * encryption key, in its own option that is never autoloaded and never sent
 * back to the browser. The access token is cached until shortly before it
 * expires.
 *
 * Messages carry data only (no notification block): the app wakes, reads the
 * command and acts, so nothing appears in the phone's notification shade.
 */

/** Option holding the encrypted service account key and its public details. */
define('MKS_ST_FCM_OPTION', 'mks_sales_track_fcm');

/** Option caching the encrypted access token and its expiry. */
define('MKS_ST_FCM_TOKEN_OPTION', 'mks_sales_track_fcm_token');

/**
 * Validate and store a service account key pasted into Settings.
 *
 * @param  string $json
 *
 * @return true|string true, or a language key for the error
 */
function mks_st_fcm_save_key($json)
{
    $key = json_decode((string) $json, true);

    if (!is_array($key) || (isset($key['type']) && $key['type'] !== 'service_account')
        || empty($key['project_id']) || empty($key['client_email']) || empty($key['private_key'])) {
        return 'mks_st_err_fcm_key';
    }

    if (!function_exists('openssl_pkey_get_private') || openssl_pkey_get_private((string) $key['private_key']) === false) {
        return 'mks_st_err_fcm_private_key';
    }

    $CI = &get_instance();

    mks_st_option_put(MKS_ST_FCM_OPTION, json_encode([
        'project_id'   => (string) $key['project_id'],
        'client_email' => (string) $key['client_email'],
        'secret'       => $CI->encryption->encrypt(json_encode([
            'private_key' => (string) $key['private_key'],
            'token_uri'   => isset($key['token_uri']) ? (string) $key['token_uri'] : 'https://oauth2.googleapis.com/token',
        ])),
        'saved_at'     => date('Y-m-d H:i:s'),
    ]), 0);

    mks_st_option_put(MKS_ST_FCM_TOKEN_OPTION, '', 0);

    return true;
}

/**
 * @return void
 */
function mks_st_fcm_clear()
{
    mks_st_option_put(MKS_ST_FCM_OPTION, '', 0);
    mks_st_option_put(MKS_ST_FCM_TOKEN_OPTION, '', 0);
}

/**
 * What Settings may show about the stored key: never the key itself.
 *
 * @return array configured, project_id, client_email, saved_at
 */
function mks_st_fcm_status()
{
    $stored = json_decode((string) get_option(MKS_ST_FCM_OPTION), true);

    if (!is_array($stored) || empty($stored['secret'])) {
        return ['configured' => false, 'project_id' => '', 'client_email' => '', 'saved_at' => ''];
    }

    return [
        'configured'   => true,
        'project_id'   => (string) $stored['project_id'],
        'client_email' => (string) $stored['client_email'],
        'saved_at'     => (string) $stored['saved_at'],
    ];
}

/**
 * The decrypted credentials, or null.
 *
 * @return array|null project_id, client_email, private_key, token_uri
 */
function mks_st_fcm_credentials()
{
    $stored = json_decode((string) get_option(MKS_ST_FCM_OPTION), true);

    if (!is_array($stored) || empty($stored['secret'])) {
        return null;
    }

    $CI     = &get_instance();
    $secret = json_decode((string) $CI->encryption->decrypt($stored['secret']), true);

    if (!is_array($secret) || empty($secret['private_key'])) {
        return null;
    }

    return [
        'project_id'   => (string) $stored['project_id'],
        'client_email' => (string) $stored['client_email'],
        'private_key'  => (string) $secret['private_key'],
        'token_uri'    => defined('MKS_ST_GOOGLE_BASE') ? mks_st_google_url('oauth') . '/token' : (string) $secret['token_uri'],
    ];
}

/**
 * @param  string $data
 *
 * @return string
 */
function mks_st_base64url($data)
{
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

/**
 * The signed assertion Google exchanges for an access token.
 *
 * @param  array $cred
 * @param  int   $now
 *
 * @return string|false
 */
function mks_st_fcm_jwt(array $cred, $now)
{
    $header = mks_st_base64url(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
    $claims = mks_st_base64url(json_encode([
        'iss'   => $cred['client_email'],
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud'   => $cred['token_uri'],
        'iat'   => (int) $now,
        'exp'   => (int) $now + 3600,
    ]));

    $key = openssl_pkey_get_private($cred['private_key']);

    if ($key === false || !openssl_sign($header . '.' . $claims, $signature, $key, OPENSSL_ALGO_SHA256)) {
        return false;
    }

    return $header . '.' . $claims . '.' . mks_st_base64url($signature);
}

/**
 * One HTTPS request to Google.
 *
 * @param  string $url
 * @param  array  $headers
 * @param  string $body
 *
 * @return array status, json, error
 */
function mks_st_fcm_http($url, array $headers, $body)
{
    if (!function_exists('curl_init')) {
        return ['status' => 0, 'json' => null, 'error' => 'curl_missing'];
    }

    $curl = curl_init($url);
    curl_setopt_array($curl, [
        CURLOPT_POST           => true,
        CURLOPT_POSTFIELDS     => $body,
        CURLOPT_HTTPHEADER     => $headers,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 5,
        CURLOPT_TIMEOUT        => 10,
    ]);

    $raw    = curl_exec($curl);
    $status = (int) curl_getinfo($curl, CURLINFO_HTTP_CODE);
    $error  = $raw === false ? curl_error($curl) : '';

    curl_close($curl);

    return ['status' => $status, 'json' => json_decode((string) $raw, true), 'error' => $error];
}

/**
 * An access token for FCM, cached until a minute before it expires.
 *
 * @return array token, error
 */
function mks_st_fcm_access_token()
{
    $CI     = &get_instance();
    $cached = json_decode((string) get_option(MKS_ST_FCM_TOKEN_OPTION), true);

    if (is_array($cached) && isset($cached['expires'], $cached['token']) && $cached['expires'] > time() + 60) {
        $token = $CI->encryption->decrypt($cached['token']);

        if (is_string($token) && $token !== '') {
            return ['token' => $token, 'error' => ''];
        }
    }

    $cred = mks_st_fcm_credentials();

    if ($cred === null) {
        return ['token' => '', 'error' => 'not_configured'];
    }

    $jwt = mks_st_fcm_jwt($cred, time());

    if ($jwt === false) {
        return ['token' => '', 'error' => 'sign_failed'];
    }

    $reply = mks_st_fcm_http($cred['token_uri'], ['Content-Type: application/x-www-form-urlencoded'],
        http_build_query(['grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer', 'assertion' => $jwt]));

    if ($reply['status'] !== 200 || empty($reply['json']['access_token'])) {
        $detail = isset($reply['json']['error_description']) ? $reply['json']['error_description'] : ($reply['error'] ?: 'HTTP ' . $reply['status']);

        return ['token' => '', 'error' => 'auth_failed: ' . mks_st_clean_line($detail, 160)];
    }

    $lifetime = isset($reply['json']['expires_in']) ? (int) $reply['json']['expires_in'] : 3600;

    mks_st_option_put(MKS_ST_FCM_TOKEN_OPTION, json_encode([
        'token'   => $CI->encryption->encrypt($reply['json']['access_token']),
        'expires' => time() + $lifetime,
    ]), 0);

    return ['token' => $reply['json']['access_token'], 'error' => ''];
}

/**
 * The FCM message for a command: data only, high priority, short-lived.
 *
 * @param  string $token  the phone's registration token
 * @param  array  $data   string values only
 * @param  int    $ttl    seconds
 *
 * @return array
 */
function mks_st_fcm_message($token, array $data, $ttl)
{
    return [
        'message' => [
            'token'   => (string) $token,
            'data'    => array_map('strval', $data),
            'android' => ['priority' => 'high', 'ttl' => (int) $ttl . 's'],
            'apns'    => ['headers' => ['apns-priority' => '10', 'apns-push-type' => 'background'], 'payload' => ['aps' => ['content-available' => 1]]],
        ],
    ];
}

/**
 * Push a data message to one phone.
 *
 * @param  array $device
 * @param  array $data
 * @param  int   $ttl
 *
 * @return array ok, error
 */
function mks_st_fcm_send(array $device, array $data, $ttl = 120)
{
    if (empty($device['push_token'])) {
        return ['ok' => false, 'error' => 'no_push_token'];
    }

    $cred   = mks_st_fcm_credentials();
    $access = mks_st_fcm_access_token();

    if ($cred === null || $access['token'] === '') {
        return ['ok' => false, 'error' => $access['error'] ?: 'not_configured'];
    }

    $reply = mks_st_fcm_http(mks_st_google_url('fcm') . '/v1/projects/' . rawurlencode($cred['project_id']) . '/messages:send',
        ['Content-Type: application/json', 'Authorization: Bearer ' . $access['token']],
        json_encode(mks_st_fcm_message($device['push_token'], $data, $ttl)));

    if ($reply['status'] === 200) {
        return ['ok' => true, 'error' => ''];
    }

    // A token the phone no longer holds is forgotten, so the next command
    // waits for the heartbeat instead of failing again.
    $code = isset($reply['json']['error']['status']) ? $reply['json']['error']['status'] : '';

    if (in_array($code, ['NOT_FOUND', 'UNREGISTERED'], true) || ($code === 'INVALID_ARGUMENT' && $reply['status'] === 400)) {
        $CI = &get_instance();
        $CI->db->where('id', (int) $device['id'])->update(mks_st_devices_table(), ['push_token' => null]);
    }

    $detail = isset($reply['json']['error']['message']) ? $reply['json']['error']['message'] : ($reply['error'] ?: 'HTTP ' . $reply['status']);

    return ['ok' => false, 'error' => mks_st_clean_line($detail, 200)];
}
