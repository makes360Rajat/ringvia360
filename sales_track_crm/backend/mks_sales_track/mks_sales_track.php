<?php

defined('BASEPATH') or exit('No direct script access allowed');

/*
Module Name: Sales Track
Description: Mobile call tracking for sales teams on company phones: calls and their recordings, WhatsApp calls and SMS, sent in by the Sales Track app through a token secured API, matched to leads, customers and staff, with devices paired by a 6-digit code. Everything is reached from one Sales Track menu item and controlled from its own Settings page. No core file is modified.
Version: 1.9.2
Requires at least: 3.0.0
Author: Makes360
Author URI: https://makes360.com
*/

define('MKS_SALES_TRACK_MODULE_NAME', 'mks_sales_track');

/**
 * Must always equal the Version header above. The header decides the migration
 * number, this constant the ?v= cache buster. tooling/gates.php fails the
 * release when they differ.
 */
define('MKS_SALES_TRACK_VERSION', '1.9.2');

/**
 * Bumped whenever the installer learns something new, so it re-runs on the next
 * admin page or API call even when files were uploaded over an older copy
 * without Upgrade Database. 2: devices v2 columns, nullable phone binding.
 * 3: targets and analytics settings.
 * 4: outcomes, follow-ups, missed-call queue and device alerts.
 * 5: push tokens, lead automation and click-to-call settings.
 * 6: scheduled email report settings.
 * 7: Google Drive storage, retention and Best Pitches.
 * 8: AI call insights (event columns and the insights table).
 * 9: call lists, do-not-call numbers, caller popup and wallboard settings.
 * 10: intelligent 120s call deduplication, recording auto-linking and multi-device match.
 * 11: full multi-kind intra-batch and natural window deduplication for calls, SMS, WhatsApp and notifications.
 * 12: comprehensive number-agnostic duplicate purge and clock-sync alignment for calls, SMS and WhatsApp.
 * 13: comprehensive fetch and save/update API with events endpoint and enhanced field updates.
 * 14: precise Android CallLog ID-based and direction-aware call deduplication so distinct historical and sequential calls are fully preserved.
 * 15: resilient direct-db pairing store synchronization, fallback expiration guard, and safe non-destructive pairing redemption.
 * 16: client sync reliability and unsaved contact identification standardization.
 * 17: numeric pairing code input, 3/4-tier call card UI, and contact title fallback harmonization.
 */
define('MKS_SALES_TRACK_SCHEMA_REV', '17');

/** Every setting lives in this one autoloaded JSON option. */
define('MKS_SALES_TRACK_OPTION', 'mks_sales_track_settings');

/** The phone API, routed by config/routes.php and exempt from CSRF. */
define('MKS_SALES_TRACK_API_PATH', 'mks_sales_track/api/v1/');

/** PBKDF2 rounds for the app lock PIN. The phone checks the PIN with the same. */
define('MKS_ST_PIN_ITERATIONS', 100000);

/**
 * Google's endpoints. A test installation may point every one of them at a
 * local stand-in by defining MKS_ST_GOOGLE_BASE in its own config; nothing in
 * the module ever defines it.
 *
 * @param  string $service oauth, accounts, apis or fcm
 *
 * @return string base URL without a trailing slash
 */
function mks_st_google_url($service)
{
    if (defined('MKS_ST_GOOGLE_BASE')) {
        return rtrim((string) MKS_ST_GOOGLE_BASE, '/');
    }

    $bases = [
        'oauth'    => 'https://oauth2.googleapis.com',
        'accounts' => 'https://accounts.google.com',
        'apis'     => 'https://www.googleapis.com',
        'fcm'      => 'https://fcm.googleapis.com',
        'gemini'   => 'https://generativelanguage.googleapis.com',
    ];

    return $bases[$service];
}

$CI = &get_instance();

register_language_files(MKS_SALES_TRACK_MODULE_NAME, [MKS_SALES_TRACK_MODULE_NAME]);

/**
 * Required rather than loaded through the CodeIgniter helper loader so the
 * functions exist before any hook fires, and guarded so a partially uploaded
 * folder can never take the CRM down with a fatal require.
 */
foreach (['mks_sales_track_helper.php', 'mks_sales_track_view_helper.php', 'mks_sales_track_workflow_helper.php'] as $mks_st_helper) {
    if (file_exists(__DIR__ . '/helpers/' . $mks_st_helper)) {
        require_once __DIR__ . '/helpers/' . $mks_st_helper;
    }
}

/*
|--------------------------------------------------------------------------
| Activation and uninstall
|--------------------------------------------------------------------------
*/
register_activation_hook(MKS_SALES_TRACK_MODULE_NAME, 'mks_sales_track_activation_hook');

function mks_sales_track_activation_hook()
{
    $CI = &get_instance();

    require __DIR__ . '/install.php';
}

register_uninstall_hook(MKS_SALES_TRACK_MODULE_NAME, 'mks_sales_track_uninstall_hook');

function mks_sales_track_uninstall_hook()
{
    $CI = &get_instance();

    require __DIR__ . '/uninstall.php';
}

/*
|--------------------------------------------------------------------------
| Hooks
|--------------------------------------------------------------------------
*/
hooks()->add_action('admin_init', 'mks_st_maybe_upgrade', 0);
hooks()->add_action('admin_init', 'mks_st_register_permissions');
hooks()->add_action('admin_init', 'mks_st_register_settings_link');
hooks()->add_action('admin_init', 'mks_st_register_menu');
hooks()->add_action('app_admin_head', 'mks_st_admin_head');
hooks()->add_action('app_admin_footer', 'mks_st_admin_footer');

// A Calls tab on the lead window and on the customer profile.
hooks()->add_action('after_lead_lead_tabs', 'mks_st_lead_tab');
hooks()->add_action('after_lead_tabs_content', 'mks_st_lead_tab_content');
hooks()->add_action('admin_init', 'mks_st_register_customer_tab');
hooks()->add_filter('module_' . MKS_SALES_TRACK_MODULE_NAME . '_action_links', 'mks_st_module_action_links');

// Numbers that were unknown when their calls arrived link themselves as soon
// as somebody saves them on a lead, contact or customer.
hooks()->add_action('lead_created', 'mks_st_on_lead_saved');
hooks()->add_action('after_lead_updated', 'mks_st_on_lead_saved');
hooks()->add_action('contact_created', 'mks_st_on_contact_saved');
hooks()->add_action('contact_updated', 'mks_st_on_contact_saved', 10, 2);
hooks()->add_action('after_client_created', 'mks_st_on_client_saved');
hooks()->add_action('client_updated', 'mks_st_on_client_saved');

// Missed-call escalation and silent phone alerts run with Perfex's own cron.
hooks()->add_action('after_cron_run', 'mks_st_on_cron');

// A deactivated or deleted member of staff loses their phone's access.
hooks()->add_action('after_staff_status_change', 'mks_st_on_staff_changed');
hooks()->add_action('staff_member_updated', 'mks_st_on_staff_changed');
hooks()->add_action('staff_member_deleted', 'mks_st_on_staff_changed');

/**
 * Re-run the idempotent installer when the shipped revision is newer than the
 * recorded one. The recorded value is autoloaded, so the check is in memory.
 *
 * @return void
 */
function mks_st_maybe_upgrade()
{
    if (!function_exists('get_option')) {
        return;
    }

    if ((string) get_option('mks_sales_track_schema_rev') === (string) MKS_SALES_TRACK_SCHEMA_REV) {
        return;
    }

    $CI = &get_instance();

    require __DIR__ . '/install.php';
}

/*
|--------------------------------------------------------------------------
| Settings
|--------------------------------------------------------------------------
| Defined in the bootstrap: the sidebar is built on admin_init from these, and
| anything that early must not depend on a file that might be missing. The
| schema file is the one exception, and a missing schema leaves the module
| switched off rather than broken.
*/

/**
 * The settings schema from config/settings_schema.php.
 *
 * @return array sections, fields
 */
function mks_st_settings_schema()
{
    static $schema = null;

    if ($schema === null) {
        $file   = __DIR__ . '/config/settings_schema.php';
        $loaded = file_exists($file) ? include $file : null;
        $schema = is_array($loaded) && isset($loaded['sections'], $loaded['fields'])
            ? $loaded
            : ['sections' => [], 'fields' => []];
    }

    return $schema;
}

/**
 * Stored keys and their defaults. A pin field is never stored itself; its hash
 * and salt are, as internal fields.
 *
 * @return array
 */
function mks_st_setting_defaults()
{
    $out = [];

    foreach (mks_st_settings_schema()['fields'] as $key => $field) {
        if (!in_array($field['type'], ['pin', 'secret_json', 'secret'], true)) {
            $out[$key] = $field['default'];
        }
    }

    return $out;
}

/**
 * The stored settings merged over the defaults.
 *
 * $override exists because get_option() keeps serving the value autoloaded at
 * the start of the request; re-reading straight after a save would return the
 * old settings for the rest of that request.
 *
 * @param  bool       $reload
 * @param  array|null $override
 *
 * @return array
 */
function mks_st_settings($reload = false, $override = null)
{
    static $cache = null;

    $defaults = mks_st_setting_defaults();

    if (is_array($override)) {
        $cache = array_merge($defaults, array_intersect_key($override, $defaults));

        return $cache;
    }

    if ($cache !== null && !$reload) {
        return $cache;
    }

    $stored = [];

    if (function_exists('get_option')) {
        $decoded = json_decode((string) get_option(MKS_SALES_TRACK_OPTION), true);
        $stored  = is_array($decoded) ? $decoded : [];
    }

    // A key retired in a later version cannot come back, and a key added later
    // still gets its default.
    $cache = array_merge($defaults, array_intersect_key($stored, $defaults));

    return $cache;
}

/**
 * @param  string $key
 * @param  mixed  $default
 *
 * @return mixed
 */
function mks_st_setting($key, $default = null)
{
    $settings = mks_st_settings();

    return array_key_exists($key, $settings) ? $settings[$key] : $default;
}

/**
 * Is a feature on? With no argument this answers for the master switch, which
 * every other switch sits behind.
 *
 * @param  string|null $key
 *
 * @return bool
 */
function mks_st_enabled($key = null)
{
    $settings = mks_st_settings();

    if (empty($settings['enabled'])) {
        return false;
    }

    if ($key === null || $key === 'enabled') {
        return true;
    }

    return !empty($settings[$key]);
}

/**
 * Clean and store a posted settings form against the schema.
 *
 * Absent switches are stored as 0, which is what lets a switch be turned off.
 * A blank PIN keeps the current one; App Lock cannot be on without a PIN.
 *
 * @param  array $posted
 *
 * @return array settings, errors (language keys)
 */
function mks_st_save_settings($posted)
{
    $posted  = is_array($posted) ? $posted : [];
    $current = mks_st_settings();
    $clean   = $current;
    $errors  = [];

    foreach (mks_st_settings_schema()['fields'] as $key => $field) {
        switch ($field['type']) {
            case 'switch':
                $clean[$key] = (isset($posted[$key]) && (string) $posted[$key] === '1') ? 1 : 0;
                break;

            case 'number':
                $value       = isset($posted[$key]) && is_numeric($posted[$key]) ? (int) $posted[$key] : (int) $current[$key];
                $clean[$key] = max((int) $field['min'], min((int) $field['max'], $value));
                break;

            case 'choice':
                $value       = isset($posted[$key]) ? (string) $posted[$key] : (string) $current[$key];
                $clean[$key] = array_key_exists($value, $field['options']) ? $value : $field['default'];
                break;

            case 'text':
            case 'textarea':
                $value       = isset($posted[$key]) && is_string($posted[$key]) ? $posted[$key] : (string) $current[$key];
                $clean[$key] = mks_st_clean_setting_text($value, $field);
                break;

            case 'days':
                // The form always posts a blank entry first, so a missing key
                // means the field was not on the form at all.
                if (!isset($posted[$key]) || !is_array($posted[$key])) {
                    break;
                }

                $days = array_values(array_unique(array_filter(array_map('intval', $posted[$key]), function ($day) {
                    return $day >= 1 && $day <= 7;
                })));
                sort($days);

                if ($days) {
                    $clean[$key] = $days;
                } else {
                    $errors[] = 'mks_st_err_working_days';
                }
                break;

            case 'staff_targets':
                if (!isset($posted[$key]) || !is_array($posted[$key])) {
                    break;
                }

                $targets = [];

                foreach ($posted[$key] as $staffId => $values) {
                    if (!ctype_digit((string) $staffId) || !is_array($values)) {
                        continue;
                    }

                    $row = [];

                    foreach (['calls' => 500, 'connected' => 500, 'talk' => 600] as $metric => $max) {
                        if (isset($values[$metric]) && is_scalar($values[$metric]) && trim((string) $values[$metric]) !== '' && is_numeric($values[$metric])) {
                            $row[$metric] = max(0, min($max, (int) $values[$metric]));
                        }
                    }

                    if ($row) {
                        $targets[(string) (int) $staffId] = $row;
                    }
                }

                $clean[$key] = $targets;
                break;

            case 'outcomes':
                if (isset($posted[$key]) && is_array($posted[$key])) {
                    $clean[$key] = mks_st_clean_outcomes($posted[$key]);
                }
                break;

            case 'lead_status':
            case 'lead_source':
            case 'staff':
                if (isset($posted[$key]) && is_scalar($posted[$key])) {
                    $clean[$key] = max(0, (int) $posted[$key]);
                }
                break;

            case 'time':
                if (isset($posted[$key]) && is_scalar($posted[$key])) {
                    $time = trim((string) $posted[$key]);

                    if (preg_match('/^([01]\d|2[0-3]):[0-5]\d$/', $time)) {
                        $clean[$key] = $time;
                    } else {
                        $errors[] = 'mks_st_err_time';
                    }
                }
                break;

            case 'secret':
                $secret = isset($posted[$key]) && is_string($posted[$key]) ? trim($posted[$key]) : '';
                $clear  = isset($posted[$key . '_clear']) && (string) $posted[$key . '_clear'] === '1';

                if ($clear) {
                    mks_st_option_put($field['option'], '', 0);
                } elseif ($secret !== '') {
                    if (strlen($secret) > 300 || preg_match('/\s/', $secret)) {
                        $errors[] = 'mks_st_err_secret';
                    } else {
                        $CI = &get_instance();
                        mks_st_option_put($field['option'], $CI->encryption->encrypt($secret), 0);
                    }
                }
                break;

            case 'secret_json':
                // Kept encrypted in its own option by the push helper; a blank
                // field keeps what is there.
                $secret = isset($posted[$key]) && is_string($posted[$key]) ? trim($posted[$key]) : '';
                $clear  = isset($posted[$key . '_clear']) && (string) $posted[$key . '_clear'] === '1';

                if (($clear || $secret !== '') && file_exists(__DIR__ . '/helpers/mks_sales_track_push_helper.php')) {
                    require_once __DIR__ . '/helpers/mks_sales_track_push_helper.php';

                    if ($clear) {
                        mks_st_fcm_clear();
                    } else {
                        $stored = mks_st_fcm_save_key($secret);

                        if ($stored !== true) {
                            $errors[] = $stored;
                        }
                    }
                }
                break;

            case 'pin':
                $pin   = isset($posted[$key]) && is_string($posted[$key]) ? trim($posted[$key]) : '';
                $clear = isset($posted[$key . '_clear']) && (string) $posted[$key . '_clear'] === '1';

                list($hashKey, $saltKey) = $field['store'];

                if ($clear) {
                    $clean[$hashKey] = '';
                    $clean[$saltKey] = '';
                } elseif ($pin !== '') {
                    if (preg_match('/^\d{4,8}$/', $pin)) {
                        $salt            = bin2hex(random_bytes(16));
                        $clean[$saltKey] = $salt;
                        $clean[$hashKey] = mks_st_pin_hash($pin, $salt);
                    } else {
                        $errors[] = 'mks_st_err_pin_format';
                    }
                }
                break;
        }
    }

    if (!empty($clean['app_lock_enabled']) && $clean['app_lock_hash'] === '') {
        $clean['app_lock_enabled'] = 0;
        $errors[]                  = 'mks_st_err_pin_needed';
    }

    // The wallboard's secret link: made when the public board is switched on,
    // and replaced on request so an old link stops working.
    if ((!empty($clean['wallboard_public']) && (string) $clean['wallboard_key'] === '') || !empty($posted['wallboard_new_link'])) {
        $clean['wallboard_key'] = bin2hex(random_bytes(20));
    }

    if (isset($clean['work_start'], $clean['work_end']) && $clean['work_end'] <= $clean['work_start']) {
        $clean['work_start'] = $current['work_start'];
        $clean['work_end']   = $current['work_end'];
        $errors[]            = 'mks_st_err_work_hours';
    }

    mks_st_option_put(MKS_SALES_TRACK_OPTION, json_encode($clean), 1);
    mks_st_option_put('mks_sales_track_saved_at', (string) time(), 0);

    return ['settings' => mks_st_settings(false, $clean), 'errors' => $errors];
}

/**
 * @param  string $value
 * @param  array  $field
 *
 * @return string
 */
function mks_st_clean_setting_text($value, array $field)
{
    $clean = isset($field['clean']) ? $field['clean'] : '';
    $max   = isset($field['max_length']) ? (int) $field['max_length'] : 255;

    switch ($clean) {
        case 'digits':
            $value = preg_replace('/\D+/', '', $value);

            return ($value === '' || strlen($value) > $max) ? (string) $field['default'] : $value;

        case 'version':
            $value = trim($value);

            return preg_match('/^\d+(\.\d+){0,3}$/', $value) && strlen($value) <= $max ? $value : '';

        case 'url':
            $value = trim($value);

            return ($value !== '' && strlen($value) <= $max && preg_match('#^https://[^\s<>"\']+$#i', $value)) ? $value : '';

        case 'numbers':
            return implode("\n", mks_st_clean_number_list($value));

        case 'model':
            $value = strtolower(trim($value));

            return preg_match('/^[a-z0-9][a-z0-9.\-]{2,59}$/', $value) ? $value : (string) $field['default'];

        case 'decimal':
            $value = trim(str_replace(',', '.', $value));

            return is_numeric($value) && $value >= 0 && $value <= 1000 ? rtrim(rtrim(number_format((float) $value, 4, '.', ''), '0'), '.') : (string) $field['default'];

        case 'lines':
            $lines = [];

            foreach (preg_split('/[\r\n]+/', $value) as $line) {
                $line = mb_substr(trim(strip_tags($line)), 0, 160, 'UTF-8');

                if ($line !== '' && !in_array($line, $lines, true)) {
                    $lines[] = $line;
                }
            }

            return implode("\n", array_slice($lines, 0, 20));
    }

    return mb_substr(trim(strip_tags($value)), 0, $max, 'UTF-8');
}

/**
 * The app lock PIN hash the phone recomputes: PBKDF2-SHA256, hex.
 *
 * @param  string $pin
 * @param  string $salt hex
 *
 * @return string
 */
function mks_st_pin_hash($pin, $salt)
{
    return hash_pbkdf2('sha256', (string) $pin, (string) $salt, MKS_ST_PIN_ITERATIONS, 64);
}

/**
 * The after-call outcome list, cleaned. Keys are kept for existing rows and
 * made from the label for new ones; the converted outcome is fixed: it can be
 * renamed but never removed or switched off, and comes back if it goes
 * missing.
 *
 * @param  array $rows
 *
 * @return array
 */
function mks_st_clean_outcomes(array $rows)
{
    $tones = ['blue', 'green', 'red', 'amber', 'violet', 'slate'];
    $out   = [];
    $keys  = [];

    foreach ($rows as $row) {
        if (!is_array($row)) {
            continue;
        }

        $label = isset($row['label']) && is_scalar($row['label']) ? trim(preg_replace('/\s+/', ' ', strip_tags((string) $row['label']))) : '';
        $label = mb_substr($label, 0, 40, 'UTF-8');
        $key   = isset($row['key']) && is_scalar($row['key']) ? preg_replace('/[^a-z0-9_]/', '', strtolower((string) $row['key'])) : '';
        $fixed = $key === 'converted';

        if (!$fixed && ($label === '' || !empty($row['remove']))) {
            continue;
        }

        if ($label === '') {
            $label = 'Converted';
        }

        if ($key === '') {
            $key = trim(substr(preg_replace('/[^a-z0-9]+/', '_', strtolower($label)), 0, 30), '_');
            $key = $key === '' ? 'outcome' : $key;
        }

        $base = $key;
        $n    = 2;

        while (isset($keys[$key]) || ($key === 'converted' && !$fixed)) {
            $key = $base . '_' . $n++;
        }

        $keys[$key] = true;

        $out[] = [
            'key'         => $key,
            'label'       => $label,
            'tone'        => isset($row['tone']) && in_array($row['tone'], $tones, true) ? $row['tone'] : 'slate',
            'follow_up'   => !empty($row['follow_up']) ? 1 : 0,
            'lead_status' => isset($row['lead_status']) && is_numeric($row['lead_status']) ? max(0, (int) $row['lead_status']) : 0,
            'active'      => ($fixed || !empty($row['active'])) ? 1 : 0,
        ];

        if (count($out) >= 20) {
            break;
        }
    }

    if (!isset($keys['converted'])) {
        $out[] = ['key' => 'converted', 'label' => 'Converted', 'tone' => 'violet', 'follow_up' => 0, 'lead_status' => 0, 'active' => 1];
    }

    return $out;
}

/**
 * Phone numbers, one per line, kept as digits (a leading + is preserved).
 * Anything shorter than six digits is not a number worth excluding.
 *
 * @param  string $text
 *
 * @return array
 */
function mks_st_clean_number_list($text)
{
    $out = [];

    foreach (preg_split('/[\r\n,;]+/', (string) $text) as $item) {
        $item   = trim($item);
        $digits = preg_replace('/\D+/', '', $item);

        if (strlen($digits) < 6 || strlen($digits) > 18) {
            continue;
        }

        $value       = (strpos($item, '+') === 0 ? '+' : '') . $digits;
        $out[$value] = $value;

        if (count($out) >= 500) {
            break;
        }
    }

    return array_values($out);
}

/**
 * Create or update an option with an explicit autoload flag.
 *
 * Perfex's update_option() creates a missing option through
 * add_option($name, $value, $autoload === null ? 1 : 0): passing 1 creates it
 * NOT autoloaded, and get_option() then queries on every call.
 *
 * @param  string $name
 * @param  string $value
 * @param  int    $autoload
 *
 * @return void
 */
function mks_st_option_put($name, $value, $autoload = 1)
{
    $CI = &get_instance();
    $table = db_prefix() . 'options';
    $data  = ['value' => $value, 'autoload' => $autoload ? 1 : 0];

    // Direct DB check - never trust the in-memory cache for existence.
    $exists = $CI->db->select('name')->where('name', $name)->get($table)->row();

    if ($exists) {
        $CI->db->where('name', $name)->update($table, $data);
    } else {
        $data['name'] = $name;
        $CI->db->insert($table, $data);

        // Guard against a race: if insert failed (duplicate), fall back to update.
        if ($CI->db->affected_rows() === 0) {
            unset($data['name']);
            $CI->db->where('name', $name)->update($table, $data);
        }
    }

    // Keep every Perfex cache layer consistent.
    if (isset($CI->app_object_cache) && is_object($CI->app_object_cache)) {
        $CI->app_object_cache->set('option-' . $name, $value);
    }

    if (isset($CI->app) && isset($CI->app->options) && is_array($CI->app->options)) {
        $CI->app->options[$name] = $value;
    }
}

/*
|--------------------------------------------------------------------------
| Permissions
|--------------------------------------------------------------------------
| view_own        own activity, own phone's status
| view_team       the activity of everybody who shares a Perfex department
|                 with you (team leads)
| view            everybody's activity
| play_recordings listen to and download recordings you can see
| manage_pitches  add calls to the Best Pitches library and approve nominations
| manage_devices  add, edit, pause, regenerate, revoke and delete phones
| delete          delete activity records
| Settings follow Perfex's own settings permission.
*/
function mks_st_register_permissions()
{
    if (!function_exists('register_staff_capabilities')) {
        return;
    }

    register_staff_capabilities(MKS_SALES_TRACK_MODULE_NAME, [
        'capabilities' => [
            'view_own'        => _l('mks_st_cap_view_own'),
            'view_team'       => _l('mks_st_cap_view_team'),
            'view'            => _l('mks_st_cap_view'),
            'play_recordings' => _l('mks_st_cap_play_recordings'),
            'manage_pitches'  => _l('mks_st_cap_manage_pitches'),
            'manage_devices'  => _l('mks_st_cap_manage_devices'),
            'delete'          => _l('mks_st_cap_delete'),
        ],
    ], _l('mks_st_menu'));
}

/**
 * @return bool
 */
function mks_st_is_admin()
{
    return function_exists('is_admin') && is_admin();
}

/**
 * Whose activity can the signed in member of staff see?
 *
 *   null   everybody (administrators, View All Activity)
 *   int[]  these staff ids: yourself, plus your department colleagues with
 *          View Team Activity
 *   false  nothing
 *
 * Enforced in SQL by every read in the module, through mks_st_scope_sql().
 * Worked out once per request; $reset is for the gates, which change the
 * signed in member of staff's permissions between checks.
 *
 * @param  bool $reset
 *
 * @return int[]|null|false
 */
function mks_st_scope($reset = false)
{
    static $cache = [];

    if ($reset) {
        $cache = [];
    }

    if (!function_exists('is_staff_logged_in') || !is_staff_logged_in()) {
        return false;
    }

    $me = (int) get_staff_user_id();

    if (array_key_exists($me, $cache)) {
        return $cache[$me];
    }

    if (mks_st_is_admin() || staff_can('view', MKS_SALES_TRACK_MODULE_NAME)) {
        return $cache[$me] = null;
    }

    if (staff_can('view_team', MKS_SALES_TRACK_MODULE_NAME)) {
        return $cache[$me] = array_values(array_unique(array_merge([$me], mks_st_team_ids($me))));
    }

    if (staff_can('view_own', MKS_SALES_TRACK_MODULE_NAME)) {
        return $cache[$me] = [$me];
    }

    return $cache[$me] = false;
}

/**
 * Everybody who shares at least one Perfex department with a member of staff.
 *
 * @param  int $staff_id
 *
 * @return int[]
 */
function mks_st_team_ids($staff_id)
{
    $CI = &get_instance();
    $p  = db_prefix();

    $rows = $CI->db->query('SELECT DISTINCT b.staffid FROM ' . $p . 'staff_departments a'
        . ' JOIN ' . $p . 'staff_departments b ON b.departmentid = a.departmentid'
        . ' WHERE a.staffid = ' . (int) $staff_id)->result_array();

    return array_map('intval', array_column($rows, 'staffid'));
}

/**
 * The scope as an SQL condition on a staff id column, starting with AND, or ''
 * for everybody.
 *
 * @param  string               $column
 * @param  int[]|null|false|string $scope 'auto' for the signed in viewer
 *
 * @return string
 */
function mks_st_scope_sql($column, $scope = 'auto')
{
    $scope = $scope === 'auto' ? mks_st_scope() : $scope;

    if ($scope === null) {
        return '';
    }

    if ($scope === false || !$scope) {
        return 'AND 1 = 0';
    }

    return 'AND ' . $column . ' IN (' . implode(', ', array_map('intval', $scope)) . ')';
}

/**
 * May the viewer see this member of staff's activity?
 *
 * @param  int $staff_id
 *
 * @return bool
 */
function mks_st_scope_allows($staff_id)
{
    $scope = mks_st_scope();

    if ($scope === false) {
        return false;
    }

    return $scope === null || in_array((int) $staff_id, $scope, true);
}

/**
 * Does the viewer see only themselves (a rep's view)?
 *
 * @return bool
 */
function mks_st_scope_is_own()
{
    $scope = mks_st_scope();

    return is_array($scope) && count($scope) === 1;
}

/**
 * @return bool
 */
function mks_st_can_access()
{
    return mks_st_scope() !== false || mks_st_can_settings();
}

/**
 * @param  string $capability play_recordings, manage_devices or delete
 *
 * @return bool
 */
function mks_st_can($capability)
{
    if (!function_exists('is_staff_logged_in') || !is_staff_logged_in()) {
        return false;
    }

    return mks_st_is_admin() || staff_can($capability, MKS_SALES_TRACK_MODULE_NAME);
}

/**
 * Settings follow Perfex's own settings permission.
 *
 * @param  bool $edit
 *
 * @return bool
 */
function mks_st_can_settings($edit = false)
{
    if (!function_exists('is_staff_logged_in') || !is_staff_logged_in()) {
        return false;
    }

    return mks_st_is_admin() || staff_can($edit ? 'edit' : 'view', 'settings');
}

/*
|--------------------------------------------------------------------------
| Activity pages
|--------------------------------------------------------------------------
*/

/**
 * @return array slug => kind, setting, icon, label key, subtitle key
 */
function mks_st_pages()
{
    return [
        'calls' => [
            'kind'    => 'call',
            'setting' => 'track_calls',
            'icon'    => 'fa-solid fa-phone',
            'label'   => 'mks_st_page_calls',
            'sub'     => 'mks_st_page_calls_sub',
        ],
        'recordings' => [
            'kind'    => 'call',
            'setting' => 'track_recordings',
            'icon'    => 'fa-solid fa-microphone',
            'label'   => 'mks_st_page_recordings',
            'sub'     => 'mks_st_page_recordings_sub',
        ],
        'whatsapp_calls' => [
            'kind'    => 'whatsapp_call',
            'setting' => 'track_whatsapp_calls',
            'icon'    => 'fa-brands fa-whatsapp',
            'label'   => 'mks_st_page_whatsapp_calls',
            'sub'     => 'mks_st_page_whatsapp_calls_sub',
        ],
        'sms' => [
            'kind'    => 'sms',
            'setting' => 'track_sms',
            'icon'    => 'fa-solid fa-message',
            'label'   => 'mks_st_page_sms',
            'sub'     => 'mks_st_page_sms_sub',
        ],
    ];
}

/*
|--------------------------------------------------------------------------
| Sidebar: one item
|--------------------------------------------------------------------------
| Sales Track opens the Dashboard; every other page, Settings included, is
| reached from the tab bar on the module's pages.
*/
function mks_st_register_menu()
{
    if (!mks_st_enabled() || !mks_st_enabled('sidebar') || mks_st_scope() === false) {
        return;
    }

    $CI = &get_instance();

    $CI->app_menu->add_sidebar_menu_item('mks-sales-track', [
        'name'     => _l('mks_st_menu'),
        'href'     => admin_url(MKS_SALES_TRACK_MODULE_NAME),
        'icon'     => 'fa-solid fa-phone-volume',
        'position' => 47,
    ]);
}

/**
 * Setup > Settings keeps one Sales Track entry: a link to the module's own
 * settings page, with Perfex's Save button switched off.
 *
 * @return void
 */
function mks_st_register_settings_link()
{
    $CI = &get_instance();

    if (!mks_st_can_settings()) {
        return;
    }

    $CI->app->add_settings_section('mks-sales-track', [
        'title'    => _l('mks_st_menu'),
        'position' => 42,
        'children' => [
            [
                'id'                    => 'mks_sales_track',
                'name'                  => _l('mks_st_menu'),
                'view'                  => MKS_SALES_TRACK_MODULE_NAME . '/settings_link',
                'position'              => 5,
                'icon'                  => 'fa-solid fa-phone-volume',
                'without_submit_button' => true,
            ],
        ],
    ]);
}

/**
 * @param  array $actions
 *
 * @return array
 */
function mks_st_module_action_links($actions)
{
    $actions[] = '<a href="' . admin_url(MKS_SALES_TRACK_MODULE_NAME . '/settings') . '">' . _l('settings') . '</a>';

    return $actions;
}

/*
|--------------------------------------------------------------------------
| Assets: only on the module's own screens
|--------------------------------------------------------------------------
*/

/**
 * The module page being rendered, 'crm' on Perfex's leads and customer pages
 * (which carry our Calls tab), or ''.
 *
 * @return string
 */
function mks_st_current_page()
{
    static $page = null;

    if ($page === null) {
        $CI    = &get_instance();
        $class = strtolower((string) $CI->router->fetch_class());

        if ($class === MKS_SALES_TRACK_MODULE_NAME) {
            $page = strtolower((string) $CI->router->fetch_method()) ?: 'index';
        } elseif (in_array($class, ['leads', 'clients'], true) && mks_st_enabled() && mks_st_enabled('crm_tabs') && mks_st_scope() !== false) {
            $page = 'crm';
        } else {
            $page = '';
        }
    }

    return $page;
}

/**
 * The script configuration a controller hands to the footer.
 *
 * @param  array|null $config
 *
 * @return array
 */
function mks_st_page_config($config = null)
{
    static $store = [];

    if (is_array($config)) {
        $store = $config;
    }

    return $store;
}

function mks_st_admin_head()
{
    if (mks_st_current_page() === '') {
        return;
    }

    echo '<link rel="stylesheet" type="text/css" href="'
        . module_dir_url(MKS_SALES_TRACK_MODULE_NAME, 'assets/css/mks-sales-track.css')
        . '?v=' . MKS_SALES_TRACK_VERSION . '" />' . PHP_EOL;
}

function mks_st_admin_footer()
{
    $page = mks_st_current_page();

    if ($page === '') {
        return;
    }

    $config = mks_st_page_config();

    if (!isset($config['page'])) {
        $config['page'] = $page;
    }

    $config['version'] = MKS_SALES_TRACK_VERSION;

    // Click-to-call works on every page that shows a Call button.
    if (!isset($config['dial']) && function_exists('mks_st_dial_config')) {
        $config['dial'] = mks_st_dial_config();
    }

    $json = json_encode($config, JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE
        | JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT);

    // Never a bare assignment: a false from json_encode would be a syntax error
    // that takes every later script on the page with it.
    echo '<script>window.mksSalesTrack = ' . ($json === false ? '{}' : $json) . ';</script>' . PHP_EOL;
    echo '<script src="' . module_dir_url(MKS_SALES_TRACK_MODULE_NAME, 'assets/js/mks-sales-track.js')
        . '?v=' . MKS_SALES_TRACK_VERSION . '"></script>' . PHP_EOL;
}

/*
|--------------------------------------------------------------------------
| CRM hooks
|--------------------------------------------------------------------------
*/

/**
 * @param  int $lead_id
 *
 * @return void
 */
function mks_st_on_lead_saved($lead_id)
{
    if (function_exists('mks_st_rematch_lead') && mks_st_enabled()) {
        mks_st_rematch_lead((int) $lead_id);
    }
}

/**
 * @param  int   $contact_id
 * @param  mixed $data
 *
 * @return void
 */
function mks_st_on_contact_saved($contact_id, $data = null)
{
    if (function_exists('mks_st_rematch_contact') && mks_st_enabled()) {
        mks_st_rematch_contact((int) $contact_id);
    }
}

/**
 * Core passes an array carrying the client id to both client hooks.
 *
 * @param  mixed $payload
 *
 * @return void
 */
function mks_st_on_client_saved($payload)
{
    $id = is_array($payload) && isset($payload['id']) ? (int) $payload['id'] : (int) $payload;

    if ($id > 0 && function_exists('mks_st_rematch_client') && mks_st_enabled()) {
        mks_st_rematch_client($id);
    }
}

/* ---------------------------------------------------------------------
 * Calls tabs on leads and customers
 * ------------------------------------------------------------------ */

/**
 * @param  object|null $lead
 *
 * @return void
 */
function mks_st_lead_tab($lead)
{
    if (!$lead || !function_exists('mks_st_crm_events') || !mks_st_enabled() || !mks_st_enabled('crm_tabs') || mks_st_scope() === false) {
        return;
    }

    echo '<li role="presentation"><a href="#mks_sales_track_calls" aria-controls="mks_sales_track_calls" role="tab" data-toggle="tab">'
        . '<i class="fa-solid fa-phone-volume menu-icon"></i> ' . e(_l('mks_st_tab_calls')) . '</a></li>';
}

/**
 * @param  object|null $lead
 *
 * @return void
 */
function mks_st_lead_tab_content($lead)
{
    if (!$lead || !function_exists('mks_st_crm_events') || !mks_st_enabled() || !mks_st_enabled('crm_tabs') || mks_st_scope() === false) {
        return;
    }

    $CI = &get_instance();

    echo '<div role="tabpanel" class="tab-pane" id="mks_sales_track_calls">';
    $CI->load->view(MKS_SALES_TRACK_MODULE_NAME . '/partials/crm_calls', [
        'mks_rel'     => 'lead',
        'mks_rel_id'  => (int) $lead->id,
        'mks_numbers' => array_filter([['number' => (string) $lead->phonenumber, 'name' => (string) $lead->name]], function ($row) {
            return $row['number'] !== '';
        }),
    ]);
    echo '</div>';
}

/**
 * The customer profile tab, for those allowed to see customers in Sales Track.
 *
 * @return void
 */
function mks_st_register_customer_tab()
{
    if (!function_exists('mks_st_customer_visible') || !mks_st_enabled() || !mks_st_enabled('crm_tabs')
        || mks_st_scope() === false || !mks_st_customer_visible()) {
        return;
    }

    $CI = &get_instance();

    $CI->app_tabs->add_customer_profile_tab('mks_sales_track', [
        'name'     => _l('mks_st_tab_calls'),
        'icon'     => 'fa-solid fa-phone-volume',
        'view'     => MKS_SALES_TRACK_MODULE_NAME . '/crm_customer_tab',
        'position' => 96,
        'badge'    => [],
    ]);
}

/**
 * Perfex's cron: missed-call escalation and silent phone alerts.
 *
 * @param  bool $manually
 *
 * @return void
 */
function mks_st_on_cron($manually = false)
{
    if (function_exists('mks_st_cron_run') && mks_st_enabled()) {
        mks_st_cron_run();
    }
}

/**
 * Status change and edit pass the staff id; deletion passes an array.
 *
 * @param  mixed $payload
 *
 * @return void
 */
function mks_st_on_staff_changed($payload)
{
    $id = is_array($payload) && isset($payload['id']) ? (int) $payload['id'] : (int) $payload;

    if ($id > 0 && function_exists('mks_st_revoke_staff_devices') && mks_st_enabled('revoke_on_deactivate')) {
        mks_st_revoke_staff_devices($id, is_array($payload));
    }
}
