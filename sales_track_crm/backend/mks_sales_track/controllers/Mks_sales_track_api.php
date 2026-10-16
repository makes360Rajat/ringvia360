<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - phone app API.
 *
 * Routes: mks_sales_track/api/v1/{ping|pair|config|sync|recording}
 *
 * Extends App_Controller, the base Perfex's own public endpoints sit on: no
 * staff or customer session is wanted, hooks and the database behave normally.
 * The full contract is in docs/API.md.
 *
 * Every reply is JSON, including errors. The database runs with db_debug off
 * here, because CodeIgniter's HTML error page is the one response a phone app
 * can never parse.
 *
 * A phone pairs with the 6-digit code of a device created in the CRM, then
 * reports with that device's token. Commands queued in the CRM ride back on
 * the heartbeat. A minimum app version set in the CRM turns sync and upload
 * away with 426 until the app is updated; ping and config keep answering so
 * the app can tell the user.
 *
 * Four things this controller is shaped around, each learned the hard way on
 * this hosting:
 *   - JSON bodies never reach $_POST, so the body is read from php://input.
 *   - Shared hosting can strip the Authorization header, so the token is
 *     accepted from X-Sales-Track-Token, Authorization: Bearer, or the body.
 *   - post_max_size overflow silently empties $_POST and $_FILES, so a too
 *     large recording is detected from Content-Length and named as such.
 *   - get_staff_user_id() is empty here; the device row says who is acting.
 */
class Mks_sales_track_api extends App_Controller
{
    /** @var array|null decoded request body */
    private $mksBody = null;

    /** @var array|null the authenticated device */
    private $mksDevice = null;

    public function __construct()
    {
        parent::__construct();

        $this->db->db_debug = false;
    }

    /**
     * The whitelist. Nothing outside it is reachable.
     *
     * @param  string $endpoint
     * @param  array  $params
     *
     * @return void
     */
    public function _remap($endpoint, $params = [])
    {
        $routes = [
            'ping'      => ['methods' => ['GET', 'POST'], 'handler' => 'mks_ping'],
            'pair'      => ['methods' => ['POST'], 'handler' => 'mks_pair'],
            'config'    => ['methods' => ['GET', 'POST'], 'handler' => 'mks_config'],
            'sync'      => ['methods' => ['POST'], 'handler' => 'mks_sync'],
            'recording' => ['methods' => ['POST'], 'handler' => 'mks_recording'],
            'outcome'   => ['methods' => ['POST'], 'handler' => 'mks_outcome'],
            'lists'     => ['methods' => ['GET', 'POST'], 'handler' => 'mks_lists'],
            'directory' => ['methods' => ['GET', 'POST'], 'handler' => 'mks_directory'],
            'lookup'    => ['methods' => ['GET', 'POST'], 'handler' => 'mks_lookup'],
        ];

        $endpoint = strtolower((string) $endpoint);

        if (!isset($routes[$endpoint])) {
            $this->mks_fail(404, 'not_found');
        }

        if (!function_exists('mks_st_ingest') || !function_exists('mks_st_view_columns')) {
            $this->mks_fail(503, 'module_incomplete');
        }

        if (!mks_st_enabled()) {
            $this->mks_fail(503, 'module_disabled');
        }

        if ($endpoint !== 'ping' && !mks_st_enabled('api_enabled')) {
            $this->mks_fail(503, 'api_disabled');
        }

        $method = strtoupper(isset($_SERVER['REQUEST_METHOD']) ? $_SERVER['REQUEST_METHOD'] : 'GET');

        if (!in_array($method, $routes[$endpoint]['methods'], true)) {
            $this->mks_fail(405, 'method_not_allowed');
        }

        // An upload over the top of older files must not meet an old schema.
        if (function_exists('mks_st_maybe_upgrade')) {
            mks_st_maybe_upgrade();
        }

        $this->{$routes[$endpoint]['handler']}();
    }

    /* ---------------------------------------------------------------------
     * Endpoints
     * ------------------------------------------------------------------ */

    /**
     * Unauthenticated. Lets an app confirm an address really is a Sales Track
     * CRM before asking anybody for a code.
     *
     * @return void
     */
    private function mks_ping()
    {
        $this->mks_send(200, [
            'success'        => true,
            'name'           => 'Sales Track',
            'api'            => 'v1',
            'module_version' => MKS_SALES_TRACK_VERSION,
            'pairing'        => mks_st_enabled('api_enabled'),
            'server_time'    => (int) round(microtime(true) * 1000),
        ]);
    }

    /**
     * Exchange a pairing code for a device token.
     *
     * @return void
     */
    private function mks_pair()
    {
        $body   = $this->mks_body();
        $code   = isset($body['code']) && is_scalar($body['code']) ? trim((string) $body['code']) : '';
        $device = isset($body['device']) ? $body['device'] : null;

        if ($code === '' || !is_array($device)) {
            $this->mks_fail(400, 'invalid_request');
        }

        $info = mks_st_clean_device_info($device);

        if ($info === false) {
            $this->mks_fail(422, 'invalid_device');
        }

        $ip   = (string) $this->input->ip_address();
        $wait = mks_st_pairing_locked($ip);

        if ($wait > 0) {
            header('Retry-After: ' . $wait);
            $this->mks_fail(429, 'too_many_attempts', ['retry_after' => $wait]);
        }

        $entry = mks_st_pairing_redeem($code, $ip);

        if (!is_array($entry)) {
            $this->mks_fail($entry === 'code_expired' ? 410 : 401, $entry);
        }

        $target = mks_st_device_get($entry['device_id']);

        if (!$target || $target['status'] === 'revoked') {
            $this->mks_fail(401, 'invalid_code');
        }

        if (!mks_st_staff_active($target['staff_id'])) {
            $this->mks_fail(403, 'staff_inactive');
        }

        $paired = mks_st_device_bind($target, $info, $ip);

        if (!$paired || !$paired['device']) {
            $this->mks_fail(500, 'store_failed');
        }

        mks_st_pairing_mark_used($entry['id'], $paired['device']['id']);

        log_activity('Sales Track: phone paired [' . $target['label'] . ', ' . trim($info['manufacturer'] . ' ' . $info['model'])
            . ', ' . $info['platform'] . ', Staff: ' . mks_st_staff_name($target['staff_id']) . ']', (int) $entry['by'] ?: null);

        $this->mks_send(200, [
            'success'         => true,
            'token'           => $paired['token'],
            'device'          => mks_st_device_public($paired['device']),
            'staff'           => $this->mks_staff($paired['device']['staff_id']),
            'config'          => mks_st_device_config($paired['device']),
            'update_required' => mks_st_app_update_required($paired['device']['app_version']),
            'commands'        => [],
        ]);
    }

    /**
     * Heartbeat and configuration. Whatever the phone reports about itself is
     * stored; what it should collect is returned.
     *
     * @return void
     */
    private function mks_config()
    {
        $this->mks_auth();

        $body = $this->mks_body();

        // Lost permissions and tampering the phone noticed become alerts.
        if (isset($body['health']) && is_array($body['health'])) {
            mks_st_device_health_check($this->mksDevice, mks_st_clean_health($body['health']));
        }

        if (isset($body['tamper']) && is_array($body['tamper'])) {
            foreach (array_slice($body['tamper'], 0, 20) as $tamper) {
                if (is_array($tamper) && isset($tamper['type']) && is_string($tamper['type'])) {
                    mks_st_device_alert(mks_st_device_get($this->mksDevice['id']), $tamper['type'], isset($tamper['detail']) && is_scalar($tamper['detail']) ? (string) $tamper['detail'] : '');
                }
            }
        }

        mks_st_device_report($this->mksDevice['id'], $body);

        $device   = mks_st_device_get($this->mksDevice['id']);
        $commands = mks_st_device_commands_exchange($device, isset($body['acks']) ? $body['acks'] : []);

        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_lists_helper.php');

        $salt   = (string) get_option('mks_sales_track_salt');
        $config = mks_st_device_config($device);

        // Do-not-call numbers travel as salted hashes, like excluded ones.
        $config['do_not_call'] = ['salt' => $salt, 'hashes' => array_map(function ($key) use ($salt) {
            return hash('sha256', $salt . $key);
        }, array_keys(mks_st_dnc_keys()))];

        $config['popup'] = [
            'directory' => mks_st_enabled('directory_enabled'),
            'incoming'  => mks_st_enabled('directory_enabled') && mks_st_enabled('popup_incoming'),
            'outgoing'  => mks_st_enabled('directory_enabled') && mks_st_enabled('popup_outgoing'),
            'version'   => mks_st_enabled('directory_enabled') ? mks_st_directory_version($device['staff_id']) : '',
        ];

        $config['call_lists'] = count(array_filter(mks_st_lists(), function ($list) use ($device) {
            return $list['status'] === 'active' && in_array((int) $device['staff_id'], array_map('intval', $list['staff']), true);
        }));

        $this->mks_send(200, [
            'success'         => true,
            'device'          => mks_st_device_public($device),
            'staff'           => $this->mks_staff($device['staff_id']),
            'config'          => $config,
            'update_required' => mks_st_app_update_required($device['app_version']),
            'commands'        => $commands,
        ]);
    }

    /**
     * The phone owner's active call lists with their own leads; POST can
     * skip leads or bring them back: {"skip": [{"list_id": 1, "lead_id": 7}], "unskip": [...]}.
     *
     * @return void
     */
    private function mks_lists()
    {
        $this->mks_auth();
        $this->mks_require_current_app();

        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_lists_helper.php');

        $staffId = (int) $this->mksDevice['staff_id'];
        $body    = $this->input->method() === 'post' ? $this->mks_body() : [];

        foreach (['skip' => true, 'unskip' => false] as $key => $skip) {
            foreach (isset($body[$key]) && is_array($body[$key]) ? array_slice($body[$key], 0, 100) : [] as $item) {
                $list = is_array($item) && isset($item['list_id'], $item['lead_id']) ? mks_st_list_get((int) $item['list_id']) : null;

                // A phone may only touch its owner's own leads on an active list.
                if ($list && $list['status'] === 'active' && isset($list['assign'][(int) $item['lead_id']]) && (int) $list['assign'][(int) $item['lead_id']] === $staffId) {
                    mks_st_list_skip($list, (int) $item['lead_id'], $skip);
                }
            }
        }

        $this->mks_send(200, ['success' => true, 'lists' => mks_st_lists_for($staffId)]);
    }

    /**
     * Everyone the phone can recognise for the caller popup, a page at a time.
     *
     * @return void
     */
    private function mks_directory()
    {
        $this->mks_auth();
        $this->mks_require_current_app();

        if (!mks_st_enabled('directory_enabled')) {
            $this->mks_fail(403, 'directory_disabled');
        }

        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_lists_helper.php');

        $page    = max(1, (int) $this->input->get_post('page'));
        $entries = array_values(mks_st_directory((int) $this->mksDevice['staff_id']));
        $size    = 1000;

        $this->mks_send(200, [
            'success' => true,
            'version' => mks_st_directory_version((int) $this->mksDevice['staff_id']),
            'page'    => $page,
            'pages'   => max(1, (int) ceil(count($entries) / $size)),
            'total'   => count($entries),
            'entries' => array_slice($entries, ($page - 1) * $size, $size),
        ]);
    }

    /**
     * One number, for a caller the phone's copy does not know yet.
     *
     * @return void
     */
    private function mks_lookup()
    {
        $this->mks_auth();
        $this->mks_require_current_app();

        if (!mks_st_enabled('directory_enabled')) {
            $this->mks_fail(403, 'directory_disabled');
        }

        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_lists_helper.php');

        $key     = mks_st_lst_key((string) $this->input->get_post('number'));
        $entries = $key !== '' ? mks_st_directory((int) $this->mksDevice['staff_id']) : [];

        $this->mks_send(200, ['success' => true, 'found' => isset($entries[$key]), 'entry' => isset($entries[$key]) ? $entries[$key] : null]);
    }

    /**
     * A batch of events.
     *
     * @return void
     */
    private function mks_sync()
    {
        $this->mks_auth();
        $this->mks_require_current_app();

        $body   = $this->mks_body();
        $events = isset($body['events']) ? $body['events'] : null;

        if (!is_array($events)) {
            $this->mks_fail(400, 'invalid_request');
        }

        if (count($events) > MKS_ST_BATCH_MAX) {
            $this->mks_fail(413, 'batch_too_large', ['max' => MKS_ST_BATCH_MAX]);
        }

        $result = mks_st_ingest($this->mksDevice, array_values($events));

        if ($result === false) {
            $this->mks_fail(500, 'store_failed');
        }

        mks_st_device_log_sync($this->mksDevice['id'], $result, $this->mksDevice);

        $config = mks_st_device_config($this->mksDevice);

        $this->mks_send(200, array_merge(['success' => true], $result, [
            'config_version' => $config['version'],
        ]));
    }

    /**
     * One recording for one call, as multipart/form-data with fields uid and
     * file. The call must have been synced first.
     *
     * @return void
     */
    private function mks_recording()
    {
        $length = isset($_SERVER['CONTENT_LENGTH']) ? (int) $_SERVER['CONTENT_LENGTH'] : 0;
        $postMax = mks_st_ini_bytes(ini_get('post_max_size'));

        // Over post_max_size PHP discards the whole body, token field
        // included, so this check has to come before authentication reads it.
        if ($postMax > 0 && $length > $postMax) {
            $this->mks_fail(413, 'file_too_large', ['max_mb' => mks_st_recording_limit_mb()]);
        }

        $this->mks_auth();
        $this->mks_require_current_app();

        if (!mks_st_enabled('track_recordings')) {
            $this->mks_fail(403, 'recordings_off');
        }

        $uid = isset($_POST['uid']) ? mks_st_clean_uid($_POST['uid']) : '';

        if ($uid === '') {
            $this->mks_fail(400, 'invalid_request');
        }

        $event = mks_st_event_by_uid($this->mksDevice['id'], $uid, $this->mksDevice['staff_id']);

        if (!$event) {
            // Auto-heal: If UID has a timestamp, create call record so recording is never dropped
            if (preg_match('/(\d{10,13})$/', $uid, $m)) {
                $tsMs  = (int) $m[1];
                $tsSec = $tsMs > 100000000000 ? (int) floor($tsMs / 1000) : $tsMs;
                $now   = date('Y-m-d H:i:s');
                $synth = mks_st_event_template();
                $synth['device_id']        = (int) $this->mksDevice['id'];
                $synth['staff_id']         = (int) $this->mksDevice['staff_id'];
                $synth['uid']              = $uid;
                $synth['kind']             = 'call';
                $synth['direction']        = 'outgoing';
                $synth['occurred_at']      = date('Y-m-d H:i:s', $tsSec);
                $synth['received_at']      = $now;
                $synth['recording_status'] = 'pending';
                $this->db->insert(mks_st_events_table(), $synth);
                $event = mks_st_event_get($this->db->insert_id());
            }

            if (!$event) {
                $this->mks_fail(404, 'event_not_found');
            }
        }

        if ($event['kind'] !== 'call') {
            $this->mks_fail(422, 'not_a_call');
        }

        if ($event['recording_status'] === 'stored') {
            $this->mks_send(200, ['success' => true, 'uid' => $uid, 'already' => true]);
        }

        $check = mks_st_validate_recording_upload(isset($_FILES['file']) ? $_FILES['file'] : null);

        if (!is_array($check)) {
            $status = ['file_too_large' => 413, 'unsupported_type' => 415, 'missing_file' => 400];

            $this->mks_fail(isset($status[$check]) ? $status[$check] : 400, $check, ['max_mb' => mks_st_recording_limit_mb()]);
        }

        if (!mks_st_store_recording($event, $_FILES['file']['tmp_name'], $check['ext'], $check['mime'], true)) {
            $this->mks_fail(500, 'store_failed');
        }

        $stored = mks_st_event_get($event['id']);

        $this->mks_send(200, [
            'success' => true,
            'uid'     => $uid,
            'size'    => (int) $stored['recording_size'],
        ]);
    }

    /* ---------------------------------------------------------------------
     * Plumbing
     * ------------------------------------------------------------------ */

    /**
     * Resolve the device from its token, or stop with 401.
     *
     * @return void
     */
    private function mks_auth()
    {
        $token = $this->mks_token();

        if ($token === '') {
            $this->mks_fail(401, 'missing_token');
        }

        $device = mks_st_device_by_token($token);

        if (!$device) {
            $this->mks_fail(401, 'invalid_token');
        }

        if ($device['status'] === 'revoked') {
            $this->mks_fail(401, 'device_revoked');
        }

        $claimed = isset($_SERVER['HTTP_X_SALES_TRACK_DEVICE']) ? trim((string) $_SERVER['HTTP_X_SALES_TRACK_DEVICE']) : '';

        if ($claimed === '') {
            $body    = $this->mks_body();
            $claimed = isset($body['device_uid']) && is_scalar($body['device_uid']) ? trim((string) $body['device_uid']) : '';
        }

        if ($claimed !== '' && !hash_equals((string) $device['device_uid'], $claimed)) {
            $this->mks_fail(401, 'device_mismatch');
        }

        if (!mks_st_staff_active($device['staff_id'])) {
            $this->mks_fail(403, 'staff_inactive');
        }

        mks_st_device_touch($device['id'], (string) $this->input->ip_address());

        $this->mksDevice = $device;
    }

    /**
     * Outcomes from the after-call popup, one or many (the phone queues them
     * while offline). Each names the call by the uid it was synced with.
     *
     * @return void
     */
    private function mks_outcome()
    {
        $this->mks_auth();
        $this->mks_require_current_app();

        $body  = $this->mks_body();
        $items = isset($body['items']) && is_array($body['items']) ? array_values($body['items']) : [];

        if (!$items) {
            $this->mks_fail(422, 'invalid_request');
        }

        if (count($items) > 100) {
            $this->mks_fail(413, 'batch_too_large', ['max' => 100]);
        }

        $stored   = [];
        $rejected = [];
        $leads    = [];

        foreach ($items as $item) {
            $uid = is_array($item) ? mks_st_clean_uid(isset($item['uid']) ? $item['uid'] : '') : '';

            if ($uid === '') {
                $rejected[] = ['uid' => is_array($item) && isset($item['uid']) && is_scalar($item['uid']) ? (string) $item['uid'] : '', 'reason' => 'invalid_uid'];

                continue;
            }

            $event = mks_st_event_by_uid($this->mksDevice['id'], $uid);

            if (!$event) {
                $rejected[] = ['uid' => $uid, 'reason' => 'event_not_found'];

                continue;
            }

            if (!empty($item['create_lead']) && !mks_st_enabled('lead_create_phone')) {
                unset($item['create_lead']);
            }

            $result = mks_st_apply_outcome($event, $item, (int) $this->mksDevice['staff_id']);

            if ($result['ok']) {
                $stored[] = $uid;

                if ($result['lead_id'] > 0) {
                    $leads[$uid] = $result['lead_id'];
                }
            } else {
                $rejected[] = ['uid' => $uid, 'reason' => $result['error']];
            }
        }

        $this->mks_send(200, ['success' => true, 'stored' => $stored, 'rejected' => $rejected, 'leads' => (object) $leads]);
    }

    /**
     * Turn sync and uploads away from an app older than the minimum version
     * set in the CRM. The app learns why from config, which still answers.
     *
     * @return void
     */
    private function mks_require_current_app()
    {
        if (mks_st_app_update_required($this->mksDevice['app_version'])) {
            $this->mks_fail(426, 'update_required', ['min_version' => (string) mks_st_setting('min_app_version', '')]);
        }
    }

    /**
     * @return string
     */
    private function mks_token()
    {
        $candidates = [];

        if (isset($_SERVER['HTTP_X_SALES_TRACK_TOKEN'])) {
            $candidates[] = $_SERVER['HTTP_X_SALES_TRACK_TOKEN'];
        }

        foreach (['HTTP_AUTHORIZATION', 'REDIRECT_HTTP_AUTHORIZATION'] as $key) {
            if (isset($_SERVER[$key]) && preg_match('/^\s*Bearer\s+(\S+)\s*$/i', (string) $_SERVER[$key], $m)) {
                $candidates[] = $m[1];
            }
        }

        $body = $this->mks_body();

        if (isset($body['token'])) {
            $candidates[] = $body['token'];
        }

        foreach ($candidates as $candidate) {
            $candidate = is_scalar($candidate) ? strtolower(trim((string) $candidate)) : '';

            if (preg_match('/^[a-f0-9]{64}$/', $candidate)) {
                return $candidate;
            }
        }

        return '';
    }

    /**
     * The request body as an array, from JSON or form fields.
     *
     * @return array
     */
    private function mks_body()
    {
        if ($this->mksBody !== null) {
            return $this->mksBody;
        }

        $this->mksBody = [];

        $type = isset($_SERVER['CONTENT_TYPE']) ? strtolower((string) $_SERVER['CONTENT_TYPE']) : '';

        if (strpos($type, 'application/json') !== false) {
            $raw = file_get_contents('php://input');

            if (is_string($raw) && $raw !== '') {
                if (strlen($raw) > 4194304) {
                    $this->mks_fail(413, 'payload_too_large');
                }

                $decoded = json_decode($raw, true);

                if (!is_array($decoded)) {
                    $this->mks_fail(400, 'invalid_json');
                }

                $this->mksBody = $decoded;
            }
        } elseif (!empty($_POST)) {
            $this->mksBody = $_POST;
        }

        return $this->mksBody;
    }

    /**
     * @param  int $staff_id
     *
     * @return array
     */
    private function mks_staff($staff_id)
    {
        return [
            'id'   => (int) $staff_id,
            'name' => mks_st_staff_name($staff_id),
        ];
    }

    /**
     * @param  int    $status
     * @param  string $code
     * @param  array  $extra
     *
     * @return void
     */
    private function mks_fail($status, $code, array $extra = [])
    {
        $this->mks_send($status, array_merge([
            'success' => false,
            'error'   => $code,
            'message' => function_exists('mks_st_api_message') ? mks_st_api_message($code) : $code,
        ], $extra));
    }

    /**
     * @param  int   $status
     * @param  array $payload
     *
     * @return void
     */
    private function mks_send($status, array $payload)
    {
        $payload['server_time'] = (int) round(microtime(true) * 1000);

        http_response_code((int) $status);
        header('Content-Type: application/json; charset=utf-8');
        header('Cache-Control: no-store');
        header('X-Content-Type-Options: nosniff');
        header('X-Robots-Tag: noindex, nofollow');

        echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
        exit;
    }
}
