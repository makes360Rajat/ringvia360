<?php

/**
 * MKS Sales Track - release gates.
 *
 *   php tooling/gates.php          (from the module folder, or the extracted ZIP)
 *
 * Every gate names the fault it guards against. Most of those faults shipped in
 * a sibling MKS module first; the ones marked [this build] were caught while
 * this module was being written. Gates are added, never removed.
 *
 * Section 7 loads the helpers against a small stub of Perfex to test the pure
 * functions. Anything that needs a database or HTTP is covered by
 * tooling/e2e.php, which runs against a live CRM.
 */

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

$root = dirname(__DIR__);
$pass = 0;
$fail = 0;

function gate($ok, $name, $why = '', $note = '')
{
    global $pass, $fail;

    if ($ok) {
        $pass++;
        echo "PASS  " . $name . "\n";

        return;
    }

    $fail++;
    echo "FAIL  " . $name . "\n";

    if ($why !== '') {
        echo "      guards: " . $why . "\n";
    }

    if ($note !== '') {
        echo "      " . $note . "\n";
    }
}

/**
 * Module files only; tooling quotes the very patterns these gates look for.
 */
function files_in($dir, $ext)
{
    $out = [];

    if (!is_dir($dir)) {
        return $out;
    }

    $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($dir, FilesystemIterator::SKIP_DOTS));

    foreach ($it as $file) {
        if (!$file->isFile() || strtolower($file->getExtension()) !== $ext) {
            continue;
        }

        if (strpos($file->getPathname(), DIRECTORY_SEPARATOR . 'tooling' . DIRECTORY_SEPARATOR) !== false) {
            continue;
        }

        $out[] = $file->getPathname();
    }

    sort($out);

    return $out;
}

/**
 * Source without comments, so prose explaining a banned pattern cannot trip
 * the gate that bans it.
 */
function code_only($body)
{
    $body = preg_replace('!/\*.*?\*/!s', '', $body);
    $body = preg_replace('!^\s*//.*$!m', '', $body);

    return $body;
}

function rel($root, $path)
{
    return ltrim(str_replace($root, '', $path), '/\\');
}

$php   = files_in($root, 'php');
$js    = files_in($root . '/assets/js', 'js');
$css   = files_in($root . '/assets/css', 'css');
$docs  = files_in($root . '/docs', 'md');
$boot  = (string) @file_get_contents($root . '/mks_sales_track.php');
$bootC = code_only($boot);
$all   = [];

foreach (array_merge($php, $js, $css) as $file) {
    $all[$file] = code_only((string) file_get_contents($file));
}

echo "MKS Sales Track - release gates\n" . str_repeat('=', 66) . "\n";

/* =====================================================================
 * 1. Syntax
 * ================================================================== */
echo "SECTION 1  syntax\n";

$bad = [];

foreach ($php as $file) {
    $out = [];
    exec('php -l ' . escapeshellarg($file) . ' 2>&1', $out, $code);

    if ($code !== 0) {
        $bad[] = rel($root, $file);
    }
}

gate(!$bad, 'PHP lint, every file', 'a parse error in any module file white screens the whole CRM', implode(', ', $bad));

$bad = [];

foreach ($js as $file) {
    $out = [];
    exec('node --check ' . escapeshellarg($file) . ' 2>&1', $out, $code);

    if ($code !== 0) {
        $bad[] = rel($root, $file);
    }
}

gate(!$bad, 'JS syntax', 'a broken footer script takes every later handler on the page with it', implode(', ', $bad));

$bad = [];

foreach ($css as $file) {
    $body = (string) file_get_contents($file);

    if (substr_count($body, '{') !== substr_count($body, '}')) {
        $bad[] = rel($root, $file);
    }
}

gate(!$bad, 'CSS braces balanced', 'an unclosed rule silently swallows every rule after it', implode(', ', $bad));

/* =====================================================================
 * 2. Version and migration
 * ================================================================== */
echo "\nSECTION 2  version and migration\n";

preg_match('/^Version:\s*(.+)$/m', $boot, $m);
$version = isset($m[1]) ? trim($m[1]) : '';
$digits  = str_replace('.', '', $version);

gate(strlen($digits) === 3, 'Version collapses to exactly three digits',
    'Perfex strips the dots, so 1.0.10 becomes 1010 and the upgrade can never find its migration', $version . ' -> ' . $digits);

preg_match("/define\('MKS_SALES_TRACK_VERSION', '([^']+)'\)/", $boot, $m);

gate(isset($m[1]) && $m[1] === $version, 'Version constant equals the header',
    'the constant is the asset cache buster; a stale one serves last release\'s CSS and JS');

$migrations = glob($root . '/migrations/*.php');

gate(count($migrations) === 1, 'Exactly one migration file',
    'CodeIgniter checks for gaps in a sequence; one cumulative migration never has any', count($migrations) . ' found');

$migration = @file_get_contents($root . '/migrations/' . $digits . '_version_' . $digits . '.php');

gate(is_string($migration) && strpos($migration, 'class Migration_Version_' . $digits . ' extends App_module_migration') !== false,
    'Migration file and class match the version',
    'Perfex refuses an in-place upgrade without migrations/NNN_version_NNN.php holding Migration_Version_NNN');

gate(is_string($migration) && strpos($migration, "install.php") !== false,
    'Migration re-runs the idempotent installer', 'a migration that does its own DDL drifts from install.php');

/* =====================================================================
 * 3. House rules
 * ================================================================== */
echo "\nSECTION 3  house rules\n";

$bad = [];

foreach (array_merge($php, $js, $css, $docs, files_in($root . '/tooling', 'php')) as $file) {
    $body = (string) file_get_contents($file);

    if (strpos($body, "\xE2\x80\x94") !== false || strpos($body, "\xE2\x80\x93") !== false) {
        $bad[] = rel($root, $file);
    }
}

foreach (glob($root . '/tooling/*') as $file) {
    if (is_file($file) && (strpos((string) file_get_contents($file), "\xE2\x80\x94") !== false || strpos((string) file_get_contents($file), "\xE2\x80\x93") !== false)) {
        $bad[] = rel($root, $file);
    }
}

gate(!$bad, 'No em or en dashes anywhere', 'house rule: plain hyphens only, comments and docs included', implode(', ', array_unique($bad)));

$bad = [];

foreach (array_merge($php, $js, $css) as $file) {
    if (preg_match('/[^\x00-\x7F]/', (string) file_get_contents($file))) {
        $bad[] = rel($root, $file);
    }
}

gate(!$bad, 'Code and strings are ASCII', 'a stray non-ASCII character in a language string once shipped as mojibake', implode(', ', $bad));

$bad = [];

foreach ($all as $file => $body) {
    if (preg_match('/sprintf\s*\(\s*_l\s*\(/', $body)) {
        $bad[] = rel($root, $file);
    }
}

gate(!$bad, 'No sprintf() around _l()', '_l() already runs sprintf with an empty default, so wrapping it blanks the output', implode(', ', $bad));

/*
 * Every Font Awesome name below was checked against the font-awesome 6.2.0
 * all.min.css that Perfex 3.4.1 ships. A new icon is added here only after
 * the same check.
 */
$verifiedIcons = [
    'address-book', 'android', 'apple', 'arrow-down', 'arrow-left', 'arrow-up', 'arrows-rotate', 'ban', 'bell', 'bolt',
    'bullseye', 'calendar-days', 'chart-column', 'check', 'circle-check', 'circle-info', 'circle-question', 'clock', 'cloud-arrow-up', 'copy', 'download', 'flask',
    'ban', 'envelope', 'eye', 'file-csv', 'file-excel', 'flag', 'gauge-high', 'gear', 'google-drive', 'id-card', 'list', 'list-ol', 'phone-slash', 'tv', 'grip', 'hard-drive', 'hashtag', 'lightbulb', 'link-slash', 'list-check', 'lock', 'minus', 'paper-plane', 'plug', 'print', 'star', 'message', 'microphone', 'mobile-screen-button', 'pause',
    'pen', 'phone', 'phone-slash', 'phone-volume', 'play', 'plus', 'qrcode', 'rotate-left', 'satellite-dish',
    'shield-halved', 'sim-card', 'sliders', 'trash-can', 'triangle-exclamation', 'trophy', 'user', 'user-plus', 'wand-magic-sparkles',
    'user-shield', 'users', 'video', 'voicemail', 'whatsapp', 'xmark',
];

$used = [];

foreach ($all as $body) {
    preg_match_all("/fa-(?!solid\b|brands\b|regular\b)([a-z0-9-]+)/", $body, $m);

    foreach ($m[1] as $name) {
        $used[$name] = true;
    }
}

$unknown = array_values(array_diff(array_keys($used), $verifiedIcons));

gate(!$unknown, 'Every icon is a verified Font Awesome 6.2 name',
    'Perfex never loads the v4 shims, and an unknown or FA4 style name renders as an invisible gap', implode(', ', $unknown));

$bad = [];

foreach ($all as $file => $body) {
    if (preg_match("/fa-regular/", $body)) {
        $bad[] = rel($root, $file);
    }
}

gate(!$bad, 'No fa-regular icons', 'FA6 Free regular has about 160 glyphs; most names render blank', implode(', ', $bad));

$cssAll = '';

foreach ($css as $file) {
    $cssAll .= code_only((string) file_get_contents($file));
}

gate(!preg_match('/border-left\s*:\s*\d/', $cssAll) && !preg_match('/border-left-width\s*:\s*[1-9]/', $cssAll),
    'No left border accent bars', 'house rule on UI design');

gate(strpos($cssAll, ':root') === false, 'No design tokens on :root',
    '[this build] a sibling module declares its tokens on :root, where any other module using the same names collides');

gate(!preg_match('/class="[^"]*\btw-[a-z0-9-]+/', implode("\n", $all)), 'No tw- classes authored',
    'Perfex 3.4.1 ships a precompiled tailwind.css, so a new tw- class silently does nothing');

/* =====================================================================
 * 4. Perfex contracts
 * ================================================================== */
echo "\nSECTION 4  Perfex contracts\n";

gate(strpos($bootC, 'register_language_files(') !== false && strpos($bootC, '->load->language(') === false,
    'Language registered with register_language_files()', 'the loader form leaves every key printing raw');

gate(strpos($bootC, '$CI->app_menu->add_sidebar_menu_item(') !== false,
    'Sidebar registered through $CI->app_menu', 'the global function form does not exist and fatals at admin_init');

gate(strpos($bootC, '->add_settings_section(') !== false && strpos($bootC, 'add_settings_tab(') === false,
    'Setup > Settings entry registered with add_settings_section()', 'add_settings_tab() has been deprecated since Perfex 3.2.0');

gate(substr_count($bootC, '->add_sidebar_menu_item(') === 1 && strpos($bootC, 'add_sidebar_children_item(') === false,
    'Exactly one sidebar item, no children', 'decision: one Sales Track item; every other page is reached from the module\'s own tab bar');

gate(strpos($bootC, "'without_submit_button' => true") !== false,
    'The Setup > Settings entry has no Save button', '[this build] a Save button on a link-only group posts no settings[] array, and Settings_model::update() walks a missing key');

gate(preg_match("/register_staff_capabilities\([^;]+'capabilities'\s*=>/s", $bootC) === 1,
    'Capabilities passed inside a capabilities key', 'without the wrapper nothing appears under Setup > Staff > Roles');

$bad = [];

foreach ($all as $file => $body) {
    if (preg_match("/update_option\s*\([^;]*,\s*1\s*\)/", $body)) {
        $bad[] = rel($root, $file);
    }
}

gate(!$bad, 'No update_option(..., 1)',
    '[this build] Perfex creates a missing option with autoload off when 1 is passed, so every get_option() costs a query; use mks_st_option_put()',
    implode(', ', $bad));

$bad = [];

// PHP only: SQL lives there, and JavaScript's Date.now() is not SQL.
foreach ($php as $file) {
    if (preg_match('/\bNOW\s*\(\s*\)/', $all[$file])) {
        $bad[] = rel($root, $file);
    }
}

gate(!$bad, 'No SQL NOW()', 'Perfex stores PHP local time; the database server can sit in another timezone', implode(', ', $bad));

$routes = (string) @file_get_contents($root . '/config/routes.php');
$csrf   = (string) @file_get_contents($root . '/config/csrf_exclude_uris.php');

gate(strpos($routes, "'mks_sales_track/api/v1/(:any)'") !== false, 'API route present', 'without it the phones meet a 404');

preg_match_all("/^\s*'([^']+)',?\s*$/m", code_only($csrf), $m);

gate(count($m[1]) === 1 && $m[1][0] === 'mks_sales_track/api/v1/.+',
    'CSRF exemption covers the API and nothing else', 'an over-broad exemption removes CSRF protection from admin screens',
    implode(', ', $m[1]));

$api = code_only((string) @file_get_contents($root . '/controllers/Mks_sales_track_api.php'));

gate(strpos($api, "file_get_contents('php://input')") !== false,
    'API reads JSON bodies from php://input', 'PHP never fills $_POST from a JSON body; Chrome Track Pro 1.0.4 answered 401 to everything for this');

gate(strpos($api, 'HTTP_X_SALES_TRACK_TOKEN') !== false && strpos($api, 'HTTP_AUTHORIZATION') !== false && strpos($api, "\$body['token']") !== false,
    'Token accepted from header, bearer and body', 'shared hosting can strip the Authorization header; a single path leaves no fallback');

gate(strpos($api, '$this->db->db_debug = false;') !== false,
    'API runs with db_debug off', 'a database error would otherwise answer the phone with an HTML page it cannot parse');

gate(preg_match('/extends\s+App_Controller/', $api) === 1, 'API controller extends App_Controller',
    'AdminController would redirect every phone to the sign in page');

gate(strpos($bootC, "add_action('after_lead_lead_tabs', 'mks_st_lead_tab')") !== false && strpos($bootC, "add_action('after_lead_tabs_content', 'mks_st_lead_tab_content')") !== false
    && strpos($bootC, '->add_customer_profile_tab(') !== false, 'Calls tabs hook into the lead window and the customer profile', 'phase 5: call history where the lead or customer is');

gate(substr_count($api, '$this->mks_require_current_app();') === 6,
    'Sync, outcomes, recording uploads, call lists, the directory and lookups enforce the minimum app version', 'an outdated app keeps sending data in a shape the CRM has moved on from');

gate(strpos($helper = code_only((string) @file_get_contents($root . '/helpers/mks_sales_track_helper.php')), "'notification'") === false,
    'Notification tracking is gone', 'decision: the app sends calls, recordings, WhatsApp calls and SMS only');

gate(strpos($api, "'outcome'   => ['methods' => ['POST'], 'handler' => 'mks_outcome']") !== false,
    'The after-call outcome endpoint is routed', 'the popup has nowhere to send its answer otherwise');

$workflow = code_only((string) @file_get_contents($root . '/helpers/mks_sales_track_workflow_helper.php'));

gate(strpos($workflow, "db_prefix() . 'reminders'") !== false && strpos($workflow, 'CREATE TABLE') === false && strpos($workflow, "->model('leads_model')") !== false,
    'Follow-ups are native Perfex reminders and leads go through Leads_model', 'decision: Perfex\'s own reminders and lead hooks, no parallel copies');

gate(strpos($bootC, "add_action('after_cron_run', 'mks_st_on_cron')") !== false && strpos($bootC, "'mks_sales_track_workflow_helper.php'") !== false,
    'Escalation runs on Perfex\'s cron and the workflow helper loads with the module', 'missed calls would never escalate');

$admin = code_only((string) @file_get_contents($root . '/controllers/Mks_sales_track.php'));
$pagesMissing = [];

preg_match_all("/'([a-z_]+)'\s*=>\s*\[\s*'kind'/", $bootC, $m);

foreach ($m[1] as $slug) {
    if (!preg_match('/public function ' . preg_quote($slug, '/') . '\(/', $admin)) {
        $pagesMissing[] = $slug;
    }
}

gate($m[1] && !$pagesMissing, 'Every sidebar page has a controller method', 'a registered page without a method is a sidebar link to a 404',
    implode(', ', $pagesMissing));

$helper = code_only((string) @file_get_contents($root . '/helpers/mks_sales_track_helper.php'));

gate(strpos($helper, 'session_write_close()') !== false,
    'Recording stream closes the session first', '[this build] the database session lock would freeze every other request from that browser for the length of the stream');

gate(strpos($helper, 'HTTP_RANGE') !== false, 'Recording stream honours Range', 'without 206 responses the player cannot seek');

$uninstall = code_only((string) @file_get_contents($root . '/uninstall.php'));

gate(!preg_match('/\bmks_st_[a-z_]+\s*\(/', $uninstall), 'Uninstaller is self-contained',
    'the module files are not guaranteed to be loaded at uninstall, so a helper call is a fatal');

gate(strpos($uninstall, "purge_on_uninstall") !== false, 'Uninstall keeps data unless purge is ticked',
    'deactivating or reinstalling is often a diagnostic step, not a decision to discard a call history');

/* =====================================================================
 * 5. Views and settings form
 * ================================================================== */
echo "\nSECTION 5  views and settings form\n";

$settingsView = (string) @file_get_contents($root . '/views/settings.php');
$settingsCode = code_only($settingsView);

gate(strpos($settingsCode, 'form_open(') !== false && strpos($settingsCode, "foreach (\$schema['sections']") !== false,
    'Settings page is its own CSRF-protected form drawn from the schema', 'a field hand-written into the view drifts from the schema that saves and documents it');

gate(preg_match('/<input type="hidden" name="<\?= e\(\$name\); \?>" value="0">\s*<input type="checkbox"/', $settingsCode) === 1,
    'Each hidden 0 sits before its checkbox', 'PHP keeps the last value posted under a name, so a mirror after the box turns every switch off');

preg_match('/<input type="password"[^>]*>/', $settingsCode, $pinInput);

gate(isset($pinInput[0]) && strpos($pinInput[0], 'value=') === false,
    'The App Lock PIN is never printed back', 'a PIN echoed into the page is readable by anybody who can open the settings');

$secretStart = strpos($settingsCode, "case 'secret_json':");
$secretBlock = $secretStart === false ? '' : substr($settingsCode, $secretStart, strpos($settingsCode, 'break;', $secretStart) - $secretStart);

gate($secretBlock !== '' && strpos($secretBlock, '$disabled; ?>></textarea>') !== false && strpos($secretBlock, '$values[$key]') === false
    && strpos($secretBlock, 'private_key') === false, 'The Firebase key is never printed back', 'a private key echoed into the page is readable by anybody who can open the settings');

$docCheck = [];
exec('php ' . escapeshellarg($root . '/tooling/settings_doc.php') . ' --check 2>&1', $docCheck, $docCode);

gate($docCode === 0, 'docs/SETTINGS.md matches the schema', 'a settings reference nobody regenerates misleads the next person who reads it', implode(' ', $docCheck));

$tableView = code_only((string) @file_get_contents($root . '/views/tables/events.php'));

gate(strpos($tableView, "' as mks_c' . \$mks_index") !== false, 'Every list column is aliased',
    'data_tables_init() runs SHOW COLUMNS on every draw for a qualified column without an alias');

/**
 * How many divs are open at a point in a view.
 */
function div_depth($body, $position)
{
    $before = substr($body, 0, $position);

    return preg_match_all('/<div\b/', $before) - substr_count($before, '</div>');
}

foreach (['events.php', 'devices.php', 'device.php', 'dashboard.php', 'settings.php'] as $view) {
    $body = (string) @file_get_contents($root . '/views/' . $view);
    $tail = (int) strpos($body, 'init_tail()');

    gate(preg_match_all('/<div\b/', $body) === substr_count($body, '</div>') && div_depth($body, $tail) === 0,
        'views/' . $view . ': divs balance and close before init_tail()',
        'content left outside #wrapper is in the DOM but never renders; balanced counts alone miss a block closed in the wrong place');
}

$eventsView = (string) @file_get_contents($root . '/views/events.php');

gate(div_depth($eventsView, (int) strpos($eventsView, 'id="mks-sales-track-player"')) >= 3,
    'Player sits inside #wrapper > .content', 'the same never-renders fault, for the one element that is position fixed');

/* =====================================================================
 * 6. Language
 * ================================================================== */
echo "\nSECTION 6  language\n";

$lang = [];

if (!defined('BASEPATH')) {
    define('BASEPATH', __DIR__);
}

include $root . '/language/english/mks_sales_track_lang.php';

// Called directly: these must exist.
$calledKeys = [];

// Mentioned anywhere as a literal, or built from a known prefix at run time
// (API error codes, device states, choice hints): these count as used.
$mentioned = [];

foreach (array_merge($php, $js) as $file) {
    $body = (string) file_get_contents($file);

    preg_match_all("/_l\(\s*'(mks_st_[a-z0-9_]+)'/", $body, $m);

    foreach ($m[1] as $key) {
        // A key ending in an underscore is a prefix joined at run time.
        if (substr($key, -1) !== '_') {
            $calledKeys[$key] = true;
        }
    }

    preg_match_all("/'(mks_st_[a-z0-9_]+)'/", $body, $m);

    foreach ($m[1] as $key) {
        $mentioned[$key] = true;
    }
}

foreach (array_keys($lang) as $key) {
    if (preg_match('/^mks_st_(api_|state_|cmd_|network_|mail_subject_|note_alert_|alert_)/', $key) || preg_match('/^mks_st_sms_text_\w+_hint$/', $key)) {
        $mentioned[$key] = true;
    }
}

$missing = array_values(array_diff(array_keys($calledKeys), array_keys($lang)));
$orphans = array_values(array_diff(array_keys($lang), array_keys($mentioned + $calledKeys)));

gate(!$missing, 'Every language key used exists', 'a missing key prints the raw key into the interface', implode(', ', $missing));
gate(!$orphans, 'No orphaned language keys', 'dead keys pile up and make the file impossible to translate with confidence', implode(', ', $orphans));

$bad = [];

foreach ($lang as $key => $value) {
    if (strpos(str_replace(['%s', '%%'], '', $value), '%') !== false) {
        $bad[] = $key;
    }
}

gate(!$bad, 'Literal per cent signs are doubled', 'sprintf eats the character after a lone per cent sign', implode(', ', $bad));

$bad = [];

foreach ($all as $file => $body) {
    preg_match_all("/_l\(\s*'(mks_st_[a-z0-9_]+)'\s*\)/", $body, $m);

    foreach ($m[1] as $key) {
        if (isset($lang[$key]) && strpos($lang[$key], '%s') !== false) {
            $bad[] = $key . ' in ' . rel($root, $file);
        }
    }
}

gate(!$bad, 'No placeholder string called without its value',
    '[this build] _l() runs sprintf, so a %s string called with no value loses its placeholder before a script can fill it', implode(', ', $bad));

/* =====================================================================
 * 7. Behaviour of the pure helpers
 * ================================================================== */
echo "\nSECTION 7  behaviour\n";

$GLOBALS['STUB_OPTIONS'] = [];
$GLOBALS['STUB_LANG']    = $lang;

function _l($key, $value = '')
{
    $line = isset($GLOBALS['STUB_LANG'][$key]) ? $GLOBALS['STUB_LANG'][$key] : $key;

    return is_array($value) ? vsprintf($line, $value) : sprintf($line, $value);
}

function get_option($name)
{
    return isset($GLOBALS['STUB_OPTIONS'][$name]) ? $GLOBALS['STUB_OPTIONS'][$name] : '';
}

// Always false, so mks_st_option_put() writes through the add_option stub
// rather than reaching for a database that is not here.
function option_exists($name)
{
    return false;
}

function add_option($name, $value, $autoload = 1)
{
    $GLOBALS['STUB_OPTIONS'][$name] = $value;
}

function db_prefix()
{
    return 'tbl';
}

function e($value)
{
    return htmlspecialchars((string) $value, ENT_QUOTES, 'UTF-8');
}

function _d($date)
{
    return $date;
}

function _dt($date)
{
    return (string) $date;
}

function admin_url($url = '')
{
    return 'https://crm.test/admin/' . $url;
}

function hooks()
{
    return new class () {
        public function add_action()
        {
        }

        public function add_filter()
        {
        }
    };
}

function register_language_files()
{
}

function register_activation_hook()
{
}

function register_uninstall_hook()
{
}

function &get_instance()
{
    static $ci = null;

    return $ci;
}

function is_staff_logged_in()
{
    return $GLOBALS['STUB_STAFF'] !== null;
}

function is_admin()
{
    return $GLOBALS['STUB_STAFF'] === 'admin';
}

function staff_can($capability, $feature = null)
{
    return is_array($GLOBALS['STUB_STAFF']) && in_array($capability, $GLOBALS['STUB_STAFF'], true);
}

function get_staff_user_id()
{
    return 7;
}

// Team membership, as the department lookup would answer it.
function mks_st_stub_team()
{
    return [7, 8, 9];
}

$GLOBALS['STUB_STAFF'] = 'admin';

if (!defined('FCPATH')) {
    define('FCPATH', sys_get_temp_dir() . '/');
}

require $root . '/mks_sales_track.php';
require $root . '/helpers/mks_sales_track_analytics_helper.php';
require_once $root . '/helpers/mks_sales_track_workflow_helper.php';
require_once $root . '/helpers/mks_sales_track_push_helper.php';
require_once $root . '/helpers/mks_sales_track_reports_helper.php';
require_once $root . '/helpers/mks_sales_track_drive_helper.php';
require_once $root . '/helpers/mks_sales_track_ai_helper.php';
require_once $root . '/helpers/mks_sales_track_lists_helper.php';

// Settings save writes through the option store stubbed above.
function mks_st_stub_settings(array $values)
{
    $GLOBALS['STUB_OPTIONS'][MKS_SALES_TRACK_OPTION] = json_encode(array_merge(mks_st_setting_defaults(), $values));
    mks_st_settings(true);
}

mks_st_stub_settings([]);

/* numbers */
$cases = [
    ['+91 98140 00002', '+919814000002', '9814000002'],
    ['098140 00002', '+919814000002', '9814000002'],
    ['98140-00002', '+919814000002', '9814000002'],
    ['0091 98140 00002', '+919814000002', '9814000002'],
    ['(981) 400-0002', '+919814000002', '9814000002'],
    ['AX-HDFCBK', null, null],
    ['121', '121', null],
    ['', null, null],
];

$bad = [];

foreach ($cases as $case) {
    $parts = mks_st_number_parts($case[0]);

    if ($parts['number'] !== $case[1] || $parts['key'] !== $case[2]) {
        $bad[] = $case[0] . ' gave ' . var_export($parts['number'], true) . '/' . var_export($parts['key'], true);
    }
}

gate(!$bad, 'Numbers normalise to one match key',
    'a number saved as 098140 00002 in the CRM must still find the call from +91 98140 00002', implode('; ', $bad));

gate(mks_st_sql_digits('p') === "REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(p, ' ', ''), '-', ''), '.', ''), '(', ''), ')', ''), '+', ''), '/', '')",
    'SQL digit stripping is MySQL 5.7 safe', 'REGEXP_REPLACE does not exist before MySQL 8, which some CodeCanyon buyers still run');

/* time */
gate(mks_st_clean_time(1760000000000) === 1760000000000 && mks_st_clean_time(1760000000) === 1760000000000
    && mks_st_clean_time('1760000000000') === 1760000000000 && mks_st_clean_time(0) === null && mks_st_clean_time('junk') === null,
    'Event time accepts milliseconds, seconds and numeric strings', 'a phone sending seconds would otherwise land every call in January 1970');

/* uid and direction */
gate(mks_st_clean_uid('call-1:2') === 'call-1:2' && mks_st_clean_uid('has space') === '' && mks_st_clean_uid(str_repeat('a', 81)) === ''
    && mks_st_clean_uid(['x']) === '', 'Event ids are validated', 'the uid is half of a unique key; an unbounded one breaks the insert');

gate(mks_st_clean_direction('call', 'declined') === 'rejected' && mks_st_clean_direction('sms', 'sent') === 'outgoing'
    && mks_st_clean_direction('fax', 'incoming') === 'unknown' && mks_st_clean_direction('call', 'odd') === 'unknown',
    'Directions map aliases and fall back safely', 'an unexpected value from a new app build must not be stored as is');

/* lists */
gate(mks_st_clean_number_list("+91 98765 41230\n12345\n98765-00001") === ['+919876541230', '9876500001'],
    'Excluded numbers keep digits and drop short ones', 'a five digit typo would exclude nothing and look like it worked');

/* settings save */
$saved = mks_st_save_settings(['match_digits' => '99', 'country_code' => '+91 ', 'sms_text' => 'evil', 'track_sms' => '1', 'enabled' => '1'])['settings'];

gate($saved['match_digits'] === 15 && $saved['country_code'] === '91' && $saved['sms_text'] === 'all',
    'Settings are clamped and whitelisted on save', 'an out of range value from a hand edited form would break matching for every phone');

gate($saved['track_calls'] === 0 && $saved['track_sms'] === 1,
    'A switch missing from the post is stored as off', 'an unticked box posts nothing, so skipping absent keys means a feature can never be turned off');

gate(mks_st_settings()['match_digits'] === 15, 'Saved settings are what the rest of the request reads',
    '[this build] get_option() keeps serving the value autoloaded at the start of the request');

mks_st_stub_settings(['enabled' => 0, 'track_calls' => 1]);

gate(mks_st_enabled() === false && mks_st_enabled('track_calls') === false,
    'Master switch off turns every feature off', 'a tracker still reporting on would keep the API accepting it');

mks_st_stub_settings([]);

/* scope */
gate(mks_st_scope_sql('e.staff_id', [7]) === 'AND e.staff_id IN (7)' && mks_st_scope_sql('e.staff_id', null) === ''
    && mks_st_scope_sql('e.staff_id', false) === 'AND 1 = 0' && mks_st_scope_sql('e.staff_id', []) === 'AND 1 = 0'
    && mks_st_scope_sql('d.staff_id', ['7', '8x']) === 'AND d.staff_id IN (7, 8)',
    'Scope becomes SQL: own, team, everybody, nothing', 'every list, tile, chart and device read relies on this one translation');

$GLOBALS['STUB_STAFF'] = ['view_own'];
mks_st_scope(true);
$ownOnly = mks_st_view_where('calls', ['range' => 'all', 'staff' => '3']);

gate(in_array('AND e.staff_id IN (7)', $ownOnly, true) && !in_array('AND e.staff_id = 3', $ownOnly, true),
    'View Own is enforced in SQL and ignores a requested staff filter', 'a client supplied staff id must never widen what a rep can see');

$GLOBALS['STUB_STAFF'] = 'admin';
mks_st_scope(true);

gate(in_array('AND e.staff_id = 3', mks_st_view_where('calls', ['range' => 'all', 'staff' => '3']), true),
    'View All honours the staff filter', 'the filter must still work for managers');

gate(strpos(code_only((string) file_get_contents($root . '/mks_sales_track.php')), "staff_can('view_team', MKS_SALES_TRACK_MODULE_NAME)") !== false,
    'Team leads see everybody sharing a department with them', 'decision A3: teams are Perfex departments, gated by View Team Activity');

/* ranges */
list($from, $to) = mks_st_range_bounds('custom', '2026-10-20', '2026-10-01');

gate($from === '2026-10-01 00:00:00' && $to === '2026-10-20 23:59:59', 'Reversed custom dates are swapped', 'a reversed range would show an empty list with no explanation');

list($from, $to) = mks_st_range_bounds('custom', "2026-10-01' OR 1=1 --", '');

gate($from === null && $to === null, 'Custom dates are validated before reaching SQL', 'dates are written into the WHERE clause');

/* table config */
$config = mks_st_view_table_config('calls');

gate($config['order'] === [3, 'desc'], 'Default order is a flat pair',
    'initDataTable wraps a nested [[3, desc]] a second time and DataTables then ignores it');

/* formatting */
gate(mks_st_number_label(1234567) === '12,34,567' && mks_st_number_label(999) === '999' && mks_st_number_label(100000) === '1,00,000',
    'Counts use Indian digit grouping', 'house convention: 1,23,456 not 123,456');

gate(mks_st_duration_label(45) === '45s' && mks_st_duration_label(245) === '4m 05s' && mks_st_duration_label(8100) === '2h 15m',
    'Durations read naturally', 'raw seconds are unreadable in a talk time tile');

gate(mks_st_format_number('+919814000002') === '+91 98140 00002' && mks_st_format_number('121') === '121',
    'Indian mobiles are spaced for reading', 'display only; anything else is shown as stored');

gate(mks_st_ini_bytes('128M') === 134217728 && mks_st_ini_bytes('2G') === 2147483648 && mks_st_ini_bytes('-1') === 0,
    'php.ini sizes parse', 'the upload limit reported to the phones comes from these');

gate(mks_st_recording_playable('a.m4a') && !mks_st_recording_playable('a.amr') && !mks_st_recording_playable('a.3gp'),
    'AMR and 3GP are offered as downloads', 'browsers cannot play them, and a play button that does nothing reads as a broken recording');

gate(mks_st_device_state(['status' => 'revoked', 'token_hash' => null, 'last_seen_at' => date('Y-m-d H:i:s')]) === 'revoked'
    && mks_st_device_state(['status' => 'active', 'token_hash' => 'x', 'last_seen_at' => null]) === 'offline'
    && mks_st_device_state(['status' => 'active', 'token_hash' => 'x', 'last_seen_at' => date('Y-m-d H:i:s')]) === 'online'
    && mks_st_device_state(['status' => 'active', 'token_hash' => 'x', 'last_seen_at' => date('Y-m-d H:i:s', time() - 3 * 86400)]) === 'offline',
    'Device states', 'a phone that stopped reporting must stand out on the Devices page');

$health = mks_st_clean_health(['permissions' => ['sms' => 1, 'bogus' => true], 'battery' => 140, 'network' => 'satellite']);

gate($health['permissions'] === ['sms' => true] && $health['battery'] === 100 && !isset($health['network']),
    'Phone health is whitelisted and clamped', 'whatever a phone sends is stored and shown to managers');

/* schema integrity */
$schema = mks_st_settings_schema();
$bad    = [];

foreach ($schema['fields'] as $key => $field) {
    if (!isset($schema['sections'][$field['section']]) || !in_array($field['type'], ['switch', 'number', 'text', 'textarea', 'choice', 'pin', 'internal', 'days', 'staff_targets', 'outcomes', 'lead_status', 'lead_source', 'staff', 'time', 'secret_json', 'secret'], true)) {
        $bad[] = $key;
    } elseif ($field['type'] !== 'internal' && (!isset($lang[$field['label']], $lang[$field['hint']]))) {
        $bad[] = $key . ' (language)';
    } elseif ($field['type'] === 'number' && !($field['min'] <= $field['default'] && $field['default'] <= $field['max'])) {
        $bad[] = $key . ' (default out of range)';
    }
}

gate(!$bad, 'Every schema field has a section, a type, its strings and a sane default', 'a malformed field breaks the settings page for everybody', implode(', ', $bad));

/* PIN */
mks_st_stub_settings([]);
$pinSave = mks_st_save_settings(['enabled' => '1', 'app_lock_enabled' => '1', 'app_lock_pin' => '4821']);
$stored  = $pinSave['settings'];

gate($stored['app_lock_enabled'] === 1 && $stored['app_lock_hash'] === hash_pbkdf2('sha256', '4821', $stored['app_lock_salt'], MKS_ST_PIN_ITERATIONS, 64)
    && !isset($stored['app_lock_pin']), 'The PIN is stored only as a salted PBKDF2 hash the phone can recompute',
    'a PIN kept in plain text, or hashed differently from the phone, either leaks or locks every rep out');

$GLOBALS['STUB_OPTIONS'][MKS_SALES_TRACK_OPTION] = json_encode($stored);
mks_st_settings(true);
$kept = mks_st_save_settings(['enabled' => '1', 'app_lock_enabled' => '1', 'app_lock_pin' => ''])['settings'];

gate($kept['app_lock_hash'] === $stored['app_lock_hash'], 'An empty PIN field keeps the current PIN', 'saving any other setting would otherwise wipe the PIN');

$noPin = mks_st_save_settings(['enabled' => '1', 'app_lock_enabled' => '1', 'app_lock_pin_clear' => '1']);

gate($noPin['settings']['app_lock_enabled'] === 0 && in_array('mks_st_err_pin_needed', $noPin['errors'], true),
    'App Lock cannot be on without a PIN', 'an enabled lock with no PIN would lock the app with nothing able to open it');

mks_st_stub_settings([]);

/* app version gate */
mks_st_stub_settings(['min_app_version' => '1.2']);

gate(mks_st_app_update_required('1.1.9') && !mks_st_app_update_required('1.2') && !mks_st_app_update_required('1.10.0')
    && mks_st_app_update_required('') && !mks_st_app_update_required('2.0-beta'), 'Minimum app version compares versions, not strings',
    'a string comparison would treat 1.10 as older than 1.2 and lock out an up-to-date phone');

mks_st_stub_settings([]);

gate(!mks_st_app_update_required('0.1'), 'No minimum set means every version may sync', 'an empty setting must not lock anybody out');

/* states */
gate(mks_st_device_state(['status' => 'pending', 'token_hash' => null, 'last_seen_at' => null]) === 'pending'
    && mks_st_device_state(['status' => 'paused', 'token_hash' => 'x', 'last_seen_at' => date('Y-m-d H:i:s')]) === 'paused',
    'Waiting and paused devices show as such', 'a device that never paired must not look offline');

/* connected threshold */
mks_st_stub_settings(['connected_seconds' => 12]);
$connected = mks_st_view_where('calls', ['range' => 'all', 'direction' => 'connected']);
$unanswered = mks_st_view_where('calls', ['range' => 'all', 'direction' => 'unanswered']);

gate(in_array('AND e.duration >= 12', $connected, true) && in_array("AND e.direction = 'outgoing' AND e.duration < 12", $unanswered, true),
    'Connected and Not Answered follow the setting', 'decision C3: the administrator sets when a call counts as connected');

mks_st_stub_settings([]);

gate(!isset(mks_st_kinds()['notification']), 'The phones can send calls, WhatsApp calls and SMS only', 'decision: notifications are not tracked');

/* outcomes */
$cleanOutcomes = mks_st_clean_outcomes([
    ['key' => 'interested', 'label' => ' Hot  lead ', 'tone' => 'green', 'follow_up' => '1', 'lead_status' => '4', 'active' => '1'],
    ['key' => '', 'label' => 'Demo Booked', 'tone' => 'evil', 'active' => '1'],
    ['key' => '', 'label' => 'Demo Booked', 'tone' => 'blue', 'active' => '1'],
    ['key' => 'old_one', 'label' => 'Old', 'remove' => '1'],
    ['key' => 'converted', 'label' => '', 'active' => '0', 'remove' => '1'],
    ['key' => '', 'label' => ''],
]);

gate(array_column($cleanOutcomes, 'key') === ['interested', 'demo_booked', 'demo_booked_2', 'converted']
    && $cleanOutcomes[0]['label'] === 'Hot lead' && $cleanOutcomes[0]['lead_status'] === 4 && $cleanOutcomes[1]['tone'] === 'slate'
    && $cleanOutcomes[3]['active'] === 1 && $cleanOutcomes[3]['label'] === 'Converted',
    'Outcomes clean: new keys from labels, duplicates split, removals honoured, Converted fixed',
    'decision: Converted can never be removed or switched off; everything else is the customer\'s to edit');

gate(array_column(mks_st_clean_outcomes([['key' => 'a', 'label' => 'A', 'active' => '1']]), 'key') === ['a', 'converted'],
    'A list saved without Converted gets it back', 'a missing Converted outcome would break the conversion flow');

/* callback times */
mks_st_stub_settings(['working_days' => [1, 2, 3, 4, 5], 'work_start' => '09:30', 'work_end' => '18:30', 'callback_minutes' => 30]);

gate(mks_st_callback_due('2026-10-13 11:00:00') === '2026-10-13 11:30:00'
    && mks_st_callback_due('2026-10-13 18:20:00') === '2026-10-14 09:50:00'
    && mks_st_callback_due('2026-10-13 21:00:00') === '2026-10-14 10:00:00'
    && mks_st_callback_due('2026-10-16 18:15:00') === '2026-10-19 09:45:00'
    && mks_st_callback_due('2026-10-17 10:00:00') === '2026-10-19 10:00:00',
    'Callback times count working hours only, across nights and weekends', 'decision E4: a call missed after hours is due the next working morning');

$hours = mks_st_save_settings(['enabled' => '1', 'work_start' => '19:00', 'work_end' => '10:00']);
$badTime = mks_st_save_settings(['enabled' => '1', 'work_start' => '9am']);

gate(in_array('mks_st_err_work_hours', $hours['errors'], true) && $hours['settings']['work_start'] === '09:30'
    && in_array('mks_st_err_time', $badTime['errors'], true), 'Working hours are validated', 'a day that ends before it starts makes every callback due at once');

mks_st_stub_settings(['match_customers' => 0]);

gate(!mks_st_customer_visible(), 'With customers switched off nobody sees customer matches', 'decision: lead-only CRMs never show customers');

mks_st_stub_settings([]);

/* lead automation */
$autoSettings = ['auto_lead_direction' => 'both', 'auto_lead_min_seconds' => 30, 'connected_seconds' => 5, 'auto_lead_whatsapp' => 1,
    'auto_lead_history' => 0, 'auto_lead_working_hours' => 0];
$autoRow = ['rel_type' => null, 'number' => '+919812200001', 'number_key' => '9812200001', 'kind' => 'call', 'direction' => 'incoming',
    'duration' => 45, 'occurred_at' => '2026-10-13 11:00:00'];

gate(mks_st_auto_lead_wanted($autoRow, $autoSettings, '2026-10-12 09:00:00')
    && !mks_st_auto_lead_wanted(['duration' => 10] + $autoRow, $autoSettings, null)
    && !mks_st_auto_lead_wanted(['direction' => 'missed', 'duration' => 0] + $autoRow, $autoSettings, null)
    && !mks_st_auto_lead_wanted(['rel_type' => 'lead'] + $autoRow, $autoSettings, null)
    && !mks_st_auto_lead_wanted($autoRow, $autoSettings, '2026-10-13 12:00:00')
    && mks_st_auto_lead_wanted($autoRow, ['auto_lead_history' => 1] + $autoSettings, '2026-10-13 12:00:00')
    && !mks_st_auto_lead_wanted($autoRow, ['auto_lead_direction' => 'outgoing'] + $autoSettings, null)
    && !mks_st_auto_lead_wanted(['kind' => 'whatsapp_call'] + $autoRow, ['auto_lead_whatsapp' => 0] + $autoSettings, null),
    'Automatic leads follow every rule: duration, direction, history, WhatsApp, known numbers',
    'decision: leads are created only by the rules in Settings, never for history unless asked');

mks_st_stub_settings(['working_days' => [1, 2, 3, 4, 5], 'work_start' => '09:30', 'work_end' => '18:30']);

gate(!mks_st_auto_lead_wanted(['occurred_at' => '2026-10-13 21:00:00'] + $autoRow, ['auto_lead_working_hours' => 1] + $autoSettings, null)
    && mks_st_auto_lead_wanted($autoRow, ['auto_lead_working_hours' => 1] + $autoSettings, null),
    'Working Hours Only keeps evening calls from creating leads', 'the switch must hold at the edges of the working day');

mks_st_stub_settings([]);

/* push: the assertion Google verifies */
$rsa = openssl_pkey_new(['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA]);
openssl_pkey_export($rsa, $pem);
$jwt   = mks_st_fcm_jwt(['client_email' => 'svc@demo.iam.gserviceaccount.com', 'private_key' => $pem, 'token_uri' => 'https://oauth2.googleapis.com/token'], 1791900000);
$parts = explode('.', (string) $jwt);
$pad   = function ($b) {
    return base64_decode(strtr($b, '-_', '+/') . str_repeat('=', (4 - strlen($b) % 4) % 4));
};
$claims = count($parts) === 3 ? json_decode($pad($parts[1]), true) : [];

gate(count($parts) === 3 && openssl_verify($parts[0] . '.' . $parts[1], $pad($parts[2]), openssl_pkey_get_details($rsa)['key'], OPENSSL_ALGO_SHA256) === 1
    && $claims['scope'] === 'https://www.googleapis.com/auth/firebase.messaging' && $claims['exp'] - $claims['iat'] === 3600
    && json_decode($pad($parts[0]), true) === ['alg' => 'RS256', 'typ' => 'JWT'],
    'The Firebase assertion is a valid RS256 JWT for the messaging scope', 'Google refuses anything else, and every click-to-call fails silently');

$message = mks_st_fcm_message('tok', ['type' => 'command', 'n' => 5], 120);

gate(!isset($message['message']['notification']) && $message['message']['data'] === ['type' => 'command', 'n' => '5']
    && $message['message']['android']['priority'] === 'high', 'Push messages are data only, high priority, string values',
    'a notification block would show in the phone\'s shade, and FCM rejects non-string data');

/* commands with parameters */
$dialDevice = ['id' => 1, 'status' => 'active', 'commands' => null];

gate(in_array('dial', mks_st_command_types(), true) && mks_st_device_command_add(['status' => 'pending'] + $dialDevice, 'dial', 1, ['number' => '1']) === false,
    'Dial is a command, and only a paired phone can be sent one', 'a dial to a phone that is not there would wait forever');

/* reports */
$missing = array_filter(array_keys(mks_st_reports()), function ($key) {
    return !function_exists('mks_st_report_' . $key);
});

gate(!$missing, 'Every report in the list has its function', 'a report on the menu that cannot run shows an empty page', implode(', ', $missing));

$schedule = ['report_daily' => 1, 'report_daily_time' => '19:00', 'report_weekly' => 1, 'report_weekly_day' => 'mon', 'report_weekly_time' => '09:00',
    'report_monthly' => 1, 'report_monthly_time' => '09:00'];
$monday   = strtotime('2026-11-02 09:05:00');

gate(mks_st_reports_due(strtotime('2026-10-13 18:59:00'), [], $schedule) === []
    && mks_st_reports_due(strtotime('2026-10-13 19:00:00'), [], $schedule) === ['daily' => ['from' => '2026-10-13', 'to' => '2026-10-13']]
    && mks_st_reports_due(strtotime('2026-10-13 21:00:00'), ['daily' => '2026-10-13'], $schedule) === []
    && array_keys(mks_st_reports_due($monday, [], $schedule)) === ['weekly']
    && mks_st_reports_due($monday, [], $schedule)['weekly'] === ['from' => '2026-10-26', 'to' => '2026-11-01']
    && mks_st_reports_due(strtotime('2026-11-01 09:30:00'), [], $schedule)['monthly'] === ['from' => '2026-10-01', 'to' => '2026-10-31'],
    'Scheduled reports go out once, at their time, for the right period', 'a report sent twice, or for the wrong week, is worse than none');

gate(mks_st_xlsx_column(0) === 'A' && mks_st_xlsx_column(25) === 'Z' && mks_st_xlsx_column(26) === 'AA' && mks_st_xlsx_column(51) === 'AZ' && mks_st_xlsx_column(52) === 'BA',
    'Excel column letters run past Z correctly', 'the daily report has more than 26 columns for a month');

$csv = mks_st_report_csv([['Name', 'Calls'], ['=HYPERLINK("x")', 5], ['-12', '-x']]);

gate(substr($csv, 0, 3) === "\xEF\xBB\xBF" && strpos($csv, "'=HYPERLINK") !== false && strpos($csv, "-12") !== false && strpos($csv, "'-x") !== false,
    'CSV opens cleanly in Excel and never carries a live formula', 'a staff or contact name starting with = would run as a formula');

$xlsx = mks_st_report_xlsx([['Staff', 'Calls'], ['A & B <x>', 12], ['C', 3.5]], 'Team: Summary/1');

if ($xlsx !== false) {
    $xlsxFile = tempnam(sys_get_temp_dir(), 'mks_gate_');
    file_put_contents($xlsxFile, $xlsx);
    $xlsxZip = new ZipArchive();
    $xlsxZip->open($xlsxFile);
    $sheetXml = $xlsxZip->getFromName('xl/worksheets/sheet1.xml');
    $bookXml  = $xlsxZip->getFromName('xl/workbook.xml');
    $xlsxZip->close();
    @unlink($xlsxFile);
}

gate($xlsx !== false && simplexml_load_string($sheetXml) !== false && simplexml_load_string($bookXml) !== false
    && strpos($sheetXml, '<v>12</v>') !== false && strpos($sheetXml, 'A &amp; B &lt;x&gt;') !== false && strpos($bookXml, 'Team  Summary 1') !== false,
    'Excel export is a valid workbook with numbers as numbers and text escaped', 'Excel refuses a workbook with one bad character');

/* recordings: Drive, Best Pitches, retention */
$moments = mks_st_parse_moments("1:02 The objection\n0:05 Opening\n75 Close\nno time here\n1:75 bad\n");

gate($moments === [['t' => 5, 'label' => 'Opening'], ['t' => 62, 'label' => 'The objection'], ['t' => 75, 'label' => 'Close']],
    'Best Pitch moments parse from minutes:seconds or seconds, in time order', 'a moment that seeks to the wrong second teaches nothing');

$driveEvent = ['id' => 379, 'occurred_at' => '2026-10-14 02:36:18', 'direction' => 'outgoing', 'number' => '+919813300001', 'number_raw' => null, 'staff_id' => 2];

gate(mks_st_drive_file_name($driveEvent, 'WAV') === '2026-10-14_0236_out_+919813300001_379.wav'
    && mks_st_drive_quote("Rep's \\ name") === "'Rep\\'s \\\\ name'",
    'Drive file names and query literals are built safely', 'a quote in a rep\'s name would break the folder search');

$driveCode = code_only((string) file_get_contents($root . '/helpers/mks_sales_track_drive_helper.php'));

gate(strpos($driveCode, 'best_pitch < 2') !== false && strpos($driveCode, "drive_file_id IS NULL") !== false
    && strpos($driveCode, "source <> 'demo'") !== false && strpos($driveCode, 'auth/drive.file') !== false,
    'Retention spares Best Pitches and Drive copies; demo recordings never go to Drive; Drive access is limited to its own files',
    'decision G6: Best Pitches are never deleted; least-privilege Drive scope');

gate(strpos($bootC, "define('MKS_ST_GOOGLE_BASE'") === false && strpos((string) file_get_contents($root . '/tooling/fake_google.php'), "PHP_SAPI !== 'cli-server'") !== false,
    'Only a test installation can point Google calls elsewhere', 'the stand-in for Google must never answer on a live site');

mks_st_stub_settings(['recording_download' => 'managers']);
$GLOBALS['STUB_STAFF'] = ['view_own', 'play_recordings'];
mks_st_scope(true);
$repDownload = mks_st_can_download();
$GLOBALS['STUB_STAFF'] = 'admin';
mks_st_scope(true);

gate(!$repDownload && mks_st_can_download(), 'Downloads follow the setting: managers only by default', 'decision A5: reps play their own recordings, downloads are for managers');

mks_st_stub_settings([]);

/* AI */
mks_st_stub_settings(['ai_price_audio' => '1.00', 'ai_price_text' => '0.30', 'ai_price_output' => '2.50']);
$aiCost = mks_st_ai_cost(['promptTokenCount' => 21200, 'candidatesTokenCount' => 3000, 'thoughtsTokenCount' => 1000,
    'promptTokensDetails' => [['modality' => 'TEXT', 'tokenCount' => 2000], ['modality' => 'AUDIO', 'tokenCount' => 19200]]]);

gate(abs($aiCost['cost'] - (19200 * 1.00 + 2000 * 0.30 + 4000 * 2.50) / 1000000) < 0.0000001 && $aiCost['out'] === 4000,
    'AI cost prices audio, text and output (thinking included) separately', 'a spending cap built on the wrong price stops too late');

gate(mks_st_ai_estimate(600) > 0.019 && mks_st_ai_estimate(600) < 0.05, 'A ten minute call is estimated at a few cents before it is sent',
    'the cap is checked against this estimate before every call');

mks_st_stub_settings(['outcomes' => [['key' => 'interested', 'label' => 'Interested', 'tone' => 'green', 'follow_up' => 1, 'lead_status' => 0, 'active' => 1]]]);
$norm = mks_st_ai_normalise(['summary' => '<b>Good</b> call', 'sentiment' => 'ecstatic', 'temperature' => 'hot', 'objections' => ['Price', ['x']], 'next_steps' => [],
    'rubric' => [['criterion' => 'A', 'score' => 2], ['criterion' => 'B', 'score' => 7], ['criterion' => 'C', 'score' => -1]],
    'flags' => [['type' => 'discount', 'quote' => 'ten percent'], ['type' => 'made_up']], 'suggestion' => ['outcome' => 'invented', 'follow_up_days' => 400]]);

gate($norm['score'] === 67 && $norm['sentiment'] === 'neutral' && $norm['summary'] === 'Good call' && count($norm['flags']) === 1
    && $norm['suggestion']['outcome'] === '' && $norm['suggestion']['follow_up_days'] === 60 && $norm['objections'] === ['Price'],
    'The model\'s answer is clipped and checked, and the score is worked out from the marks', 'a model that invents an outcome or a score of 140 must not reach the CRM');

mks_st_stub_settings(['ai_rubric' => "Greets\nCloses", 'ai_competitors' => 'Callyzer', 'ai_keywords' => '']);
$ins = mks_st_ai_instructions(['staff_id' => 7, 'direction' => 'incoming', 'duration' => 95, 'rel_type' => 'lead', 'rel_id' => 1, 'number' => '+919800000001', 'contact_name' => 'Secret Person'], 'Asha Rep');
mks_st_stub_settings([]);

gate(strpos($ins, 'Greets; Closes') !== false && strpos($ins, 'Callyzer') !== false && strpos($ins, 'Secret Person') === false && strpos($ins, '+919800000001') === false,
    'Only the call\'s own facts and the module\'s lists reach Gemini: no names, no numbers', 'house rule: scope is enforced in PHP before anything reaches the model');

gate(mks_st_clean_setting_text(' Gemini-2.5-FLASH ', ['clean' => 'model', 'default' => 'gemini-2.5-flash', 'max_length' => 60]) === 'gemini-2.5-flash'
    && mks_st_clean_setting_text('gemini/../x', ['clean' => 'model', 'default' => 'gemini-2.5-flash', 'max_length' => 60]) === 'gemini-2.5-flash'
    && mks_st_clean_setting_text('1,50', ['clean' => 'decimal', 'default' => '1.00', 'max_length' => 10]) === '1.5'
    && mks_st_clean_setting_text('-3', ['clean' => 'decimal', 'default' => '1.00', 'max_length' => 10]) === '1.00',
    'Model names and prices are cleaned', 'the model name is part of the request URL');

gate(strpos(code_only((string) file_get_contents($root . '/uninstall.php')), 'mks_sales_track_ai`') !== false,
    'Uninstall with purge removes the insights table too', 'transcripts must not outlive a purge');

/* call lists, do not call, popup, wallboard */
$totals = mks_st_list_totals([['state' => 'pending'], ['state' => 'tried'], ['state' => 'reached'], ['state' => 'skipped'], ['state' => 'reached']]);

gate($totals === ['total' => 5, 'done' => 3, 'reached' => 2, 'skipped' => 1, 'pending' => 1, 'percent' => 80],
    'Call list progress counts tried, reached and skipped leads', 'a progress bar that disagrees with the rows below it is ignored');

$listsCode = code_only((string) file_get_contents($root . '/helpers/mks_sales_track_lists_helper.php'));
$apiCode   = code_only((string) file_get_contents($root . '/controllers/Mks_sales_track_api.php'));
$wallCode  = code_only((string) file_get_contents($root . '/controllers/Mks_sales_track_wall.php'));

gate(strpos($listsCode, "array_merge(['assign' => [], 'skipped' => []], is_array(\$body)") !== false && strpos($listsCode, 'OVER (') === false,
    'A stored list is never hidden behind empty defaults, and no query needs window functions', 'array union keeps the left value; MySQL 5.7 has no window functions');

gate(strpos($apiCode, "(int) \$list['assign'][(int) \$item['lead_id']] === \$staffId") !== false,
    'A phone can only skip its owner\'s own leads', 'a list is shared between reps; one phone must not reorder another rep\'s work');

gate(strpos($wallCode, "mks_st_enabled('wallboard_public')") !== false && strpos($wallCode, 'hash_equals') !== false && strpos($wallCode, 'noindex') !== false,
    'The public wallboard answers only when switched on, with the exact key, and asks not to be indexed', 'the board is reachable without signing in');

$wallData = code_only((string) substr($listsCode, strpos($listsCode, 'function mks_st_wallboard_data')));

gate(strpos($wallData, 'contact') === false && strpos($wallData, 'number') === false && strpos($wallData, 'rel_id') === false,
    'The wallboard reads no contact names or numbers', 'a screen on the sales floor can be read by visitors');

gate(strpos(code_only((string) file_get_contents($root . '/helpers/mks_sales_track_workflow_helper.php')), "mks_st_is_dnc(\$number)") !== false,
    'Click-to-call refuses do-not-call numbers', 'a number someone asked never to be called again must not ring from a button');

/* analytics: periods */
$tuesday = strtotime('2026-10-13 15:00:00');
$p7      = mks_st_dash_period('7d', $tuesday);
$pm      = mks_st_dash_period('month', $tuesday);
$plm     = mks_st_dash_period('last_month', $tuesday);
$pt      = mks_st_dash_period('today', $tuesday);

gate($p7['from'] === '2026-10-07' && $p7['to'] === '2026-10-13' && $p7['prev_from'] === '2026-09-30' && $p7['prev_to'] === '2026-10-06' && $p7['days'] === 7,
    'A period is compared with the equal period just before it', 'a seven day period compared with six days would make every change look like a drop');

gate($pm['from'] === '2026-10-01' && $pm['days'] === 13 && $pm['prev_to'] === '2026-09-30' && $pm['prev_from'] === '2026-09-18'
    && $plm['from'] === '2026-09-01' && $plm['to'] === '2026-09-30' && $plm['prev_from'] === '2026-08-01' && $plm['prev_to'] === '2026-08-31'
    && $pt['single_day'] && $pt['prev_from'] === '2026-10-12', 'Month, last month and today periods are exact',
    'month boundaries are where off-by-one errors live');

/* analytics: targets */
mks_st_stub_settings(['working_days' => [1, 2, 3, 4, 5], 'target_calls' => 10, 'target_connected' => 6, 'target_talk_minutes' => 30,
    'target_overrides' => ['8' => ['calls' => 15]]]);

gate(mks_st_working_days_between('2026-10-05', '2026-10-18') === 10 && mks_st_working_days_between('2026-10-17', '2026-10-18') === 0,
    'Working days are counted from the days set in Settings', 'targets for a fortnight are ten working days, and a weekend has none');

gate(mks_st_target_for(8) === ['calls' => 15, 'connected' => 6, 'talk' => 1800] && mks_st_target_for(9) === ['calls' => 10, 'connected' => 6, 'talk' => 1800],
    'A person\'s own target overrides only the metrics they were given', 'a blank override box must keep the default, not zero');

$targetSave = mks_st_save_settings(['enabled' => '1', 'working_days' => ['', '6', '9', '6'], 'target_overrides' => ['8' => ['calls' => '20', 'connected' => '', 'talk' => '999'], 'x' => ['calls' => '5']]]);

gate($targetSave['settings']['working_days'] === [6] && $targetSave['settings']['target_overrides'] === ['8' => ['calls' => 20, 'talk' => 600]],
    'Working days and per-person targets are cleaned on save', 'a forged weekday or staff id must not reach the targets');

$noDays = mks_st_save_settings(['enabled' => '1', 'working_days' => ['']]);

gate(in_array('mks_st_err_working_days', $noDays['errors'], true) && $noDays['settings']['working_days'] === [6],
    'At least one working day is required', 'with no working days every target silently disappears');

mks_st_stub_settings([]);

/* analytics: change against the previous period */
gate(mks_st_dash_delta(12, 10)['direction'] === 'up' && mks_st_dash_delta(12, 10)['good'] && !mks_st_dash_delta(12, 10, true)['good']
    && mks_st_dash_delta(0, 0) === null && mks_st_dash_delta(5, 0)['label'] === 'New' && mks_st_dash_delta(10, 10)['direction'] === 'flat',
    'Changes are judged the right way round', 'more missed calls must never show as good news');

gate(mks_st_nice_max(0) === 1 && mks_st_nice_max(7) === 10 && mks_st_nice_max(13) === 20 && mks_st_nice_max(240) === 500,
    'Chart axes round to readable maxima', 'an axis topping out at 13 reads as a rendering fault');

/* analytics: internal calls */
mks_st_stub_settings(['exclude_internal' => 1]);
$withRule = mks_st_dash_where('2026-10-01', '2026-10-13', [7]);
mks_st_stub_settings(['exclude_internal' => 0]);
$withoutRule = mks_st_dash_where('2026-10-01', '2026-10-13', [7]);
mks_st_stub_settings([]);

gate(strpos($withRule, "rel_type <> 'staff'") !== false && strpos($withoutRule, "rel_type <> 'staff'") === false && strpos($withRule, 'AND e.staff_id IN (7)') !== false,
    'Analytics leave calls between staff out when told to, and stay scoped', 'decision C2: internal calls are kept but not counted');

/* analytics: SVG */
$svgs = [
    mks_st_svg_columns([['label' => 'Mon', 'full' => 'Mon <b>&', 'values' => [3, 2]], ['label' => '2', 'full' => 'x', 'values' => [0, 0]]], 'Calls & more'),
    mks_st_svg_heatmap(['matrix' => [0 => [10 => ['calls' => 4, 'connected' => 3]]], 'hours' => range(9, 19), 'wide' => false, 'best' => null]),
    mks_st_svg_donut([['label' => 'A <x>', 'value' => 3, 'tone' => 'blue'], ['label' => 'B', 'value' => 1, 'tone' => 'red']], '4', 'Calls'),
];
$xmlOk = true;

libxml_use_internal_errors(true);

foreach ($svgs as $svg) {
    if (simplexml_load_string($svg) === false || strpos($svg, '<b>') !== false) {
        $xmlOk = false;
    }
}

gate($xmlOk, 'Charts are well formed SVG with every label escaped', 'a stray ampersand in a staff or day label breaks the whole chart');

echo "\n" . str_repeat('=', 66) . "\n" . $pass . " passed, " . $fail . " failed\n";

exit($fail > 0 ? 1 : 0);
