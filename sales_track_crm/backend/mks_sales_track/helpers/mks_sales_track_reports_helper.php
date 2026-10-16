<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - reports, exports and scheduled email reports.
 *
 * Loaded on demand by the Reports page and the cron run. Needs the analytics
 * helper for periods, filters and the shared WHERE.
 *
 * Every report returns the same shape - columns, rows, an optional totals row
 * and a note - so one view draws them all, one exporter writes CSV and Excel,
 * and the email uses the same figures. Every query goes through
 * mks_st_dash_where() or applies mks_st_scope_sql() itself, so a report never
 * describes activity the viewer may not see.
 *
 * Column types: text, number, percent, duration (seconds), datetime, money.
 */

require_once __DIR__ . '/mks_sales_track_analytics_helper.php';

/* =========================================================================
 * REGISTRY
 * ====================================================================== */

/**
 * @return array key => label, icon, description language keys
 */
function mks_st_reports()
{
    return [
        'team'       => ['icon' => 'fa-solid fa-users', 'label' => 'mks_st_rep_team', 'sub' => 'mks_st_rep_team_sub'],
        'daily'      => ['icon' => 'fa-solid fa-calendar-days', 'label' => 'mks_st_rep_daily', 'sub' => 'mks_st_rep_daily_sub'],
        'callbacks'  => ['icon' => 'fa-solid fa-phone-slash', 'label' => 'mks_st_rep_callbacks', 'sub' => 'mks_st_rep_callbacks_sub'],
        'duration'   => ['icon' => 'fa-solid fa-clock', 'label' => 'mks_st_rep_duration', 'sub' => 'mks_st_rep_duration_sub'],
        'outcomes'   => ['icon' => 'fa-solid fa-list-check', 'label' => 'mks_st_rep_outcomes', 'sub' => 'mks_st_rep_outcomes_sub'],
        'speed'      => ['icon' => 'fa-solid fa-bolt', 'label' => 'mks_st_rep_speed', 'sub' => 'mks_st_rep_speed_sub'],
        'engagement' => ['icon' => 'fa-solid fa-user-plus', 'label' => 'mks_st_rep_engagement', 'sub' => 'mks_st_rep_engagement_sub'],
        'conversion' => ['icon' => 'fa-solid fa-trophy', 'label' => 'mks_st_rep_conversion', 'sub' => 'mks_st_rep_conversion_sub'],
        'recordings' => ['icon' => 'fa-solid fa-microphone', 'label' => 'mks_st_rep_recordings', 'sub' => 'mks_st_rep_recordings_sub'],
        'sms'        => ['icon' => 'fa-solid fa-message', 'label' => 'mks_st_rep_sms', 'sub' => 'mks_st_rep_sms_sub'],
        'health'     => ['icon' => 'fa-solid fa-mobile-screen-button', 'label' => 'mks_st_rep_health', 'sub' => 'mks_st_rep_health_sub'],
    ] + (mks_st_enabled('ai_enabled') ? ['ai' => ['icon' => 'fa-solid fa-wand-magic-sparkles', 'label' => 'mks_st_rep_ai', 'sub' => 'mks_st_rep_ai_sub']] : [])
      + (mks_st_scope() === null ? ['access' => ['icon' => 'fa-solid fa-eye', 'label' => 'mks_st_rep_access', 'sub' => 'mks_st_rep_access_sub']] : []);
}

/**
 * Per rep: what the AI made of their calls.
 */
function mks_st_report_ai(array $period, $ids)
{
    $CI   = &get_instance();
    $cost = mks_st_scope() === null;
    $rows = [];

    foreach ($CI->db->query("SELECT e.staff_id, COUNT(*) AS analysed, AVG(e.ai_score) AS score,"
        . " SUM(e.ai_temperature = 'hot') AS hot, SUM(e.ai_temperature = 'warm') AS warm, SUM(e.ai_temperature = 'cold') AS cold,"
        . " SUM(e.ai_sentiment = 'positive') AS positive, SUM(e.ai_sentiment = 'negative') AS negative,"
        . ' SUM(e.ai_flags IS NOT NULL) AS flagged, COALESCE(SUM(e.ai_cost), 0) AS cost'
        . ' FROM ' . mks_st_events_table() . " e WHERE e.ai_status = 'done' AND e.occurred_at >= '" . $period['from'] . " 00:00:00'"
        . " AND e.occurred_at <= '" . $period['to'] . " 23:59:59' " . mks_st_scope_sql('e.staff_id', $ids) . ' GROUP BY e.staff_id')->result_array() as $row) {
        $rows[(int) $row['staff_id']] = [
            'analysed' => (int) $row['analysed'],
            'score'    => (int) round($row['score']),
            'hot'      => (int) $row['hot'],
            'warm'     => (int) $row['warm'],
            'cold'     => (int) $row['cold'],
            'positive' => mks_st_pct($row['positive'], $row['analysed']),
            'negative' => mks_st_pct($row['negative'], $row['analysed']),
            'flagged'  => (int) $row['flagged'],
        ] + ($cost ? ['cost' => round((float) $row['cost'], 4)] : []);
    }

    $rows    = mks_st_report_named($rows);
    $columns = [
        mks_st_col('staff', 'mks_st_col_staff', 'text'),
        mks_st_col('analysed', 'mks_st_ai_analysed'),
        mks_st_col('score', 'mks_st_ai_avg_score'),
        mks_st_col('hot', 'mks_st_ai_hot'),
        mks_st_col('warm', 'mks_st_ai_warm'),
        mks_st_col('cold', 'mks_st_ai_cold'),
        mks_st_col('positive', 'mks_st_ai_positive', 'percent'),
        mks_st_col('negative', 'mks_st_ai_negative', 'percent'),
        mks_st_col('flagged', 'mks_st_ai_flagged'),
    ];

    if ($cost) {
        $columns[] = mks_st_col('cost', 'mks_st_ai_cost_usd');
    }

    return ['columns' => $columns, 'rows' => $rows, 'totals' => mks_st_report_sum($rows, $cost ? ['analysed', 'hot', 'warm', 'cold', 'flagged', 'cost'] : ['analysed', 'hot', 'warm', 'cold', 'flagged'])];
}

/**
 * Run one report.
 *
 * @param  string     $key
 * @param  array      $period from mks_st_dash_period()
 * @param  int[]|null $ids    people the report covers
 *
 * @return array columns, rows, totals, note
 */
function mks_st_report($key, array $period, $ids)
{
    $function = 'mks_st_report_' . $key;

    if (!isset(mks_st_reports()[$key]) || !function_exists($function)) {
        return ['columns' => [], 'rows' => [], 'totals' => null, 'note' => ''];
    }

    $report = $function($period, $ids);

    return $report + ['totals' => null, 'note' => ''];
}

/**
 * A column definition.
 *
 * @return array
 */
function mks_st_col($key, $label, $type = 'number')
{
    return ['key' => $key, 'label' => _l($label), 'type' => $type];
}

/**
 * Staff names for a set of ids.
 *
 * @param  int[] $ids
 *
 * @return array id => name
 */
function mks_st_report_names(array $ids)
{
    $CI  = &get_instance();
    $out = [];

    if ($ids) {
        foreach ($CI->db->select('staffid, firstname, lastname')->where_in('staffid', array_map('intval', $ids))->get(db_prefix() . 'staff')->result_array() as $row) {
            $out[(int) $row['staffid']] = trim($row['firstname'] . ' ' . $row['lastname']);
        }
    }

    return $out;
}

/**
 * Sort rows by staff name and give each its name.
 *
 * @param  array $rows staff_id => row
 *
 * @return array
 */
function mks_st_report_named(array $rows)
{
    $names = mks_st_report_names(array_keys($rows));

    foreach ($rows as $id => $row) {
        $rows[$id] = ['staff' => isset($names[$id]) ? $names[$id] : _l('mks_st_removed_staff')] + $row;
    }

    uasort($rows, function ($a, $b) {
        return strcasecmp($a['staff'], $b['staff']);
    });

    return array_values($rows);
}

/**
 * The sum of numeric columns over rows, under a label.
 *
 * @param  array $rows
 * @param  array $keys
 *
 * @return array
 */
function mks_st_report_sum(array $rows, array $keys)
{
    $out = ['staff' => _l('mks_st_total')];

    foreach ($keys as $key) {
        $out[$key] = array_sum(array_column($rows, $key));
    }

    return $out;
}

/**
 * @return float|null
 */
function mks_st_pct($part, $whole)
{
    return (int) $whole > 0 ? round($part * 100 / $whole, 1) : null;
}

/* =========================================================================
 * REPORTS
 * ====================================================================== */

/**
 * Per rep: everything a manager asks first.
 */
function mks_st_report_team(array $period, $ids)
{
    $CI = &get_instance();
    $t  = mks_st_connected_seconds();

    $rows = [];

    foreach ($CI->db->query("SELECT e.staff_id, SUM(e.kind = 'call') AS calls,"
        . " SUM(e.kind = 'call' AND e.direction = 'incoming') AS incoming, SUM(e.kind = 'call' AND e.direction = 'outgoing') AS outgoing,"
        . " SUM(e.kind = 'call' AND e.duration >= " . $t . ") AS connected, SUM(e.kind = 'call' AND e.direction IN ('missed', 'rejected')) AS missed,"
        . " COALESCE(SUM(CASE WHEN e.kind = 'call' THEN e.duration ELSE 0 END), 0) AS talk,"
        . " COUNT(DISTINCT CASE WHEN e.kind = 'call' THEN e.number_key END) AS clients,"
        . " SUM(e.kind = 'whatsapp_call') AS whatsapp, SUM(e.kind IN ('sms', 'whatsapp_message', 'notification')) AS sms,"
        . " MIN(CASE WHEN e.kind = 'call' THEN e.occurred_at END) AS first_call, MAX(CASE WHEN e.kind = 'call' THEN e.occurred_at END) AS last_call"
        . ' FROM ' . mks_st_events_table() . ' e ' . mks_st_dash_where($period['from'], $period['to'], $ids)
        . ' GROUP BY e.staff_id')->result_array() as $row) {
        $workdays = mks_st_working_days_between($period['from'], $period['to']);
        $target   = mks_st_target_for((int) $row['staff_id'])['calls'] * $workdays;

        $rows[(int) $row['staff_id']] = [
            'calls'      => (int) $row['calls'],
            'incoming'   => (int) $row['incoming'],
            'outgoing'   => (int) $row['outgoing'],
            'connected'  => (int) $row['connected'],
            'rate'       => mks_st_pct($row['connected'], $row['calls']),
            'talk'       => (int) $row['talk'],
            'average'    => (int) $row['connected'] > 0 ? (int) round($row['talk'] / $row['connected']) : 0,
            'missed'     => (int) $row['missed'],
            'clients'    => (int) $row['clients'],
            'whatsapp'   => (int) $row['whatsapp'],
            'sms'        => (int) $row['sms'],
            'first_call' => $row['first_call'],
            'last_call'  => $row['last_call'],
            'target'     => $target > 0 ? mks_st_pct($row['calls'], $target) : null,
        ];
    }

    $rows   = mks_st_report_named($rows);
    $totals = mks_st_report_sum($rows, ['calls', 'incoming', 'outgoing', 'connected', 'talk', 'missed', 'whatsapp', 'sms']);

    $totals['rate']    = mks_st_pct($totals['connected'], $totals['calls']);
    $totals['average'] = $totals['connected'] > 0 ? (int) round($totals['talk'] / $totals['connected']) : 0;

    return [
        'columns' => [
            mks_st_col('staff', 'mks_st_col_staff', 'text'),
            mks_st_col('calls', 'mks_st_kpi_calls'),
            mks_st_col('incoming', 'mks_st_dir_incoming'),
            mks_st_col('outgoing', 'mks_st_dir_outgoing'),
            mks_st_col('connected', 'mks_st_kpi_connected'),
            mks_st_col('rate', 'mks_st_connect_rate', 'percent'),
            mks_st_col('talk', 'mks_st_kpi_talk_time', 'duration'),
            mks_st_col('average', 'mks_st_average_call', 'duration'),
            mks_st_col('missed', 'mks_st_kpi_missed'),
            mks_st_col('clients', 'mks_st_kpi_clients'),
            mks_st_col('whatsapp', 'mks_st_page_whatsapp_calls'),
            mks_st_col('sms', 'mks_st_page_sms'),
            mks_st_col('first_call', 'mks_st_first_call', 'datetime'),
            mks_st_col('last_call', 'mks_st_last_call', 'datetime'),
            mks_st_col('target', 'mks_st_call_target', 'percent'),
        ],
        'rows'    => $rows,
        'totals'  => $totals,
    ];
}

/**
 * Per rep and day: calls. Long periods are counted by week instead.
 */
function mks_st_report_daily(array $period, $ids)
{
    $CI      = &get_instance();
    $weekly  = $period['days'] > 31;
    $buckets = [];

    for ($day = strtotime($period['from']); $day <= strtotime($period['to']); $day = strtotime('+1 day', $day)) {
        $key = $weekly ? date('o-\WW', $day) : date('Y-m-d', $day);

        if (!isset($buckets[$key])) {
            $buckets[$key] = $weekly ? _l('mks_st_week_of', date('j M', $day)) : date('D j', $day);
        }
    }

    $group = $weekly ? "DATE_FORMAT(e.occurred_at, '%x-W%v')" : 'DATE(e.occurred_at)';
    $rows  = [];

    foreach ($CI->db->query('SELECT e.staff_id, ' . $group . ' AS bucket, COUNT(*) AS calls FROM ' . mks_st_events_table() . ' e '
        . mks_st_dash_where($period['from'], $period['to'], $ids, ['call']) . ' GROUP BY e.staff_id, bucket')->result_array() as $row) {
        $id = (int) $row['staff_id'];

        if (!isset($rows[$id])) {
            $rows[$id] = array_fill_keys(array_map(function ($k) {
                return 'b_' . $k;
            }, array_keys($buckets)), 0) + ['total' => 0];
        }

        if (isset($rows[$id]['b_' . $row['bucket']])) {
            $rows[$id]['b_' . $row['bucket']] = (int) $row['calls'];
            $rows[$id]['total'] += (int) $row['calls'];
        }
    }

    $columns = [mks_st_col('staff', 'mks_st_col_staff', 'text')];

    foreach ($buckets as $key => $label) {
        $columns[] = ['key' => 'b_' . $key, 'label' => $label, 'type' => 'number'];
    }

    $columns[] = mks_st_col('total', 'mks_st_total');
    $rows      = mks_st_report_named($rows);

    return [
        'columns' => $columns,
        'rows'    => $rows,
        'totals'  => mks_st_report_sum($rows, array_merge(array_map(function ($k) {
            return 'b_' . $k;
        }, array_keys($buckets)), ['total'])),
        'note'    => $weekly ? _l('mks_st_rep_daily_weekly') : '',
    ];
}

/**
 * Per rep: the callback queue, for calls missed in the period.
 */
function mks_st_report_callbacks(array $period, $ids)
{
    $CI   = &get_instance();
    $rows = [];

    foreach ($CI->db->query("SELECT e.staff_id, COUNT(*) AS missed, SUM(e.callback_state = 'resolved') AS returned,"
        . " SUM(e.callback_state = 'resolved' AND e.callback_at <= e.callback_due_at) AS on_time,"
        . " SUM(e.callback_state IN ('open', 'escalated')) AS still_open, SUM(e.escalated_at IS NOT NULL) AS escalated,"
        . " AVG(CASE WHEN e.callback_state = 'resolved' THEN TIMESTAMPDIFF(SECOND, e.occurred_at, e.callback_at) END) AS wait"
        . ' FROM ' . mks_st_events_table() . " e WHERE e.callback_state IS NOT NULL AND e.occurred_at >= '" . $period['from'] . " 00:00:00'"
        . " AND e.occurred_at <= '" . $period['to'] . " 23:59:59' " . mks_st_scope_sql('e.staff_id', $ids)
        . ' GROUP BY e.staff_id')->result_array() as $row) {
        $rows[(int) $row['staff_id']] = [
            'missed'    => (int) $row['missed'],
            'returned'  => (int) $row['returned'],
            'rate'      => mks_st_pct($row['returned'], $row['missed']),
            'on_time'   => (int) $row['on_time'],
            'open'      => (int) $row['still_open'],
            'escalated' => (int) $row['escalated'],
            'wait'      => $row['wait'] !== null ? (int) round($row['wait']) : null,
        ];
    }

    $rows   = mks_st_report_named($rows);
    $totals = mks_st_report_sum($rows, ['missed', 'returned', 'on_time', 'open', 'escalated']);

    $totals['rate'] = mks_st_pct($totals['returned'], $totals['missed']);
    $totals['wait'] = null;

    return [
        'columns' => [
            mks_st_col('staff', 'mks_st_col_staff', 'text'),
            mks_st_col('missed', 'mks_st_kpi_missed'),
            mks_st_col('returned', 'mks_st_queue_resolved'),
            mks_st_col('rate', 'mks_st_returned_rate', 'percent'),
            mks_st_col('on_time', 'mks_st_on_time'),
            mks_st_col('open', 'mks_st_queue_open'),
            mks_st_col('escalated', 'mks_st_escalated'),
            mks_st_col('wait', 'mks_st_avg_callback', 'duration'),
        ],
        'rows'    => $rows,
        'totals'  => $totals,
    ];
}

/**
 * Per rep: how long connected calls last.
 */
function mks_st_report_duration(array $period, $ids)
{
    $CI    = &get_instance();
    $t     = mks_st_connected_seconds();
    $edges = ['u30' => [0, 29], 'u60' => [30, 59], 'u180' => [60, 179], 'u300' => [180, 299], 'u600' => [300, 599], 'o600' => [600, 86400 * 7]];
    $sums  = [];

    foreach ($edges as $key => $range) {
        $sums[] = 'SUM(e.duration BETWEEN ' . $range[0] . ' AND ' . $range[1] . ') AS ' . $key;
    }

    $rows = [];

    foreach ($CI->db->query('SELECT e.staff_id, COUNT(*) AS connected, ' . implode(', ', $sums) . ', AVG(e.duration) AS average, MAX(e.duration) AS longest'
        . ' FROM ' . mks_st_events_table() . ' e ' . mks_st_dash_where($period['from'], $period['to'], $ids, ['call'])
        . ' AND e.duration >= ' . $t . ' GROUP BY e.staff_id')->result_array() as $row) {
        $rows[(int) $row['staff_id']] = ['connected' => (int) $row['connected']] + array_map('intval', array_intersect_key($row, $edges))
            + ['average' => (int) round($row['average']), 'longest' => (int) $row['longest']];
    }

    $rows   = mks_st_report_named($rows);
    $totals = mks_st_report_sum($rows, array_merge(['connected'], array_keys($edges)));

    $totals['average'] = null;
    $totals['longest'] = $rows ? max(array_column($rows, 'longest')) : 0;

    return [
        'columns' => [
            mks_st_col('staff', 'mks_st_col_staff', 'text'),
            mks_st_col('connected', 'mks_st_kpi_connected'),
            mks_st_col('u30', 'mks_st_dur_u30'),
            mks_st_col('u60', 'mks_st_dur_u60'),
            mks_st_col('u180', 'mks_st_dur_u180'),
            mks_st_col('u300', 'mks_st_dur_u300'),
            mks_st_col('u600', 'mks_st_dur_u600'),
            mks_st_col('o600', 'mks_st_dur_o600'),
            mks_st_col('average', 'mks_st_average_call', 'duration'),
            mks_st_col('longest', 'mks_st_longest_call', 'duration'),
        ],
        'rows'    => $rows,
        'totals'  => $totals,
    ];
}

/**
 * Per rep: outcomes given to calls and WhatsApp calls.
 */
function mks_st_report_outcomes(array $period, $ids)
{
    $CI       = &get_instance();
    $outcomes = mks_st_outcomes(false);
    $t        = mks_st_connected_seconds();
    $rows     = [];

    foreach ($CI->db->query("SELECT e.staff_id, COALESCE(e.outcome, '') AS outcome, COUNT(*) AS n FROM " . mks_st_events_table() . ' e '
        . mks_st_dash_where($period['from'], $period['to'], $ids, ['call', 'whatsapp_call'])
        . ' AND (e.outcome IS NOT NULL OR e.duration >= ' . $t . ') GROUP BY e.staff_id, outcome')->result_array() as $row) {
        $id  = (int) $row['staff_id'];
        $key = $row['outcome'] === '' ? 'o__none' : 'o_' . $row['outcome'];

        if (!isset($rows[$id])) {
            $rows[$id] = array_fill_keys(array_map(function ($k) {
                return 'o_' . $k;
            }, array_keys($outcomes)), 0) + ['o__none' => 0, 'total' => 0];
        }

        $rows[$id][$key] = (isset($rows[$id][$key]) ? $rows[$id][$key] : 0) + (int) $row['n'];

        if ($key !== 'o__none') {
            $rows[$id]['total'] += (int) $row['n'];
        }
    }

    $columns = [mks_st_col('staff', 'mks_st_col_staff', 'text')];

    foreach ($outcomes as $key => $outcome) {
        $columns[] = ['key' => 'o_' . $key, 'label' => $outcome['label'], 'type' => 'number'];
    }

    $columns[] = mks_st_col('total', 'mks_st_with_outcome');
    $columns[] = mks_st_col('o__none', 'mks_st_no_outcome');

    $rows = mks_st_report_named($rows);

    return [
        'columns' => $columns,
        'rows'    => $rows,
        'totals'  => mks_st_report_sum($rows, array_slice(array_column($columns, 'key'), 1)),
        'note'    => _l('mks_st_rep_outcomes_note'),
    ];
}

/**
 * Speed to lead: for leads created in the period, how soon the first call
 * came, by the person the lead is assigned to. A lead created by a call
 * counts as called at once.
 */
function mks_st_report_speed(array $period, $ids)
{
    $CI    = &get_instance();
    $p     = db_prefix();
    $table = mks_st_events_table();

    $leads = $CI->db->query('SELECT l.id, l.assigned, l.dateadded, (SELECT MIN(e.occurred_at) FROM ' . $table . " e WHERE ((e.rel_type = 'lead' AND e.rel_id = l.id) OR e.lead_id = l.id)"
        . " AND e.kind IN ('call', 'whatsapp_call') AND e.occurred_at >= l.dateadded - INTERVAL 10 MINUTE) AS first_call"
        . ' FROM ' . $p . "leads l WHERE l.dateadded >= '" . $period['from'] . " 00:00:00' AND l.dateadded <= '" . $period['to'] . " 23:59:59' "
        . mks_st_scope_sql('l.assigned', $ids))->result_array();

    $rows = [];

    foreach ($leads as $lead) {
        $id = (int) $lead['assigned'];

        if (!isset($rows[$id])) {
            $rows[$id] = ['leads' => 0, 'm5' => 0, 'h1' => 0, 'day' => 0, 'later' => 0, 'never' => 0, 'waits' => []];
        }

        $rows[$id]['leads']++;

        if ($lead['first_call'] === null) {
            $rows[$id]['never']++;

            continue;
        }

        $wait = max(0, strtotime($lead['first_call']) - strtotime($lead['dateadded']));

        $rows[$id]['waits'][] = $wait;
        $bucket               = $wait <= 300 ? 'm5' : ($wait <= 3600 ? 'h1' : (date('Y-m-d', strtotime($lead['first_call'])) === date('Y-m-d', strtotime($lead['dateadded'])) ? 'day' : 'later'));
        $rows[$id][$bucket]++;
    }

    foreach ($rows as $id => $row) {
        $waits = $row['waits'];
        sort($waits);

        $rows[$id]['median'] = $waits ? $waits[(int) floor((count($waits) - 1) / 2)] : null;
        $rows[$id]['rate']   = mks_st_pct($row['m5'] + $row['h1'], $row['leads']);
        unset($rows[$id]['waits']);
    }

    $named = [];

    foreach ($rows as $id => $row) {
        $named[$id] = $row;
    }

    $rows = mks_st_report_named($named);

    foreach ($rows as $index => $row) {
        if ($row['staff'] === _l('mks_st_removed_staff') && $row['leads'] > 0) {
            $rows[$index]['staff'] = _l('mks_st_unassigned');
        }
    }

    $totals = mks_st_report_sum($rows, ['leads', 'm5', 'h1', 'day', 'later', 'never']);

    $totals['rate']   = mks_st_pct($totals['m5'] + $totals['h1'], $totals['leads']);
    $totals['median'] = null;

    return [
        'columns' => [
            mks_st_col('staff', 'mks_st_assigned_to', 'text'),
            mks_st_col('leads', 'mks_st_new_leads'),
            mks_st_col('m5', 'mks_st_speed_m5'),
            mks_st_col('h1', 'mks_st_speed_h1'),
            mks_st_col('day', 'mks_st_speed_day'),
            mks_st_col('later', 'mks_st_speed_later'),
            mks_st_col('never', 'mks_st_speed_never'),
            mks_st_col('rate', 'mks_st_speed_rate', 'percent'),
            mks_st_col('median', 'mks_st_speed_median', 'duration'),
        ],
        'rows'    => $rows,
        'totals'  => $totals,
        'note'    => _l('mks_st_rep_speed_note'),
    ];
}

/**
 * Per lead status: how much calling each stage gets, and how many leads have
 * gone quiet.
 */
function mks_st_report_engagement(array $period, $ids)
{
    $CI       = &get_instance();
    $p        = db_prefix();
    $t        = mks_st_connected_seconds();
    $statuses = mks_st_lead_statuses();
    $quiet    = date('Y-m-d H:i:s', strtotime('-14 days'));
    $rows     = [];

    foreach ($CI->db->query('SELECT l.status, COUNT(*) AS leads, SUM(l.lost = 0 AND l.junk = 0 AND l.date_converted IS NULL'
        . ' AND COALESCE(l.lastcontact, l.dateadded) < ' . $CI->db->escape($quiet) . ') AS quiet FROM ' . $p . 'leads l WHERE 1 = 1 '
        . mks_st_scope_sql('l.assigned', $ids) . ' GROUP BY l.status')->result_array() as $row) {
        $rows[(int) $row['status']] = ['leads' => (int) $row['leads'], 'quiet' => (int) $row['quiet'], 'called' => 0, 'calls' => 0, 'connected' => 0, 'talk' => 0];
    }

    foreach ($CI->db->query('SELECT l.status, COUNT(DISTINCT l.id) AS called, COUNT(*) AS calls, SUM(e.duration >= ' . $t . ') AS connected,'
        . ' COALESCE(SUM(e.duration), 0) AS talk FROM ' . mks_st_events_table() . ' e'
        . ' JOIN ' . $p . "leads l ON l.id = IF(e.rel_type = 'lead', e.rel_id, e.lead_id) "
        . mks_st_dash_where($period['from'], $period['to'], $ids, ['call', 'whatsapp_call']) . ' GROUP BY l.status')->result_array() as $row) {
        $id = (int) $row['status'];

        if (!isset($rows[$id])) {
            $rows[$id] = ['leads' => 0, 'quiet' => 0];
        }

        $rows[$id] = array_merge($rows[$id], ['called' => (int) $row['called'], 'calls' => (int) $row['calls'], 'connected' => (int) $row['connected'], 'talk' => (int) $row['talk']]);
    }

    $out = [];

    foreach ($statuses as $id => $status) {
        if (isset($rows[$id])) {
            $out[] = ['status' => $status['name']] + $rows[$id];
        }
    }

    $totals = mks_st_report_sum($out, ['leads', 'quiet', 'called', 'calls', 'connected', 'talk']);
    unset($totals['staff']);

    return [
        'columns' => [
            mks_st_col('status', 'mks_st_lead_status', 'text'),
            mks_st_col('leads', 'mks_st_leads'),
            mks_st_col('called', 'mks_st_leads_called'),
            mks_st_col('calls', 'mks_st_kpi_calls'),
            mks_st_col('connected', 'mks_st_kpi_connected'),
            mks_st_col('talk', 'mks_st_kpi_talk_time', 'duration'),
            mks_st_col('quiet', 'mks_st_leads_quiet'),
        ],
        'rows'    => $out,
        'totals'  => ['status' => _l('mks_st_total')] + $totals,
        'note'    => _l('mks_st_rep_engagement_note'),
    ];
}

/**
 * Per rep: leads they called in the period, how many were converted since,
 * and, for those who may see customers, what those customers have paid.
 */
function mks_st_report_conversion(array $period, $ids)
{
    $CI      = &get_instance();
    $p       = db_prefix();
    $t       = mks_st_connected_seconds();
    $revenue = mks_st_customer_visible() && (mks_st_is_admin() || staff_can('view', 'invoices'));
    $rows    = [];

    $called = $CI->db->query('SELECT e.staff_id, l.id AS lead, MAX(e.outcome = \'converted\') AS marked, l.date_converted, l.client_id'
        . ' FROM ' . mks_st_events_table() . ' e JOIN ' . $p . "leads l ON l.id = IF(e.rel_type = 'lead', e.rel_id, e.lead_id) "
        . mks_st_dash_where($period['from'], $period['to'], $ids, ['call', 'whatsapp_call']) . ' AND e.duration >= ' . $t
        . ' GROUP BY e.staff_id, l.id, l.date_converted, l.client_id')->result_array();

    $paid = [];

    if ($revenue) {
        $clients = array_unique(array_filter(array_map('intval', array_column($called, 'client_id'))));

        if ($clients) {
            $base = function_exists('get_base_currency') ? get_base_currency() : null;

            foreach ($CI->db->query('SELECT clientid, SUM(total) AS total FROM ' . $p . 'invoices WHERE status = 2'
                . ($base ? ' AND currency = ' . (int) $base->id : '') . " AND date >= '" . $period['from'] . "' AND date <= '" . $period['to'] . "'"
                . ' AND clientid IN (' . implode(',', $clients) . ') GROUP BY clientid')->result_array() as $row) {
                $paid[(int) $row['clientid']] = (float) $row['total'];
            }
        }
    }

    foreach ($called as $row) {
        $id = (int) $row['staff_id'];

        if (!isset($rows[$id])) {
            $rows[$id] = ['leads' => 0, 'marked' => 0, 'converted' => 0, 'clients' => []];
        }

        $rows[$id]['leads']++;
        $rows[$id]['marked'] += (int) $row['marked'];

        if ($row['date_converted'] !== null && $row['date_converted'] >= $period['from'] . ' 00:00:00') {
            $rows[$id]['converted']++;

            if ((int) $row['client_id'] > 0) {
                $rows[$id]['clients'][(int) $row['client_id']] = true;
            }
        }
    }

    foreach ($rows as $id => $row) {
        $rows[$id]['rate'] = mks_st_pct($row['converted'], $row['leads']);

        if ($revenue) {
            $rows[$id]['revenue'] = array_sum(array_intersect_key($paid, $row['clients']));
        }

        unset($rows[$id]['clients']);
    }

    $rows   = mks_st_report_named($rows);
    $totals = mks_st_report_sum($rows, $revenue ? ['leads', 'marked', 'converted', 'revenue'] : ['leads', 'marked', 'converted']);

    $totals['rate'] = mks_st_pct($totals['converted'], $totals['leads']);

    $columns = [
        mks_st_col('staff', 'mks_st_col_staff', 'text'),
        mks_st_col('leads', 'mks_st_leads_called'),
        mks_st_col('marked', 'mks_st_marked_converted'),
        mks_st_col('converted', 'mks_st_converted_in_perfex'),
        mks_st_col('rate', 'mks_st_conversion_rate', 'percent'),
    ];

    if ($revenue) {
        $columns[] = mks_st_col('revenue', 'mks_st_paid_invoices', 'money');
    }

    return ['columns' => $columns, 'rows' => $rows, 'totals' => $totals, 'note' => _l('mks_st_rep_conversion_note')];
}

/**
 * Per rep: how many calls came with a recording.
 */
function mks_st_report_recordings(array $period, $ids)
{
    $CI   = &get_instance();
    $rows = [];

    foreach ($CI->db->query("SELECT e.staff_id, COUNT(*) AS calls, SUM(e.recording_status = 'stored') AS recorded,"
        . " SUM(e.recording_status = 'pending') AS waiting, SUM(e.drive_file_id IS NOT NULL) AS on_drive,"
        . " COALESCE(SUM(CASE WHEN e.recording_status = 'stored' THEN e.duration ELSE 0 END), 0) AS minutes,"
        . " COALESCE(SUM(CASE WHEN e.recording_status = 'stored' THEN e.recording_size ELSE 0 END), 0) AS bytes"
        . ' FROM ' . mks_st_events_table() . ' e ' . mks_st_dash_where($period['from'], $period['to'], $ids, ['call'])
        . ' AND e.duration > 0 GROUP BY e.staff_id')->result_array() as $row) {
        $rows[(int) $row['staff_id']] = [
            'calls'    => (int) $row['calls'],
            'recorded' => (int) $row['recorded'],
            'rate'     => mks_st_pct($row['recorded'], $row['calls']),
            'waiting'  => (int) $row['waiting'],
            'on_drive' => (int) $row['on_drive'],
            'length'   => (int) $row['minutes'],
            'size'     => round($row['bytes'] / 1048576, 1),
        ];
    }

    $rows   = mks_st_report_named($rows);
    $totals = mks_st_report_sum($rows, ['calls', 'recorded', 'waiting', 'on_drive', 'length', 'size']);

    $totals['rate'] = mks_st_pct($totals['recorded'], $totals['calls']);

    return [
        'columns' => [
            mks_st_col('staff', 'mks_st_col_staff', 'text'),
            mks_st_col('calls', 'mks_st_answered_calls'),
            mks_st_col('recorded', 'mks_st_kpi_recordings'),
            mks_st_col('rate', 'mks_st_recorded_share', 'percent'),
            mks_st_col('waiting', 'mks_st_kpi_pending'),
            mks_st_col('on_drive', 'mks_st_on_drive_short'),
            mks_st_col('length', 'mks_st_kpi_recorded_time', 'duration'),
            mks_st_col('size', 'mks_st_storage_mb'),
        ],
        'rows'    => $rows,
        'totals'  => $totals,
    ];
}

/**
 * Per rep: messages.
 */
function mks_st_report_sms(array $period, $ids)
{
    $CI   = &get_instance();
    $rows = [];

    foreach ($CI->db->query("SELECT e.staff_id, SUM(e.direction = 'incoming') AS received, SUM(e.direction = 'outgoing') AS sent,"
        . ' COUNT(DISTINCT e.number_key) AS numbers, SUM(e.rel_type IS NOT NULL) AS crm FROM ' . mks_st_events_table() . ' e '
        . mks_st_dash_where($period['from'], $period['to'], $ids, ['sms', 'whatsapp_message', 'notification']) . ' GROUP BY e.staff_id')->result_array() as $row) {
        $rows[(int) $row['staff_id']] = ['received' => (int) $row['received'], 'sent' => (int) $row['sent'],
            'total' => (int) $row['received'] + (int) $row['sent'], 'numbers' => (int) $row['numbers'], 'crm' => (int) $row['crm']];
    }

    $rows = mks_st_report_named($rows);

    return [
        'columns' => [
            mks_st_col('staff', 'mks_st_col_staff', 'text'),
            mks_st_col('received', 'mks_st_dir_received'),
            mks_st_col('sent', 'mks_st_dir_sent'),
            mks_st_col('total', 'mks_st_total'),
            mks_st_col('numbers', 'mks_st_kpi_numbers'),
            mks_st_col('crm', 'mks_st_kpi_in_crm'),
        ],
        'rows'    => $rows,
        'totals'  => mks_st_report_sum($rows, ['received', 'sent', 'total', 'numbers', 'crm']),
    ];
}

/**
 * Per phone: whether it kept reporting through the period.
 */
function mks_st_report_health(array $period, $ids)
{
    $from = strtotime($period['from'] . ' 00:00:00');
    $to   = strtotime($period['to'] . ' 23:59:59');
    $rows = [];

    foreach (mks_st_devices_list($ids) as $device) {
        if ($device['status'] === 'revoked' || $device['status'] === 'pending') {
            continue;
        }

        $health  = mks_st_decode($device['health']);
        $perms   = isset($health['permissions']) && is_array($health['permissions']) ? $health['permissions'] : [];
        $syncs   = 0;
        $refused = 0;
        $alerts  = 0;

        foreach (mks_st_decode($device['sync_log']) as $sync) {
            $at = strtotime($sync['t']);

            if ($at >= $from && $at <= $to) {
                $syncs++;
                $refused += (int) $sync['re'];
            }
        }

        foreach (mks_st_decode($device['alerts']) as $alert) {
            $at = strtotime($alert['t']);

            if ($at >= $from && $at <= $to) {
                $alerts++;
            }
        }

        $rows[] = [
            'device'    => $device['label'],
            'staff'     => trim($device['firstname'] . ' ' . $device['lastname']),
            'state'     => _l('mks_st_state_' . mks_st_device_state($device)),
            'app'       => (string) $device['app_version'],
            'last_seen' => $device['last_seen_at'],
            'syncs'     => $syncs,
            'refused'   => $refused,
            'missing'   => count(array_filter($perms, function ($granted) {
                return !$granted;
            })),
            'alerts'    => $alerts,
        ];
    }

    return [
        'columns' => [
            mks_st_col('device', 'mks_st_device_name', 'text'),
            mks_st_col('staff', 'mks_st_col_staff', 'text'),
            mks_st_col('state', 'mks_st_status', 'text'),
            mks_st_col('app', 'mks_st_app', 'text'),
            mks_st_col('last_seen', 'mks_st_last_seen', 'datetime'),
            mks_st_col('syncs', 'mks_st_syncs_logged'),
            mks_st_col('refused', 'mks_st_sync_rejected'),
            mks_st_col('missing', 'mks_st_permissions_missing_short'),
            mks_st_col('alerts', 'mks_st_alerts'),
        ],
        'rows'    => $rows,
        'note'    => _l('mks_st_rep_health_note'),
    ];
}

/**
 * Who played or downloaded which recording, from Perfex's activity log.
 * Managers only: the activity log is theirs.
 */
function mks_st_report_access(array $period, $ids)
{
    $CI   = &get_instance();
    $rows = [];

    if (mks_st_scope() === null) {
        foreach ($CI->db->query('SELECT date, staffid, description FROM ' . db_prefix() . "activity_log WHERE description LIKE 'Sales Track: recording %'"
            . " AND date >= '" . $period['from'] . " 00:00:00' AND date <= '" . $period['to'] . " 23:59:59' ORDER BY date DESC LIMIT 1000")->result_array() as $row) {
            if (!preg_match('/^Sales Track: recording (played|downloaded) \[#(\d+), (.*)\]$/', $row['description'], $m)) {
                continue;
            }

            $rows[] = [
                'time'      => $row['date'],
                'staff'     => $row['staffid'],
                'action'    => _l($m[1] === 'played' ? 'mks_st_access_played' : 'mks_st_access_downloaded'),
                'recording' => '#' . $m[2],
                'details'   => $m[3],
            ];
        }
    }

    return [
        'columns' => [
            mks_st_col('time', 'mks_st_col_time', 'datetime'),
            mks_st_col('staff', 'mks_st_col_staff', 'text'),
            mks_st_col('action', 'mks_st_access_action', 'text'),
            mks_st_col('recording', 'mks_st_access_recording', 'text'),
            mks_st_col('details', 'mks_st_access_details', 'text'),
        ],
        'rows'    => $rows,
        'note'    => _l('mks_st_rep_access_note'),
    ];
}

/* =========================================================================
 * FORMATTING AND EXPORT
 * ====================================================================== */

/**
 * A value for the screen or an email.
 *
 * @param  mixed  $value
 * @param  string $type
 *
 * @return string
 */
function mks_st_report_cell($value, $type)
{
    if ($value === null || $value === '') {
        return '-';
    }

    switch ($type) {
        case 'number':
            return mks_st_number_label($value);

        case 'percent':
            return rtrim(rtrim(number_format((float) $value, 1), '0'), '.') . '%';

        case 'duration':
            return mks_st_duration_label((int) $value);

        case 'datetime':
            return _dt($value);

        case 'money':
            return function_exists('app_format_money') && function_exists('get_base_currency') ? app_format_money((float) $value, get_base_currency()) : number_format((float) $value, 2);
    }

    return (string) $value;
}

/**
 * A value for a spreadsheet: numbers stay numbers, durations become minutes.
 *
 * @param  mixed  $value
 * @param  string $type
 *
 * @return mixed
 */
function mks_st_report_raw($value, $type)
{
    if ($value === null) {
        return '';
    }

    switch ($type) {
        case 'duration':
            return round((int) $value / 60, 1);

        case 'number':
        case 'percent':
        case 'money':
            return is_numeric($value) ? $value + 0 : $value;

        case 'datetime':
            return date('Y-m-d H:i', strtotime($value));
    }

    return (string) $value;
}

/**
 * Header and body rows for export.
 *
 * @param  array $report
 *
 * @return array rows of plain values, header first
 */
function mks_st_report_matrix(array $report)
{
    $header = [];

    foreach ($report['columns'] as $column) {
        $header[] = $column['label'] . ($column['type'] === 'duration' ? ' (' . _l('mks_st_unit_minutes') . ')' : ($column['type'] === 'percent' ? ' (%)' : ''));
    }

    $out = [$header];

    foreach (array_merge($report['rows'], $report['totals'] ? [$report['totals']] : []) as $row) {
        $line = [];

        foreach ($report['columns'] as $column) {
            $line[] = mks_st_report_raw(isset($row[$column['key']]) ? $row[$column['key']] : null, $column['type']);
        }

        $out[] = $line;
    }

    return $out;
}

/**
 * CSV for Excel: UTF-8 with a byte order mark, and no cell can start a
 * formula.
 *
 * @param  array $matrix
 *
 * @return string
 */
function mks_st_report_csv(array $matrix)
{
    $handle = fopen('php://temp', 'w+');
    fwrite($handle, "\xEF\xBB\xBF");

    foreach ($matrix as $row) {
        fputcsv($handle, array_map('mks_st_report_safe_text', $row), ',', '"', '\\');
    }

    rewind($handle);
    $csv = stream_get_contents($handle);
    fclose($handle);

    return $csv;
}

/**
 * Text that a spreadsheet would read as a formula gets a leading quote.
 *
 * @param  mixed $value
 *
 * @return mixed
 */
function mks_st_report_safe_text($value)
{
    if (is_string($value) && $value !== '' && in_array($value[0], ['=', '+', '-', '@', "\t", "\r"], true) && !is_numeric($value)) {
        return "'" . $value;
    }

    return $value;
}

/**
 * A minimal Excel workbook: one sheet, a bold header row, numbers as numbers.
 *
 * @param  array  $matrix
 * @param  string $sheet
 *
 * @return string|false the .xlsx bytes
 */
function mks_st_report_xlsx(array $matrix, $sheet)
{
    if (!class_exists('ZipArchive')) {
        return false;
    }

    $xml = function ($value) {
        return htmlspecialchars((string) $value, ENT_QUOTES | ENT_XML1, 'UTF-8');
    };

    $rowsXml = '';

    foreach (array_values($matrix) as $r => $row) {
        $rowsXml .= '<row r="' . ($r + 1) . '">';

        foreach (array_values($row) as $c => $value) {
            $ref = mks_st_xlsx_column($c) . ($r + 1);

            if (is_int($value) || is_float($value)) {
                $rowsXml .= '<c r="' . $ref . '"' . ($r === 0 ? ' s="1"' : '') . '><v>' . $value . '</v></c>';
            } else {
                $rowsXml .= '<c r="' . $ref . '" t="inlineStr"' . ($r === 0 ? ' s="1"' : '') . '><is><t xml:space="preserve">'
                    . $xml(mks_st_report_safe_text($value)) . '</t></is></c>';
            }
        }

        $rowsXml .= '</row>';
    }

    $file = tempnam(sys_get_temp_dir(), 'mks_st_xlsx_');
    $zip  = new ZipArchive();

    if ($zip->open($file, ZipArchive::OVERWRITE) !== true) {
        return false;
    }

    $zip->addFromString('[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        . '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        . '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        . '<Default Extension="xml" ContentType="application/xml"/>'
        . '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        . '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        . '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        . '</Types>');
    $zip->addFromString('_rels/.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        . '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        . '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        . '</Relationships>');
    $zip->addFromString('xl/workbook.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        . '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        . '<sheets><sheet name="' . $xml(mb_substr(preg_replace('/[\\\\\/\?\*\[\]:]/', ' ', $sheet), 0, 31, 'UTF-8')) . '" sheetId="1" r:id="rId1"/></sheets></workbook>');
    $zip->addFromString('xl/_rels/workbook.xml.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        . '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        . '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
        . '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        . '</Relationships>');
    $zip->addFromString('xl/styles.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        . '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        . '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
        . '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>'
        . '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
        . '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        . '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>'
        . '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
        . '</styleSheet>');
    $zip->addFromString('xl/worksheets/sheet1.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        . '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>' . $rowsXml . '</sheetData></worksheet>');
    $zip->close();

    $bytes = file_get_contents($file);
    @unlink($file);

    return $bytes;
}

/**
 * A, B, ..., Z, AA, AB, ...
 *
 * @param  int $index zero based
 *
 * @return string
 */
function mks_st_xlsx_column($index)
{
    $name = '';

    for ($n = (int) $index + 1; $n > 0; $n = (int) (($n - 1) / 26)) {
        $name = chr(65 + ($n - 1) % 26) . $name;
    }

    return $name;
}

/* =========================================================================
 * SCHEDULED EMAIL REPORTS
 * ====================================================================== */

/**
 * Which scheduled reports are due right now, and the period each covers.
 *
 * @param  int   $now
 * @param  array $sent     kind => last date sent (Y-m-d)
 * @param  array $settings
 *
 * @return array kind => period [from, to]
 */
function mks_st_reports_due($now, array $sent, array $settings)
{
    $today = date('Y-m-d', $now);
    $clock = date('H:i', $now);
    $due   = [];

    if (!empty($settings['report_daily']) && $clock >= $settings['report_daily_time'] && (!isset($sent['daily']) || $sent['daily'] !== $today)) {
        $due['daily'] = ['from' => $today, 'to' => $today];
    }

    $days = ['mon' => 1, 'tue' => 2, 'wed' => 3, 'thu' => 4, 'fri' => 5, 'sat' => 6, 'sun' => 7];

    if (!empty($settings['report_weekly']) && (int) date('N', $now) === $days[$settings['report_weekly_day']]
        && $clock >= $settings['report_weekly_time'] && (!isset($sent['weekly']) || $sent['weekly'] !== $today)) {
        $due['weekly'] = ['from' => date('Y-m-d', strtotime('-7 days', strtotime($today))), 'to' => date('Y-m-d', strtotime('-1 day', strtotime($today)))];
    }

    if (!empty($settings['report_monthly']) && date('j', $now) === '1' && $clock >= $settings['report_monthly_time']
        && (!isset($sent['monthly']) || $sent['monthly'] !== $today)) {
        $first          = strtotime('first day of last month', strtotime($today));
        $due['monthly'] = ['from' => date('Y-m-01', $first), 'to' => date('Y-m-t', $first)];
    }

    return $due;
}

/**
 * Send whatever is due. Called from the cron run; records what went so a
 * report is sent once per period.
 *
 * @return int emails sent
 */
function mks_st_reports_run()
{
    $sent     = json_decode((string) get_option('mks_sales_track_reports_sent'), true);
    $sent     = is_array($sent) ? $sent : [];
    $settings = mks_st_settings();
    $coaching = mks_st_enabled('ai_enabled') && mks_st_enabled('ai_coaching');
    $weekly   = !empty($settings['report_weekly']);

    // Weekly coaching keeps the weekly report's day and time, even when the
    // weekly report itself is switched off.
    $settings['report_weekly'] = $weekly || $coaching ? 1 : 0;

    $due = mks_st_reports_due(time(), $sent, $settings);
    $n   = 0;

    foreach ($due as $kind => $range) {
        // Recorded first: a slow mail server must not send a report twice.
        $sent[$kind] = date('Y-m-d');
        mks_st_option_put('mks_sales_track_reports_sent', json_encode($sent), 0);

        if ($kind !== 'weekly' || $weekly) {
            foreach (mks_st_report_recipients() as $recipient) {
                $n += mks_st_report_email($kind, $range, $recipient['staff_id'], $recipient['ids']) ? 1 : 0;
            }
        }

        if ($kind === 'weekly' && $coaching) {
            require_once __DIR__ . '/mks_sales_track_ai_helper.php';
            $n += mks_st_ai_coaching($range);
        }
    }

    return $n;
}

/**
 * Who receives scheduled reports, each with the people their report covers.
 *
 * @return array [staff_id, ids]
 */
function mks_st_report_recipients()
{
    $CI   = &get_instance();
    $to   = (string) mks_st_setting('report_to', 'both');
    $out  = [];
    $seen = [];

    if ($to !== 'team_leads') {
        foreach (mks_st_managers() as $id) {
            $out[]     = ['staff_id' => $id, 'ids' => null];
            $seen[$id] = true;
        }
    }

    if ($to !== 'managers') {
        $leads = $CI->db->query('SELECT DISTINCT sp.staff_id FROM ' . db_prefix() . 'staff_permissions sp JOIN ' . db_prefix() . 'staff s ON s.staffid = sp.staff_id AND s.active = 1'
            . " WHERE sp.feature = 'mks_sales_track' AND sp.capability = 'view_team'")->result_array();

        foreach ($leads as $row) {
            $id = (int) $row['staff_id'];

            if (!isset($seen[$id])) {
                $out[]     = ['staff_id' => $id, 'ids' => array_values(array_unique(array_merge([$id], mks_st_team_ids($id))))];
                $seen[$id] = true;
            }
        }
    }

    if (mks_st_enabled('report_reps')) {
        $reps = $CI->db->query('SELECT DISTINCT d.staff_id FROM ' . mks_st_devices_table() . ' d JOIN ' . db_prefix() . 'staff s ON s.staffid = d.staff_id AND s.active = 1'
            . " WHERE d.status IN ('active', 'paused')")->result_array();

        foreach ($reps as $row) {
            $id = (int) $row['staff_id'];

            if (!isset($seen[$id])) {
                $out[]     = ['staff_id' => $id, 'ids' => [$id]];
                $seen[$id] = true;
            }
        }
    }

    return $out;
}

/**
 * The email body for one person: totals, the team table and the callbacks.
 *
 * @param  string     $kind daily, weekly or monthly
 * @param  array      $range from, to
 * @param  int[]|null $ids
 *
 * @return array subject, html, empty
 */
function mks_st_report_email_body($kind, array $range, $ids)
{
    $period = ['from' => $range['from'], 'to' => $range['to'], 'days' => (int) round((strtotime($range['to']) - strtotime($range['from'])) / 86400) + 1];
    $period['single_day'] = $period['days'] === 1;

    $team      = mks_st_report('team', $period, $ids);
    $callbacks = mks_st_report('callbacks', $period, $ids);
    $totals    = $team['totals'] ?: [];
    $label     = $range['from'] === $range['to'] ? _d($range['from']) : _d($range['from']) . ' - ' . _d($range['to']);
    $subject   = _l('mks_st_mail_subject_' . $kind, $label);

    $cell = 'padding:8px 10px;border-bottom:1px solid #e5e7eb;font-size:13px;text-align:left;';
    $head = 'padding:8px 10px;background:#f8fafc;border-bottom:1px solid #e5e7eb;font-size:12px;color:#64748b;text-align:left;';

    $kpis = [
        _l('mks_st_kpi_calls')     => mks_st_number_label(isset($totals['calls']) ? $totals['calls'] : 0),
        _l('mks_st_kpi_connected') => mks_st_number_label(isset($totals['connected']) ? $totals['connected'] : 0),
        _l('mks_st_kpi_talk_time') => mks_st_duration_label(isset($totals['talk']) ? $totals['talk'] : 0),
        _l('mks_st_kpi_missed')    => mks_st_number_label(isset($totals['missed']) ? $totals['missed'] : 0),
    ];

    $html = '<div style="font-family:Arial,Helvetica,sans-serif;color:#0f172a;max-width:760px">'
        . '<h2 style="margin:0 0 4px;font-size:20px">' . e($subject) . '</h2>'
        . '<p style="margin:0 0 18px;color:#64748b;font-size:13px">' . e(get_option('companyname')) . '</p><table style="border-collapse:collapse;margin:0 0 20px"><tr>';

    foreach ($kpis as $name => $value) {
        $html .= '<td style="padding:10px 16px;border:1px solid #e5e7eb;border-radius:8px"><div style="font-size:12px;color:#64748b">' . e($name)
            . '</div><div style="font-size:20px;font-weight:bold">' . e($value) . '</div></td>';
    }

    $html .= '</tr></table>';

    $sections = [[_l('mks_st_rep_team'), $team, ['staff', 'calls', 'connected', 'rate', 'talk', 'missed', 'clients', 'target']],
        [_l('mks_st_rep_callbacks'), $callbacks, ['staff', 'missed', 'returned', 'rate', 'open', 'wait']]];

    foreach ($sections as $section) {
        list($title, $report, $keys) = $section;

        if (!$report['rows']) {
            continue;
        }

        $columns = array_values(array_filter($report['columns'], function ($column) use ($keys) {
            return in_array($column['key'], $keys, true);
        }));

        $html .= '<h3 style="margin:18px 0 8px;font-size:15px">' . e($title) . '</h3><table style="border-collapse:collapse;width:100%"><tr>';

        foreach ($columns as $column) {
            $html .= '<th style="' . $head . '">' . e($column['label']) . '</th>';
        }

        $html .= '</tr>';

        foreach (array_slice($report['rows'], 0, 25) as $row) {
            $html .= '<tr>';

            foreach ($columns as $column) {
                $html .= '<td style="' . $cell . '">' . e(mks_st_report_cell(isset($row[$column['key']]) ? $row[$column['key']] : null, $column['type'])) . '</td>';
            }

            $html .= '</tr>';
        }

        $html .= '</table>';
    }

    $html .= '<p style="margin:22px 0 0"><a href="' . admin_url(MKS_SALES_TRACK_MODULE_NAME) . '" style="color:#2563eb">' . e(_l('mks_st_mail_open')) . '</a></p></div>';

    $activity = (isset($totals['calls']) ? $totals['calls'] : 0) + (isset($totals['whatsapp']) ? $totals['whatsapp'] : 0) + (isset($totals['sms']) ? $totals['sms'] : 0);

    return ['subject' => $subject, 'html' => $html, 'empty' => $activity === 0];
}

/**
 * Build and send one person's report through the CRM's own SMTP.
 *
 * @param  string     $kind
 * @param  array      $range
 * @param  int        $staffId
 * @param  int[]|null $ids
 *
 * @return bool sent
 */
function mks_st_report_email($kind, array $range, $staffId, $ids)
{
    $CI    = &get_instance();
    $staff = $CI->db->select('email')->where('staffid', (int) $staffId)->where('active', 1)->get(db_prefix() . 'staff')->row();

    if (!$staff || $staff->email === '') {
        return false;
    }

    $body = mks_st_report_email_body($kind, $range, $ids);

    if ($body['empty'] && mks_st_enabled('report_skip_empty')) {
        return false;
    }

    $CI->load->model('emails_model');

    return (bool) $CI->emails_model->send_simple_email($staff->email, $body['subject'], $body['html']);
}
