<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - core helper.
 *
 * Everything the API and the admin screens share: number normalisation, CRM
 * matching, devices, pairing and commands, the single ingest path every event
 * takes, and recording storage. Rendering lives in mks_sales_track_view_helper.php.
 *
 * Timestamps are always written with PHP's date(), never SQL NOW(): Perfex sets
 * PHP to the CRM timezone and stores local times, while the database server can
 * sit in a different zone.
 */

/** Largest number of events one sync request may carry. */
define('MKS_ST_BATCH_MAX', 200);

/** Longest SMS text kept, in characters. */
define('MKS_ST_TEXT_MAX', 5000);

/** Option holding live pairing codes, recent pairings and failed attempts. */
define('MKS_ST_PAIRING_OPTION', 'mks_sales_track_pairing');

/* =========================================================================
 * TABLES AND KINDS
 * ====================================================================== */

/**
 * @return string
 */
function mks_st_devices_table()
{
    return db_prefix() . 'mks_sales_track_devices';
}

/**
 * @return string
 */
function mks_st_events_table()
{
    return db_prefix() . 'mks_sales_track_events';
}

/**
 * The three kinds of event a phone can send, the switch that governs each, and
 * the directions each may carry.
 *
 * @return array
 */
function mks_st_kinds()
{
    return [
        'call' => [
            'setting'    => 'track_calls',
            'directions' => ['incoming', 'outgoing', 'missed', 'rejected', 'blocked', 'voicemail', 'unknown'],
        ],
        'whatsapp_call' => [
            'setting'    => 'track_whatsapp_calls',
            'directions' => ['incoming', 'outgoing', 'missed', 'rejected', 'unknown'],
        ],
        'sms' => [
            'setting'    => 'track_sms',
            'directions' => ['incoming', 'outgoing', 'unknown'],
        ],
        'whatsapp_message' => [
            'setting'    => 'track_sms',
            'directions' => ['incoming', 'outgoing', 'unknown'],
        ],
        'notification' => [
            'setting'    => 'track_sms',
            'directions' => ['incoming', 'outgoing', 'unknown'],
        ],
    ];
}

/* =========================================================================
 * CLEANING
 * ====================================================================== */

/**
 * One line of text: valid UTF-8, no control characters, trimmed and capped.
 *
 * @param  mixed $value
 * @param  int   $max
 *
 * @return string
 */
function mks_st_clean_line($value, $max)
{
    if (!is_scalar($value)) {
        return '';
    }

    $value = mb_scrub((string) $value, 'UTF-8');
    $value = preg_replace('/[\x00-\x1F\x7F]+/u', ' ', $value);
    $value = trim(preg_replace('/\s{2,}/u', ' ', (string) $value));

    return mb_substr($value, 0, $max, 'UTF-8');
}

/**
 * Multi line text, as an SMS carries. Line breaks survive;
 * other control characters do not.
 *
 * @param  mixed $value
 * @param  int   $max
 *
 * @return string
 */
function mks_st_clean_body($value, $max = MKS_ST_TEXT_MAX)
{
    if (!is_scalar($value)) {
        return '';
    }

    $value = mb_scrub((string) $value, 'UTF-8');
    $value = str_replace(["\r\n", "\r"], "\n", $value);
    $value = preg_replace('/[\x00-\x08\x0B-\x1F\x7F]+/u', '', $value);

    return trim(mb_substr((string) $value, 0, $max, 'UTF-8'));
}

/**
 * A device side event id. Printable ASCII without spaces, 1 to 80 characters.
 *
 * @param  mixed $value
 *
 * @return string '' when unusable
 */
function mks_st_clean_uid($value)
{
    if (!is_scalar($value)) {
        return '';
    }

    $value = trim((string) $value);

    if ($value === '' || strlen($value) > 80 || !preg_match('/^[\x21-\x7E]+$/', $value)) {
        return '';
    }

    return $value;
}

/**
 * An event time, as epoch milliseconds.
 *
 * Accepts milliseconds (what Android and iOS both report), seconds (detected
 * by size), or an ISO 8601 string for hand written clients.
 *
 * @param  mixed $value
 *
 * @return int|null
 */
function mks_st_clean_time($value)
{
    if (is_string($value)) {
        $value = trim($value);

        if (preg_match('/^\d+(\.\d+)?$/', $value)) {
            $value = (float) $value;
        } elseif ($value !== '') {
            $parsed = strtotime($value);

            return $parsed === false ? null : $parsed * 1000;
        }
    }

    if (!is_int($value) && !is_float($value)) {
        return null;
    }

    $ms = (float) $value;

    if ($ms <= 0) {
        return null;
    }

    // Anything below 10^11 is seconds: 10^11 milliseconds is March 1973.
    if ($ms < 100000000000) {
        $ms *= 1000;
    }

    return (int) round($ms);
}

/**
 * @param  string $kind
 * @param  mixed  $value
 *
 * @return string
 */
function mks_st_clean_direction($kind, $value)
{
    $value   = is_scalar($value) ? strtolower(trim((string) $value)) : '';
    $aliases = [
        'in'       => 'incoming',
        'inbound'  => 'incoming',
        'received' => 'incoming',
        'inbox'    => 'incoming',
        'out'      => 'outgoing',
        'outbound' => 'outgoing',
        'sent'     => 'outgoing',
        'dialed'   => 'outgoing',
        'dialled'  => 'outgoing',
        'declined' => 'rejected',
    ];

    if (isset($aliases[$value])) {
        $value = $aliases[$value];
    }

    $kinds = mks_st_kinds();

    return isset($kinds[$kind]) && in_array($value, $kinds[$kind]['directions'], true) ? $value : 'unknown';
}

/**
 * An Android package name, or ''.
 *
 * @param  mixed $value
 *
 * @return string
 */
function mks_st_clean_package($value)
{
    if (!is_scalar($value)) {
        return '';
    }

    $value = trim((string) $value);

    if (strlen($value) > 100 || !preg_match('/^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$/', $value)) {
        return '';
    }

    return $value;
}

/**
 * SIM cards a phone reports: slot, label and, where the phone knows it, the
 * SIM's own number.
 *
 * @param  mixed $sims
 *
 * @return array
 */
function mks_st_clean_sims($sims)
{
    $out = [];

    if (!is_array($sims)) {
        return $out;
    }

    foreach ($sims as $sim) {
        if (!is_array($sim) || !isset($sim['slot']) || !is_numeric($sim['slot'])) {
            continue;
        }

        $slot = (int) $sim['slot'];

        if ($slot < 1 || $slot > 4) {
            continue;
        }

        $number = isset($sim['number']) && is_scalar($sim['number']) ? preg_replace('/[^\d+]/', '', (string) $sim['number']) : '';

        $out[$slot] = [
            'slot'   => $slot,
            'label'  => mks_st_clean_line(isset($sim['label']) ? $sim['label'] : '', 40),
            'number' => substr($number, 0, 18),
        ];
    }

    ksort($out);

    return array_values($out);
}

/**
 * Permission keys a phone can report. battery_unrestricted means the app is
 * exempt from battery optimisation, which is what keeps it syncing on phones
 * that kill background apps.
 *
 * @return array
 */
function mks_st_health_keys()
{
    return ['call_log', 'phone_state', 'contacts', 'sms', 'notifications', 'recordings', 'battery_unrestricted'];
}

/**
 * @param  array $health
 *
 * @return array
 */
function mks_st_clean_health($health)
{
    $out = [
        'permissions' => [],
        'reported_at' => date('Y-m-d H:i:s'),
    ];

    if (!is_array($health)) {
        return $out;
    }

    if (isset($health['permissions']) && is_array($health['permissions'])) {
        foreach (mks_st_health_keys() as $key) {
            if (array_key_exists($key, $health['permissions'])) {
                $out['permissions'][$key] = (bool) $health['permissions'][$key];
            }
        }
    }

    if (isset($health['battery']) && is_numeric($health['battery'])) {
        $out['battery'] = max(0, min(100, (int) $health['battery']));
    }

    if (isset($health['charging'])) {
        $out['charging'] = (bool) $health['charging'];
    }

    foreach (['queue', 'recordings_queue'] as $key) {
        if (isset($health[$key]) && is_numeric($health[$key])) {
            $out[$key] = max(0, min(1000000, (int) $health[$key]));
        }
    }

    if (isset($health['network']) && in_array($health['network'], ['wifi', 'mobile', 'none', 'unknown'], true)) {
        $out['network'] = $health['network'];
    }

    if (isset($health['last_error'])) {
        $out['last_error'] = mks_st_clean_line($health['last_error'], 255);
    }

    if (isset($health['recorder_folder'])) {
        $out['recorder_folder'] = mks_st_clean_line($health['recorder_folder'], 120);
    }

    return $out;
}

/* =========================================================================
 * NUMBERS
 * ====================================================================== */

/**
 * Split a number as the phone reported it into what is stored.
 *
 *   raw     exactly as received, for display when nothing else is known
 *   number  digits with a + country code wherever one can be inferred
 *   key     the last N digits, the only thing matching ever compares
 *
 * Matching on the tail is what lets "+91 98140 00002", "098140 00002" and
 * "98140-00002" all find the same lead without anybody tidying the CRM first.
 *
 * @param  mixed $raw
 *
 * @return array raw, number, key (each may be null)
 */
function mks_st_number_parts($raw)
{
    $out = ['raw' => null, 'number' => null, 'key' => null];

    if (!is_scalar($raw)) {
        return $out;
    }

    $raw = trim(preg_replace('/[\x00-\x1F\x7F]+/', '', (string) $raw));

    if ($raw === '') {
        return $out;
    }

    $out['raw'] = mb_substr($raw, 0, 50, 'UTF-8');
    $digits     = preg_replace('/\D+/', '', $raw);

    // Alphanumeric senders such as AX-HDFCBK carry no number at all.
    if ($digits === '') {
        return $out;
    }

    $n  = (int) mks_st_setting('match_digits', 10);
    $cc = (string) mks_st_setting('country_code', '91');

    if (strpos($raw, '+') === 0) {
        $number = '+' . $digits;
    } elseif (strpos($digits, '00') === 0 && strlen($digits) > $n + 2) {
        $number = '+' . substr($digits, 2);
    } elseif (strlen($digits) === $n + 1 && $digits[0] === '0') {
        $number = '+' . $cc . substr($digits, 1);
    } elseif (strlen($digits) === $n) {
        $number = '+' . $cc . $digits;
    } else {
        $number = $digits;
    }

    $out['number'] = substr($number, 0, 20);

    if (strlen($digits) >= $n) {
        $out['key'] = substr($digits, -$n);
    }

    return $out;
}

/**
 * A SQL expression giving a phone column's digits, stripping the separators
 * people actually type. Portable to MySQL 5.7, which has no REGEXP_REPLACE.
 *
 * @param  string $column
 *
 * @return string
 */
function mks_st_sql_digits($column)
{
    $expr = $column;

    foreach ([' ', '-', '.', '(', ')', '+', '/'] as $char) {
        $expr = "REPLACE(" . $expr . ", '" . $char . "', '')";
    }

    return $expr;
}

/**
 * Excluded numbers as match keys.
 *
 * @return array key => true
 */
function mks_st_excluded_keys()
{
    static $cache = null;
    static $source = null;

    $text = (string) mks_st_setting('excluded_numbers', '');

    if ($cache !== null && $source === $text) {
        return $cache;
    }

    $n     = (int) mks_st_setting('match_digits', 10);
    $cache = [];

    foreach (preg_split('/[\r\n]+/', $text) as $line) {
        $digits = preg_replace('/\D+/', '', $line);

        if (strlen($digits) >= $n) {
            $cache[substr($digits, -$n)] = true;
        }
    }

    $source = $text;

    return $cache;
}

/**
 * Excluded numbers as salted hashes, which is how phones receive them: a phone
 * can skip an excluded number before it ever leaves the handset without the
 * list of personal numbers being handed to every device.
 *
 * @return array
 */
function mks_st_excluded_hashes()
{
    $salt = (string) get_option('mks_sales_track_salt');
    $out  = [];

    foreach (array_keys(mks_st_excluded_keys()) as $key) {
        $out[] = hash('sha256', $salt . $key);
    }

    return $out;
}

/* =========================================================================
 * CRM MATCHING
 * ====================================================================== */

/**
 * Find the CRM record behind each match key.
 *
 * Priority: a customer contact, then a customer's own number, then a lead,
 * then a member of staff, so a converted lead shows as the customer it
 * became and calls between colleagues are recognisable as internal. Within
 * one source the newest record wins. The lead behind a number is kept even
 * when a customer outranks it, so the lead's side of the story is never lost.
 *
 * With Match Numbers To Customers off (a CRM run on leads alone), customers
 * and contacts are never looked at.
 *
 * @param  array $keys
 *
 * @return array key => rel_type, rel_id, contact_id, lead_id
 */
function mks_st_match_numbers(array $keys)
{
    $n    = (int) mks_st_setting('match_digits', 10);
    $want = [];

    foreach ($keys as $key) {
        $key = (string) $key;

        if ($key !== '' && ctype_digit($key) && strlen($key) === $n) {
            $want['k' . $key] = $key;
        }
    }

    if (!$want) {
        return [];
    }

    $p     = db_prefix();
    $leads = mks_st_match_source($want, 'SELECT NULL AS contact_id, id AS rel_id, phonenumber FROM ' . $p . 'leads', 'id', $n);
    $found = [];

    if (mks_st_enabled('match_customers')) {
        $found = mks_st_match_source($want, 'SELECT id AS contact_id, userid AS rel_id, phonenumber FROM ' . $p . 'contacts', 'id', $n);
        $found += mks_st_match_source(array_diff_key($want, $found), 'SELECT NULL AS contact_id, userid AS rel_id, phonenumber FROM ' . $p . 'clients', 'userid', $n);

        foreach ($found as $slot => $match) {
            $found[$slot]['rel_type'] = 'customer';
        }
    }

    foreach ($leads as $slot => $match) {
        if (!isset($found[$slot])) {
            $found[$slot] = ['rel_type' => 'lead', 'rel_id' => $match['rel_id'], 'contact_id' => null];
        }
    }

    foreach (mks_st_match_source(array_diff_key($want, $found), 'SELECT NULL AS contact_id, staffid AS rel_id, phonenumber FROM ' . $p . 'staff', 'staffid', $n) as $slot => $match) {
        $found[$slot] = ['rel_type' => 'staff', 'rel_id' => $match['rel_id'], 'contact_id' => null];
    }

    $out = [];

    foreach ($found as $slot => $match) {
        $match['lead_id']    = isset($leads[$slot]) ? $leads[$slot]['rel_id'] : null;
        $out[$want[$slot]] = $match;
    }

    return $out;
}

/**
 * One source table's matches for the wanted keys. Keys are prefixed so a ten
 * digit number never becomes an integer array key.
 *
 * Core tables have no normalised phone column, so the SQL strips the usual
 * separators and PHP confirms the exact tail.
 *
 * @param  array  $want  'k' . key => key
 * @param  string $sql   SELECT contact_id, rel_id, phonenumber FROM ...
 * @param  string $order newest first by this column
 * @param  int    $n
 *
 * @return array 'k' . key => rel_id, contact_id
 */
function mks_st_match_source(array $want, $sql, $order, $n)
{
    $CI    = &get_instance();
    $found = [];
    $expr  = mks_st_sql_digits('phonenumber');

    foreach (array_chunk(array_values($want), 25) as $chunk) {
        $likes = [];

        foreach ($chunk as $key) {
            // Keys are validated digit strings, so they are safe in the LIKE.
            $likes[] = $expr . " LIKE '%" . $key . "'";
        }

        $query = $CI->db->query($sql . " WHERE phonenumber IS NOT NULL AND phonenumber <> '' AND (" . implode(' OR ', $likes) . ')'
            . ' ORDER BY ' . $order . ' DESC');

        if (!$query) {
            continue;
        }

        foreach ($query->result_array() as $row) {
            $digits = preg_replace('/\D+/', '', (string) $row['phonenumber']);

            if (strlen($digits) < $n) {
                continue;
            }

            $slot = 'k' . substr($digits, -$n);

            if (isset($want[$slot]) && !isset($found[$slot])) {
                $found[$slot] = [
                    'rel_id'     => (int) $row['rel_id'],
                    'contact_id' => $row['contact_id'] !== null ? (int) $row['contact_id'] : null,
                ];
            }
        }
    }

    return $found;
}

/**
 * A lead was created or edited: link every still-unknown event with its number.
 *
 * @param  int $lead_id
 *
 * @return void
 */
function mks_st_rematch_lead($lead_id)
{
    $CI = &get_instance();

    if ($lead_id <= 0 || !$CI->db->table_exists(mks_st_events_table())) {
        return;
    }

    $lead = $CI->db->select('id, phonenumber')->where('id', $lead_id)->get(db_prefix() . 'leads')->row_array();

    if (!$lead) {
        return;
    }

    $parts = mks_st_number_parts($lead['phonenumber']);

    if ($parts['key'] === null) {
        return;
    }

    $CI->db->where('number_key', $parts['key']);
    $CI->db->where('rel_type IS NULL', null, false);
    $CI->db->update(mks_st_events_table(), [
        'rel_type'   => 'lead',
        'rel_id'     => (int) $lead['id'],
        'contact_id' => null,
    ]);

    // Calls already shown under a customer still learn which lead they are.
    $CI->db->where('number_key', $parts['key']);
    $CI->db->where('lead_id IS NULL', null, false);
    $CI->db->update(mks_st_events_table(), ['lead_id' => (int) $lead['id']]);

    if (function_exists('mks_st_lead_last_contact')) {
        mks_st_lead_last_contact((int) $lead['id']);
    }
}

/**
 * A contact was created or edited. Customers outrank leads and staff, so their
 * events move across as well as the unknown ones.
 *
 * @param  int $contact_id
 *
 * @return void
 */
function mks_st_rematch_contact($contact_id)
{
    $CI = &get_instance();

    if ($contact_id <= 0 || !mks_st_enabled('match_customers') || !$CI->db->table_exists(mks_st_events_table())) {
        return;
    }

    $contact = $CI->db->select('id, userid, phonenumber')->where('id', $contact_id)->get(db_prefix() . 'contacts')->row_array();

    if (!$contact) {
        return;
    }

    $parts = mks_st_number_parts($contact['phonenumber']);

    if ($parts['key'] === null) {
        return;
    }

    $CI->db->where('number_key', $parts['key']);
    $CI->db->group_start();
    $CI->db->where('rel_type IS NULL', null, false);
    $CI->db->or_where_in('rel_type', ['lead', 'staff']);
    $CI->db->group_end();
    $CI->db->update(mks_st_events_table(), [
        'rel_type'   => 'customer',
        'rel_id'     => (int) $contact['userid'],
        'contact_id' => (int) $contact['id'],
    ]);
}

/**
 * A customer was created or edited (its own company number, not a contact's).
 *
 * @param  int $client_id
 *
 * @return void
 */
function mks_st_rematch_client($client_id)
{
    $CI = &get_instance();

    if ($client_id <= 0 || !mks_st_enabled('match_customers') || !$CI->db->table_exists(mks_st_events_table())) {
        return;
    }

    $client = $CI->db->select('userid, phonenumber')->where('userid', $client_id)->get(db_prefix() . 'clients')->row_array();

    if (!$client) {
        return;
    }

    $parts = mks_st_number_parts($client['phonenumber']);

    if ($parts['key'] === null) {
        return;
    }

    $CI->db->where('number_key', $parts['key']);
    $CI->db->group_start();
    $CI->db->where('rel_type IS NULL', null, false);
    $CI->db->or_where_in('rel_type', ['lead', 'staff']);
    $CI->db->group_end();
    $CI->db->update(mks_st_events_table(), [
        'rel_type'   => 'customer',
        'rel_id'     => (int) $client['userid'],
        'contact_id' => null,
    ]);
}

/* =========================================================================
 * STAFF
 * ====================================================================== */

/**
 * @param  int $staff_id
 *
 * @return bool
 */
function mks_st_staff_active($staff_id)
{
    static $cache = [];

    $staff_id = (int) $staff_id;

    if ($staff_id <= 0) {
        return false;
    }

    if (!array_key_exists($staff_id, $cache)) {
        $CI  = &get_instance();
        $row = $CI->db->select('active')->where('staffid', $staff_id)->get(db_prefix() . 'staff')->row_array();

        $cache[$staff_id] = $row && (int) $row['active'] === 1;
    }

    return $cache[$staff_id];
}

/**
 * @param  int $staff_id
 *
 * @return string
 */
function mks_st_staff_name($staff_id)
{
    $CI  = &get_instance();
    $row = $CI->db->select('firstname, lastname')->where('staffid', (int) $staff_id)->get(db_prefix() . 'staff')->row_array();

    return $row ? trim($row['firstname'] . ' ' . $row['lastname']) : '';
}

/**
 * Active staff for filter and pairing pickers.
 *
 * @param  int[]|null $ids only these, or everybody
 *
 * @return array id => name
 */
function mks_st_staff_options($ids = null)
{
    $CI = &get_instance();
    $CI->db->select('staffid, firstname, lastname')->where('active', 1);

    if (is_array($ids)) {
        $CI->db->where_in('staffid', $ids ?: [0]);
    }

    $rows = $CI->db->order_by('firstname', 'asc')->get(db_prefix() . 'staff')->result_array();

    $out = [];

    foreach ($rows as $row) {
        $out[(int) $row['staffid']] = trim($row['firstname'] . ' ' . $row['lastname']);
    }

    return $out;
}

/* =========================================================================
 * DEVICES
 * ====================================================================== */

/**
 * Device states, in the order the Devices page sorts them.
 *
 *   pending  created in the CRM, waiting for a phone to enter its code
 *   active   a phone is bound and reporting
 *   paused   bound, but told to collect nothing until resumed
 *   revoked  cut off; its token no longer works
 *
 * @return array
 */
function mks_st_device_statuses()
{
    return ['pending', 'active', 'paused', 'revoked'];
}

/**
 * Validate what a phone says about itself when it pairs.
 *
 * @param  mixed $device
 *
 * @return array|false
 */
function mks_st_clean_device_info($device)
{
    if (!is_array($device)) {
        return false;
    }

    $uid = isset($device['uid']) && is_scalar($device['uid']) ? trim((string) $device['uid']) : '';

    // demo- is reserved for the demo data so a real phone can never collide
    // with, or be deleted along with, a demo device.
    if (!preg_match('/^[A-Za-z0-9_-]{8,64}$/', $uid) || stripos($uid, 'demo-') === 0) {
        return false;
    }

    $platform = isset($device['platform']) && is_scalar($device['platform']) ? strtolower(trim((string) $device['platform'])) : 'android';

    if (!in_array($platform, ['android', 'ios'], true)) {
        return false;
    }

    return [
        'device_uid'   => $uid,
        'platform'     => $platform,
        'manufacturer' => mks_st_clean_line(isset($device['manufacturer']) ? $device['manufacturer'] : '', 60),
        'model'        => mks_st_clean_line(isset($device['model']) ? $device['model'] : '', 100),
        'os_version'   => mks_st_clean_line(isset($device['os_version']) ? $device['os_version'] : '', 30),
        'app_version'  => mks_st_clean_line(isset($device['app_version']) ? $device['app_version'] : '', 30),
        'sims'         => mks_st_clean_sims(isset($device['sims']) ? $device['sims'] : []),
    ];
}

/**
 * The fields an administrator types when adding or editing a device.
 *
 * @param  array $input
 *
 * @return array|string cleaned fields, or a language key for the error
 */
function mks_st_clean_device_form(array $input)
{
    $name  = mks_st_clean_line(isset($input['name']) ? $input['name'] : '', 100);
    $staff = isset($input['staff_id']) ? (int) $input['staff_id'] : 0;

    if ($name === '') {
        return 'mks_st_err_device_name';
    }

    if (!mks_st_staff_active($staff)) {
        return 'mks_st_staff_inactive';
    }

    $number = isset($input['phone_number']) && is_scalar($input['phone_number'])
        ? preg_replace('/[^\d+]/', '', (string) $input['phone_number']) : '';

    return [
        'label'        => $name,
        'description'  => mks_st_clean_body(isset($input['description']) ? $input['description'] : '', 500),
        'staff_id'     => $staff,
        'phone_number' => substr($number, 0, 20),
        'asset_tag'    => mks_st_clean_line(isset($input['asset_tag']) ? $input['asset_tag'] : '', 50),
    ];
}

/**
 * Add a device in the CRM. It waits for a phone until its code is entered.
 *
 * @param  array $fields from mks_st_clean_device_form()
 * @param  int   $by
 *
 * @return int new device id, 0 on failure
 */
function mks_st_device_create(array $fields, $by)
{
    $CI  = &get_instance();
    $now = date('Y-m-d H:i:s');

    $CI->db->insert(mks_st_devices_table(), array_merge($fields, [
        'device_uid' => null,
        'token_hash' => null,
        'platform'   => 'android',
        'track_sim'  => 0,
        'status'     => 'pending',
        'created_at' => $now,
        'created_by' => $by > 0 ? (int) $by : null,
    ]));

    return (int) $CI->db->insert_id();
}

/**
 * Bind a phone to a device record and mint its token.
 *
 * Whatever phone held this record before loses access the moment the new
 * token is written, which is what makes Regenerate Code a handset swap. A
 * phone already bound to a different record is released from it first, so
 * one phone is never two devices. With One Phone Per Staff Member on, the
 * staff member's other phones are revoked once this one is live.
 *
 * @param  array  $device
 * @param  array  $info   from mks_st_clean_device_info()
 * @param  string $ip
 *
 * @return array|false device, token
 */
function mks_st_device_bind(array $device, array $info, $ip)
{
    $CI    = &get_instance();
    $table = mks_st_devices_table();
    $token = bin2hex(random_bytes(32));
    $now   = date('Y-m-d H:i:s');
    $id    = (int) $device['id'];

    $other = $CI->db->select('id')->where('device_uid', $info['device_uid'])->where('id !=', $id)->get($table)->row_array();

    if ($other) {
        mks_st_device_revoke((int) $other['id'], 0, true);
        $CI->db->where('id', (int) $other['id'])->update($table, ['device_uid' => null]);
    }

    $CI->db->where('id', $id);
    $CI->db->update($table, [
        'device_uid'   => $info['device_uid'],
        'token_hash'   => hash('sha256', $token),
        'platform'     => $info['platform'],
        'manufacturer' => $info['manufacturer'],
        'model'        => $info['model'],
        'os_version'   => $info['os_version'],
        'app_version'  => $info['app_version'],
        'sims'         => $info['sims'] ? json_encode($info['sims']) : null,
        'status'       => 'active',
        'paired_at'    => $now,
        'revoked_at'   => null,
        'revoked_by'   => null,
        'commands'     => null,
        'last_seen_at' => $now,
        'last_ip'      => substr((string) $ip, 0, 45),
    ]);

    if ($CI->db->affected_rows() < 1 && !mks_st_device_get($id)) {
        return false;
    }

    if (mks_st_enabled('one_phone_per_staff')) {
        $others = $CI->db->select('id')
            ->where('staff_id', (int) $device['staff_id'])
            ->where('id !=', $id)
            ->where_in('status', ['active', 'paused'])
            ->get($table)
            ->result_array();

        foreach ($others as $old) {
            mks_st_device_revoke((int) $old['id'], 0, false);
        }
    }

    return [
        'device' => mks_st_device_get($id),
        'token'  => $token,
    ];
}

/**
 * Cut a device off. Its token is cleared, so it can never come back by
 * accident; pairing again needs a fresh code.
 *
 * @param  int  $id
 * @param  int  $by
 * @param  bool $quiet skip the activity log (internal moves)
 *
 * @return void
 */
function mks_st_device_revoke($id, $by, $quiet = false)
{
    $CI     = &get_instance();
    $device = mks_st_device_get($id);

    if (!$device || $device['status'] === 'revoked') {
        return;
    }

    $CI->db->where('id', (int) $id);
    $CI->db->update(mks_st_devices_table(), [
        'status'     => 'revoked',
        'token_hash' => null,
        'commands'   => null,
        'revoked_at' => date('Y-m-d H:i:s'),
        'revoked_by' => $by > 0 ? (int) $by : null,
    ]);

    mks_st_pairing_forget_device($id);

    if (!$quiet) {
        log_activity('Sales Track: phone revoked [' . $device['label'] . ', Staff: ' . mks_st_staff_name($device['staff_id']) . ']');
    }
}

/**
 * Revoke a member of staff's phones when they are deactivated or deleted.
 *
 * @param  int  $staff_id
 * @param  bool $deleted
 *
 * @return void
 */
function mks_st_revoke_staff_devices($staff_id, $deleted)
{
    $CI = &get_instance();

    if (!$CI->db->table_exists(mks_st_devices_table())) {
        return;
    }

    if (!$deleted) {
        $row = $CI->db->select('active')->where('staffid', (int) $staff_id)->get(db_prefix() . 'staff')->row_array();

        if ($row && (int) $row['active'] === 1) {
            return;
        }
    }

    $devices = $CI->db->select('id')
        ->where('staff_id', (int) $staff_id)
        ->where('status !=', 'revoked')
        ->get(mks_st_devices_table())
        ->result_array();

    foreach ($devices as $device) {
        mks_st_device_revoke((int) $device['id'], (int) get_staff_user_id());
    }
}

/**
 * @param  int $id
 *
 * @return array|null
 */
function mks_st_device_get($id)
{
    $CI  = &get_instance();
    $row = $CI->db->where('id', (int) $id)->get(mks_st_devices_table())->row_array();

    return $row ?: null;
}

/**
 * @param  string $token
 *
 * @return array|null
 */
function mks_st_device_by_token($token)
{
    if (!is_string($token) || !preg_match('/^[a-f0-9]{64}$/', $token)) {
        return null;
    }

    $CI  = &get_instance();
    $row = $CI->db->where('token_hash', hash('sha256', $token))->limit(1)->get(mks_st_devices_table())->row_array();

    return $row ?: null;
}

/**
 * Record that a phone has been heard from.
 *
 * @param  int    $id
 * @param  string $ip
 *
 * @return void
 */
function mks_st_device_touch($id, $ip)
{
    $CI = &get_instance();
    $CI->db->where('id', (int) $id);
    $CI->db->update(mks_st_devices_table(), [
        'last_seen_at' => date('Y-m-d H:i:s'),
        'last_ip'      => substr((string) $ip, 0, 45),
    ]);
}

/**
 * Store what a phone reports about itself on its heartbeat.
 *
 * @param  int   $id
 * @param  array $body
 *
 * @return void
 */
function mks_st_device_report($id, array $body)
{
    $update = [];

    foreach (['app_version' => 30, 'os_version' => 30, 'manufacturer' => 60, 'model' => 100] as $key => $max) {
        if (isset($body[$key]) && is_scalar($body[$key]) && trim((string) $body[$key]) !== '') {
            $update[$key] = mks_st_clean_line($body[$key], $max);
        }
    }

    if (isset($body['sims']) && is_array($body['sims'])) {
        $sims           = mks_st_clean_sims($body['sims']);
        $update['sims'] = $sims ? json_encode($sims) : null;
    }

    if (isset($body['health']) && is_array($body['health'])) {
        $update['health'] = json_encode(mks_st_clean_health($body['health']));
    }

    // The Firebase registration token, for instant commands. An empty string
    // forgets it (the app signed out of push).
    if (isset($body['push_token']) && is_string($body['push_token'])) {
        $push = trim($body['push_token']);

        if ($push === '' || preg_match('/^[A-Za-z0-9_:\-.]{20,512}$/', $push)) {
            $update['push_token'] = $push !== '' ? $push : null;
            $update['push_at']    = date('Y-m-d H:i:s');
        }
    }

    if (!$update) {
        return;
    }

    $CI = &get_instance();
    $CI->db->where('id', (int) $id);
    $CI->db->update(mks_st_devices_table(), $update);
}

/**
 * What a phone is told about its own record.
 *
 * @param  array $device
 *
 * @return array
 */
function mks_st_device_public(array $device)
{
    return [
        'id'          => (int) $device['id'],
        'name'        => (string) $device['label'],
        'description' => (string) $device['description'],
        'platform'    => (string) $device['platform'],
        'status'      => (string) $device['status'],
        'track_sim'   => (int) $device['track_sim'],
    ];
}

/**
 * Is this app build older than the minimum set in settings?
 *
 * @param  string $app_version
 *
 * @return bool
 */
function mks_st_app_update_required($app_version)
{
    $minimum = (string) mks_st_setting('min_app_version', '');

    if ($minimum === '') {
        return false;
    }

    $app_version = preg_replace('/[^0-9.].*$/', '', (string) $app_version);

    return $app_version === '' || version_compare($app_version, $minimum, '<');
}

/**
 * Everything a phone needs to know. The version is a hash of the payload,
 * carried on every sync reply, so a change reaches each phone on its next sync.
 *
 * A paused device is told to collect nothing.
 *
 * @param  array $device
 *
 * @return array
 */
function mks_st_device_config(array $device)
{
    $s      = mks_st_settings();
    $paused = $device['status'] === 'paused';

    $config = [
        'tracking' => [
            'calls'          => !$paused && !empty($s['track_calls']),
            'recordings'     => !$paused && !empty($s['track_recordings']),
            'whatsapp_calls' => !$paused && !empty($s['track_whatsapp_calls']),
            'sms'            => !$paused && !empty($s['track_sms']),
        ],
        'paused'       => $paused,
        'excluded'     => [
            'salt'   => (string) get_option('mks_sales_track_salt'),
            'hashes' => mks_st_excluded_hashes(),
        ],
        'match_digits' => (int) $s['match_digits'],
        'country_code' => (string) $s['country_code'],
        'track_sim'    => (int) $device['track_sim'],
        'sms_text'     => (string) $s['sms_text'],
        'sync_minutes' => (int) $s['sync_minutes'],
        'history_days' => (int) $s['history_days'],
        'batch_size'   => MKS_ST_BATCH_MAX,
        'recordings'   => [
            'wifi_only' => !empty($s['recording_wifi_only']),
            'max_mb'    => mks_st_recording_limit_mb(),
            'formats'   => array_keys(mks_st_recording_formats()),
        ],
        'app'          => [
            'min_version' => (string) $s['min_app_version'],
            'url_android' => (string) $s['app_url_android'],
            'url_ios'     => (string) $s['app_url_ios'],
        ],
        'outcomes'     => [
            'ask'           => (string) $s['outcome_ask'],
            'mandatory'     => !empty($s['outcome_mandatory']),
            'note_required' => !empty($s['note_required']),
            'create_lead'   => !empty($s['lead_create_phone']),
            'list'          => array_values(array_map(function ($outcome) {
                return [
                    'key'         => $outcome['key'],
                    'label'       => $outcome['label'],
                    'tone'        => $outcome['tone'],
                    'follow_up'   => (bool) $outcome['follow_up'],
                    'lead_status' => (int) $outcome['lead_status'],
                    'fixed'       => $outcome['key'] === 'converted',
                ];
            }, function_exists('mks_st_outcomes') ? mks_st_outcomes() : [])),
            'lead_statuses' => function_exists('mks_st_lead_statuses') ? array_values(array_map(function ($id, $status) {
                return ['id' => $id, 'name' => $status['name'], 'color' => $status['color']];
            }, array_keys(mks_st_lead_statuses()), mks_st_lead_statuses())) : [],
        ],
        'calling'      => [
            'click_to_call' => !empty($s['click_to_call']),
            'dial_confirm'  => !empty($s['dial_confirm']),
            'push'          => (string) get_option('mks_sales_track_fcm') !== '',
        ],
        'app_lock'     => [
            'enabled'    => !empty($s['app_lock_enabled']) && $s['app_lock_hash'] !== '',
            'algorithm'  => 'pbkdf2-sha256',
            'iterations' => MKS_ST_PIN_ITERATIONS,
            'salt'       => (string) $s['app_lock_salt'],
            'hash'       => (string) $s['app_lock_hash'],
        ],
    ];

    $config['version'] = substr(md5(json_encode($config)), 0, 12);

    return $config;
}

/**
 * Waiting, online, idle, offline, paused or revoked.
 *
 * @param  array $device
 *
 * @return string
 */
function mks_st_device_state(array $device)
{
    if ($device['status'] === 'revoked') {
        return 'revoked';
    }

    if ($device['status'] === 'pending' || empty($device['token_hash'])) {
        return 'pending';
    }

    if ($device['status'] === 'paused') {
        return 'paused';
    }

    if (empty($device['last_seen_at'])) {
        return 'offline';
    }

    $age    = time() - strtotime($device['last_seen_at']);
    $online = ((int) mks_st_setting('sync_minutes', 15) * 2 + 5) * 60;

    if ($age <= $online) {
        return 'online';
    }

    return $age <= 86400 ? 'idle' : 'offline';
}

/**
 * Devices with their owner and event counts.
 *
 * @param  int[]|null|false $scope null for every device, else these owners
 *
 * @return array
 */
function mks_st_devices_list($scope = null)
{
    $CI = &get_instance();
    $p  = db_prefix();

    $sql = 'SELECT d.*, s.firstname, s.lastname, s.active AS staff_active,'
        . ' (SELECT COUNT(*) FROM ' . mks_st_events_table() . ' ev WHERE ev.device_id = d.id) AS events_count'
        . ' FROM ' . mks_st_devices_table() . ' d'
        . ' LEFT JOIN ' . $p . 'staff s ON s.staffid = d.staff_id';

    if ($scope !== null) {
        $sql .= ' WHERE 1 = 1 ' . mks_st_scope_sql('d.staff_id', $scope);
    }

    $sql .= " ORDER BY FIELD(d.status, 'pending', 'active', 'paused', 'revoked'), d.last_seen_at DESC, d.id DESC";

    return $CI->db->query($sql)->result_array();
}

/**
 * Phones for the list filter, limited to what the viewer may see.
 *
 * @param  int[]|null|false $scope
 *
 * @return array id => label
 */
function mks_st_device_options($scope)
{
    if ($scope === false) {
        return [];
    }

    $out = [];

    foreach (mks_st_devices_list($scope) as $device) {
        if ($device['status'] === 'pending') {
            continue;
        }

        $owner = trim($device['firstname'] . ' ' . $device['lastname']);

        $out[(int) $device['id']] = $owner !== '' ? $device['label'] . ' (' . $owner . ')' : $device['label'];
    }

    return $out;
}

/**
 * Activity counts per kind for one device, today and over seven days.
 *
 * @param  int $id
 *
 * @return array kind => [today, week]
 */
function mks_st_device_activity($id)
{
    $CI    = &get_instance();
    $today = date('Y-m-d') . ' 00:00:00';
    $week  = date('Y-m-d', strtotime('-6 days')) . ' 00:00:00';

    $rows = $CI->db->query('SELECT kind, SUM(occurred_at >= ' . $CI->db->escape($today) . ') AS today, COUNT(*) AS week'
        . ' FROM ' . mks_st_events_table()
        . ' WHERE device_id = ' . (int) $id . ' AND occurred_at >= ' . $CI->db->escape($week)
        . ' GROUP BY kind')->result_array();

    $out = [];

    foreach ($rows as $row) {
        $k = in_array($row['kind'], ['sms', 'whatsapp_message', 'notification'], true) ? 'sms' : $row['kind'];
        if (!isset($out[$k])) {
            $out[$k] = ['today' => 0, 'week' => 0];
        }
        $out[$k]['today'] += (int) $row['today'];
        $out[$k]['week']  += (int) $row['week'];
    }

    return $out;
}

/* ---------------------------------------------------------------------
 * Sync history
 * ------------------------------------------------------------------ */

/**
 * Prepend one sync to the device's history, keeping the last thirty. Kept as
 * JSON on the device row: a few hundred bytes per phone does not earn a table.
 *
 * @param  int   $id
 * @param  array $result from mks_st_ingest()
 * @param  array $device
 *
 * @return void
 */
function mks_st_device_log_sync($id, array $result, array $device)
{
    $log = json_decode((string) $device['sync_log'], true);
    $log = is_array($log) ? $log : [];

    array_unshift($log, [
        't'   => date('Y-m-d H:i:s'),
        'st'  => count($result['stored']),
        'dup' => count($result['duplicate']),
        'sk'  => count($result['skipped']),
        're'  => count($result['rejected']),
        'app' => (string) $device['app_version'],
    ]);

    $CI = &get_instance();
    $CI->db->where('id', (int) $id);
    $CI->db->update(mks_st_devices_table(), ['sync_log' => json_encode(array_slice($log, 0, 30))]);
}

/* ---------------------------------------------------------------------
 * Commands
 * ------------------------------------------------------------------ */

/**
 * Commands a device can be sent. Delivered at once by push when Firebase is
 * set up, and on the phone's next heartbeat either way. There is no unpair
 * command: Revoke is the unpair, and the phone stops on its next call when it
 * meets device_revoked.
 *
 *   dial  params: number, name. Expires after two minutes: a call placed
 *         long after the click would surprise everybody.
 *
 * @return array
 */
function mks_st_command_types()
{
    return ['sync_now', 'recheck_permissions', 'dial'];
}

/**
 * Queue a command for a device, keeping the last twenty.
 *
 * @param  array  $device
 * @param  string $type
 * @param  int    $by
 *
 * @return string|false the command id
 */
function mks_st_device_command_add(array $device, $type, $by, array $params = [])
{
    if (!in_array($type, mks_st_command_types(), true) || !in_array($device['status'], ['active', 'paused'], true)) {
        return false;
    }

    $commands = json_decode((string) $device['commands'], true);
    $commands = is_array($commands) ? $commands : [];
    $id       = bin2hex(random_bytes(6));

    $command = [
        'id'      => $id,
        'type'    => $type,
        'status'  => 'pending',
        'created' => date('Y-m-d H:i:s'),
        'by'      => (int) $by,
    ];

    if ($params) {
        $command['params'] = $params;
    }

    if ($type === 'dial') {
        $command['expires'] = date('Y-m-d H:i:s', time() + 120);
    }

    array_unshift($commands, $command);

    $CI = &get_instance();
    $CI->db->where('id', (int) $device['id']);
    $CI->db->update(mks_st_devices_table(), ['commands' => json_encode(array_slice($commands, 0, 20))]);

    return $id;
}

/**
 * Apply the phone's acknowledgements, then hand over what is still pending.
 *
 * @param  array $device
 * @param  mixed $acks [{id, status: done|failed, message}]
 *
 * @return array commands for the phone: [{id, type}]
 */
function mks_st_device_commands_exchange(array $device, $acks)
{
    $commands = json_decode((string) $device['commands'], true);
    $commands = is_array($commands) ? $commands : [];
    $changed  = false;
    $byId     = [];

    if (is_array($acks)) {
        foreach ($acks as $ack) {
            if (is_array($ack) && isset($ack['id']) && is_scalar($ack['id'])) {
                $byId[(string) $ack['id']] = $ack;
            }
        }
    }

    $out = [];

    foreach ($commands as $index => $command) {
        if (isset($byId[$command['id']]) && in_array($command['status'], ['pending', 'delivered'], true)) {
            $ack                         = $byId[$command['id']];
            $commands[$index]['status']  = (isset($ack['status']) && $ack['status'] === 'failed') ? 'failed' : 'done';
            $commands[$index]['message'] = mks_st_clean_line(isset($ack['message']) ? $ack['message'] : '', 200);
            $commands[$index]['done']    = date('Y-m-d H:i:s');
            $changed                     = true;

            continue;
        }

        if (in_array($command['status'], ['pending', 'delivered'], true) && isset($command['expires']) && strtotime($command['expires']) < time()) {
            $commands[$index]['status'] = 'expired';
            $changed                    = true;

            continue;
        }

        if (in_array($command['status'], ['pending', 'delivered'], true)) {
            $out[] = array_filter(['id' => $command['id'], 'type' => $command['type'], 'params' => isset($command['params']) ? $command['params'] : null]);

            if ($command['status'] === 'pending') {
                $commands[$index]['status']    = 'delivered';
                $commands[$index]['delivered'] = date('Y-m-d H:i:s');
                $changed                       = true;
            }
        }
    }

    if ($changed) {
        $CI = &get_instance();
        $CI->db->where('id', (int) $device['id']);
        $CI->db->update(mks_st_devices_table(), ['commands' => json_encode($commands)]);
    }

    return $out;
}

/* =========================================================================
 * PAIRING
 * ====================================================================== */

/**
 * The pairing store: live codes, recent pairings the CRM polls for, and
 * failed attempts for throttling. A small JSON option, not autoloaded.
 *
 * Each code is kept twice: hashed, which is what pairing checks, and
 * encrypted with the CRM's own key, so the device page can show a live code
 * again until it is used or expires.
 *
 * @return array
 */
function mks_st_pairing_load()
{
    $raw   = get_option(MKS_ST_PAIRING_OPTION);
    $store = is_string($raw) && $raw !== '' ? json_decode($raw, true) : [];
    $store = is_array($store) ? $store : [];

    foreach (['codes', 'used', 'fails'] as $key) {
        if (!isset($store[$key]) || !is_array($store[$key])) {
            $store[$key] = [];
        }
    }

    $now = time();

    // Expired codes stay an hour so a late attempt can be told it expired.
    // Codes from 1.0.0 belonged to a person, not a device, and are dropped.
    $store['codes'] = array_values(array_filter($store['codes'], function ($entry) use ($now) {
        return is_array($entry) && isset($entry['expires'], $entry['device_id']) && $entry['expires'] > $now - 3600;
    }));

    $store['used'] = array_values(array_filter($store['used'], function ($entry) use ($now) {
        return is_array($entry) && isset($entry['t']) && $entry['t'] > $now - 3600;
    }));

    $store['fails'] = array_values(array_filter($store['fails'], function ($entry) use ($now) {
        return is_array($entry) && isset($entry['t']) && $entry['t'] > $now - 900;
    }));

    return $store;
}

/**
 * @param  array $store
 *
 * @return void
 */
function mks_st_pairing_save(array $store)
{
    $store['codes'] = array_slice($store['codes'], -50);
    $store['used']  = array_slice($store['used'], -25);
    $store['fails'] = array_slice($store['fails'], -200);

    mks_st_option_put(MKS_ST_PAIRING_OPTION, json_encode($store), 0);
}

/**
 * Issue a pairing code for a device: six digits to type, or a longer secret
 * inside the QR code. Either redeems the same entry, once. A new code
 * replaces any earlier code for the same device.
 *
 * @param  int $device_id
 * @param  int $by
 *
 * @return array id, code, secret, expires
 */
function mks_st_pairing_create($device_id, $by)
{
    $CI      = &get_instance();
    $store   = mks_st_pairing_load();
    $minutes = (int) mks_st_setting('pair_minutes', 60);
    $live    = [];

    $store['codes'] = array_values(array_filter($store['codes'], function ($entry) use ($device_id) {
        return (int) $entry['device_id'] !== (int) $device_id;
    }));

    foreach ($store['codes'] as $entry) {
        $live[$entry['code']] = true;
    }

    do {
        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    } while (isset($live[hash('sha256', $code)]));

    $secret  = bin2hex(random_bytes(16));
    $id      = bin2hex(random_bytes(8));
    $expires = time() + $minutes * 60;

    $store['codes'][] = [
        'id'        => $id,
        'code'      => hash('sha256', $code),
        'secret'    => hash('sha256', $secret),
        'enc'       => $CI->encryption->encrypt($code . '|' . $secret),
        'device_id' => (int) $device_id,
        'by'        => (int) $by,
        'created'   => time(),
        'expires'   => $expires,
    ];

    mks_st_pairing_save($store);

    return ['id' => $id, 'code' => $code, 'secret' => $secret, 'expires' => $expires];
}

/**
 * The live code for a device, decrypted for its page, or null.
 *
 * @param  int $device_id
 *
 * @return array|null id, code, secret, expires
 */
function mks_st_pairing_live_code($device_id)
{
    $CI = &get_instance();

    foreach (mks_st_pairing_load()['codes'] as $entry) {
        if ((int) $entry['device_id'] !== (int) $device_id || $entry['expires'] <= time() || empty($entry['enc'])) {
            continue;
        }

        $plain = $CI->encryption->decrypt($entry['enc']);

        if (!is_string($plain) || strpos($plain, '|') === false) {
            return null;
        }

        list($code, $secret) = explode('|', $plain, 2);

        return ['id' => $entry['id'], 'code' => $code, 'secret' => $secret, 'expires' => (int) $entry['expires']];
    }

    return null;
}

/**
 * Drop every code issued for a device (it was revoked or deleted).
 *
 * @param  int $device_id
 *
 * @return void
 */
function mks_st_pairing_forget_device($device_id)
{
    $store  = mks_st_pairing_load();
    $before = count($store['codes']);

    $store['codes'] = array_values(array_filter($store['codes'], function ($entry) use ($device_id) {
        return (int) $entry['device_id'] !== (int) $device_id;
    }));

    if (count($store['codes']) !== $before) {
        mks_st_pairing_save($store);
    }
}

/**
 * Seconds until pairing is allowed again from this address, or 0.
 *
 * Ten failures from one address, or forty from anywhere, within fifteen
 * minutes close pairing for the rest of that window.
 *
 * @param  string $ip
 *
 * @return int
 */
function mks_st_pairing_locked($ip)
{
    $mine = [];
    $all  = [];

    foreach (mks_st_pairing_load()['fails'] as $fail) {
        $all[] = (int) $fail['t'];

        if (isset($fail['ip']) && $fail['ip'] === $ip) {
            $mine[] = (int) $fail['t'];
        }
    }

    if (count($mine) >= 10) {
        return max(1, min($mine) + 900 - time());
    }

    if (count($all) >= 40) {
        return max(1, min($all) + 900 - time());
    }

    return 0;
}

/**
 * Redeem a code. Returns the entry, or an error code string.
 *
 * @param  string $code six digits or the QR secret
 * @param  string $ip
 *
 * @return array|string
 */
function mks_st_pairing_redeem($code, $ip)
{
    $store = mks_st_pairing_load();
    $code  = preg_replace('/[\s-]+/', '', (string) $code);

    if (preg_match('/^\d{6}$/', $code) || preg_match('/^[a-f0-9]{32}$/', $code)) {
        $hash = hash('sha256', $code);

        foreach ($store['codes'] as $index => $entry) {
            if (!hash_equals((string) $entry['code'], $hash) && !hash_equals((string) $entry['secret'], $hash)) {
                continue;
            }

            array_splice($store['codes'], $index, 1);
            mks_st_pairing_save($store);

            return $entry['expires'] < time() ? 'code_expired' : $entry;
        }
    }

    $store['fails'][] = ['ip' => (string) $ip, 't' => time()];
    mks_st_pairing_save($store);

    return 'invalid_code';
}

/**
 * @param  string $id
 * @param  int    $device_id
 *
 * @return void
 */
function mks_st_pairing_mark_used($id, $device_id)
{
    $store           = mks_st_pairing_load();
    $store['used'][] = ['id' => (string) $id, 'device_id' => (int) $device_id, 't' => time()];

    mks_st_pairing_save($store);
}

/**
 * What the pairing window shows while it waits. Device managers only.
 *
 * @param  string $id
 *
 * @return array state waiting|paired|expired, plus details
 */
function mks_st_pairing_status($id)
{
    $store = mks_st_pairing_load();

    foreach ($store['used'] as $used) {
        if ($used['id'] === $id) {
            $device = mks_st_device_get($used['device_id']);

            return $device
                ? ['state' => 'paired', 'device' => (string) $device['label'], 'model' => trim($device['manufacturer'] . ' ' . $device['model'])]
                : ['state' => 'expired'];
        }
    }

    foreach ($store['codes'] as $entry) {
        if ($entry['id'] === $id) {
            $left = (int) $entry['expires'] - time();

            return $left > 0 ? ['state' => 'waiting', 'expires_in' => $left] : ['state' => 'expired'];
        }
    }

    return ['state' => 'expired'];
}

/**
 * The pairing QR code as an image data URI, drawn by the bacon-qr-code
 * library Perfex already ships for two factor sign in. The SVG backend needs
 * no Imagick. Returns '' when the library or XMLWriter is missing, and the
 * pairing window falls back to the typed code.
 *
 * @param  string $text
 *
 * @return string
 */
function mks_st_qr_data_uri($text)
{
    if (!class_exists('XMLWriter') || !class_exists('BaconQrCode\Writer')
        || !class_exists('BaconQrCode\Renderer\Image\SvgImageBackEnd')) {
        return '';
    }

    try {
        $renderer = new \BaconQrCode\Renderer\ImageRenderer(
            new \BaconQrCode\Renderer\RendererStyle\RendererStyle(240, 1),
            new \BaconQrCode\Renderer\Image\SvgImageBackEnd()
        );

        $svg = (new \BaconQrCode\Writer($renderer))->writeString($text);
    } catch (\Throwable $e) {
        log_message('error', 'Sales Track: QR code could not be drawn - ' . $e->getMessage());

        return '';
    }

    return 'data:image/svg+xml;base64,' . base64_encode($svg);
}

/* =========================================================================
 * INGEST
 * ====================================================================== */

/**
 * Columns every inserted event carries, in order.
 *
 * @return array
 */
function mks_st_event_template()
{
    return [
        'device_id'        => 0,
        'staff_id'         => 0,
        'uid'              => '',
        'kind'             => '',
        'direction'        => '',
        'media'            => null,
        'source'           => 'auto',
        'number_raw'       => null,
        'number'           => null,
        'number_key'       => null,
        'contact_name'     => null,
        'sim_slot'         => null,
        'app_package'      => null,
        'app_name'         => null,
        'title'            => null,
        'body'             => null,
        'occurred_at'      => '',
        'duration'         => 0,
        'rel_type'         => null,
        'rel_id'           => null,
        'contact_id'       => null,
        'lead_id'          => null,
        'recording_status' => 'none',
        'callback_state'   => null,
        'callback_due_at'  => null,
        'received_at'      => '',
    ];
}

/**
 * The one path every event takes into the database, whether it came from a
 * phone or from the demo data.
 *
 * Each event ends in exactly one list:
 *   stored     written now
 *   duplicate  already held (same device and uid, or the same call or SMS
 *              re-sent by a reinstalled app)
 *   skipped    acceptable but not wanted: its tracker is off, the phone is
 *              paused, its number is excluded, its SIM is not tracked
 *   rejected   unusable: no uid, unknown kind, impossible time
 *
 * A phone removes all four from its queue. Only a failed request is retried.
 *
 * @param  array       $device
 * @param  array       $events
 * @param  string|null $forced_source 'demo' for demo data
 *
 * @return array|false false when the database refused the write
 */
function mks_st_ingest(array $device, array $events, $forced_source = null)
{
    $CI       = &get_instance();
    $settings = mks_st_settings();
    $kinds    = mks_st_kinds();
    $now      = date('Y-m-d H:i:s');
    $nowMs    = time() * 1000;
    $minMs    = 946684800000; // Jan 1, 2000 in ms: full history allowed
    $maxMs    = $nowMs + 86400000;
    $excluded = mks_st_excluded_keys();
    $trackSim = (int) $device['track_sim'];

    $result = [
        'stored'            => [],
        'duplicate'         => [],
        'skipped'           => [],
        'rejected'          => [],
        'recordings_wanted' => [],
    ];

    $rows = [];

    foreach ($events as $raw) {
        if (!is_array($raw)) {
            $result['rejected'][] = ['uid' => '', 'reason' => 'invalid_event'];

            continue;
        }

        $uid = mks_st_clean_uid(isset($raw['uid']) ? $raw['uid'] : '');

        if ($uid === '') {
            $result['rejected'][] = ['uid' => isset($raw['uid']) && is_scalar($raw['uid']) ? substr((string) $raw['uid'], 0, 80) : '', 'reason' => 'invalid_uid'];

            continue;
        }

        if (isset($rows[$uid])) {
            $result['duplicate'][] = $uid;

            continue;
        }

        if ($device['status'] === 'paused') {
            $result['skipped'][] = ['uid' => $uid, 'reason' => 'device_paused'];

            continue;
        }

        $kind = isset($raw['kind']) && is_scalar($raw['kind']) ? strtolower(trim((string) $raw['kind'])) : '';

        if (!isset($kinds[$kind])) {
            $result['rejected'][] = ['uid' => $uid, 'reason' => 'invalid_kind'];

            continue;
        }

        if (empty($settings[$kinds[$kind]['setting']])) {
            $result['skipped'][] = ['uid' => $uid, 'reason' => 'tracking_off'];

            continue;
        }

        $ms = mks_st_clean_time(isset($raw['time']) ? $raw['time'] : null);

        if ($ms === null || $ms < $minMs || $ms > $maxMs) {
            $result['rejected'][] = ['uid' => $uid, 'reason' => 'invalid_time'];

            continue;
        }

        $parts = mks_st_number_parts(isset($raw['number']) ? $raw['number'] : '');

        if ($parts['key'] !== null && isset($excluded[$parts['key']])) {
            $result['skipped'][] = ['uid' => $uid, 'reason' => 'excluded_number'];

            continue;
        }

        $sim = isset($raw['sim']) && is_numeric($raw['sim']) ? (int) $raw['sim'] : 0;
        $sim = ($sim >= 1 && $sim <= 4) ? $sim : 0;

        if ($trackSim > 0 && $sim > 0 && $sim !== $trackSim && in_array($kind, ['call', 'sms'], true)) {
            $result['skipped'][] = ['uid' => $uid, 'reason' => 'sim_not_tracked'];

            continue;
        }

        $app = mks_st_clean_package(isset($raw['app']) ? $raw['app'] : '');

        if ($kind === 'whatsapp_call' && $app === '') {
            $app = 'com.whatsapp';
        }

        $direction = mks_st_clean_direction($kind, isset($raw['direction']) ? $raw['direction'] : '');
        $duration  = isset($raw['duration']) && is_numeric($raw['duration']) ? (int) $raw['duration'] : 0;
        $duration  = max(0, min(86400, $duration));

        if (in_array($direction, ['missed', 'rejected', 'blocked'], true) || $kind === 'sms') {
            $duration = 0;
        }

        $media = null;

        if ($kind === 'whatsapp_call') {
            $media = (isset($raw['media']) && $raw['media'] === 'video') ? 'video' : 'voice';
        }

        $source = 'auto';

        if ($forced_source === 'demo') {
            $source = 'demo';
        } elseif (isset($raw['source']) && in_array($raw['source'], ['auto', 'app', 'manual'], true)) {
            $source = $raw['source'];
        }

        $row = mks_st_event_template();

        $row['device_id']    = (int) $device['id'];
        $row['staff_id']     = (int) $device['staff_id'];
        $row['uid']          = $uid;
        $row['kind']         = $kind;
        $row['direction']    = $direction;
        $row['media']        = $media;
        $row['source']       = $source;
        $row['number_raw']   = $parts['raw'];
        $row['number']       = $parts['number'];
        $row['number_key']   = $parts['key'];
        $row['contact_name'] = mks_st_null_if_empty(mks_st_clean_line(isset($raw['name']) ? $raw['name'] : '', 191));
        $row['sim_slot']     = $sim > 0 ? $sim : null;
        $row['app_package']  = $app !== '' ? $app : null;
        $row['app_name']     = mks_st_null_if_empty(mks_st_clean_line(isset($raw['app_name']) ? $raw['app_name'] : '', 100));
        $row['title']        = mks_st_null_if_empty(mks_st_clean_line(isset($raw['title']) ? $raw['title'] : '', 255));
        $row['body']         = mks_st_null_if_empty(mks_st_clean_body(isset($raw['text']) ? $raw['text'] : ''));
        $row['occurred_at']  = date('Y-m-d H:i:s', (int) floor($ms / 1000));
        $row['duration']     = $duration;
        $row['received_at']  = $now;

        if ($kind === 'call' && !empty($raw['recording']) && !empty($settings['track_recordings'])) {
            $row['recording_status'] = 'pending';
        }

        $rows[$uid] = $row;
    }

    if (!$rows) {
        return $result;
    }

    $table = mks_st_events_table();

    // Already stored from this device: update duration & recording status if incoming has more complete data
    foreach (array_chunk(array_keys($rows), 100) as $chunk) {
        $held = $CI->db->select('id, uid, duration, direction, recording_status, contact_name, occurred_at')
            ->where('device_id', (int) $device['id'])
            ->where_in('uid', array_map('strval', $chunk))
            ->get($table)
            ->result_array();

        foreach ($held as $h) {
            $hUid = (string) $h['uid'];
            if (isset($rows[$hUid])) {
                $incoming = $rows[$hUid];
                $update = [];

                if ((int) $incoming['duration'] > (int) $h['duration']) {
                    $update['duration'] = (int) $incoming['duration'];
                    if (!in_array($incoming['direction'], ['unknown', ''], true)) {
                        $update['direction'] = $incoming['direction'];
                    }
                }

                if ($incoming['recording_status'] === 'pending' && $h['recording_status'] !== 'stored') {
                    $update['recording_status'] = 'pending';
                    $result['recordings_wanted'][] = $hUid;
                }

                if (empty($h['contact_name']) && !empty($incoming['contact_name'])) {
                    $update['contact_name'] = $incoming['contact_name'];
                }

                if (!empty($update)) {
                    $CI->db->where('id', (int) $h['id'])->update($table, $update);
                }

                $result['duplicate'][] = $hUid;
                unset($rows[$hUid]);
            }
        }
    }

    // 1. Intra-batch deduplication: collapse duplicate events within the incoming batch itself
    if (count($rows) > 1) {
        $uids = array_keys($rows);
        $total = count($uids);
        for ($i = 0; $i < $total; $i++) {
            $u1 = $uids[$i];
            if (!isset($rows[$u1])) continue;
            $r1 = $rows[$u1];
            $t1 = strtotime($r1['occurred_at']);
            $isCall1 = in_array($r1['kind'], ['call', 'whatsapp_call'], true);
            $window1 = $isCall1 ? 120 : 60;

            for ($j = $i + 1; $j < $total; $j++) {
                $u2 = $uids[$j];
                if (!isset($rows[$u2])) continue;
                $r2 = $rows[$u2];

                $kindsMatch = ($r1['kind'] === $r2['kind']) ||
                    (!$isCall1 && in_array($r1['kind'], ['sms', 'whatsapp_message', 'notification'], true) && in_array($r2['kind'], ['sms', 'whatsapp_message', 'notification'], true));

                $numMatch = (!empty($r1['number_key']) && $r1['number_key'] === $r2['number_key'])
                    || (!empty($r1['number_raw']) && $r1['number_raw'] === $r2['number_raw'])
                    || (!empty($r1['number']) && $r1['number'] === $r2['number']);

                if ($kindsMatch && $numMatch) {
                    $t2 = strtotime($r2['occurred_at']);
                    if (abs($t1 - $t2) <= $window1) {
                        // Merge r2 into r1
                        if ((int) $r2['duration'] > (int) $rows[$u1]['duration']) {
                            $rows[$u1]['duration'] = (int) $r2['duration'];
                            if (!in_array($r2['direction'], ['unknown', ''], true)) {
                                $rows[$u1]['direction'] = $r2['direction'];
                            }
                        }
                        if ($r2['recording_status'] === 'pending' && $rows[$u1]['recording_status'] !== 'stored') {
                            $rows[$u1]['recording_status'] = 'pending';
                        }
                        if (empty($rows[$u1]['contact_name']) && !empty($r2['contact_name'])) {
                            $rows[$u1]['contact_name'] = $r2['contact_name'];
                        }
                        if (empty($rows[$u1]['body']) && !empty($r2['body'])) {
                            $rows[$u1]['body'] = $r2['body'];
                        }
                        $result['duplicate'][] = (string) $u2;
                        unset($rows[$u2]);
                    }
                }
            }
        }
    }

    // 2. Natural deduplication against database: match calls (120s) and messages (60s)
    if ($rows) {
        $times = [];
        foreach ($rows as $r) {
            $times[] = strtotime($r['occurred_at']);
        }

        if ($times) {
            $fromTime = date('Y-m-d H:i:s', min($times) - 120);
            $toTime   = date('Y-m-d H:i:s', max($times) + 120);

            $held = $CI->db->select('id, uid, device_id, kind, number_key, number_raw, number, occurred_at, duration, direction, recording_status, contact_name, body')
                ->where('staff_id', (int) $device['staff_id'])
                ->where_in('kind', ['call', 'whatsapp_call', 'sms', 'whatsapp_message', 'notification'])
                ->where('occurred_at >=', $fromTime)
                ->where('occurred_at <=', $toTime)
                ->get($table)
                ->result_array();

            foreach ($rows as $uid => $row) {
                $rowTs = strtotime($row['occurred_at']);
                $isCallKind = in_array($row['kind'], ['call', 'whatsapp_call'], true);
                $windowSec = $isCallKind ? 120 : 60;

                foreach ($held as $h) {
                    $kindsMatch = ($h['kind'] === $row['kind']) ||
                        (!$isCallKind && in_array($h['kind'], ['sms', 'whatsapp_message', 'notification'], true) && in_array($row['kind'], ['sms', 'whatsapp_message', 'notification'], true));

                    $numMatch = (!empty($row['number_key']) && $h['number_key'] === $row['number_key'])
                        || (!empty($row['number_raw']) && $h['number_raw'] === $row['number_raw'])
                        || (!empty($row['number']) && $h['number'] === $row['number']);

                    if ($kindsMatch && $numMatch) {
                        $hTs = strtotime($h['occurred_at']);
                        if (abs($rowTs - $hTs) <= $windowSec) {
                            $update = [];
                            if ((int) $row['duration'] > (int) $h['duration']) {
                                $update['duration'] = (int) $row['duration'];
                                if (!in_array($row['direction'], ['unknown', ''], true)) {
                                    $update['direction'] = $row['direction'];
                                }
                            }

                            if ($row['recording_status'] === 'pending' && $h['recording_status'] !== 'stored') {
                                $update['recording_status'] = 'pending';
                                $result['recordings_wanted'][] = (string) $uid;
                            }

                            if (empty($h['contact_name']) && !empty($row['contact_name'])) {
                                $update['contact_name'] = $row['contact_name'];
                            }

                            if (empty($h['body']) && !empty($row['body'])) {
                                $update['body'] = $row['body'];
                            }

                            if (preg_match('/^call-\d+-/', $uid) && !preg_match('/^call-\d+-/', (string) $h['uid'])) {
                                $update['uid'] = $uid;
                            } elseif (preg_match('/^sms-\d+-/', $uid) && !preg_match('/^sms-\d+-/', (string) $h['uid'])) {
                                $update['uid'] = $uid;
                            }

                            if (!empty($update)) {
                                $CI->db->where('id', (int) $h['id'])->update($table, $update);
                            }

                            $result['duplicate'][] = (string) $uid;
                            unset($rows[$uid]);
                            break;
                        }
                    }
                }
            }
        }
    }

    if (!$rows) {
        return $result;
    }

    $keys = [];

    foreach ($rows as $row) {
        if ($row['number_key'] !== null) {
            $keys[$row['number_key']] = $row['number_key'];
        }
    }

    $matches = $keys ? mks_st_match_numbers(array_values($keys)) : [];

    foreach ($rows as $uid => $row) {
        if ($row['number_key'] !== null && isset($matches[$row['number_key']])) {
            $rows[$uid]['rel_type']   = $matches[$row['number_key']]['rel_type'];
            $rows[$uid]['rel_id']     = $matches[$row['number_key']]['rel_id'];
            $rows[$uid]['contact_id'] = $matches[$row['number_key']]['contact_id'];
            $rows[$uid]['lead_id']    = $matches[$row['number_key']]['lead_id'];
        }

        // A missed call joins its rep's callback queue.
        if (function_exists('mks_st_callback_due') && $row['number_key'] !== null && in_array($row['direction'], ['missed', 'rejected'], true)
            && ($row['kind'] === 'call' || ($row['kind'] === 'whatsapp_call' && !empty($settings['callback_whatsapp'])))) {
            $rows[$uid]['callback_state']  = 'open';
            $rows[$uid]['callback_due_at'] = mks_st_callback_due($row['occurred_at']);
        }

        if ($row['kind'] === 'sms') {
            if ($settings['sms_text'] === 'none' || ($settings['sms_text'] === 'crm' && $rows[$uid]['rel_type'] === null)) {
                $rows[$uid]['body'] = null;
            }
        }
    }

    if (!mks_st_insert_rows($table, array_values($rows))) {
        return false;
    }

    foreach ($rows as $uid => $row) {
        $result['stored'][] = (string) $uid;

        if ($row['recording_status'] === 'pending') {
            $result['recordings_wanted'][] = (string) $uid;
        }
    }

    $CI->db->where('id', (int) $device['id']);
    $CI->db->update(mks_st_devices_table(), ['last_sync_at' => $now]);

    if (function_exists('mks_st_callbacks_settle')) {
        mks_st_callbacks_settle($rows);
    }

    if (function_exists('mks_st_after_calls') && $rows) {
        mks_st_after_calls($device, $rows);
    }

    return $result;
}

/**
 * @param  string $value
 *
 * @return string|null
 */
function mks_st_null_if_empty($value)
{
    return $value === '' ? null : $value;
}

/**
 * Multi row INSERT IGNORE. The unique key on device and uid makes a race
 * between two syncs from one phone harmless instead of a duplicate key error.
 *
 * @param  string $table
 * @param  array  $rows  all built from mks_st_event_template(), so same keys
 *
 * @return bool
 */
function mks_st_insert_rows($table, array $rows)
{
    if (!$rows) {
        return true;
    }

    $CI      = &get_instance();
    $columns = array_keys($rows[0]);

    foreach (array_chunk($rows, 100) as $chunk) {
        $values = [];

        foreach ($chunk as $row) {
            $cells = [];

            foreach ($columns as $column) {
                $cells[] = $row[$column] === null ? 'NULL' : $CI->db->escape($row[$column]);
            }

            $values[] = '(' . implode(', ', $cells) . ')';
        }

        $sql = 'INSERT IGNORE INTO `' . $table . '` (`' . implode('`, `', $columns) . '`) VALUES ' . implode(', ', $values);

        if (!$CI->db->query($sql)) {
            log_message('error', 'Sales Track: event insert failed - ' . json_encode($CI->db->error()));

            return false;
        }
    }

    return true;
}

/* =========================================================================
 * EVENTS
 * ====================================================================== */

/**
 * @param  int $id
 *
 * @return array|null
 */
function mks_st_event_get($id)
{
    $CI  = &get_instance();
    $row = $CI->db->where('id', (int) $id)->get(mks_st_events_table())->row_array();

    return $row ?: null;
}

/**
 * @param  int    $device_id
 * @param  string $uid
 *
 * @return array|null
 */
function mks_st_event_by_uid($device_id, $uid, $staff_id = null)
{
    $CI    = &get_instance();
    $table = mks_st_events_table();

    // 1. Direct device_id + uid
    $row = $CI->db->where('device_id', (int) $device_id)->where('uid', (string) $uid)->get($table)->row_array();
    if ($row) {
        return $row;
    }

    // 2. Direct uid alone (in case device was re-paired or device_id changed)
    $row = $CI->db->where('uid', (string) $uid)->get($table)->row_array();
    if ($row) {
        return $row;
    }

    // 3. Match by staff member's device if staff_id is known or retrievable
    if ($staff_id === null && (int) $device_id > 0) {
        $dev = $CI->db->select('staff_id')->where('id', (int) $device_id)->get(mks_st_devices_table())->row_array();
        $staff_id = $dev ? (int) $dev['staff_id'] : 0;
    }

    // 4. Timestamp extract from UID (e.g. call-123-1729068178000 or call-1729068178000)
    if (preg_match('/(\d{10,13})$/', (string) $uid, $m)) {
        $tsMs  = (int) $m[1];
        $tsSec = $tsMs > 100000000000 ? (int) floor($tsMs / 1000) : $tsMs;
        $fromTime = date('Y-m-d H:i:s', $tsSec - 120);
        $toTime   = date('Y-m-d H:i:s', $tsSec + 120);

        $CI->db->where('kind', 'call')
            ->where('occurred_at >=', $fromTime)
            ->where('occurred_at <=', $toTime);

        if ($staff_id !== null && (int) $staff_id > 0) {
            $CI->db->where('staff_id', (int) $staff_id);
        } else {
            $CI->db->where('device_id', (int) $device_id);
        }

        $row = $CI->db->order_by('id', 'DESC')->get($table)->row_array();
        if ($row) {
            return $row;
        }
    }

    return null;
}

/**
 * Collapse duplicate historical events in the database (same staff, number, within 120s)
 * Keeps the most informative record (with duration > 0 and/or recording).
 *
 * @return int number of removed duplicate records
 */
function mks_st_cleanup_duplicate_events()
{
    $CI    = &get_instance();
    $table = mks_st_events_table();

    if (!$CI->db->table_exists($table)) {
        return 0;
    }

    $removed = 0;

    // 1. Cleanup call and whatsapp_call duplicates within 120s
    $callDups = $CI->db->query("
        SELECT e1.id as keep_id, e2.id as remove_id, 
               e1.duration as dur1, e2.duration as dur2,
               e1.direction as dir1, e2.direction as dir2,
               e1.recording_status as rec1, e2.recording_status as rec2,
               e1.recording_file as file1, e2.recording_file as file2,
               e1.contact_name as name1, e2.contact_name as name2,
               e1.uid as uid1, e2.uid as uid2
        FROM {$table} e1
        INNER JOIN {$table} e2 ON e1.staff_id = e2.staff_id 
            AND e1.kind = e2.kind 
            AND (
                (e1.number_key IS NOT NULL AND e1.number_key != '' AND e1.number_key = e2.number_key)
                OR (e1.number_raw IS NOT NULL AND e1.number_raw != '' AND e1.number_raw = e2.number_raw)
                OR (e1.number IS NOT NULL AND e1.number != '' AND e1.number = e2.number)
            )
            AND e1.id < e2.id
            AND ABS(TIMESTAMPDIFF(SECOND, e1.occurred_at, e2.occurred_at)) <= 120
        WHERE e1.kind IN ('call', 'whatsapp_call')
    ");

    if ($callDups) {
        foreach ($callDups->result_array() as $d) {
            $update = [];
            if ((int) $d['dur2'] > (int) $d['dur1']) {
                $update['duration'] = (int) $d['dur2'];
                if (!in_array($d['dir2'], ['unknown', ''], true)) {
                    $update['direction'] = $d['dir2'];
                }
            }
            if ($d['rec2'] === 'stored' && $d['rec1'] !== 'stored') {
                $update['recording_status'] = 'stored';
                $update['recording_file']   = $d['file2'];
            } elseif ($d['rec2'] === 'pending' && $d['rec1'] === 'none') {
                $update['recording_status'] = 'pending';
            }
            if (empty($d['name1']) && !empty($d['name2'])) {
                $update['contact_name'] = $d['name2'];
            }
            if (preg_match('/^call-\d+-/', (string) $d['uid2']) && !preg_match('/^call-\d+-/', (string) $d['uid1'])) {
                $update['uid'] = $d['uid2'];
            }
            if (!empty($update)) {
                $CI->db->where('id', (int) $d['keep_id'])->update($table, $update);
            }
            $CI->db->where('id', (int) $d['remove_id'])->delete($table);
            $removed++;
        }
    }

    // 2. Cleanup SMS, whatsapp_message, and notification duplicates within 60s
    $smsDups = $CI->db->query("
        SELECT e1.id as keep_id, e2.id as remove_id,
               e1.kind as kind1, e2.kind as kind2,
               e1.body as body1, e2.body as body2,
               e1.contact_name as name1, e2.contact_name as name2,
               e1.uid as uid1, e2.uid as uid2
        FROM {$table} e1
        INNER JOIN {$table} e2 ON e1.staff_id = e2.staff_id 
            AND (
                e1.kind = e2.kind 
                OR (e1.kind IN ('sms', 'whatsapp_message', 'notification') AND e2.kind IN ('sms', 'whatsapp_message', 'notification'))
            )
            AND (
                (e1.number_key IS NOT NULL AND e1.number_key != '' AND e1.number_key = e2.number_key)
                OR (e1.number_raw IS NOT NULL AND e1.number_raw != '' AND e1.number_raw = e2.number_raw)
                OR (e1.number IS NOT NULL AND e1.number != '' AND e1.number = e2.number)
            )
            AND e1.id < e2.id
            AND ABS(TIMESTAMPDIFF(SECOND, e1.occurred_at, e2.occurred_at)) <= 60
        WHERE e1.kind IN ('sms', 'whatsapp_message', 'notification')
    ");

    if ($smsDups) {
        foreach ($smsDups->result_array() as $d) {
            $update = [];
            if ($d['kind1'] === 'notification' && in_array($d['kind2'], ['sms', 'whatsapp_message'], true)) {
                $update['kind'] = $d['kind2'];
            }
            if (empty($d['body1']) && !empty($d['body2'])) {
                $update['body'] = $d['body2'];
            }
            if (empty($d['name1']) && !empty($d['name2'])) {
                $update['contact_name'] = $d['name2'];
            }
            if (preg_match('/^(sms|wamsg)-\d+-/', (string) $d['uid2']) && !preg_match('/^(sms|wamsg)-\d+-/', (string) $d['uid1'])) {
                $update['uid'] = $d['uid2'];
            }
            if (!empty($update)) {
                $CI->db->where('id', (int) $d['keep_id'])->update($table, $update);
            }
            $CI->db->where('id', (int) $d['remove_id'])->delete($table);
            $removed++;
        }
    }

    return $removed;
}

/**
 * May the signed in member of staff see this event? The same rule the lists
 * apply in SQL, for single record routes.
 *
 * @param  array $event
 *
 * @return bool
 */
function mks_st_event_visible(array $event)
{
    return mks_st_scope_allows($event['staff_id']);
}

/**
 * Delete an event and its recording file.
 *
 * @param  array $event
 *
 * @return bool
 */
function mks_st_event_delete(array $event)
{
    if (!empty($event['recording_file'])) {
        mks_st_recording_unlink($event['recording_file']);
    }

    $CI = &get_instance();
    $CI->db->where('id', (int) $event['id']);
    $CI->db->delete(mks_st_events_table());

    return $CI->db->affected_rows() > 0;
}

/* =========================================================================
 * RECORDINGS
 * ====================================================================== */

/**
 * Accepted recording formats and the type each is served with.
 *
 * @return array extension => mime
 */
function mks_st_recording_formats()
{
    return [
        'm4a'  => 'audio/mp4',
        'mp4'  => 'audio/mp4',
        'aac'  => 'audio/aac',
        'mp3'  => 'audio/mpeg',
        'ogg'  => 'audio/ogg',
        'oga'  => 'audio/ogg',
        'opus' => 'audio/ogg',
        'webm' => 'audio/webm',
        'wav'  => 'audio/wav',
        'flac' => 'audio/flac',
        'amr'  => 'audio/amr',
        'awb'  => 'audio/amr-wb',
        '3gp'  => 'audio/3gpp',
        '3ga'  => 'audio/3gpp',
    ];
}

/**
 * Browsers cannot play AMR or 3GP, which some older dialers record. Those are
 * kept and offered as downloads.
 *
 * @param  string $file
 *
 * @return bool
 */
function mks_st_recording_playable($file)
{
    $ext = strtolower(pathinfo((string) $file, PATHINFO_EXTENSION));

    return !in_array($ext, ['amr', 'awb', '3gp', '3ga'], true);
}

/**
 * A php.ini size such as 128M, in bytes.
 *
 * @param  string $value
 *
 * @return int 0 for unlimited or unknown
 */
function mks_st_ini_bytes($value)
{
    $value = trim((string) $value);

    if ($value === '' || $value === '-1') {
        return 0;
    }

    $unit   = strtolower(substr($value, -1));
    $number = (float) $value;

    switch ($unit) {
        case 'g':
            $number *= 1024;
            // no break
        case 'm':
            $number *= 1024;
            // no break
        case 'k':
            $number *= 1024;
    }

    return (int) $number;
}

/**
 * The largest recording the server will actually accept: the module setting,
 * capped by PHP's own upload limits.
 *
 * @return int bytes
 */
function mks_st_recording_limit_bytes()
{
    $limit = (int) mks_st_setting('recording_max_mb', 25) * 1048576;

    foreach (['upload_max_filesize', 'post_max_size'] as $ini) {
        $bytes = mks_st_ini_bytes(ini_get($ini));

        if ($bytes > 0) {
            // post_max_size has to hold the form fields as well as the file.
            $limit = min($limit, $ini === 'post_max_size' ? max(0, $bytes - 65536) : $bytes);
        }
    }

    return $limit;
}

/**
 * @return float
 */
function mks_st_recording_limit_mb()
{
    return round(mks_st_recording_limit_bytes() / 1048576, 1);
}

/**
 * @return string
 */
function mks_st_upload_root()
{
    return FCPATH . 'uploads/mks_sales_track/';
}

/**
 * The upload folder, protected the same way Perfex protects its own private
 * folders: an index.html against listing and Deny from all against direct
 * access. Recordings are only ever served through the permission checked
 * stream endpoint. Outside the module folder, so a module upgrade can never
 * delete them.
 *
 * @return bool
 */
function mks_st_ensure_upload_root()
{
    $root = mks_st_upload_root();

    if (!is_dir($root) && !@mkdir($root, 0755, true)) {
        return false;
    }

    if (!file_exists($root . 'index.html')) {
        @file_put_contents($root . 'index.html', '<!DOCTYPE html><html><head><title>403 Forbidden</title></head><body><p>Directory access is forbidden.</p></body></html>');
    }

    if (!file_exists($root . '.htaccess')) {
        @file_put_contents($root . '.htaccess', "Order Deny,Allow\nDeny from all\n");
    }

    return is_dir($root);
}

/**
 * @param  string $dir absolute
 *
 * @return bool
 */
function mks_st_make_dir($dir)
{
    if (is_dir($dir)) {
        return true;
    }

    if (!@mkdir($dir, 0755, true)) {
        return false;
    }

    @file_put_contents(rtrim($dir, '/') . '/index.html', '');

    return true;
}

/**
 * Check an upload before it is stored. Returns ext and mime, or an error code.
 *
 * @param  array $file one $_FILES entry
 *
 * @return array|string
 */
function mks_st_validate_recording_upload($file)
{
    if (!is_array($file) || !isset($file['error'], $file['tmp_name'], $file['size'])) {
        return 'missing_file';
    }

    if (in_array($file['error'], [UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE], true)) {
        return 'file_too_large';
    }

    if ($file['error'] !== UPLOAD_ERR_OK || !is_uploaded_file($file['tmp_name'])) {
        return 'upload_failed';
    }

    if ((int) $file['size'] <= 0) {
        return 'upload_failed';
    }

    if ((int) $file['size'] > mks_st_recording_limit_bytes()) {
        return 'file_too_large';
    }

    $formats = mks_st_recording_formats();
    $ext     = strtolower(pathinfo(isset($file['name']) ? (string) $file['name'] : '', PATHINFO_EXTENSION));

    if (!isset($formats[$ext])) {
        return 'unsupported_type';
    }

    if (!mks_st_recording_content_ok($file['tmp_name'], $ext)) {
        return 'unsupported_type';
    }

    return ['ext' => $ext, 'mime' => $formats[$ext]];
}

/**
 * Does the file's content look like audio? libmagic does not know every
 * dialer format, so AMR and raw AAC may come back as octet-stream and are
 * allowed that one exception. Anything that sniffs as text or a script is
 * refused whatever its name says.
 *
 * @param  string $path
 * @param  string $ext
 *
 * @return bool
 */
function mks_st_recording_content_ok($path, $ext)
{
    if (!function_exists('finfo_open')) {
        return true;
    }

    $finfo = finfo_open(FILEINFO_MIME_TYPE);
    $mime  = $finfo ? (string) finfo_file($finfo, $path) : '';

    if ($finfo) {
        finfo_close($finfo);
    }

    if ($mime === '' || strpos($mime, 'audio/') === 0) {
        return true;
    }

    if (in_array($mime, ['video/mp4', 'video/3gpp', 'video/webm', 'application/ogg'], true)) {
        return true;
    }

    return $mime === 'application/octet-stream' && in_array($ext, ['amr', 'awb', 'aac', 'opus', '3ga'], true);
}

/**
 * Store a recording against its call and mark it stored.
 *
 * @param  array  $event
 * @param  string $source   path of the uploaded or generated file
 * @param  string $ext
 * @param  string $mime
 * @param  bool   $uploaded true for a real HTTP upload (move_uploaded_file)
 *
 * @return bool
 */
function mks_st_store_recording(array $event, $source, $ext, $mime, $uploaded)
{
    if (!mks_st_ensure_upload_root()) {
        return false;
    }

    $sub = 'recordings/' . date('Y/m', strtotime($event['occurred_at'])) . '/';
    $dir = mks_st_upload_root() . $sub;

    if (!mks_st_make_dir($dir)) {
        return false;
    }

    $name = (int) $event['id'] . '_' . bin2hex(random_bytes(6)) . '.' . $ext;
    $ok   = $uploaded ? @move_uploaded_file($source, $dir . $name) : @copy($source, $dir . $name);

    if (!$ok) {
        return false;
    }

    @chmod($dir . $name, 0644);

    if (!empty($event['recording_file'])) {
        mks_st_recording_unlink($event['recording_file']);
    }

    $CI = &get_instance();
    $CI->db->where('id', (int) $event['id']);
    $CI->db->update(mks_st_events_table(), [
        'recording_status' => 'stored',
        'recording_file'   => $sub . $name,
        'recording_size'   => (int) filesize($dir . $name),
        'recording_mime'   => $mime,
        'recording_at'     => date('Y-m-d H:i:s'),
    ]);

    return true;
}

/**
 * The absolute path of a stored recording, only if it really sits inside the
 * upload folder.
 *
 * @param  string $relative
 *
 * @return string|false
 */
function mks_st_recording_path($relative)
{
    $root = realpath(mks_st_upload_root());
    $path = realpath(mks_st_upload_root() . ltrim((string) $relative, '/'));

    if ($root === false || $path === false || strpos($path, $root . DIRECTORY_SEPARATOR) !== 0 || !is_file($path)) {
        return false;
    }

    return $path;
}

/**
 * @param  string $relative
 *
 * @return void
 */
function mks_st_recording_unlink($relative)
{
    $path = mks_st_recording_path($relative);

    if ($path !== false) {
        @unlink($path);
    }
}

/**
 * Stream a file with HTTP range support, which is what lets the audio player
 * seek. The session is closed first: Perfex's database session holds a lock
 * for the life of the request, and a long stream would otherwise freeze every
 * other request from the same browser until it finished.
 *
 * @param  string      $path
 * @param  string      $mime
 * @param  string|null $download_name a name to force a download, or null
 *
 * @return void
 */
function mks_st_stream_file($path, $mime, $download_name = null)
{
    if (session_status() === PHP_SESSION_ACTIVE) {
        session_write_close();
    }

    while (ob_get_level() > 0) {
        ob_end_clean();
    }

    $size   = (int) filesize($path);
    $start  = 0;
    $end    = $size - 1;
    $status = 200;

    if (isset($_SERVER['HTTP_RANGE']) && preg_match('/^bytes=(\d*)-(\d*)$/', trim($_SERVER['HTTP_RANGE']), $m)) {
        if ($m[1] === '' && $m[2] !== '') {
            $start = max(0, $size - (int) $m[2]);
        } else {
            $start = (int) $m[1];

            if ($m[2] !== '') {
                $end = min((int) $m[2], $size - 1);
            }
        }

        if ($start > $end || $start >= $size) {
            http_response_code(416);
            header('Content-Range: bytes */' . $size);
            exit;
        }

        $status = 206;
    }

    $name = $download_name !== null ? $download_name : basename($path);
    $name = preg_replace('/[^A-Za-z0-9._-]+/', '_', $name);

    http_response_code($status);
    header('Content-Type: ' . $mime);
    header('Accept-Ranges: bytes');
    header('Content-Length: ' . ($end - $start + 1));
    header('Cache-Control: private, max-age=3600');
    header('X-Content-Type-Options: nosniff');
    header('Content-Disposition: ' . ($download_name !== null ? 'attachment' : 'inline') . '; filename="' . $name . '"');

    if ($status === 206) {
        header('Content-Range: bytes ' . $start . '-' . $end . '/' . $size);
    }

    $handle = fopen($path, 'rb');

    if ($handle === false) {
        exit;
    }

    fseek($handle, $start);
    $left = $end - $start + 1;

    while ($left > 0 && !feof($handle) && !connection_aborted()) {
        $chunk = fread($handle, (int) min(65536, $left));

        if ($chunk === false || $chunk === '') {
            break;
        }

        echo $chunk;
        flush();
        $left -= strlen($chunk);
    }

    fclose($handle);
    exit;
}

/* =========================================================================
 * RESPONSES
 * ====================================================================== */

/**
 * JSON for the admin screens' own AJAX calls, always carrying a fresh CSRF
 * hash so a page that stays open keeps working after a token change.
 *
 * @param  array $payload
 * @param  int   $status
 *
 * @return void
 */
function mks_st_json(array $payload, $status = 200)
{
    $CI = &get_instance();

    if ($CI->config->item('csrf_protection')) {
        $payload['csrf'] = [
            'name' => $CI->security->get_csrf_token_name(),
            'hash' => $CI->security->get_csrf_hash(),
        ];
    }

    http_response_code((int) $status);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');

    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}

/**
 * A plain sentence for each API error code, so a developer reading a raw
 * response does not need the docs open.
 *
 * @param  string $code
 *
 * @return string
 */
function mks_st_api_message($code)
{
    $key  = 'mks_st_api_' . $code;
    $text = _l($key);

    return $text === $key ? (string) $code : $text;
}

/**
 * A JSON column as an array, never null.
 *
 * @param  string|null $json
 *
 * @return array
 */
function mks_st_decode($json)
{
    $value = json_decode((string) $json, true);

    return is_array($value) ? $value : [];
}
