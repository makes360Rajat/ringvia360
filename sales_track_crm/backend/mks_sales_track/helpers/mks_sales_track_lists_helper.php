<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - call lists, do-not-call numbers, the caller popup
 * directory and the wallboard.
 *
 * Loaded on demand by the screens and the phone API.
 *
 * Call lists need no table. A list is a frozen set of leads with an assignee
 * for each, kept in its own option; whether a lead has been called, reached
 * or given an outcome is read from the calls themselves, so a list is always
 * exactly as far along as the phones say. Only skips are written back.
 */

/** Leads in one list at most. */
define('MKS_ST_LIST_MAX', 1000);

/** Directory entries sent to one phone at most. */
define('MKS_ST_DIRECTORY_MAX', 5000);

/**
 * The matching key of a number (its last digits), or an empty string.
 *
 * @param  string $number
 *
 * @return string
 */
function mks_st_lst_key($number)
{
    $parts = mks_st_number_parts($number);

    return (string) $parts['key'];
}

/**
 * A number as the phone should dial it.
 *
 * @param  string $number
 *
 * @return string
 */
function mks_st_lst_number($number)
{
    $parts = mks_st_number_parts($number);

    return (string) ($parts['number'] ?: $parts['raw']);
}

/**
 * A stored date and time for the phone, in ISO 8601 with its offset.
 *
 * @param  string $datetime
 *
 * @return string
 */
function mks_st_lst_iso($datetime)
{
    return date('c', strtotime($datetime));
}

/* =========================================================================
 * DO NOT CALL
 * ====================================================================== */

/**
 * Number keys on the do-not-call list.
 *
 * @return array key => true
 */
function mks_st_dnc_keys()
{
    static $keys = null;

    if ($keys === null) {
        $keys = [];

        foreach (preg_split('/[\r\n]+/', (string) mks_st_setting('dnc_numbers', '')) as $number) {
            $key = mks_st_lst_key($number);

            if ($key !== '') {
                $keys[$key] = true;
            }
        }
    }

    return $keys;
}

/**
 * @param  string|null $number
 *
 * @return bool
 */
function mks_st_is_dnc($number)
{
    $key = mks_st_lst_key((string) $number);

    return $key !== '' && isset(mks_st_dnc_keys()[$key]);
}

/* =========================================================================
 * CALL LISTS: STORAGE
 * ====================================================================== */

/**
 * Every list's header.
 *
 * @return array id => header
 */
function mks_st_lists()
{
    $index = json_decode((string) get_option('mks_sales_track_lists'), true);

    return is_array($index) && isset($index['lists']) && is_array($index['lists']) ? $index['lists'] : [];
}

/**
 * @param  array $lists
 * @param  int   $next
 *
 * @return void
 */
function mks_st_lists_put(array $lists, $next = null)
{
    $index = json_decode((string) get_option('mks_sales_track_lists'), true);
    $next  = $next !== null ? $next : (is_array($index) && isset($index['next']) ? (int) $index['next'] : 1);

    mks_st_option_put('mks_sales_track_lists', json_encode(['next' => $next, 'lists' => $lists]), 0);
}

/**
 * One list: header and body (leads, assignees, skips).
 *
 * @param  int $id
 *
 * @return array|null
 */
function mks_st_list_get($id)
{
    $lists = mks_st_lists();

    if (!isset($lists[(int) $id])) {
        return null;
    }

    $body = json_decode((string) get_option('mks_sales_track_list_' . (int) $id), true);

    // Stored values first, then the header, so neither is shadowed by the
    // empty defaults (array union keeps the left-hand value).
    return array_merge(['assign' => [], 'skipped' => []], is_array($body) ? $body : [], $lists[(int) $id], ['id' => (int) $id]);
}

/**
 * May the viewer see this list? Managers see every list; team leads the
 * lists they made or that include their team; reps the lists they are on.
 *
 * @param  array $list header
 *
 * @return bool
 */
function mks_st_list_visible(array $list)
{
    $scope = mks_st_scope();

    if ($scope === null) {
        return true;
    }

    if ($scope === false) {
        return false;
    }

    return (int) $list['created_by'] === (int) get_staff_user_id() || (bool) array_intersect(array_map('intval', $list['staff']), $scope);
}

/**
 * May the viewer build and change lists? Managers and team leads.
 *
 * @return bool
 */
function mks_st_can_lists()
{
    return mks_st_scope() !== false && !mks_st_scope_is_own();
}

/* =========================================================================
 * CALL LISTS: BUILDING
 * ====================================================================== */

/**
 * The leads a set of filters selects, newest first, without do-not-call
 * numbers.
 *
 * @param  array $filters statuses, sources, owners, quiet_days, created_from, created_to, open_only
 *
 * @return array rows: id, assigned, phonenumber
 */
function mks_st_list_leads(array $filters)
{
    $CI = &get_instance();

    $CI->db->select('id, assigned, phonenumber')->from(db_prefix() . 'leads')->where('phonenumber !=', '');

    foreach (['statuses' => 'status', 'sources' => 'source', 'owners' => 'assigned'] as $key => $column) {
        $values = array_values(array_filter(array_map('intval', isset($filters[$key]) ? (array) $filters[$key] : []), function ($v) {
            return $v >= 0;
        }));

        if ($values) {
            $CI->db->where_in($column, $values);
        }
    }

    if (!empty($filters['open_only'])) {
        $CI->db->where('lost', 0)->where('junk', 0)->where('date_converted IS NULL', null, false);
    }

    if (!empty($filters['quiet_days'])) {
        $CI->db->group_start()->where('lastcontact IS NULL', null, false)
            ->or_where('lastcontact <', date('Y-m-d H:i:s', strtotime('-' . (int) $filters['quiet_days'] . ' days')))->group_end();
    }

    foreach (['created_from' => '>=', 'created_to' => '<='] as $key => $op) {
        if (!empty($filters[$key]) && preg_match('/^\d{4}-\d{2}-\d{2}$/', $filters[$key])) {
            $CI->db->where('dateadded ' . $op, $filters[$key] . ($op === '>=' ? ' 00:00:00' : ' 23:59:59'));
        }
    }

    $rows = $CI->db->order_by('dateadded', 'desc')->limit(MKS_ST_LIST_MAX * 2)->get()->result_array();

    return array_slice(array_values(array_filter($rows, function ($row) {
        return !mks_st_is_dnc($row['phonenumber']);
    })), 0, MKS_ST_LIST_MAX);
}

/**
 * Create a list. Leads go to their own owner when the owner is on the list,
 * otherwise round robin among the people on it.
 *
 * @param  array $data name, note, due, staff, mode, filters
 * @param  int   $by
 *
 * @return array ok, id, count, error
 */
function mks_st_list_create(array $data, $by)
{
    $staff = array_values(array_unique(array_filter(array_map('intval', (array) $data['staff']))));
    $name  = mks_st_clean_line((string) $data['name'], 80);

    if ($name === '' || !$staff) {
        return ['ok' => false, 'error' => 'mks_st_list_need_name_staff'];
    }

    $leads = mks_st_list_leads((array) $data['filters']);

    if (!$leads) {
        return ['ok' => false, 'error' => 'mks_st_list_no_leads'];
    }

    $assign = [];
    $turn   = 0;

    foreach ($leads as $lead) {
        if ($data['mode'] === 'owner' && in_array((int) $lead['assigned'], $staff, true)) {
            $assign[(int) $lead['id']] = (int) $lead['assigned'];
        } else {
            $assign[(int) $lead['id']] = $staff[$turn++ % count($staff)];
        }
    }

    $index = json_decode((string) get_option('mks_sales_track_lists'), true);
    $id    = is_array($index) && isset($index['next']) ? (int) $index['next'] : 1;
    $lists = mks_st_lists();

    $lists[$id] = [
        'name'       => $name,
        'note'       => mks_st_clean_line((string) $data['note'], 250),
        'due'        => preg_match('/^\d{4}-\d{2}-\d{2}$/', (string) $data['due']) ? (string) $data['due'] : '',
        'staff'      => $staff,
        'created_by' => (int) $by,
        'created_at' => date('Y-m-d H:i:s'),
        'status'     => 'active',
        'count'      => count($assign),
    ];

    mks_st_option_put('mks_sales_track_list_' . $id, json_encode(['assign' => $assign, 'skipped' => []]), 0);
    mks_st_lists_put($lists, $id + 1);

    return ['ok' => true, 'id' => $id, 'count' => count($assign), 'error' => ''];
}

/**
 * Archive, reopen or delete a list.
 *
 * @param  int    $id
 * @param  string $action archive, reopen, delete
 *
 * @return bool
 */
function mks_st_list_change($id, $action)
{
    $lists = mks_st_lists();

    if (!isset($lists[(int) $id])) {
        return false;
    }

    if ($action === 'delete') {
        unset($lists[(int) $id]);
        mks_st_option_put('mks_sales_track_list_' . (int) $id, '', 0);
        get_instance()->db->where('name', 'mks_sales_track_list_' . (int) $id)->delete(db_prefix() . 'options');
    } else {
        $lists[(int) $id]['status'] = $action === 'archive' ? 'archived' : 'active';
    }

    mks_st_lists_put($lists);

    return true;
}

/**
 * Skip a lead on a list, or bring it back.
 *
 * @param  array $list
 * @param  int   $leadId
 * @param  bool  $skip
 *
 * @return bool
 */
function mks_st_list_skip(array $list, $leadId, $skip)
{
    if (!isset($list['assign'][(int) $leadId]) && !isset($list['assign'][(string) (int) $leadId])) {
        return false;
    }

    $skipped = (array) $list['skipped'];

    if ($skip) {
        $skipped[(int) $leadId] = (int) get_staff_user_id();
    } else {
        unset($skipped[(int) $leadId]);
    }

    mks_st_option_put('mks_sales_track_list_' . (int) $list['id'], json_encode(['assign' => $list['assign'], 'skipped' => $skipped]), 0);

    return true;
}

/* =========================================================================
 * CALL LISTS: PROGRESS, READ FROM THE CALLS
 * ====================================================================== */

/**
 * Each lead on a list with where it stands: called (any call or WhatsApp
 * call with the lead since the list was made), reached (connected), the
 * latest outcome, or skipped.
 *
 * @param  array    $list
 * @param  int|null $staffId only this person's leads
 *
 * @return array rows: lead, name, company, phone, status, assigned, state, last_at, outcome, dnc
 */
function mks_st_list_items(array $list, $staffId = null)
{
    $CI     = &get_instance();
    $assign = [];

    foreach ((array) $list['assign'] as $lead => $owner) {
        if ($staffId === null || (int) $owner === (int) $staffId) {
            $assign[(int) $lead] = (int) $owner;
        }
    }

    if (!$assign) {
        return [];
    }

    $ids   = array_keys($assign);
    $leads = [];

    foreach ($CI->db->select('id, name, company, phonenumber, status')->where_in('id', $ids)->get(db_prefix() . 'leads')->result_array() as $row) {
        $leads[(int) $row['id']] = $row;
    }

    $calls = [];

    foreach ($CI->db->query('SELECT IF(rel_type = \'lead\', rel_id, lead_id) AS lead, COUNT(*) AS calls, MAX(duration >= ' . mks_st_connected_seconds() . ') AS reached,'
        . ' MAX(occurred_at) AS last_at, SUBSTRING_INDEX(GROUP_CONCAT(COALESCE(outcome, \'\') ORDER BY occurred_at DESC), \',\', 1) AS outcome'
        . ' FROM ' . mks_st_events_table() . " WHERE kind IN ('call', 'whatsapp_call') AND occurred_at >= " . $CI->db->escape($list['created_at'])
        . " AND ((rel_type = 'lead' AND rel_id IN (" . implode(',', $ids) . ')) OR lead_id IN (' . implode(',', $ids) . ')) GROUP BY lead')->result_array() as $row) {
        $calls[(int) $row['lead']] = $row;
    }

    $statuses = mks_st_lead_statuses();
    $outcomes = mks_st_outcomes(false);
    $rows     = [];

    foreach ($assign as $leadId => $owner) {
        if (!isset($leads[$leadId])) {
            continue;
        }

        $lead  = $leads[$leadId];
        $call  = isset($calls[$leadId]) ? $calls[$leadId] : null;
        $state = $call ? ((int) $call['reached'] ? 'reached' : 'tried') : (isset($list['skipped'][$leadId]) || isset($list['skipped'][(string) $leadId]) ? 'skipped' : 'pending');

        $rows[] = [
            'lead'     => $leadId,
            'name'     => $lead['name'],
            'company'  => $lead['company'],
            'phone'    => $lead['phonenumber'],
            'status'   => isset($statuses[(int) $lead['status']]) ? $statuses[(int) $lead['status']]['name'] : '',
            'assigned' => $owner,
            'state'    => $state,
            'last_at'  => $call ? $call['last_at'] : null,
            'outcome'  => $call && $call['outcome'] !== '' && isset($outcomes[$call['outcome']]) ? $outcomes[$call['outcome']]['label'] : '',
            'dnc'      => mks_st_is_dnc($lead['phonenumber']),
        ];
    }

    $order = ['pending' => 0, 'tried' => 1, 'skipped' => 2, 'reached' => 3];

    usort($rows, function ($a, $b) use ($order) {
        return $order[$a['state']] - $order[$b['state']] ?: strcasecmp($a['name'], $b['name']);
    });

    return $rows;
}

/**
 * Totals for a list's items.
 *
 * @param  array $items
 *
 * @return array total, done, reached, skipped, pending, percent
 */
function mks_st_list_totals(array $items)
{
    $count = array_count_values(array_column($items, 'state'));
    $total = count($items);
    $done  = (isset($count['tried']) ? $count['tried'] : 0) + (isset($count['reached']) ? $count['reached'] : 0);

    return [
        'total'   => $total,
        'done'    => $done,
        'reached' => isset($count['reached']) ? $count['reached'] : 0,
        'skipped' => isset($count['skipped']) ? $count['skipped'] : 0,
        'pending' => isset($count['pending']) ? $count['pending'] : 0,
        'percent' => $total > 0 ? (int) round(($done + (isset($count['skipped']) ? $count['skipped'] : 0)) * 100 / $total) : 0,
    ];
}

/**
 * The active lists a person works on, with their own items, for the phone.
 *
 * @param  int $staffId
 *
 * @return array
 */
function mks_st_lists_for($staffId)
{
    $out = [];

    foreach (mks_st_lists() as $id => $header) {
        if ($header['status'] !== 'active' || !in_array((int) $staffId, array_map('intval', $header['staff']), true)) {
            continue;
        }

        $list  = mks_st_list_get($id);
        $items = mks_st_list_items($list, (int) $staffId);

        $out[] = [
            'id'       => (int) $id,
            'name'     => $header['name'],
            'note'     => $header['note'],
            'due'      => $header['due'],
            'progress' => mks_st_list_totals($items),
            'items'    => array_map(function ($item) {
                return ['lead_id' => $item['lead'], 'name' => $item['name'], 'company' => (string) $item['company'], 'number' => mks_st_lst_number($item['phone']),
                    'status' => $item['status'], 'state' => $item['state'], 'last_call' => $item['last_at'] ? mks_st_lst_iso($item['last_at']) : null,
                    'outcome' => $item['outcome'], 'do_not_call' => $item['dnc']];
            }, array_slice($items, 0, 300)),
        ];
    }

    return $out;
}

/* =========================================================================
 * CALLER POPUP DIRECTORY
 * ====================================================================== */

/**
 * Who a phone can recognise, for the caller popup: leads, customers and
 * their contacts, colleagues and the extra entries from Settings, each with
 * what the popup shows. Follows Settings > Caller Popup and the phone
 * owner's own access.
 *
 * @param  int $staffId the phone's owner
 *
 * @return array entries keyed by number key
 */
function mks_st_directory($staffId)
{
    $CI      = &get_instance();
    $p       = db_prefix();
    $out     = [];
    $names   = [];
    $statuses = mks_st_lead_statuses();
    $outcomes = mks_st_outcomes(false);

    $add = function ($number, array $entry) use (&$out) {
        $key = mks_st_lst_key((string) $number);

        if ($key !== '' && !isset($out[$key]) && count($out) < MKS_ST_DIRECTORY_MAX) {
            $out[$key] = ['k' => $key] + $entry;
        }
    };

    $staffName = function ($id) use (&$names) {
        if (!isset($names[(int) $id])) {
            $names[(int) $id] = (int) $id > 0 ? mks_st_staff_name($id) : '';
        }

        return $names[(int) $id];
    };

    if (mks_st_enabled('directory_staff')) {
        foreach ($CI->db->select('staffid, firstname, lastname, phonenumber')->where('active', 1)->where('phonenumber !=', '')->get($p . 'staff')->result_array() as $row) {
            $add($row['phonenumber'], ['t' => 'staff', 'n' => trim($row['firstname'] . ' ' . $row['lastname']), 'c' => (string) get_option('companyname')]);
        }
    }

    $leadsMode = (string) mks_st_setting('directory_leads', 'all');

    if ($leadsMode !== 'none') {
        $CI->db->select('id, name, company, phonenumber, status, assigned')->where('phonenumber !=', '');

        if ($leadsMode === 'own') {
            $CI->db->where('assigned', (int) $staffId);
        }

        $leads = $CI->db->order_by('dateadded', 'desc')->limit(MKS_ST_DIRECTORY_MAX)->get($p . 'leads')->result_array();
        $last  = [];
        $next  = [];

        if ($leads) {
            // The latest call per lead, without window functions (MySQL 5.7
            // has none): the highest id is the most recently synced call.
            foreach ($CI->db->query('SELECT x.lead, e.occurred_at, e.outcome, e.outcome_note FROM (SELECT IF(rel_type = \'lead\', rel_id, lead_id) AS lead, MAX(id) AS last_id'
                . ' FROM ' . mks_st_events_table() . " WHERE kind IN ('call', 'whatsapp_call') AND (rel_type = 'lead' OR lead_id IS NOT NULL) GROUP BY lead) x"
                . ' JOIN ' . mks_st_events_table() . ' e ON e.id = x.last_id')->result_array() as $row) {
                $last[(int) $row['lead']] = $row;
            }

            foreach ($CI->db->query('SELECT IF(rel_type = \'lead\', rel_id, lead_id) AS lead, MIN(follow_up_at) AS next FROM ' . mks_st_events_table()
                . ' WHERE follow_up_at >= ' . $CI->db->escape(date('Y-m-d H:i:s')) . " AND (rel_type = 'lead' OR lead_id IS NOT NULL) GROUP BY lead")->result_array() as $row) {
                $next[(int) $row['lead']] = $row['next'];
            }
        }

        foreach ($leads as $row) {
            $call = isset($last[(int) $row['id']]) ? $last[(int) $row['id']] : null;

            $add($row['phonenumber'], [
                't'  => 'lead',
                'id' => (int) $row['id'],
                'n'  => $row['name'],
                'c'  => (string) $row['company'],
                's'  => isset($statuses[(int) $row['status']]) ? $statuses[(int) $row['status']]['name'] : '',
                'o'  => $staffName($row['assigned']),
                'l'  => $call ? mks_st_lst_iso($call['occurred_at']) : null,
                'lo' => $call && $call['outcome'] && isset($outcomes[$call['outcome']]) ? $outcomes[$call['outcome']]['label'] : '',
                'ln' => $call ? mb_substr((string) $call['outcome_note'], 0, 120, 'UTF-8') : '',
                'f'  => isset($next[(int) $row['id']]) ? mks_st_lst_iso($next[(int) $row['id']]) : null,
            ]);
        }
    }

    $customersMode = (string) mks_st_setting('directory_customers', 'visible');

    if ($customersMode === 'all' || ($customersMode === 'visible' && mks_st_customer_visible_for($staffId))) {
        foreach ($CI->db->query('SELECT c.userid, c.company, c.phonenumber AS company_phone, ct.firstname, ct.lastname, ct.phonenumber FROM ' . $p . 'clients c'
            . ' LEFT JOIN ' . $p . 'contacts ct ON ct.userid = c.userid AND ct.active = 1 WHERE c.active = 1 LIMIT ' . MKS_ST_DIRECTORY_MAX)->result_array() as $row) {
            if ((string) $row['phonenumber'] !== '') {
                $add($row['phonenumber'], ['t' => 'customer', 'id' => (int) $row['userid'], 'n' => trim($row['firstname'] . ' ' . $row['lastname']), 'c' => (string) $row['company']]);
            }

            if ((string) $row['company_phone'] !== '') {
                $add($row['company_phone'], ['t' => 'customer', 'id' => (int) $row['userid'], 'n' => (string) $row['company'], 'c' => (string) $row['company']]);
            }
        }
    }

    foreach (preg_split('/[\r\n]+/', (string) mks_st_setting('directory_extra', '')) as $line) {
        $parts = array_map('trim', explode(',', $line, 3));

        if (count($parts) >= 2) {
            $add($parts[0], ['t' => 'custom', 'n' => $parts[1], 'c' => isset($parts[2]) ? $parts[2] : '']);
        }
    }

    foreach ($out as $key => $entry) {
        if (isset(mks_st_dnc_keys()[$key])) {
            $out[$key]['dnc'] = true;
        }
    }

    return $out;
}

/**
 * Would customer details be shown to this person under Settings > General >
 * Who Sees Customer Names? For a phone owner rather than the signed in user.
 *
 * @param  int $staffId
 *
 * @return bool
 */
function mks_st_customer_visible_for($staffId)
{
    $CI    = &get_instance();
    $staff = $CI->db->select('admin')->where('staffid', (int) $staffId)->get(db_prefix() . 'staff')->row();

    if (!$staff) {
        return false;
    }

    $mode = (string) mks_st_setting('customer_visibility', 'managers');

    if ((int) $staff->admin === 1 || $mode === 'everyone') {
        return true;
    }

    $all = $CI->db->where('staff_id', (int) $staffId)->where('feature', 'mks_sales_track')->where('capability', 'view')->count_all_results(db_prefix() . 'staff_permissions') > 0;

    if ($mode === 'managers') {
        return $all;
    }

    $customers = $CI->db->where('staff_id', (int) $staffId)->where('feature', 'customers')->where('capability', 'view')->count_all_results(db_prefix() . 'staff_permissions') > 0;

    return $all || $customers;
}

/**
 * A cheap fingerprint of what a phone's directory would hold, so the phone
 * fetches it again only when something changed.
 *
 * @param  int $staffId
 *
 * @return string
 */
function mks_st_directory_version($staffId)
{
    $CI = &get_instance();
    $p  = db_prefix();

    $parts = [
        (int) $staffId,
        json_encode(array_intersect_key(mks_st_settings(), array_flip(['directory_leads', 'directory_customers', 'directory_staff', 'directory_extra', 'dnc_numbers', 'outcomes', 'match_customers', 'customer_visibility']))),
        json_encode($CI->db->query('SELECT COUNT(*) AS n, MAX(id) AS id, MAX(last_status_change) AS s, MAX(lastcontact) AS c FROM ' . $p . 'leads')->row_array()),
        json_encode($CI->db->query('SELECT COUNT(*) AS n, MAX(id) AS id FROM ' . $p . 'contacts')->row_array()),
        json_encode($CI->db->query('SELECT COUNT(*) AS n, MAX(staffid) AS id FROM ' . $p . 'staff WHERE active = 1')->row_array()),
        json_encode($CI->db->query('SELECT MAX(outcome_at) AS o, MAX(id) AS id FROM ' . mks_st_events_table())->row_array()),
    ];

    return substr(hash('sha256', implode('|', $parts)), 0, 16);
}

/* =========================================================================
 * WALLBOARD
 * ====================================================================== */

/**
 * Today's figures for the sales-floor screen: totals, the leaderboard and
 * the latest calls. No customer names: the board may hang where visitors
 * can read it.
 *
 * @param  int[]|null $ids
 *
 * @return array
 */
function mks_st_wallboard_data($ids)
{
    require_once __DIR__ . '/mks_sales_track_analytics_helper.php';

    $CI    = &get_instance();
    $today = date('Y-m-d');
    $t     = mks_st_connected_seconds();

    $totals = $CI->db->query("SELECT SUM(e.kind = 'call') AS calls, SUM(e.kind = 'call' AND e.duration >= " . $t . ') AS connected,'
        . " COALESCE(SUM(CASE WHEN e.kind = 'call' THEN e.duration ELSE 0 END), 0) AS talk, SUM(e.kind = 'call' AND e.direction IN ('missed', 'rejected')) AS missed"
        . ' FROM ' . mks_st_events_table() . ' e ' . mks_st_dash_where($today, $today, $ids))->row_array();

    $open = (int) $CI->db->query('SELECT COUNT(*) AS n FROM ' . mks_st_events_table() . " e WHERE e.callback_state IN ('open', 'escalated') "
        . mks_st_scope_sql('e.staff_id', $ids))->row()->n;

    $board = [];

    foreach ($CI->db->query("SELECT e.staff_id, SUM(e.kind = 'call') AS calls, SUM(e.kind = 'call' AND e.duration >= " . $t . ') AS connected,'
        . " COALESCE(SUM(CASE WHEN e.kind = 'call' THEN e.duration ELSE 0 END), 0) AS talk FROM " . mks_st_events_table() . ' e '
        . mks_st_dash_where($today, $today, $ids) . ' GROUP BY e.staff_id ORDER BY calls DESC, talk DESC LIMIT 12')->result_array() as $row) {
        $target  = mks_st_target_for((int) $row['staff_id'])['calls'];
        $board[] = [
            'name'      => mks_st_staff_name($row['staff_id']),
            'calls'     => (int) $row['calls'],
            'connected' => (int) $row['connected'],
            'talk'      => (int) $row['talk'],
            'target'    => $target > 0 ? min(100, (int) round($row['calls'] * 100 / $target)) : null,
        ];
    }

    $latest = $CI->db->query('SELECT e.staff_id, e.direction, e.duration, e.occurred_at FROM ' . mks_st_events_table() . " e WHERE e.kind = 'call' "
        . mks_st_scope_sql('e.staff_id', $ids) . " AND e.occurred_at >= '" . $today . " 00:00:00' ORDER BY e.occurred_at DESC LIMIT 6")->result_array();

    foreach ($latest as $index => $row) {
        $latest[$index]['name'] = mks_st_staff_name($row['staff_id']);
    }

    return [
        'calls'     => (int) $totals['calls'],
        'connected' => (int) $totals['connected'],
        'talk'      => (int) $totals['talk'],
        'missed'    => (int) $totals['missed'],
        'open'      => $open,
        'board'     => $board,
        'latest'    => $latest,
    ];
}
