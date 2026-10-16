<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - view helper.
 *
 * The five activity lists share one table definition per view. Columns,
 * search and the KPI tiles are all derived from mks_st_view_columns(), so the
 * figures above a table always describe exactly the rows in it: same filters,
 * same search, same scope.
 */

/* =========================================================================
 * TABLE DEFINITION
 * ====================================================================== */

/**
 * FROM and JOIN shared by the list query, the detail query and the summary.
 *
 * @return array table, joins
 */
function mks_st_events_from()
{
    $p = db_prefix();

    return [
        'table' => $p . 'mks_sales_track_events e',
        'joins' => [
            'LEFT JOIN ' . $p . "leads l ON l.id = e.rel_id AND e.rel_type = 'lead'",
            'LEFT JOIN ' . $p . "clients cl ON cl.userid = e.rel_id AND e.rel_type = 'customer'",
            'LEFT JOIN ' . $p . "contacts ct ON ct.id = e.contact_id AND e.rel_type = 'customer'",
            'LEFT JOIN ' . $p . "staff rs ON rs.staffid = e.rel_id AND e.rel_type = 'staff'",
            'LEFT JOIN ' . $p . 'staff s ON s.staffid = e.staff_id',
            'LEFT JOIN ' . $p . 'mks_sales_track_devices d ON d.id = e.device_id',
        ],
    ];
}

/**
 * Columns for one list view. select is what the list sorts on, search what the
 * search box looks through.
 *
 * @param  string $view
 *
 * @return array
 */
function mks_st_view_columns($view)
{
    $contact = [
        'key'        => 'contact',
        'label'      => _l('mks_st_col_contact'),
        'select'     => "COALESCE(l.name, cl.company, CONCAT(rs.firstname, ' ', rs.lastname), NULLIF(e.contact_name, ''), e.number, e.number_raw)",
        'search'     => "CONCAT_WS(' ', e.number, e.number_raw, e.contact_name, l.name, l.company, cl.company, ct.firstname, ct.lastname, rs.firstname, rs.lastname)",
        'sortable'   => true,
        'searchable' => true,
    ];

    $direction = ['key' => 'direction', 'label' => _l('mks_st_col_direction'), 'select' => 'e.direction', 'sortable' => true, 'searchable' => false];
    $staff     = ['key' => 'staff', 'label' => _l('mks_st_col_staff'), 'select' => "CONCAT(s.firstname, ' ', s.lastname)", 'sortable' => true, 'searchable' => true];
    $time      = ['key' => 'time', 'label' => _l('mks_st_col_time'), 'select' => 'e.occurred_at', 'sortable' => true, 'searchable' => false, 'order' => true];
    $duration  = ['key' => 'duration', 'label' => _l('mks_st_col_duration'), 'select' => 'e.duration', 'sortable' => true, 'searchable' => false];
    $phone     = ['key' => 'phone', 'label' => _l('mks_st_col_phone'), 'select' => "COALESCE(NULLIF(d.label, ''), d.model)", 'sortable' => true, 'searchable' => false];
    $recording = ['key' => 'recording', 'label' => _l('mks_st_col_recording'), 'select' => 'e.recording_status', 'sortable' => true, 'searchable' => false];
    $size      = ['key' => 'size', 'label' => _l('mks_st_col_size'), 'select' => 'e.recording_size', 'sortable' => true, 'searchable' => false];
    $media     = ['key' => 'media', 'label' => _l('mks_st_col_type'), 'select' => 'e.media', 'sortable' => true, 'searchable' => false];
    $message   = ['key' => 'message', 'label' => _l('mks_st_col_message'), 'select' => 'e.body', 'sortable' => false, 'searchable' => true];
    $sim       = ['key' => 'sim', 'label' => _l('mks_st_col_sim'), 'select' => 'e.sim_slot', 'sortable' => true, 'searchable' => false];
    $ai        = ['key' => 'ai', 'label' => _l('mks_st_col_ai'), 'select' => 'e.ai_score', 'sortable' => true, 'searchable' => false];
    $outcome   = ['key' => 'outcome', 'label' => _l('mks_st_col_outcome'), 'select' => 'e.outcome', 'search' => "CONCAT_WS(' ', e.outcome, e.outcome_note)", 'sortable' => true, 'searchable' => true];
    $options   = ['key' => 'options', 'label' => _l('options'), 'select' => 'e.id', 'sortable' => false, 'searchable' => false];

    switch ($view) {
        case 'recordings':
            return mks_st_enabled('ai_enabled') ? [$direction, $contact, $staff, $time, $duration, $size, $recording, $ai, $options]
                : [$direction, $contact, $staff, $time, $duration, $size, $recording, $options];

        case 'whatsapp_calls':
            return [$direction, $contact, $staff, $time, $duration, $media, $outcome, $options];

        case 'sms':
            return [$direction, $contact, $message, $staff, $time, $sim, $options];

        default:
            return mks_st_enabled('ai_enabled') ? [$direction, $contact, $staff, $time, $duration, $phone, $recording, $outcome, $ai, $options]
                : [$direction, $contact, $staff, $time, $duration, $phone, $recording, $outcome, $options];
    }
}

/**
 * What the page script needs to initialise the table.
 *
 * @param  string $view
 *
 * @return array not_searchable, not_sortable, order
 */
function mks_st_view_table_config($view)
{
    $notSearchable = [];
    $notSortable   = [];
    $order         = [0, 'desc'];

    foreach (mks_st_view_columns($view) as $index => $column) {
        if (empty($column['searchable'])) {
            $notSearchable[] = $index;
        }

        if (empty($column['sortable'])) {
            $notSortable[] = $index;
        }

        if (!empty($column['order'])) {
            // A flat [index, direction] pair: initDataTable wraps a single
            // nested pair a second time and DataTables then silently ignores it.
            $order = [$index, 'desc'];
        }
    }

    return [
        'not_searchable' => $notSearchable,
        'not_sortable'   => $notSortable,
        'order'          => $order,
    ];
}

/**
 * Direction filter choices for one view.
 *
 * @param  string $view
 *
 * @return array value => label
 */
function mks_st_direction_filters($view)
{
    switch ($view) {
        case 'recordings':
            return [
                'incoming' => _l('mks_st_dir_incoming'),
                'outgoing' => _l('mks_st_dir_outgoing'),
            ];

        case 'whatsapp_calls':
            return [
                'incoming' => _l('mks_st_dir_incoming'),
                'outgoing' => _l('mks_st_dir_outgoing'),
                'missed'   => _l('mks_st_dir_missed'),
                'voice'    => _l('mks_st_media_voice'),
                'video'    => _l('mks_st_media_video'),
            ];

        case 'sms':
            return [
                'incoming' => _l('mks_st_dir_received'),
                'outgoing' => _l('mks_st_dir_sent'),
            ];

        default:
            return [
                'incoming'   => _l('mks_st_dir_incoming'),
                'outgoing'   => _l('mks_st_dir_outgoing'),
                'connected'      => _l('mks_st_dir_connected'),
                'unanswered'     => _l('mks_st_dir_unanswered'),
                'missed'         => _l('mks_st_dir_missed'),
                'never_attended' => _l('mks_st_never_attended'),
                'never_received' => _l('mks_st_never_received'),
                'rejected'   => _l('mks_st_dir_rejected'),
            ];
    }
}

/**
 * Date range presets, in the order the filter bar shows them.
 *
 * @return array value => label
 */
function mks_st_range_options()
{
    return [
        'today'     => _l('mks_st_range_today'),
        'yesterday' => _l('mks_st_range_yesterday'),
        '7d'        => _l('mks_st_range_7d'),
        '30d'       => _l('mks_st_range_30d'),
        'month'     => _l('mks_st_range_month'),
        'all'       => _l('mks_st_range_all'),
        'custom'    => _l('mks_st_range_custom'),
    ];
}

/**
 * The first and last moment of a range, in the CRM's own timezone.
 *
 * @param  string $range
 * @param  string $from  Y-m-d, custom only
 * @param  string $to    Y-m-d, custom only
 *
 * @return array [from|null, to|null]
 */
function mks_st_range_bounds($range, $from = '', $to = '')
{
    $today = date('Y-m-d');

    switch ($range) {
        case 'today':
            return [$today . ' 00:00:00', $today . ' 23:59:59'];

        case 'yesterday':
            $day = date('Y-m-d', strtotime('-1 day'));

            return [$day . ' 00:00:00', $day . ' 23:59:59'];

        case '30d':
            return [date('Y-m-d', strtotime('-29 days')) . ' 00:00:00', $today . ' 23:59:59'];

        case 'month':
            return [date('Y-m-01') . ' 00:00:00', $today . ' 23:59:59'];

        case 'all':
            return [null, null];

        case 'custom':
            $from = mks_st_valid_date($from);
            $to   = mks_st_valid_date($to);

            if ($from && $to && $from > $to) {
                list($from, $to) = [$to, $from];
            }

            return [
                $from ? $from . ' 00:00:00' : null,
                $to ? $to . ' 23:59:59' : null,
            ];

        default:
            return [date('Y-m-d', strtotime('-6 days')) . ' 00:00:00', $today . ' 23:59:59'];
    }
}

/**
 * @param  mixed $value
 *
 * @return string|false Y-m-d
 */
function mks_st_valid_date($value)
{
    if (!is_string($value) || !preg_match('/^(\d{4})-(\d{2})-(\d{2})$/', $value, $m)) {
        return false;
    }

    return checkdate((int) $m[2], (int) $m[3], (int) $m[1]) ? $value : false;
}

/**
 * The WHERE clauses for one view and its filters, each starting with AND as
 * data_tables_init() expects. Scope is applied here, in SQL, for every list,
 * count and tile.
 *
 * @param  string $view
 * @param  array  $filters range, from, to, staff, direction, match, device, outcome
 * @param  bool   $pending recordings view only: count pending uploads instead
 *
 * @return array
 */
function mks_st_view_where($view, array $filters, $pending = false)
{
    $CI    = &get_instance();
    $pages = mks_st_pages();
    $kind  = isset($pages[$view]) ? $pages[$view]['kind'] : 'call';
    if ($view === 'sms') {
        $where = ["AND e.kind IN ('sms', 'whatsapp_message', 'notification')"];
    } else {
        $where = ["AND e.kind = '" . $kind . "'"];
    }

    if ($view === 'recordings') {
        $where[] = $pending ? "AND e.recording_status = 'pending'" : "AND e.recording_status = 'stored'";
    }

    $scopeSql = mks_st_scope_sql('e.staff_id');

    if ($scopeSql !== '') {
        $where[] = $scopeSql;
    }

    list($from, $to) = mks_st_range_bounds(
        isset($filters['range']) ? (string) $filters['range'] : '',
        isset($filters['from']) ? (string) $filters['from'] : '',
        isset($filters['to']) ? (string) $filters['to'] : ''
    );

    if ($from !== null) {
        $where[] = "AND e.occurred_at >= '" . $from . "'";
    }

    if ($to !== null) {
        $where[] = "AND e.occurred_at <= '" . $to . "'";
    }

    $staff = isset($filters['staff']) ? (int) $filters['staff'] : 0;

    if ($staff > 0 && mks_st_scope_allows($staff)) {
        $where[] = 'AND e.staff_id = ' . $staff;
    }

    $device = isset($filters['device']) ? (int) $filters['device'] : 0;

    if ($device > 0) {
        $where[] = 'AND e.device_id = ' . $device;
    }

    $direction = isset($filters['direction']) ? (string) $filters['direction'] : '';

    if ($direction !== '' && array_key_exists($direction, mks_st_direction_filters($view))) {
        if ($direction === 'connected') {
            $where[] = 'AND e.duration >= ' . mks_st_connected_seconds();
        } elseif ($direction === 'unanswered') {
            $where[] = "AND e.direction = 'outgoing' AND e.duration < " . mks_st_connected_seconds();
        } elseif ($direction === 'never_attended') {
            $where[] = "AND e.callback_state IN ('open', 'escalated')";
        } elseif ($direction === 'never_received') {
            $where[] = "AND e.direction = 'outgoing' AND e.duration < " . mks_st_connected_seconds() . ' AND e.number_key IS NOT NULL'
                . ' AND NOT EXISTS (SELECT 1 FROM ' . mks_st_events_table() . " x WHERE x.number_key = e.number_key AND x.kind IN ('call', 'whatsapp_call')"
                . ' AND x.duration >= ' . mks_st_connected_seconds() . ')';
        } elseif ($direction === 'voice' || $direction === 'video') {
            $where[] = "AND e.media = '" . $direction . "'";
        } else {
            $where[] = "AND e.direction = '" . $direction . "'";
        }
    }

    $outcome = isset($filters['outcome']) ? (string) $filters['outcome'] : '';

    if ($outcome === 'none') {
        $where[] = 'AND e.outcome IS NULL';
    } elseif ($outcome !== '' && function_exists('mks_st_outcomes') && isset(mks_st_outcomes(false)[$outcome])) {
        $where[] = 'AND e.outcome = ' . get_instance()->db->escape($outcome);
    }

    $match = isset($filters['match']) ? (string) $filters['match'] : '';

    if (in_array($match, ['lead', 'customer', 'staff'], true)) {
        $where[] = "AND e.rel_type = '" . $match . "'";
    } elseif ($match === 'unknown') {
        $where[] = 'AND e.rel_type IS NULL';
    }

    return $where;
}

/**
 * The search clause data_tables_init() builds for the search box, rebuilt from
 * the same column definitions so the tiles can apply it too.
 *
 * @param  string $view
 * @param  string $value
 *
 * @return string
 */
function mks_st_view_search($view, $value)
{
    $value = trim((string) $value);

    if ($value === '') {
        return '';
    }

    $CI    = &get_instance();
    $like  = $CI->db->escape_like_str($value);
    $parts = [];

    foreach (mks_st_view_columns($view) as $column) {
        if (empty($column['searchable'])) {
            continue;
        }

        $expr    = isset($column['search']) ? $column['search'] : $column['select'];
        $parts[] = 'convert(' . $expr . " USING utf8) LIKE '%" . $like . "%' ESCAPE '!'";
    }

    return $parts ? 'AND (' . implode(' OR ', $parts) . ')' : '';
}

/**
 * Filters as posted by the list page.
 *
 * @return array
 */
function mks_st_posted_filters()
{
    $CI  = &get_instance();
    $out = [];

    foreach (['range', 'from', 'to', 'staff', 'direction', 'match', 'device', 'outcome'] as $key) {
        $value     = $CI->input->post('mks_st_' . $key);
        $out[$key] = is_string($value) ? trim($value) : '';
    }

    return $out;
}

/* =========================================================================
 * SUMMARY TILES
 * ====================================================================== */

/**
 * KPI tiles for one view, over exactly the population the table shows.
 *
 * @param  string $view
 * @param  array  $filters
 * @param  string $search
 *
 * @return array tiles: key, label, value, hint, icon, tone
 */
function mks_st_view_summary($view, array $filters, $search)
{
    $CI    = &get_instance();
    $from  = mks_st_events_from();
    $base  = 'FROM ' . $from['table'] . ' ' . implode(' ', $from['joins']) . ' WHERE 1 = 1 ';
    $where = implode(' ', mks_st_view_where($view, $filters)) . ' ' . mks_st_view_search($view, $search);

    switch ($view) {
        case 'recordings':
            $row = $CI->db->query('SELECT COUNT(*) AS total, COALESCE(SUM(e.duration), 0) AS talk,'
                . ' COALESCE(SUM(e.recording_size), 0) AS bytes, COUNT(DISTINCT e.staff_id) AS people ' . $base . $where)->row_array();

            $pending = $CI->db->query('SELECT COUNT(*) AS total ' . $base
                . implode(' ', mks_st_view_where($view, $filters, true)))->row_array();

            return [
                mks_st_tile('recordings', _l('mks_st_kpi_recordings'), mks_st_number_label($row['total']), '', 'fa-solid fa-microphone', 'blue'),
                mks_st_tile('talk', _l('mks_st_kpi_recorded_time'), mks_st_duration_label($row['talk']), '', 'fa-solid fa-clock', 'violet'),
                mks_st_tile('bytes', _l('mks_st_kpi_storage'), mks_st_bytes_label($row['bytes']), '', 'fa-solid fa-hard-drive', 'slate'),
                mks_st_tile('pending', _l('mks_st_kpi_pending'), mks_st_number_label($pending['total']), _l('mks_st_kpi_pending_hint'), 'fa-solid fa-cloud-arrow-up', (int) $pending['total'] > 0 ? 'amber' : 'green'),
            ];

        case 'whatsapp_calls':
            $row = $CI->db->query('SELECT COUNT(*) AS total,'
                . " SUM(e.media = 'voice') AS voice, SUM(e.media = 'video') AS video,"
                . " SUM(e.direction IN ('missed', 'rejected')) AS missed, SUM(e.duration >= " . mks_st_connected_seconds() . ') AS connected,'
                . ' COALESCE(SUM(e.duration), 0) AS talk ' . $base . $where)->row_array();

            return [
                mks_st_tile('total', _l('mks_st_kpi_whatsapp_calls'), mks_st_number_label($row['total']), '', 'fa-brands fa-whatsapp', 'green'),
                mks_st_tile('voice', _l('mks_st_media_voice'), mks_st_number_label($row['voice']), '', 'fa-solid fa-phone', 'blue'),
                mks_st_tile('video', _l('mks_st_media_video'), mks_st_number_label($row['video']), '', 'fa-solid fa-video', 'violet'),
                mks_st_tile('missed', _l('mks_st_kpi_missed'), mks_st_number_label($row['missed']), '', 'fa-solid fa-phone-slash', (int) $row['missed'] > 0 ? 'red' : 'slate'),
                mks_st_tile('talk', _l('mks_st_kpi_talk_time'), mks_st_duration_label($row['talk']), mks_st_average_hint($row['talk'], $row['connected']), 'fa-solid fa-clock', 'amber'),
            ];

        case 'sms':
            $row = $CI->db->query('SELECT COUNT(*) AS total,'
                . " SUM(e.direction = 'incoming') AS received, SUM(e.direction = 'outgoing') AS sent,"
                . ' COUNT(DISTINCT e.number_key) AS numbers, SUM(e.rel_type IS NOT NULL) AS matched ' . $base . $where)->row_array();

            return [
                mks_st_tile('total', _l('mks_st_kpi_messages'), mks_st_number_label($row['total']), '', 'fa-solid fa-message', 'blue'),
                mks_st_tile('received', _l('mks_st_dir_received'), mks_st_number_label($row['received']), '', 'fa-solid fa-arrow-down', 'green'),
                mks_st_tile('sent', _l('mks_st_dir_sent'), mks_st_number_label($row['sent']), '', 'fa-solid fa-arrow-up', 'violet'),
                mks_st_tile('numbers', _l('mks_st_kpi_numbers'), mks_st_number_label($row['numbers']), '', 'fa-solid fa-hashtag', 'slate'),
                mks_st_tile('matched', _l('mks_st_kpi_in_crm'), mks_st_number_label($row['matched']), mks_st_share_hint($row['matched'], $row['total']), 'fa-solid fa-address-book', 'amber'),
            ];

        default:
            $row = $CI->db->query('SELECT COUNT(*) AS total,'
                . " SUM(e.direction = 'incoming') AS incoming, SUM(e.direction = 'outgoing') AS outgoing,"
                . " SUM(e.direction IN ('missed', 'rejected')) AS missed, SUM(e.duration >= " . mks_st_connected_seconds() . ') AS connected,'
                . ' COALESCE(SUM(e.duration), 0) AS talk, COUNT(DISTINCT e.number_key) AS numbers ' . $base . $where)->row_array();

            return [
                mks_st_tile('total', _l('mks_st_kpi_calls'), mks_st_number_label($row['total']), mks_st_split_hint($row['incoming'], $row['outgoing']), 'fa-solid fa-phone', 'blue'),
                mks_st_tile('connected', _l('mks_st_kpi_connected'), mks_st_number_label($row['connected']), mks_st_share_hint($row['connected'], $row['total']), 'fa-solid fa-circle-check', 'green'),
                mks_st_tile('missed', _l('mks_st_kpi_missed'), mks_st_number_label($row['missed']), '', 'fa-solid fa-phone-slash', (int) $row['missed'] > 0 ? 'red' : 'slate'),
                mks_st_tile('talk', _l('mks_st_kpi_talk_time'), mks_st_duration_label($row['talk']), mks_st_average_hint($row['talk'], $row['connected']), 'fa-solid fa-clock', 'violet'),
                mks_st_tile('numbers', _l('mks_st_kpi_numbers'), mks_st_number_label($row['numbers']), '', 'fa-solid fa-hashtag', 'amber'),
            ];
    }
}

/**
 * @return array
 */
function mks_st_tile($key, $label, $value, $hint, $icon, $tone)
{
    return [
        'key'   => $key,
        'label' => $label,
        'value' => $value,
        'hint'  => $hint,
        'icon'  => $icon,
        'tone'  => $tone,
    ];
}

/**
 * @return string
 */
function mks_st_share_hint($part, $total)
{
    $total = (int) $total;

    return $total > 0 ? _l('mks_st_kpi_share', (string) round((int) $part * 100 / $total)) : '';
}

/**
 * @return string
 */
function mks_st_average_hint($seconds, $count)
{
    $count = (int) $count;

    return $count > 0 ? _l('mks_st_kpi_average', mks_st_duration_label((int) round((int) $seconds / $count))) : '';
}

/**
 * @return string
 */
function mks_st_split_hint($incoming, $outgoing)
{
    return _l('mks_st_kpi_split', [mks_st_number_label($incoming), mks_st_number_label($outgoing)]);
}

/* =========================================================================
 * ROWS
 * ====================================================================== */

/**
 * Full rows for one page of results, fetched by id. The list query only
 * selects what it sorts on; the cells need far more than that, and asking for
 * it through data_tables_init() would add every extra field to the search.
 *
 * @param  array $ids
 *
 * @return array id => row
 */
function mks_st_events_detail(array $ids)
{
    $ids = array_values(array_filter(array_map('intval', $ids)));

    if (!$ids) {
        return [];
    }

    $CI   = &get_instance();
    $from = mks_st_events_from();
    $sql  = 'SELECT e.*, l.name AS lead_name, l.lost AS lead_lost, l.junk AS lead_junk, l.date_converted AS lead_converted,'
        . ' ls.name AS lead_status, ls.color AS lead_status_color, cl.company AS client_company, cl.active AS client_active,'
        . ' ct.firstname AS contact_first, ct.lastname AS contact_last,'
        . ' rs.firstname AS rel_staff_first, rs.lastname AS rel_staff_last,'
        . ' s.firstname AS staff_first, s.lastname AS staff_last,'
        . ' d.label AS device_label, d.model AS device_model, d.platform AS device_platform,'
        . ' l2.name AS lead2_name, l2.date_converted AS lead2_converted, l2.lost AS lead2_lost, l2.junk AS lead2_junk,'
        . ' ls2.name AS lead2_status, ls2.color AS lead2_status_color'
        . ' FROM ' . $from['table'] . ' ' . implode(' ', $from['joins'])
        . ' LEFT JOIN ' . db_prefix() . 'leads_status ls ON ls.id = l.status'
        . " LEFT JOIN " . db_prefix() . "leads l2 ON l2.id = e.lead_id AND e.rel_type = 'customer'"
        . ' LEFT JOIN ' . db_prefix() . 'leads_status ls2 ON ls2.id = l2.status'
        . ' WHERE e.id IN (' . implode(',', $ids) . ')';

    $out = [];

    foreach ($CI->db->query($sql)->result_array() as $row) {
        $out[(int) $row['id']] = $row;
    }

    return $out;
}

/**
 * Turn data_tables_init() results into DataTables rows.
 *
 * @param  array  $results rResult
 * @param  string $view
 *
 * @return array
 */
function mks_st_view_rows(array $results, $view)
{
    $columns = mks_st_view_columns($view);
    $idAlias = 'mks_c' . (count($columns) - 1);
    $ids     = [];

    foreach ($results as $result) {
        $ids[] = (int) $result[$idAlias];
    }

    $details = mks_st_events_detail($ids);
    $context = [
        'play'    => mks_st_can('play_recordings'),
        'delete'  => mks_st_can('delete'),
        'view'    => $view,
        'outcome' => in_array($view, ['calls', 'whatsapp_calls'], true),
        'pitch'   => in_array($view, ['calls', 'recordings'], true),
    ];

    $rows = [];

    foreach ($ids as $id) {
        if (!isset($details[$id])) {
            continue;
        }

        $event = $details[$id];
        $row   = [];

        foreach ($columns as $column) {
            $row[] = mks_st_render_cell($column['key'], $event, $context);
        }

        $row['DT_RowId']    = 'mks-sales-track-event-' . $id;
        $row['DT_RowClass'] = 'mks-sales-track-row';
        $rows[]             = $row;
    }

    return $rows;
}

/**
 * @param  string $key
 * @param  array  $event
 * @param  array  $context
 *
 * @return string
 */
function mks_st_render_cell($key, array $event, array $context)
{
    switch ($key) {
        case 'direction':
            return mks_st_render_direction($event);

        case 'contact':
            return mks_st_render_contact($event);

        case 'outcome':
            return mks_st_render_outcome($event, $context);

        case 'ai':
            return mks_st_render_ai($event);

        case 'staff':
            return mks_st_render_staff($event);

        case 'time':
            return mks_st_render_time($event['occurred_at']);

        case 'duration':
            return (int) $event['duration'] > 0
                ? '<span class="mks-sales-track-duration">' . e(mks_st_duration_label($event['duration'])) . '</span>'
                : '<span class="mks-sales-track-muted">-</span>';

        case 'phone':
            return mks_st_render_phone($event);

        case 'recording':
            return mks_st_render_recording($event, $context);

        case 'size':
            return !empty($event['recording_size'])
                ? '<span class="mks-sales-track-muted">' . e(mks_st_bytes_label($event['recording_size'])) . '</span>'
                : '<span class="mks-sales-track-muted">-</span>';

        case 'media':
            return mks_st_render_media($event);

        case 'message':
            return mks_st_render_message($event);

        case 'sim':
            return !empty($event['sim_slot'])
                ? '<span class="mks-sales-track-chip"><i class="fa-solid fa-sim-card"></i>' . e(_l('mks_st_sim_n', (string) (int) $event['sim_slot'])) . '</span>'
                : '<span class="mks-sales-track-muted">-</span>';

        case 'options':
            return mks_st_render_options($event, $context);
    }

    return '';
}

/* =========================================================================
 * CELLS
 * ====================================================================== */

/**
 * Icon and tone for a direction.
 *
 * @param  array $event
 *
 * @return array label, icon, tone
 */
function mks_st_direction_meta(array $event)
{
    $direction = (string) $event['direction'];
    $kind      = (string) $event['kind'];

    if (in_array($kind, ['sms', 'whatsapp_message', 'notification'], true)) {
        return $direction === 'outgoing'
            ? ['label' => _l('mks_st_dir_sent'), 'icon' => 'fa-arrow-up', 'tone' => 'violet']
            : ['label' => _l('mks_st_dir_received'), 'icon' => 'fa-arrow-down', 'tone' => 'green'];
    }

    switch ($direction) {
        case 'incoming':
            return ['label' => _l('mks_st_dir_incoming'), 'icon' => 'fa-arrow-down', 'tone' => 'green'];

        case 'outgoing':
            if ((int) $event['duration'] < mks_st_connected_seconds()) {
                return ['label' => _l('mks_st_dir_unanswered'), 'icon' => 'fa-arrow-up', 'tone' => 'amber'];
            }

            return ['label' => _l('mks_st_dir_outgoing'), 'icon' => 'fa-arrow-up', 'tone' => 'blue'];

        case 'missed':
            return ['label' => _l('mks_st_dir_missed'), 'icon' => 'fa-phone-slash', 'tone' => 'red'];

        case 'rejected':
            return ['label' => _l('mks_st_dir_rejected'), 'icon' => 'fa-ban', 'tone' => 'red'];

        case 'blocked':
            return ['label' => _l('mks_st_dir_blocked'), 'icon' => 'fa-shield-halved', 'tone' => 'slate'];

        case 'voicemail':
            return ['label' => _l('mks_st_dir_voicemail'), 'icon' => 'fa-voicemail', 'tone' => 'violet'];
    }

    return ['label' => _l('mks_st_dir_unknown'), 'icon' => 'fa-circle-question', 'tone' => 'slate'];
}

/**
 * @param  array $event
 *
 * @return string
 */
function mks_st_render_direction(array $event)
{
    $meta = mks_st_direction_meta($event);

    return '<span class="mks-sales-track-dir mks-sales-track-tone-' . $meta['tone'] . '">'
        . '<i class="fa-solid ' . $meta['icon'] . '" aria-hidden="true"></i>'
        . '<span>' . e($meta['label']) . '</span></span>';
}

/**
 * Who was on the other end: the CRM record when the number is known, the name
 * the phone had saved when it is not, and the number underneath either way.
 *
 * @param  array $event
 *
 * @return string
 */
function mks_st_render_contact(array $event)
{
    $number  = mks_st_format_number($event['number'] !== null ? $event['number'] : $event['number_raw']);
    $relType = (string) $event['rel_type'];
    $html    = '<div class="mks-sales-track-contact">';
    $known   = false;

    if ($relType === 'lead' && $event['lead_name'] !== null) {
        $known = true;
        $html .= '<span class="mks-sales-track-contact-line">'
            . '<a href="#" class="mks-sales-track-contact-name" onclick="init_lead(' . (int) $event['rel_id'] . '); return false;">' . e($event['lead_name']) . '</a>'
            . '<span class="mks-sales-track-pill mks-sales-track-tone-blue">' . e(_l('mks_st_rel_lead')) . '</span>'
            . mks_st_lead_status_pills($event) . '</span>';
    } elseif ($relType === 'customer' && $event['client_company'] !== null && !mks_st_customer_visible()) {
        // Hidden from this viewer: show the lead behind the number, or only
        // that the number is known, never the customer.
        $known = true;
        $html .= '<span class="mks-sales-track-contact-line">';

        if (!empty($event['lead2_name'])) {
            $html .= '<a href="#" class="mks-sales-track-contact-name" onclick="init_lead(' . (int) $event['lead_id'] . '); return false;">' . e($event['lead2_name']) . '</a>'
                . '<span class="mks-sales-track-pill mks-sales-track-tone-blue">' . e(_l('mks_st_rel_lead')) . '</span>'
                . mks_st_lead_status_pills(mks_st_lead2_fields($event));
        } else {
            $html .= '<span class="mks-sales-track-contact-name">' . e($number) . '</span>'
                . '<span class="mks-sales-track-pill mks-sales-track-tone-slate">' . e(_l('mks_st_in_crm')) . '</span>';
            $number = '';
        }

        $html .= '</span>';
    } elseif ($relType === 'customer' && $event['client_company'] !== null) {
        $known  = true;
        $person = trim((string) $event['contact_first'] . ' ' . (string) $event['contact_last']);
        $html  .= '<span class="mks-sales-track-contact-line">'
            . '<a href="' . admin_url('clients/client/' . (int) $event['rel_id']) . '" class="mks-sales-track-contact-name">' . e($event['client_company']) . '</a>'
            . '<span class="mks-sales-track-pill mks-sales-track-tone-green">' . e(_l('mks_st_rel_customer')) . '</span>'
            . ((string) $event['client_active'] === '0' ? '<span class="mks-sales-track-pill mks-sales-track-tone-slate">' . e(_l('mks_st_inactive')) . '</span>' : '')
            . '</span>';

        if ($person !== '') {
            $html .= '<span class="mks-sales-track-contact-person">' . e($person) . '</span>';
        }

        if (!empty($event['lead2_name'])) {
            $html .= '<span class="mks-sales-track-contact-lead">' . e(_l('mks_st_also_lead')) . ' '
                . '<a href="#" onclick="init_lead(' . (int) $event['lead_id'] . '); return false;">' . e($event['lead2_name']) . '</a>'
                . mks_st_lead_status_pills(mks_st_lead2_fields($event)) . '</span>';
        }
    } elseif ($relType === 'staff' && $event['rel_staff_first'] !== null) {
        $known = true;
        $html .= '<span class="mks-sales-track-contact-line">'
            . '<span class="mks-sales-track-contact-name">' . e(trim($event['rel_staff_first'] . ' ' . $event['rel_staff_last'])) . '</span>'
            . '<span class="mks-sales-track-pill mks-sales-track-tone-slate">' . e(_l('mks_st_rel_staff')) . '</span></span>';
    } else {
        $name  = $event['contact_name'] !== null && $event['contact_name'] !== '' ? $event['contact_name'] : '';
        $html .= '<span class="mks-sales-track-contact-line">'
            . '<span class="mks-sales-track-contact-name' . ($name === '' ? ' mks-sales-track-muted' : '') . '">'
            . e($name !== '' ? $name : ($number !== '' ? $number : _l('mks_st_unknown_caller'))) . '</span></span>';
    }

    if ($number !== '' && ($known || ($event['contact_name'] !== null && $event['contact_name'] !== ''))) {
        $html .= '<span class="mks-sales-track-contact-number">' . e($number) . '</span>';
    }

    if (!$known && $event['number'] !== null) {
        $html .= '<button type="button" class="mks-sales-track-link-btn mks-sales-track-create-lead"'
            . ' data-number="' . e($event['number']) . '"'
            . ' data-name="' . e((string) $event['contact_name']) . '">'
            . '<i class="fa-solid fa-user-plus" aria-hidden="true"></i>' . e(_l('mks_st_create_lead')) . '</button>';
    }

    if (in_array($event['kind'], ['whatsapp_call', 'whatsapp_message'], true)) {
        if ($event['app_package'] === 'com.whatsapp.w4b') {
            $html .= '<span class="mks-sales-track-pill mks-sales-track-tone-green mks-sales-track-pill-soft">' . e(_l('mks_st_whatsapp_business')) . '</span>';
        } else {
            $html .= '<span class="mks-sales-track-pill mks-sales-track-tone-green mks-sales-track-pill-soft"><i class="fa-brands fa-whatsapp" aria-hidden="true"></i> WhatsApp</span>';
        }
    } elseif ($event['kind'] === 'notification') {
        $html .= '<span class="mks-sales-track-pill mks-sales-track-tone-blue mks-sales-track-pill-soft"><i class="fa-solid fa-bell" aria-hidden="true"></i> Notification</span>';
    }

    return $html . '</div>';
}

/**
 * @param  array $event
 *
 * @return string
 */
function mks_st_render_staff(array $event)
{
    $name = trim((string) $event['staff_first'] . ' ' . (string) $event['staff_last']);

    return '<div class="mks-sales-track-person">'
        . staff_profile_image($event['staff_id'], ['mks-sales-track-avatar'], 'small', ['alt' => $name])
        . '<span class="mks-sales-track-person-name">' . e($name !== '' ? $name : _l('mks_st_removed_staff')) . '</span>'
        . '</div>';
}

/**
 * Today and Yesterday read faster in a list than a date does.
 *
 * @param  string $datetime
 *
 * @return string
 */
function mks_st_render_time($datetime)
{
    $stamp = strtotime((string) $datetime);

    if ($stamp === false) {
        return '';
    }

    $day = date('Y-m-d', $stamp);

    if ($day === date('Y-m-d')) {
        $label = _l('mks_st_today');
    } elseif ($day === date('Y-m-d', strtotime('-1 day'))) {
        $label = _l('mks_st_yesterday');
    } else {
        $label = _d($day);
    }

    $clock = date(get_option('time_format') == 24 ? 'H:i' : 'g:i A', $stamp);

    return '<span class="mks-sales-track-time" title="' . e(_dt($datetime)) . '">'
        . '<span>' . e($label) . '</span><small>' . e($clock) . '</small></span>';
}

/**
 * @param  array $event
 *
 * @return string
 */
function mks_st_render_phone(array $event)
{
    $label = $event['device_label'] !== null && $event['device_label'] !== '' ? $event['device_label'] : (string) $event['device_model'];

    if ($label === '') {
        $label = _l('mks_st_removed_device');
    }

    $icon = $event['device_platform'] === 'ios' ? 'fa-brands fa-apple' : 'fa-solid fa-mobile-screen-button';
    $html = '<span class="mks-sales-track-phone"><i class="' . $icon . '" aria-hidden="true"></i><span>' . e($label) . '</span>';

    if (!empty($event['sim_slot'])) {
        $html .= '<small>' . e(_l('mks_st_sim_n', (string) (int) $event['sim_slot'])) . '</small>';
    }

    return $html . '</span>';
}

/**
 * @param  array $event
 * @param  array $context
 *
 * @return string
 */
function mks_st_render_recording(array $event, array $context)
{
    if ($event['recording_status'] === 'pending') {
        return '<span class="mks-sales-track-pill mks-sales-track-tone-amber"><i class="fa-solid fa-cloud-arrow-up" aria-hidden="true"></i>'
            . e(_l('mks_st_recording_pending')) . '</span>';
    }

    if ($event['recording_status'] === 'expired') {
        return '<span class="mks-sales-track-pill mks-sales-track-tone-slate" title="' . e(_l('mks_st_recording_expired_hint')) . '">'
            . e(_l('mks_st_recording_expired')) . '</span>';
    }

    if ($event['recording_status'] !== 'stored' || (empty($event['recording_file']) && empty($event['drive_file_id']))) {
        return '<span class="mks-sales-track-muted">-</span>';
    }

    if (empty($context['play'])) {
        return '<span class="mks-sales-track-pill mks-sales-track-tone-slate" title="' . e(_l('mks_st_recording_no_permission')) . '">'
            . '<i class="fa-solid fa-lock" aria-hidden="true"></i>' . e(_l('mks_st_recording_stored')) . '</span>';
    }

    $id       = (int) $event['id'];
    $src      = admin_url(MKS_SALES_TRACK_MODULE_NAME . '/recording/' . $id);
    $playable = mks_st_event_playable($event);
    $download = mks_st_can_download() ? $src . '?download=1' : '';
    $title    = mks_st_event_title($event);
    $sub      = trim((string) $event['staff_first'] . ' ' . (string) $event['staff_last']) . ' - ' . _dt($event['occurred_at']);
    $badges   = (!empty($event['drive_file_id']) ? '<i class="fa-brands fa-google-drive mks-sales-track-on-drive" title="' . e(_l('mks_st_on_drive')) . '" aria-hidden="true"></i>' : '')
        . ((int) $event['best_pitch'] === 2 ? '<i class="fa-solid fa-star mks-sales-track-is-pitch" title="' . e(_l('mks_st_best_pitch')) . '" aria-hidden="true"></i>' : '');

    if (!$playable) {
        return $download === '' ? '<span class="mks-sales-track-pill mks-sales-track-tone-slate">' . e(_l('mks_st_recording_stored')) . '</span>' . $badges
            : '<a class="mks-sales-track-play mks-sales-track-play-download" href="' . e($download) . '" title="' . e(_l('mks_st_recording_download_only')) . '">'
            . '<i class="fa-solid fa-download" aria-hidden="true"></i></a>' . $badges;
    }

    return '<button type="button" class="mks-sales-track-play" data-id="' . $id . '"'
        . ' data-src="' . e($src) . '" data-download="' . e($download) . '"'
        . ' data-title="' . e($title) . '" data-sub="' . e($sub) . '"'
        . ' aria-label="' . e(_l('mks_st_play')) . '">'
        . '<i class="fa-solid fa-play" aria-hidden="true"></i></button>'
        . '<span class="mks-sales-track-play-size">' . e(mks_st_bytes_label($event['recording_size'])) . '</span>' . $badges;
}

/**
 * The AI cell: score, how hot the lead is and any flags, with Insights; or
 * Analyse for a recorded call nobody has sent yet.
 *
 * @param  array $event
 *
 * @return string
 */
function mks_st_render_ai(array $event)
{
    $id = (int) $event['id'];

    if ($event['ai_status'] === 'done') {
        if (!function_exists('mks_st_ai_visible') || !mks_st_ai_visible($event)) {
            return '<span class="mks-sales-track-muted">-</span>';
        }

        $score = (int) $event['ai_score'];
        $tone  = $score >= 75 ? 'green' : ($score >= 50 ? 'amber' : 'red');
        $temp  = ['hot' => 'red', 'warm' => 'amber', 'cold' => 'blue'];

        return '<button type="button" class="mks-sales-track-ai-open" data-id="' . $id . '" title="' . e(_l('mks_st_ai_insights')) . '">'
            . '<span class="mks-sales-track-pill mks-sales-track-tone-' . $tone . '">' . $score . '</span>'
            . (isset($temp[$event['ai_temperature']]) ? '<span class="mks-sales-track-pill mks-sales-track-tone-' . $temp[$event['ai_temperature']] . '">' . e(_l('mks_st_ai_' . $event['ai_temperature'])) . '</span>' : '')
            . ($event['ai_flags'] ? '<i class="fa-solid fa-flag mks-sales-track-ai-flag" title="' . e($event['ai_flags']) . '" aria-hidden="true"></i>' : '')
            . '</button>';
    }

    $recorded = $event['recording_status'] === 'stored' && (!empty($event['recording_file']) || !empty($event['drive_file_id']));

    if (!$recorded || $event['kind'] !== 'call' || !function_exists('mks_st_ai_can_run') || !mks_st_ai_can_run($event)) {
        return in_array($event['ai_status'], ['skipped', 'failed', 'capped'], true)
            ? '<span class="mks-sales-track-muted" title="' . e((string) $event['ai_note']) . '">' . e(_l('mks_st_ai_status_' . $event['ai_status'])) . '</span>'
            : '<span class="mks-sales-track-muted">-</span>';
    }

    return '<button type="button" class="mks-sales-track-link-btn mks-sales-track-ai-run" data-id="' . $id . '"'
        . ($event['ai_note'] ? ' title="' . e((string) $event['ai_note']) . '"' : '') . '>'
        . '<i class="fa-solid fa-wand-magic-sparkles" aria-hidden="true"></i>'
        . e(_l($event['ai_status'] === 'failed' ? 'mks_st_ai_retry' : 'mks_st_ai_analyse')) . '</button>';
}

/**
 * Can the browser play this recording? Judged by the file while it is on the
 * server, by its type once it lives on Drive.
 *
 * @param  array $event
 *
 * @return bool
 */
function mks_st_event_playable(array $event)
{
    if (!empty($event['recording_file'])) {
        return mks_st_recording_playable($event['recording_file']);
    }

    return !in_array(strtolower((string) $event['recording_mime']), ['audio/amr', 'audio/amr-wb', 'audio/3gpp', 'video/3gpp'], true);
}

/**
 * May the viewer download recordings (Settings > Recording Storage)?
 *
 * @return bool
 */
function mks_st_can_download()
{
    if (!mks_st_can('play_recordings')) {
        return false;
    }

    return mks_st_setting('recording_download', 'managers') === 'play' || mks_st_is_admin() || mks_st_scope() === null;
}

/**
 * May the viewer curate Best Pitches?
 *
 * @return bool
 */
function mks_st_can_pitches()
{
    return mks_st_can('manage_pitches');
}

/**
 * The best short name for an event, for the player and confirmations.
 *
 * @param  array $event
 *
 * @return string
 */
function mks_st_event_title(array $event)
{
    if ($event['rel_type'] === 'lead' && !empty($event['lead_name'])) {
        return (string) $event['lead_name'];
    }

    if ($event['rel_type'] === 'customer' && !empty($event['client_company'])) {
        return (string) $event['client_company'];
    }

    if ($event['rel_type'] === 'staff' && !empty($event['rel_staff_first'])) {
        return trim($event['rel_staff_first'] . ' ' . $event['rel_staff_last']);
    }

    if (!empty($event['contact_name'])) {
        return (string) $event['contact_name'];
    }

    $number = mks_st_format_number($event['number'] !== null ? $event['number'] : $event['number_raw']);

    return $number !== '' ? $number : _l('mks_st_unknown_caller');
}

/**
 * @param  array $event
 *
 * @return string
 */
function mks_st_render_media(array $event)
{
    if ($event['media'] === 'video') {
        return '<span class="mks-sales-track-chip"><i class="fa-solid fa-video" aria-hidden="true"></i>' . e(_l('mks_st_media_video')) . '</span>';
    }

    return '<span class="mks-sales-track-chip"><i class="fa-solid fa-phone" aria-hidden="true"></i>' . e(_l('mks_st_media_voice')) . '</span>';
}

/**
 * Message text, clipped with the full text a click away.
 *
 * @param  array $event
 *
 * @return string
 */
function mks_st_render_message(array $event)
{
    if ($event['body'] === null || $event['body'] === '') {
        return '<span class="mks-sales-track-muted mks-sales-track-italic">' . e(_l('mks_st_text_not_stored')) . '</span>';
    }

    $body = (string) $event['body'];

    if (mb_strlen($body, 'UTF-8') <= 140) {
        return '<div class="mks-sales-track-text">' . nl2br(e($body)) . '</div>';
    }

    return '<div class="mks-sales-track-text mks-sales-track-text-clip">'
        . '<span class="mks-sales-track-text-short">' . e(mb_substr($body, 0, 140, 'UTF-8')) . '...</span>'
        . '<span class="mks-sales-track-text-full mks-sales-track-is-hidden">' . nl2br(e($body)) . '</span>'
        . '<button type="button" class="mks-sales-track-link-btn mks-sales-track-text-toggle"'
        . ' data-more="' . e(_l('mks_st_show_more')) . '" data-less="' . e(_l('mks_st_show_less')) . '">'
        . e(_l('mks_st_show_more')) . '</button></div>';
}

/**
 * @param  array $event
 * @param  array $context
 *
 * @return string
 */
function mks_st_render_options(array $event, array $context)
{
    $html = '';

    if (!empty($context['pitch']) && $event['recording_status'] === 'stored' && (!empty($event['recording_file']) || !empty($event['drive_file_id']))
        && (mks_st_can_pitches() || (mks_st_enabled('pitch_nominate') && (int) $event['best_pitch'] === 0))) {
        $moments = '';

        foreach (mks_st_decode($event['pitch_moments']) as $moment) {
            $moments .= floor($moment['t'] / 60) . ':' . str_pad((string) ($moment['t'] % 60), 2, '0', STR_PAD_LEFT) . ' ' . $moment['label'] . "\n";
        }

        $html .= '<button type="button" class="mks-sales-track-icon-btn mks-sales-track-pitch' . ((int) $event['best_pitch'] > 0 ? ' is-on' : '') . '" data-id="' . (int) $event['id'] . '"'
            . ' data-state="' . (int) $event['best_pitch'] . '" data-category="' . e((string) $event['pitch_category']) . '"'
            . ' data-note="' . e((string) $event['pitch_note']) . '" data-moments="' . e(trim($moments)) . '"'
            . ' title="' . e(_l('mks_st_best_pitch')) . '" aria-label="' . e(_l('mks_st_best_pitch')) . '"><i class="fa-' . ((int) $event['best_pitch'] > 0 ? 'solid' : 'regular') . ' fa-star" aria-hidden="true"></i></button>';
    }

    if ($event['number'] !== null && !in_array($event['kind'], ['sms', 'whatsapp_message', 'notification'], true) && function_exists('mks_st_dial_button') && mks_st_my_phone() !== null && mks_st_enabled('click_to_call')) {
        $name  = (string) ($event['lead_name'] ?: ($event['client_company'] ?: $event['contact_name']));
        $html .= '<button type="button" class="mks-sales-track-icon-btn mks-sales-track-dial" data-number="' . e($event['number']) . '"'
            . ' data-name="' . e($name) . '" title="' . e(_l('mks_st_call_from_phone')) . '" aria-label="' . e(_l('mks_st_call_from_phone')) . '">'
            . '<i class="fa-solid fa-phone" aria-hidden="true"></i></button>';
    }

    if (!empty($context['delete'])) {
        $html .= '<button type="button" class="mks-sales-track-icon-btn mks-sales-track-delete-event" data-id="' . (int) $event['id'] . '"'
            . ' title="' . e(_l('mks_st_delete_event')) . '" aria-label="' . e(_l('mks_st_delete_event')) . '">'
            . '<i class="fa-solid fa-trash-can" aria-hidden="true"></i></button>';
    }

    return $html;
}

/**
 * The lead's own Perfex status in its own colour, plus Lost, Junk and
 * Converted where they apply, so a call list shows where every lead stands.
 *
 * @param  array $event
 *
 * @return string
 */
function mks_st_lead_status_pills(array $event)
{
    $html = '';

    if (!empty($event['lead_converted'])) {
        $html .= '<span class="mks-sales-track-pill mks-sales-track-tone-green">' . e(_l('mks_st_lead_converted')) . '</span>';
    } elseif (!empty($event['lead_status'])) {
        $html .= '<span class="mks-sales-track-pill mks-sales-track-pill-status"' . mks_st_color_style($event['lead_status_color']) . '>'
            . e($event['lead_status']) . '</span>';
    }

    if (!empty($event['lead_lost'])) {
        $html .= '<span class="mks-sales-track-pill mks-sales-track-tone-red">' . e(_l('mks_st_lead_lost')) . '</span>';
    }

    if (!empty($event['lead_junk'])) {
        $html .= '<span class="mks-sales-track-pill mks-sales-track-tone-slate">' . e(_l('mks_st_lead_junk')) . '</span>';
    }

    return $html;
}

/**
 * May the viewer see which customer a number belongs to? Set under Settings >
 * General: administrators and View All Activity only, also anyone with
 * Perfex customer access, or everybody. Off entirely when numbers are not
 * matched to customers.
 *
 * @return bool
 */
function mks_st_customer_visible()
{
    if (!mks_st_enabled('match_customers')) {
        return false;
    }

    switch (mks_st_setting('customer_visibility', 'managers')) {
        case 'everyone':
            return true;

        case 'customer_access':
            if (staff_can('view', 'customers') || staff_can('view_own', 'customers')) {
                return true;
            }

            // no break
        default:
            return mks_st_is_admin() || mks_st_scope() === null;
    }
}

/**
 * The lead behind a customer number, in the shape the status pills read.
 *
 * @param  array $event
 *
 * @return array
 */
function mks_st_lead2_fields(array $event)
{
    return [
        'lead_converted'    => $event['lead2_converted'],
        'lead_status'       => $event['lead2_status'],
        'lead_status_color' => $event['lead2_status_color'],
        'lead_lost'         => $event['lead2_lost'],
        'lead_junk'         => $event['lead2_junk'],
    ];
}

/**
 * The outcome cell: the outcome in its colour, the note, the follow-up, and
 * the button that sets or changes it.
 *
 * @param  array $event
 * @param  array $context
 *
 * @return string
 */
function mks_st_render_outcome(array $event, array $context)
{
    $outcomes = function_exists('mks_st_outcomes') ? mks_st_outcomes(false) : [];
    $html     = '<div class="mks-sales-track-outcome">';

    if ($event['outcome'] !== null) {
        $outcome = isset($outcomes[$event['outcome']]) ? $outcomes[$event['outcome']] : ['label' => $event['outcome'], 'tone' => 'slate'];

        $html .= '<span class="mks-sales-track-pill mks-sales-track-tone-' . e($outcome['tone']) . '">' . e($outcome['label']) . '</span>';

        if ((string) $event['outcome_note'] !== '') {
            $html .= '<span class="mks-sales-track-outcome-note" title="' . e($event['outcome_note']) . '">'
                . e(mb_strimwidth((string) $event['outcome_note'], 0, 70, '...', 'UTF-8')) . '</span>';
        }

        if ($event['follow_up_at'] !== null) {
            $html .= '<span class="mks-sales-track-outcome-follow' . (strtotime($event['follow_up_at']) < time() ? ' is-due' : '') . '">'
                . '<i class="fa-solid fa-bell" aria-hidden="true"></i>' . e(_dt($event['follow_up_at'])) . '</span>';
        }
    }

    if (!empty($context['outcome'])) {
        $html .= '<button type="button" class="mks-sales-track-link-btn mks-sales-track-outcome-edit" data-id="' . (int) $event['id'] . '"'
            . ' data-outcome="' . e((string) $event['outcome']) . '" data-note="' . e((string) $event['outcome_note']) . '"'
            . ' data-follow="' . ($event['follow_up_at'] !== null ? e(date('Y-m-d\TH:i', strtotime($event['follow_up_at']))) : '') . '"'
            . ' data-lead="' . ($event['rel_type'] === null && $event['number'] !== null ? '0' : '1') . '">'
            . '<i class="fa-solid ' . ($event['outcome'] === null ? 'fa-plus' : 'fa-pen') . '" aria-hidden="true"></i>'
            . e(_l($event['outcome'] === null ? 'mks_st_add_outcome' : 'mks_st_change')) . '</button>';
    }

    return $html . '</div>';
}

/**
 * Tone variables for a Perfex status colour. Only a #rgb or #rrggbb value is
 * ever written into the style attribute.
 *
 * @param  string|null $hex
 *
 * @return string
 */
function mks_st_color_style($hex)
{
    $hex = trim((string) $hex);

    if (!preg_match('/^#([0-9a-f]{3}|[0-9a-f]{6})$/i', $hex)) {
        return '';
    }

    $digits = ltrim($hex, '#');

    if (strlen($digits) === 3) {
        $digits = $digits[0] . $digits[0] . $digits[1] . $digits[1] . $digits[2] . $digits[2];
    }

    list($r, $g, $b) = [hexdec(substr($digits, 0, 2)), hexdec(substr($digits, 2, 2)), hexdec(substr($digits, 4, 2))];

    return ' style="--mks-st-tone: ' . $hex . '; --mks-st-tone-soft: rgba(' . $r . ', ' . $g . ', ' . $b . ', 0.12);'
        . ' --mks-st-tone-line: rgba(' . $r . ', ' . $g . ', ' . $b . ', 0.35);"';
}

/**
 * Seconds from which a call counts as connected (Settings > General).
 *
 * @return int
 */
function mks_st_connected_seconds()
{
    return max(0, (int) mks_st_setting('connected_seconds', 5));
}

/**
 * The tab bar on every module page. A tab appears only when its feature is on
 * and the viewer may use it; later phases add their tabs here.
 *
 * @return array slug => label, icon, url
 */
function mks_st_nav_items()
{
    $items = [];

    if (mks_st_scope() !== false) {
        $items['dashboard'] = ['label' => _l('mks_st_page_dashboard'), 'icon' => 'fa-solid fa-gauge-high', 'url' => admin_url(MKS_SALES_TRACK_MODULE_NAME)];

        foreach (mks_st_pages() as $slug => $page) {
            if (mks_st_enabled($page['setting'])) {
                $items[$slug] = ['label' => _l($page['label']), 'icon' => $page['icon'], 'url' => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/' . $slug)];
            }

            if ($slug === 'calls') {
                $items['missed_calls'] = ['label' => _l('mks_st_page_missed_calls'), 'icon' => 'fa-solid fa-phone-slash', 'url' => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/missed_calls')];
                $items['follow_ups']   = ['label' => _l('mks_st_page_follow_ups'), 'icon' => 'fa-solid fa-bell', 'url' => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/follow_ups')];
            }
        }

        $items['lists']   = ['label' => _l('mks_st_page_lists'), 'icon' => 'fa-solid fa-list-ol', 'url' => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/lists')];
        $items['pitches'] = ['label' => _l('mks_st_page_pitches'), 'icon' => 'fa-solid fa-star', 'url' => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/pitches')];
        $items['reports'] = ['label' => _l('mks_st_page_reports'), 'icon' => 'fa-solid fa-chart-column', 'url' => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/reports')];
        $items['devices'] = ['label' => _l('mks_st_page_devices'), 'icon' => 'fa-solid fa-mobile-screen-button', 'url' => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/devices')];
    }

    if (mks_st_can_settings()) {
        $items['settings'] = ['label' => _l('mks_st_page_settings'), 'icon' => 'fa-solid fa-sliders', 'url' => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/settings')];
    }

    return $items;
}

/* =========================================================================
 * FORMATTING
 * ====================================================================== */

/**
 * Indian digit grouping: 1,23,456 rather than 123,456.
 *
 * @param  mixed $value
 *
 * @return string
 */
function mks_st_number_label($value)
{
    $value    = (int) $value;
    $negative = $value < 0;
    $digits   = (string) abs($value);

    if (strlen($digits) > 3) {
        $last   = substr($digits, -3);
        $rest   = substr($digits, 0, -3);
        $rest   = preg_replace('/\B(?=(\d{2})+(?!\d))/', ',', $rest);
        $digits = $rest . ',' . $last;
    }

    return ($negative ? '-' : '') . $digits;
}

/**
 * 45s, 4m 05s, 2h 15m.
 *
 * @param  mixed $seconds
 *
 * @return string
 */
function mks_st_duration_label($seconds)
{
    $seconds = max(0, (int) $seconds);

    if ($seconds < 60) {
        return $seconds . 's';
    }

    if ($seconds < 3600) {
        return floor($seconds / 60) . 'm ' . str_pad((string) ($seconds % 60), 2, '0', STR_PAD_LEFT) . 's';
    }

    return floor($seconds / 3600) . 'h ' . str_pad((string) floor(($seconds % 3600) / 60), 2, '0', STR_PAD_LEFT) . 'm';
}

/**
 * @param  mixed $bytes
 *
 * @return string
 */
function mks_st_bytes_label($bytes)
{
    $bytes = max(0, (int) $bytes);

    if ($bytes >= 1073741824) {
        return round($bytes / 1073741824, 2) . ' GB';
    }

    if ($bytes >= 1048576) {
        return round($bytes / 1048576, 1) . ' MB';
    }

    if ($bytes >= 1024) {
        return round($bytes / 1024) . ' KB';
    }

    return $bytes . ' B';
}

/**
 * Indian mobile numbers read as +91 98140 00002. Anything else is shown as
 * stored.
 *
 * @param  string|null $number
 *
 * @return string
 */
function mks_st_format_number($number)
{
    $number = (string) $number;

    if (preg_match('/^\+91(\d{5})(\d{5})$/', $number, $m)) {
        return '+91 ' . $m[1] . ' ' . $m[2];
    }

    return $number;
}

/**
 * "5 minutes ago" style, for device health.
 *
 * @param  string|null $datetime
 *
 * @return string
 */
function mks_st_relative_time($datetime)
{
    if (empty($datetime)) {
        return _l('mks_st_never');
    }

    $age = time() - strtotime($datetime);

    if ($age < 60) {
        return _l('mks_st_just_now');
    }

    if ($age < 3600) {
        return _l('mks_st_minutes_ago', (string) floor($age / 60));
    }

    if ($age < 86400) {
        return _l('mks_st_hours_ago', (string) floor($age / 3600));
    }

    return _l('mks_st_days_ago', (string) floor($age / 86400));
}
