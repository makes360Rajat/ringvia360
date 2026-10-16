<?php

/**
 * MKS Sales Track - end to end test against a running CRM.
 *
 *   php tooling/e2e.php --url=https://staging.example.com/ --email=admin@example.com --password=secret
 *
 * Signs in as an administrator and drives the module the way people and
 * phones do: renders every screen, adds a device, pairs a simulated phone with
 * its 6-digit code, round-trips a command, syncs and re-sends a batch, pauses
 * and resumes, uploads and streams a recording, refuses a disguised file,
 * swaps the handset with a regenerated code, then revokes and deletes the
 * device. Everything it creates is removed again at the end.
 *
 * Run it against a staging copy where possible. It needs an administrator
 * without two factor sign in and at least one active staff member.
 */

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

$args = [];

foreach (array_slice($argv, 1) as $arg) {
    if (preg_match('/^--([a-z]+)=(.*)$/', $arg, $m)) {
        $args[$m[1]] = $m[2];
    }
}

foreach (['url', 'email', 'password'] as $required) {
    if (empty($args[$required])) {
        fwrite(STDERR, "Usage: php tooling/e2e.php --url=... --email=... --password=...\n");
        exit(2);
    }
}

$base   = rtrim($args['url'], '/') . '/';
$api    = $base . 'mks_sales_track/api/v1/';
$jar    = tempnam(sys_get_temp_dir(), 'mks_st_e2e_');
$run    = (string) time();
$marker = '+9190' . substr($run, -8);
$pass   = 0;
$fail   = 0;
$csrf   = [];

function check($ok, $name, $note = '')
{
    global $pass, $fail;

    $ok ? $pass++ : $fail++;
    echo ($ok ? 'PASS  ' : 'FAIL  ') . $name . ($ok || $note === '' ? '' : "\n      " . $note) . "\n";
}

/**
 * @return array status, headers, body, json
 */
function http($method, $url, $data = null, array $headers = [], $form = false)
{
    global $jar;

    $curl = curl_init($url);
    curl_setopt_array($curl, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HEADER         => true,
        CURLOPT_COOKIEJAR      => $jar,
        CURLOPT_COOKIEFILE     => $jar,
        CURLOPT_CUSTOMREQUEST  => $method,
        CURLOPT_TIMEOUT        => 60,
    ]);

    if ($data !== null) {
        if ($form === 'multipart') {
            curl_setopt($curl, CURLOPT_POSTFIELDS, $data);
        } elseif ($form) {
            curl_setopt($curl, CURLOPT_POSTFIELDS, http_build_query($data));
        } else {
            $headers[] = 'Content-Type: application/json';
            curl_setopt($curl, CURLOPT_POSTFIELDS, json_encode($data));
        }
    }

    curl_setopt($curl, CURLOPT_HTTPHEADER, $headers);

    $raw    = (string) curl_exec($curl);
    $status = (int) curl_getinfo($curl, CURLINFO_HTTP_CODE);
    $size   = (int) curl_getinfo($curl, CURLINFO_HEADER_SIZE);

    curl_close($curl);

    $body = substr($raw, $size);

    return ['status' => $status, 'headers' => substr($raw, 0, $size), 'body' => $body, 'json' => json_decode($body, true)];
}

/**
 * The CSRF token name and hash Perfex prints into every admin page.
 */
function csrf_from($html)
{
    if (preg_match('/var csrfData = (\{.*?\})\s*;/s', $html, $m)) {
        $data = json_decode($m[1], true);

        if (is_array($data) && isset($data['token_name'], $data['hash'])) {
            return [$data['token_name'] => $data['hash']];
        }
    }

    return preg_match('/name="([a-z_]+)" value="([a-f0-9]{32})"/', $html, $m) ? [$m[1] => $m[2]] : [];
}

function admin_post($path, array $data)
{
    global $base, $csrf;

    $reply = http('POST', $base . $path, $data + $csrf, ['X-Requested-With: XMLHttpRequest'], true);

    if (isset($reply['json']['csrf']['name'])) {
        $csrf = [$reply['json']['csrf']['name'] => $reply['json']['csrf']['hash']];
    }

    return $reply;
}

function pair_phone($code, $uid, $platform)
{
    global $api;

    return http('POST', $api . 'pair', [
        'code'   => str_replace(' ', '', (string) $code),
        'device' => ['uid' => $uid, 'platform' => $platform, 'manufacturer' => 'E2E', 'model' => 'Test Phone', 'os_version' => '14', 'app_version' => 'e2e'],
    ]);
}

function _e2e_registered()
{
    return 'Registered';
}

function wav($seconds)
{
    $rate = 8000;
    $data = '';

    for ($i = 0; $i < $rate * $seconds; $i++) {
        $data .= pack('v', (int) (sin(2 * M_PI * 440 * $i / $rate) * 2000) & 0xFFFF);
    }

    return 'RIFF' . pack('V', 36 + strlen($data)) . 'WAVEfmt ' . pack('VvvVVvv', 16, 1, 1, $rate, $rate * 2, 2, 16)
        . 'data' . pack('V', strlen($data)) . $data;
}

echo "MKS Sales Track - end to end against " . $base . "\n" . str_repeat('=', 66) . "\n";

/* Sign in */
$login = http('GET', $base . 'admin/authentication');
$csrf  = csrf_from($login['body']);
http('POST', $base . 'admin/authentication', ['email' => $args['email'], 'password' => $args['password']] + $csrf, [], true);
$dash = http('GET', $base . 'admin/mks_sales_track');
$csrf = csrf_from($dash['body']) ?: $csrf;

check($dash['status'] === 200 && strpos($dash['body'], 'mks-sales-track-nav') !== false && !empty($csrf), 'Signed in; the Dashboard opens with its tab bar');

$side = http('GET', $base . 'admin/');
check(substr_count($side['body'], 'menu-item-mks-sales-track') === 1, 'The sidebar carries one Sales Track item');

/* Screens */
$errors = '/A PHP Error was encountered|Fatal error|A Database Error|Severity:/';

foreach ([
    'admin/mks_sales_track'                => 'mks-sales-track-kpi-value',
    'admin/mks_sales_track/calls'          => 'table-mks-sales-track-events',
    'admin/mks_sales_track/recordings'     => 'table-mks-sales-track-events',
    'admin/mks_sales_track/whatsapp_calls' => 'table-mks-sales-track-events',
    'admin/mks_sales_track/sms'            => 'table-mks-sales-track-events',
    'admin/mks_sales_track/devices'        => 'mks-sales-track-connect',
    'admin/mks_sales_track/missed_calls'   => 'mks-sales-track-queue',
    'admin/mks_sales_track/follow_ups'     => 'mks-sales-track-follow-ups',
    'admin/mks_sales_track/reports'        => 'mks-sales-track-report-card',
    'admin/mks_sales_track/pitches'        => 'mks-sales-track-pitches',
    'admin/mks_sales_track/lists'          => 'mks-sales-track-lists',
    'admin/mks_sales_track/wallboard'      => 'class="tiles"',
    'admin/mks_sales_track/settings?section=popup' => 'directory_leads',
    'admin/mks_sales_track/settings?section=ai' => 'mks-sales-track-ai-test',
    'admin/mks_sales_track/settings?section=storage' => 'mks-sales-track-drive-panel',
    'admin/mks_sales_track/settings'       => 'mks-sales-track-settings-menu-item',
    'admin/settings?group=mks_sales_track' => 'mks_sales_track/settings',
] as $path => $marker_html) {
    $page = http('GET', $base . $path);

    check($page['status'] === 200 && !preg_match($errors, $page['body']) && strpos($page['body'], $marker_html) !== false, 'Renders ' . $path, 'status ' . $page['status']);
}

$month = http('GET', $base . 'admin/mks_sales_track?range=30d&sort=talk');
check($month['status'] === 200 && !preg_match($errors, $month['body']) && substr_count($month['body'], 'mks-sales-track-kpi-value') === 8
    && preg_match_all('/<svg class="mks-sales-track-(chart|heatmap|donut)"/', $month['body']) >= 2, 'The dashboard draws its tiles and charts for 30 days');

$odd = http('GET', $base . 'admin/mks_sales_track?range=bogus&team=999999&staff=999999');
check($odd['status'] === 200 && !preg_match($errors, $odd['body']), 'The dashboard shrugs off filters outside the viewer\'s reach');

$noInsights = http('GET', $base . 'admin/mks_sales_track/ai_view/999999999');
check($noInsights['status'] === 404, 'Insights for a call that was never analysed answer 404');

/* Reports */
$reportErrors = [];

foreach (['team', 'daily', 'callbacks', 'duration', 'outcomes', 'speed', 'engagement', 'conversion', 'recordings', 'sms', 'health', 'access'] as $report) {
    $page = http('GET', $base . 'admin/mks_sales_track/reports?report=' . $report . '&range=30d');

    if ($page['status'] !== 200 || preg_match($errors, $page['body']) || strpos($page['body'], 'mks-sales-track-report-card') === false) {
        $reportErrors[] = $report;
    }
}

check(!$reportErrors, 'All twelve reports render for 30 days', implode(', ', $reportErrors));

$csvExport  = http('GET', $base . 'admin/mks_sales_track/reports?report=team&range=30d&format=csv');
$xlsxExport = http('GET', $base . 'admin/mks_sales_track/reports?report=outcomes&range=30d&format=xlsx');

check(strpos($csvExport['body'], "\xEF\xBB\xBF") === 0 && stripos($csvExport['headers'], 'text/csv') !== false
    && substr($xlsxExport['body'], 0, 2) === 'PK' && stripos($xlsxExport['headers'], 'spreadsheetml') !== false,
    'Reports export as CSV and as an Excel workbook');

$preview = http('GET', $base . 'admin/mks_sales_track/report_preview?kind=daily');
check($preview['status'] === 200 && strpos($preview['body'], '<table') !== false && !preg_match($errors, $preview['body']), 'The email report previews');

$ping = http('GET', $api . 'ping');
check($ping['status'] === 200 && !empty($ping['json']['success']), 'API ping answers');

if (empty($ping['json']['pairing'])) {
    echo "STOP  App connections are switched off under Sales Track > Settings > Devices And App.\n";
    exit(2);
}

/* Add a device */
$devicesPage = http('GET', $base . 'admin/mks_sales_track/devices');
preg_match('/id="mks-st-f-staff".*?<option value="(\d+)"/s', $devicesPage['body'], $m);
$staffId = isset($m[1]) ? (int) $m[1] : 0;

$added = admin_post('admin/mks_sales_track/device_save', ['name' => 'E2E Phone ' . $run, 'description' => 'end to end test', 'staff_id' => $staffId]);
$device = isset($added['json']['id']) ? (int) $added['json']['id'] : 0;

check($device > 0 && preg_match('/^\d{3} \d{3}$/', (string) $added['json']['code']) && strpos((string) $added['json']['qr'], 'data:image/svg+xml') === 0,
    'Add Device creates a device waiting for its phone, with a 6-digit code and QR', substr($added['body'], 0, 200));

$page = http('GET', $base . 'admin/mks_sales_track/device/' . $device);
check(strpos($page['body'], 'data-code="' . $added['json']['code'] . '"') !== false, 'The device page shows its live code again');

/* Pair */
$wrong = pair_phone('000000', 'e2e-wrong-' . $run, 'android');
check($wrong['status'] === 401 && $wrong['json']['error'] === 'invalid_code', 'A wrong code is refused');

$paired = pair_phone($added['json']['code'], 'e2e-' . $run, 'android');
$token  = isset($paired['json']['token']) ? $paired['json']['token'] : '';

check($paired['status'] === 200 && strlen($token) === 64 && $paired['json']['device']['id'] === $device, 'The phone pairs to that device record');

$poll = http('GET', $base . 'admin/mks_sales_track/pair_status?id=' . $added['json']['code_id'], null, ['X-Requested-With: XMLHttpRequest']);
check(isset($poll['json']['state']) && $poll['json']['state'] === 'paired', 'The pairing window learns the phone paired');

$reuse = pair_phone($added['json']['code'], 'e2e-reuse-' . $run, 'android');
check($reuse['status'] === 401, 'A used code cannot pair another phone');

$auth = ['X-Sales-Track-Token: ' . $token];

/* Commands */
admin_post('admin/mks_sales_track/device_action', ['id' => $device, 'action' => 'command:sync_now']);
$beat = http('POST', $api . 'config', ['health' => ['permissions' => ['call_log' => true], 'battery' => 64]], $auth);
$cmd  = isset($beat['json']['commands'][0]) ? $beat['json']['commands'][0] : [];

check(isset($cmd['type']) && $cmd['type'] === 'sync_now', 'A queued command reaches the phone on its heartbeat');

$acked = http('POST', $api . 'config', ['acks' => [['id' => isset($cmd['id']) ? $cmd['id'] : '', 'status' => 'done']]], $auth);
check($acked['status'] === 200 && $acked['json']['commands'] === [], 'An acknowledged command is not sent again');

/* Sync */
$now    = (int) round(microtime(true) * 1000);
$events = [
    ['uid' => 'e2e-call-' . $run, 'kind' => 'call', 'direction' => 'outgoing', 'number' => $marker, 'time' => $now - 120000, 'duration' => 42, 'recording' => true],
    ['uid' => 'e2e-missed-' . $run, 'kind' => 'call', 'direction' => 'missed', 'number' => $marker, 'time' => $now - 20000],
    ['uid' => 'e2e-wa-' . $run, 'kind' => 'whatsapp_call', 'direction' => 'incoming', 'number' => $marker, 'time' => $now - 60000, 'duration' => 30, 'media' => 'video'],
    ['uid' => 'e2e-sms-' . $run, 'kind' => 'sms', 'direction' => 'incoming', 'number' => $marker, 'time' => $now - 30000, 'text' => 'E2E ' . $run],
    ['uid' => 'e2e-bad-' . $run, 'kind' => 'notification', 'time' => $now],
];

$sync = http('POST', $api . 'sync', ['events' => $events], $auth);
check($sync['status'] === 200 && count($sync['json']['rejected']) === 1 && count($sync['json']['stored']) + count($sync['json']['skipped']) === 4,
    'Sync stores, skips or rejects every event once', $sync['body']);

$again = http('POST', $api . 'sync', ['events' => $events], $auth);
check($again['status'] === 200 && count($again['json']['stored']) === 0, 'A retried batch stores nothing twice');

/* Callback queue */
$queue = http('GET', $base . 'admin/mks_sales_track/missed_calls');
preg_match('/id="mks-sales-track-queue-(\d+)"[^>]*>(?:(?!<\/tr>).)*' . preg_quote(substr($marker, -5), '/') . '/s', $queue['body'], $qm);

check(!empty($qm[1]), 'A missed call with no callback after it waits in the queue');

if (!empty($qm[1])) {
    $resolved = admin_post('admin/mks_sales_track/callback_resolve', ['id' => (int) $qm[1]]);
    check(!empty($resolved['json']['success']), 'Marking it returned clears it');
}

/* Outcomes */
$outcomeKey = isset($paired['json']['config']['outcomes']['list'][0]['key']) ? $paired['json']['config']['outcomes']['list'][0]['key'] : '';
$outcomes   = http('POST', $api . 'outcome', ['items' => [
    ['uid' => 'e2e-call-' . $run, 'outcome' => $outcomeKey, 'note' => 'E2E note ' . $run, 'follow_up_at' => (time() + 86400) * 1000],
    ['uid' => 'e2e-call-' . $run, 'outcome' => 'no-such-outcome'],
]], $auth);

check($outcomeKey !== '' && isset($outcomes['json']['stored']) && $outcomes['json']['stored'] === ['e2e-call-' . $run]
    && $outcomes['json']['rejected'][0]['reason'] === 'invalid_outcome', 'The phone sets an outcome, note and follow-up; an unknown outcome is refused', $outcomes['body']);

/* Click to call and push registration */
$registered = http('POST', $api . 'config', ['push_token' => 'e2e-push-token_' . $run . ':abcdefghijklmnop'], $auth);
$devicePage = http('GET', $base . 'admin/mks_sales_track/device/' . $device);

check($registered['status'] === 200 && isset($registered['json']['config']['calling']) && strpos($devicePage['body'], _e2e_registered()) !== false,
    'The phone registers its push token and the device page shows it');

$dial = admin_post('admin/mks_sales_track/dial', ['number' => $marker, 'name' => 'E2E']);
check(in_array($dial['status'], [200, 422], true) && isset($dial['json']['message']) && $dial['json']['message'] !== '',
    'Click-to-call answers with a clear result', $dial['body']);

/* Call lists and the caller popup, as the phone sees them */
$phoneLists = http('GET', $api . 'lists', null, $auth);
$directory  = http('GET', $api . 'directory', null, $auth);
$lookup     = http('GET', $api . 'lookup?number=' . rawurlencode($marker), null, $auth);

check($phoneLists['status'] === 200 && isset($phoneLists['json']['lists']) && is_array($phoneLists['json']['lists']),
    'The phone receives its call lists');
check(($directory['status'] === 200 && isset($directory['json']['entries'], $directory['json']['version'])) || $directory['status'] === 403,
    'The phone receives the caller popup directory (or a clear refusal when it is off)');
check($lookup['status'] === 200 && array_key_exists('found', (array) $lookup['json']) || $lookup['status'] === 403, 'The phone can look up one caller');

$publicWall = http('GET', $base . 'mks_sales_track/wallboard/not-the-key');
check($publicWall['status'] === 404, 'The wallboard\'s secret link refuses a wrong key');

/* Pause and resume */
admin_post('admin/mks_sales_track/device_action', ['id' => $device, 'action' => 'pause']);
$paused = http('POST', $api . 'sync', ['events' => [['uid' => 'e2e-paused-' . $run, 'kind' => 'call', 'direction' => 'incoming', 'number' => $marker, 'time' => $now, 'duration' => 9]]], $auth);
check(isset($paused['json']['skipped'][0]['reason']) && $paused['json']['skipped'][0]['reason'] === 'device_paused', 'A paused phone has its events skipped');
admin_post('admin/mks_sales_track/device_action', ['id' => $device, 'action' => 'resume']);

/* Recording */
$callStored = in_array('e2e-call-' . $run, (array) $sync['json']['stored'], true);
$file       = tempnam(sys_get_temp_dir(), 'mks_st_e2e_wav_');
$fake       = tempnam(sys_get_temp_dir(), 'mks_st_e2e_php_');

file_put_contents($file, wav(2));
file_put_contents($fake, '<?php echo 1; ?>');

if ($callStored && in_array('e2e-call-' . $run, (array) $sync['json']['recordings_wanted'], true)) {
    $upload = http('POST', $api . 'recording', ['uid' => 'e2e-call-' . $run, 'file' => new CURLFile($file, 'audio/wav', 'call.wav')], $auth, 'multipart');
    check($upload['status'] === 200 && (int) $upload['json']['size'] === filesize($file), 'Recording uploads intact', $upload['body']);

    $disguised = http('POST', $api . 'recording', ['uid' => 'e2e-missed-' . $run, 'file' => new CURLFile($fake, 'audio/mp4', 'x.m4a')], $auth, 'multipart');
    check(in_array($disguised['status'], [415, 422], true), 'A script named .m4a is refused');
} else {
    echo "SKIP  recording checks: calls or recordings are switched off on this CRM\n";
}

/* List, as DataTables asks for it */
$draw = [
    'draw' => 1, 'start' => 0, 'length' => 25,
    'search' => ['value' => substr($marker, -8)],
    'order' => [['column' => 3, 'dir' => 'desc']],
    // As many as any list can have: DataTables always posts one per column.
    'columns' => array_fill(0, 20, ['searchable' => 'true', 'search' => ['value' => '']]),
    'mks_st_range' => 'today',
];

$list     = admin_post('admin/mks_sales_track/table/calls', $draw);
$recorded = 0;

foreach ((array) (isset($list['json']['aaData']) ? $list['json']['aaData'] : []) as $row) {
    if (strpos(implode('', array_filter($row, 'is_string')), 'mks-sales-track-play') !== false) {
        $recorded = (int) str_replace('mks-sales-track-event-', '', $row['DT_RowId']);
    }
}

check($list['status'] === 200 && !empty($list['json']['mks_st_summary']) && ($callStored ? count($list['json']['aaData']) >= 1 : true),
    'Calls list answers with rows and tiles for the search', substr($list['body'], 0, 300));

check(strpos($list['body'], 'E2E note ' . $run) !== false, 'The outcome and its note show in the Calls list');

if ($recorded > 0) {
    $stream = http('GET', $base . 'admin/mks_sales_track/recording/' . $recorded, null, ['Range: bytes=0-99']);
    check($stream['status'] === 206 && stripos($stream['headers'], 'Content-Range: bytes 0-99/') !== false, 'Recording streams with range support');
}

/* Handset swap */
$regen  = admin_post('admin/mks_sales_track/device_code', ['id' => $device]);
$second = pair_phone(isset($regen['json']['code']) ? $regen['json']['code'] : '', 'e2e-second-' . $run, 'ios');
$old    = http('POST', $api . 'config', [], $auth);

check($second['status'] === 200 && $old['status'] === 401, 'A regenerated code moves the device to a new phone and cuts the old one off');

/* Revoke and clean up */
$token2 = isset($second['json']['token']) ? $second['json']['token'] : '';
admin_post('admin/mks_sales_track/device_action', ['id' => $device, 'action' => 'revoke']);
$after = http('POST', $api . 'config', [], ['X-Sales-Track-Token: ' . $token2]);
check($after['status'] === 401 && $after['json']['error'] === 'invalid_token', 'A revoked device is refused at once');

foreach (['calls', 'whatsapp_calls', 'sms'] as $view) {
    $found = admin_post('admin/mks_sales_track/table/' . $view, $draw);

    foreach ((array) (isset($found['json']['aaData']) ? $found['json']['aaData'] : []) as $row) {
        admin_post('admin/mks_sales_track/event_delete', ['id' => (int) str_replace('mks-sales-track-event-', '', $row['DT_RowId'])]);
    }
}

// With automatic leads switched on, the test calls created a lead: remove it.
$leadHit   = admin_post('admin/leads/table', ['draw' => 1, 'start' => 0, 'length' => 10, 'search' => ['value' => substr($marker, -8)],
    'columns' => array_fill(0, 30, ['searchable' => 'true', 'search' => ['value' => '']]), 'order' => [['column' => 0, 'dir' => 'desc']]]);

foreach ((array) (isset($leadHit['json']['aaData']) ? $leadHit['json']['aaData'] : []) as $row) {
    if (preg_match('/init_lead\((\d+)/', implode(' ', array_filter($row, 'is_string')), $lm)) {
        http('GET', $base . 'admin/leads/delete/' . (int) $lm[1]);
    }
}

$deleted = admin_post('admin/mks_sales_track/device_action', ['id' => $device, 'action' => 'delete']);
check(!empty($deleted['json']['success']), 'Test device and its records removed again');

@unlink($file);
@unlink($fake);
@unlink($jar);

echo str_repeat('=', 66) . "\n" . $pass . " passed, " . $fail . " failed\n";

exit($fail > 0 ? 1 : 0);
