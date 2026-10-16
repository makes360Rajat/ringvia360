<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - dashboard analytics.
 *
 * Loaded on demand by the dashboard only. Every query goes through
 * mks_st_dash_where(), which applies the viewer's scope, the team and staff
 * filters and the internal-calls rule, so no figure on the dashboard can
 * describe activity the viewer may not see.
 *
 * Charts are drawn here as plain SVG: the Chart.js Perfex bundles is 2.4.0,
 * and a server-drawn chart needs no script, prints cleanly and cannot fail to
 * load. Every label is escaped; hover text uses native <title> elements.
 */

/* =========================================================================
 * PERIODS AND FILTERS
 * ====================================================================== */

/**
 * @return array value => language key
 */
function mks_st_dash_ranges()
{
    return [
        'today'      => 'mks_st_range_today',
        'yesterday'  => 'mks_st_range_yesterday',
        '7d'         => 'mks_st_range_7d',
        '30d'        => 'mks_st_range_30d',
        'month'      => 'mks_st_range_month',
        'last_month' => 'mks_st_range_last_month',
    ];
}

/**
 * A range as a period, with the equal period before it for comparison.
 *
 * @param  string   $range
 * @param  int|null $now   a timestamp, for tests
 *
 * @return array from, to, prev_from, prev_to (Y-m-d), days, single_day
 */
function mks_st_dash_period($range, $now = null)
{
    $now   = $now === null ? time() : (int) $now;
    $today = strtotime(date('Y-m-d', $now));
    $day   = 86400;

    switch ($range) {
        case 'yesterday':
            $from = $today - $day;
            $to   = $from;
            break;

        case '7d':
            $from = strtotime('-6 days', $today);
            $to   = $today;
            break;

        case '30d':
            $from = strtotime('-29 days', $today);
            $to   = $today;
            break;

        case 'month':
            $from = strtotime(date('Y-m-01', $today));
            $to   = $today;
            break;

        case 'last_month':
            $from = strtotime(date('Y-m-01', strtotime('first day of last month', $today)));
            $to   = strtotime(date('Y-m-t', $from));
            break;

        default:
            $from = $today;
            $to   = $today;
    }

    $days = (int) round(($to - $from) / $day) + 1;

    if ($range === 'last_month') {
        $prevFrom = strtotime(date('Y-m-01', strtotime('first day of last month', $from)));
        $prevTo   = strtotime(date('Y-m-t', $prevFrom));
    } else {
        $prevTo   = strtotime('-1 day', $from);
        $prevFrom = strtotime('-' . ($days - 1) . ' days', $prevTo);
    }

    return [
        'from'       => date('Y-m-d', $from),
        'to'         => date('Y-m-d', $to),
        'prev_from'  => date('Y-m-d', $prevFrom),
        'prev_to'    => date('Y-m-d', $prevTo),
        'days'       => $days,
        'single_day' => $days === 1,
    ];
}

/**
 * Departments the viewer may filter by: all of them for those who see
 * everybody, their own for team leads, none for reps.
 *
 * @return array id => name
 */
function mks_st_dash_teams()
{
    $scope = mks_st_scope();

    if ($scope !== null && count((array) $scope) <= 1) {
        return [];
    }

    $CI = &get_instance();
    $p  = db_prefix();

    $sql = 'SELECT d.departmentid, d.name FROM ' . $p . 'departments d';

    if ($scope !== null) {
        $sql .= ' WHERE d.departmentid IN (SELECT departmentid FROM ' . $p . 'staff_departments WHERE staffid = ' . (int) get_staff_user_id() . ')';
    }

    $out = [];

    foreach ($CI->db->query($sql . ' ORDER BY d.name')->result_array() as $row) {
        $out[(int) $row['departmentid']] = $row['name'];
    }

    return $out;
}

/**
 * The dashboard's filters, validated against what the viewer may see.
 *
 * @param  array $input range, team, staff
 *
 * @return array range, team, staff
 */
function mks_st_dash_filters(array $input)
{
    $range = isset($input['range']) ? (string) $input['range'] : 'today';
    $team  = isset($input['team']) ? (int) $input['team'] : 0;
    $staff = isset($input['staff']) ? (int) $input['staff'] : 0;

    return [
        'range' => array_key_exists($range, mks_st_dash_ranges()) ? $range : 'today',
        'team'  => ($team > 0 && array_key_exists($team, mks_st_dash_teams())) ? $team : 0,
        'staff' => ($staff > 0 && mks_st_scope_allows($staff)) ? $staff : 0,
    ];
}

/**
 * The staff ids the dashboard describes: the viewer's scope narrowed by the
 * team and staff filters. null means everybody.
 *
 * @param  array $filters
 *
 * @return int[]|null
 */
function mks_st_dash_staff_ids(array $filters)
{
    $ids = mks_st_scope();

    if ($ids === false) {
        return [];
    }

    if ($filters['team'] > 0) {
        $CI      = &get_instance();
        $members = array_map('intval', array_column($CI->db->select('staffid')
            ->where('departmentid', (int) $filters['team'])
            ->get(db_prefix() . 'staff_departments')->result_array(), 'staffid'));

        $ids = $ids === null ? $members : array_values(array_intersect($ids, $members));
    }

    if ($filters['staff'] > 0) {
        $ids = ($ids === null || in_array($filters['staff'], $ids, true)) ? [$filters['staff']] : [];
    }

    return $ids;
}

/**
 * WHERE for one period over the given people and kinds.
 *
 * @param  string     $from  Y-m-d
 * @param  string     $to    Y-m-d
 * @param  int[]|null $ids
 * @param  array      $kinds
 *
 * @return string
 */
function mks_st_dash_where($from, $to, $ids, array $kinds = ['call', 'whatsapp_call', 'sms', 'whatsapp_message', 'notification'])
{
    $where = "WHERE e.occurred_at >= '" . $from . " 00:00:00' AND e.occurred_at <= '" . $to . " 23:59:59'"
        . " AND e.kind IN ('" . implode("', '", $kinds) . "') "
        . mks_st_scope_sql('e.staff_id', $ids);

    if (mks_st_enabled('exclude_internal')) {
        $where .= " AND (e.rel_type IS NULL OR e.rel_type <> 'staff')";
    }

    return $where;
}

/* =========================================================================
 * FIGURES
 * ====================================================================== */

/**
 * Totals for one period.
 *
 * @return array
 */
function mks_st_dash_totals($from, $to, $ids)
{
    $CI = &get_instance();
    $t  = mks_st_connected_seconds();

    $row = $CI->db->query("SELECT SUM(e.kind = 'call') AS calls,"
        . " SUM(e.kind = 'call' AND e.direction = 'incoming') AS incoming,"
        . " SUM(e.kind = 'call' AND e.direction = 'outgoing') AS outgoing,"
        . " SUM(e.kind = 'call' AND e.duration >= " . $t . ') AS connected,'
        . " SUM(e.kind = 'call' AND e.direction = 'outgoing' AND e.duration >= " . $t . ') AS out_connected,'
        . " SUM(e.kind = 'call' AND e.direction = 'incoming' AND e.duration >= " . $t . ') AS in_connected,'
        . " SUM(e.kind = 'call' AND e.direction = 'outgoing' AND e.duration < " . $t . ') AS unanswered,'
        . " SUM(e.kind = 'call' AND e.direction = 'missed') AS missed,"
        . " SUM(e.kind = 'call' AND e.direction = 'rejected') AS rejected,"
        . " COALESCE(SUM(CASE WHEN e.kind = 'call' THEN e.duration ELSE 0 END), 0) AS talk,"
        . " COUNT(DISTINCT CASE WHEN e.kind = 'call' THEN e.number_key END) AS clients,"
        . " SUM(e.kind = 'whatsapp_call') AS whatsapp, SUM(e.kind IN ('sms', 'whatsapp_message', 'notification')) AS sms"
        . ' FROM ' . mks_st_events_table() . ' e ' . mks_st_dash_where($from, $to, $ids))->row_array();

    $out = [];

    foreach ((array) $row as $key => $value) {
        $out[$key] = (int) $value;
    }

    return $out;
}

/**
 * The KPI tiles, each compared with the period before.
 *
 * @param  array      $period
 * @param  int[]|null $ids
 *
 * @return array tiles and the current totals
 */
function mks_st_dash_kpis(array $period, $ids)
{
    $now  = mks_st_dash_totals($period['from'], $period['to'], $ids);
    $then = mks_st_dash_totals($period['prev_from'], $period['prev_to'], $ids);

    $tile = function ($key, $label, $value, $hint, $icon, $tone, $current, $previous, $lowerIsBetter = false) {
        return mks_st_tile($key, $label, $value, $hint, $icon, $tone) + ['delta' => mks_st_dash_delta($current, $previous, $lowerIsBetter)];
    };

    $tiles = [
        $tile('calls', _l('mks_st_kpi_calls'), mks_st_number_label($now['calls']), mks_st_split_hint($now['incoming'], $now['outgoing']),
            'fa-solid fa-phone', 'blue', $now['calls'], $then['calls']),
        $tile('connected', _l('mks_st_kpi_connected'), mks_st_number_label($now['connected']), mks_st_share_hint($now['connected'], $now['calls']),
            'fa-solid fa-circle-check', 'green', $now['connected'], $then['connected']),
        $tile('talk', _l('mks_st_kpi_talk_time'), mks_st_duration_label($now['talk']), mks_st_average_hint($now['talk'], $now['connected']),
            'fa-solid fa-clock', 'violet', $now['talk'], $then['talk']),
        $tile('missed', _l('mks_st_kpi_missed'), mks_st_number_label($now['missed'] + $now['rejected']), '',
            'fa-solid fa-phone-slash', ($now['missed'] + $now['rejected']) > 0 ? 'red' : 'slate', $now['missed'] + $now['rejected'], $then['missed'] + $then['rejected'], true),
        $tile('clients', _l('mks_st_kpi_clients'), mks_st_number_label($now['clients']), '',
            'fa-solid fa-users', 'amber', $now['clients'], $then['clients']),
        $tile('unanswered', _l('mks_st_kpi_unanswered'), mks_st_number_label($now['unanswered']), mks_st_share_hint($now['unanswered'], $now['outgoing']),
            'fa-solid fa-arrow-up', 'slate', $now['unanswered'], $then['unanswered'], true),
        $tile('whatsapp', _l('mks_st_kpi_whatsapp_calls'), mks_st_number_label($now['whatsapp']), '',
            'fa-brands fa-whatsapp', 'green', $now['whatsapp'], $then['whatsapp']),
        $tile('sms', _l('mks_st_kpi_messages'), mks_st_number_label($now['sms']), '',
            'fa-solid fa-message', 'amber', $now['sms'], $then['sms']),
    ];

    return ['tiles' => $tiles, 'totals' => $now];
}

/**
 * Change against the previous period.
 *
 * @return array|null direction up|down|flat, label, good
 */
function mks_st_dash_delta($current, $previous, $lowerIsBetter = false)
{
    $current  = (int) $current;
    $previous = (int) $previous;

    if ($current === 0 && $previous === 0) {
        return null;
    }

    if ($previous === 0) {
        return ['direction' => 'up', 'label' => _l('mks_st_delta_new'), 'good' => !$lowerIsBetter];
    }

    $change = (int) round(($current - $previous) * 100 / $previous);

    if ($change === 0) {
        return ['direction' => 'flat', 'label' => _l('mks_st_delta_same'), 'good' => true];
    }

    return [
        'direction' => $change > 0 ? 'up' : 'down',
        'label'     => _l('mks_st_delta_pct', (string) abs($change)),
        'good'      => $lowerIsBetter ? $change < 0 : $change > 0,
    ];
}

/**
 * Calls per day, or per hour for a single day, split connected and not.
 *
 * @param  array      $period
 * @param  int[]|null $ids
 *
 * @return array buckets: label, full, values [connected, other]
 */
function mks_st_dash_trend(array $period, $ids)
{
    $CI    = &get_instance();
    $t     = mks_st_connected_seconds();
    $group = $period['single_day'] ? 'HOUR(e.occurred_at)' : 'DATE(e.occurred_at)';

    $rows = $CI->db->query('SELECT ' . $group . ' AS bucket, COUNT(*) AS calls, SUM(e.duration >= ' . $t . ') AS connected'
        . ' FROM ' . mks_st_events_table() . ' e ' . mks_st_dash_where($period['from'], $period['to'], $ids, ['call'])
        . ' GROUP BY bucket')->result_array();

    $found = [];

    foreach ($rows as $row) {
        $found[(string) $row['bucket']] = [(int) $row['connected'], (int) $row['calls'] - (int) $row['connected']];
    }

    $buckets = [];

    if ($period['single_day']) {
        $hours = array_keys($found);
        $first = $hours ? min(8, (int) min($hours)) : 8;
        $last  = $hours ? max(20, (int) max($hours)) : 20;

        for ($h = $first; $h <= $last; $h++) {
            $values    = isset($found[(string) $h]) ? $found[(string) $h] : [0, 0];
            $buckets[] = ['label' => (string) $h, 'full' => str_pad((string) $h, 2, '0', STR_PAD_LEFT) . ':00', 'values' => $values];
        }

        return $buckets;
    }

    for ($day = strtotime($period['from']); $day <= strtotime($period['to']); $day = strtotime('+1 day', $day)) {
        $key       = date('Y-m-d', $day);
        $buckets[] = [
            'label'  => $period['days'] <= 7 ? date('D', $day) : date('j', $day),
            'full'   => date('D j M', $day),
            'values' => isset($found[$key]) ? $found[$key] : [0, 0],
        ];
    }

    return $buckets;
}

/**
 * How the calls ended, for the donut.
 *
 * @param  array $totals from mks_st_dash_totals()
 *
 * @return array label, value, tone
 */
function mks_st_dash_mix(array $totals)
{
    $segments = [
        ['label' => _l('mks_st_mix_out_connected'), 'value' => $totals['out_connected'], 'tone' => 'blue'],
        ['label' => _l('mks_st_mix_in_connected'), 'value' => $totals['in_connected'], 'tone' => 'green'],
        ['label' => _l('mks_st_dir_unanswered'), 'value' => $totals['unanswered'], 'tone' => 'amber'],
        ['label' => _l('mks_st_dir_missed'), 'value' => $totals['missed'], 'tone' => 'red'],
        ['label' => _l('mks_st_dir_rejected'), 'value' => $totals['rejected'], 'tone' => 'violet'],
    ];

    $known = array_sum(array_column($segments, 'value'));

    if ($totals['calls'] > $known) {
        $segments[] = ['label' => _l('mks_st_mix_other'), 'value' => $totals['calls'] - $known, 'tone' => 'slate'];
    }

    return array_values(array_filter($segments, function ($segment) {
        return $segment['value'] > 0;
    }));
}

/**
 * Calls by weekday and hour. A short period has too little to show a
 * pattern, so anything under a week uses the last thirty days instead.
 *
 * @param  array      $period
 * @param  int[]|null $ids
 *
 * @return array matrix [weekday 0-6][hour] => calls, connected; hours; label; best
 */
function mks_st_dash_heatmap(array $period, $ids)
{
    $CI   = &get_instance();
    $t    = mks_st_connected_seconds();
    $from = $period['from'];
    $to   = $period['to'];
    $wide = false;

    if ($period['days'] < 7) {
        $to   = date('Y-m-d');
        $from = date('Y-m-d', strtotime('-29 days'));
        $wide = true;
    }

    $rows = $CI->db->query('SELECT WEEKDAY(e.occurred_at) AS dow, HOUR(e.occurred_at) AS hr, COUNT(*) AS calls,'
        . ' SUM(e.duration >= ' . $t . ') AS connected'
        . ' FROM ' . mks_st_events_table() . ' e ' . mks_st_dash_where($from, $to, $ids, ['call'])
        . ' GROUP BY dow, hr')->result_array();

    $matrix = [];
    $byHour = [];
    $first  = 9;
    $last   = 19;

    foreach ($rows as $row) {
        $dow = (int) $row['dow'];
        $hr  = (int) $row['hr'];

        $matrix[$dow][$hr] = ['calls' => (int) $row['calls'], 'connected' => (int) $row['connected']];

        $first = min($first, $hr);
        $last  = max($last, $hr);

        if (!isset($byHour[$hr])) {
            $byHour[$hr] = ['calls' => 0, 'connected' => 0];
        }

        $byHour[$hr]['calls'] += (int) $row['calls'];
        $byHour[$hr]['connected'] += (int) $row['connected'];
    }

    // The best hour needs enough calls to mean something.
    $best = null;

    foreach ($byHour as $hr => $cell) {
        if ($cell['calls'] < 5) {
            continue;
        }

        $rate = $cell['connected'] / $cell['calls'];

        if ($best === null || $rate > $best['rate']) {
            $best = ['hour' => $hr, 'rate' => $rate, 'calls' => $cell['calls']];
        }
    }

    return [
        'matrix' => $matrix,
        'hours'  => range($first, $last),
        'wide'   => $wide,
        'best'   => $best,
    ];
}

/**
 * One row per person: activity, plus their targets for the period.
 *
 * People with a phone are listed even on a day they made no calls, which is
 * exactly when a manager needs to see them.
 *
 * @param  array      $period
 * @param  int[]|null $ids
 * @param  string     $sort calls, connected or talk
 *
 * @return array
 */
function mks_st_dash_leaderboard(array $period, $ids, $sort)
{
    $CI = &get_instance();
    $t  = mks_st_connected_seconds();
    $p  = db_prefix();

    $rows = $CI->db->query("SELECT e.staff_id, SUM(e.kind = 'call') AS calls,"
        . " SUM(e.kind = 'call' AND e.direction = 'outgoing') AS outgoing,"
        . " SUM(e.kind = 'call' AND e.duration >= " . $t . ') AS connected,'
        . " SUM(e.kind = 'call' AND e.direction IN ('missed', 'rejected')) AS missed,"
        . " COALESCE(SUM(CASE WHEN e.kind = 'call' THEN e.duration ELSE 0 END), 0) AS talk,"
        . " COUNT(DISTINCT CASE WHEN e.kind = 'call' THEN e.number_key END) AS clients,"
        . " SUM(e.kind = 'whatsapp_call') AS whatsapp, SUM(e.kind IN ('sms', 'whatsapp_message', 'notification')) AS sms"
        . ' FROM ' . mks_st_events_table() . ' e ' . mks_st_dash_where($period['from'], $period['to'], $ids)
        . ' GROUP BY e.staff_id')->result_array();

    $people = [];

    foreach ($rows as $row) {
        $people[(int) $row['staff_id']] = array_map('intval', $row);
    }

    $withPhone = $CI->db->query("SELECT DISTINCT d.staff_id FROM " . mks_st_devices_table() . " d"
        . ' JOIN ' . $p . 'staff s ON s.staffid = d.staff_id AND s.active = 1'
        . " WHERE d.status IN ('active', 'paused') " . mks_st_scope_sql('d.staff_id', $ids))->result_array();

    foreach ($withPhone as $row) {
        $id = (int) $row['staff_id'];

        if (!isset($people[$id])) {
            $people[$id] = ['staff_id' => $id, 'calls' => 0, 'outgoing' => 0, 'connected' => 0, 'missed' => 0, 'talk' => 0, 'clients' => 0, 'whatsapp' => 0, 'sms' => 0];
        }
    }

    if (!$people) {
        return [];
    }

    $names = [];

    foreach ($CI->db->select('staffid, firstname, lastname')->where_in('staffid', array_keys($people))->get($p . 'staff')->result_array() as $row) {
        $names[(int) $row['staffid']] = trim($row['firstname'] . ' ' . $row['lastname']);
    }

    $workdays = mks_st_working_days_between($period['from'], $period['to']);

    foreach ($people as $id => $person) {
        $target = mks_st_target_for($id);

        $people[$id]['name']   = isset($names[$id]) ? $names[$id] : _l('mks_st_removed_staff');
        $people[$id]['target'] = [
            'calls'     => $target['calls'] * $workdays,
            'connected' => $target['connected'] * $workdays,
            'talk'      => $target['talk'] * $workdays,
        ];
    }

    $sort = in_array($sort, ['calls', 'connected', 'talk'], true) ? $sort : 'calls';

    uasort($people, function ($a, $b) use ($sort) {
        return $b[$sort] === $a[$sort] ? strcmp($a['name'], $b['name']) : $b[$sort] - $a[$sort];
    });

    return array_values($people);
}

/**
 * Targets against what was done, for one person or a whole team.
 *
 * @param  array $leaderboard
 * @param  array $period
 *
 * @return array|null rows of metric => done, target; on_target count; null when no target is set
 */
function mks_st_dash_targets(array $leaderboard, array $period)
{
    $sum = ['calls' => [0, 0], 'connected' => [0, 0], 'talk' => [0, 0]];
    $met = 0;
    $set = 0;

    foreach ($leaderboard as $person) {
        foreach ($sum as $metric => $pair) {
            $sum[$metric][0] += $person[$metric];
            $sum[$metric][1] += $person['target'][$metric];
        }

        if ($person['target']['calls'] > 0) {
            $set++;

            if ($person['calls'] >= $person['target']['calls']) {
                $met++;
            }
        }
    }

    if ($sum['calls'][1] === 0 && $sum['connected'][1] === 0 && $sum['talk'][1] === 0) {
        return null;
    }

    return [
        'rows'     => [
            'calls'     => ['label' => _l('mks_st_kpi_calls'), 'done' => $sum['calls'][0], 'target' => $sum['calls'][1], 'time' => false],
            'connected' => ['label' => _l('mks_st_kpi_connected'), 'done' => $sum['connected'][0], 'target' => $sum['connected'][1], 'time' => false],
            'talk'      => ['label' => _l('mks_st_kpi_talk_time'), 'done' => $sum['talk'][0], 'target' => $sum['talk'][1], 'time' => true],
        ],
        'on_target' => $met,
        'with_target' => $set,
        'workdays'  => mks_st_working_days_between($period['from'], $period['to']),
    ];
}

/**
 * Working days between two dates, inclusive, by the days set in Settings.
 *
 * @param  string $from Y-m-d
 * @param  string $to   Y-m-d
 *
 * @return int
 */
function mks_st_working_days_between($from, $to)
{
    $days  = array_map('intval', (array) mks_st_setting('working_days', [1, 2, 3, 4, 5]));
    $count = 0;

    for ($day = strtotime($from); $day <= strtotime($to); $day = strtotime('+1 day', $day)) {
        if (in_array((int) date('N', $day), $days, true)) {
            $count++;
        }
    }

    return $count;
}

/**
 * One person's daily targets: their own override, else the default.
 *
 * @param  int $staff_id
 *
 * @return array calls, connected, talk (seconds)
 */
function mks_st_target_for($staff_id)
{
    $overrides = (array) mks_st_setting('target_overrides', []);
    $own       = isset($overrides[(string) $staff_id]) && is_array($overrides[(string) $staff_id]) ? $overrides[(string) $staff_id] : [];

    $calls     = isset($own['calls']) ? (int) $own['calls'] : (int) mks_st_setting('target_calls', 0);
    $connected = isset($own['connected']) ? (int) $own['connected'] : (int) mks_st_setting('target_connected', 0);
    $talk      = isset($own['talk']) ? (int) $own['talk'] : (int) mks_st_setting('target_talk_minutes', 0);

    return ['calls' => $calls, 'connected' => $connected, 'talk' => $talk * 60];
}

/**
 * The latest activity the dashboard describes.
 *
 * @param  int[]|null $ids
 *
 * @return array
 */
function mks_st_dash_latest($ids)
{
    $CI = &get_instance();

    $rows = $CI->db->query('SELECT e.id FROM ' . mks_st_events_table() . " e WHERE e.kind IN ('call', 'whatsapp_call', 'sms') "
        . mks_st_scope_sql('e.staff_id', $ids) . ' ORDER BY e.occurred_at DESC LIMIT 8')->result_array();

    $ids    = array_map('intval', array_column($rows, 'id'));
    $detail = mks_st_events_detail($ids);
    $out    = [];

    foreach ($ids as $id) {
        if (isset($detail[$id])) {
            $out[] = $detail[$id];
        }
    }

    return $out;
}

/* =========================================================================
 * CHARTS
 * ====================================================================== */

/**
 * A round axis maximum: 1, 2 or 5 times a power of ten.
 *
 * @param  int $value
 *
 * @return int
 */
function mks_st_nice_max($value)
{
    $value = max(1, (int) $value);
    $power = (int) pow(10, floor(log10($value)));

    foreach ([1, 2, 5, 10] as $step) {
        if ($value <= $step * $power) {
            return $step * $power;
        }
    }

    return 10 * $power;
}

/**
 * Stacked columns: connected at the bottom, the rest above.
 *
 * @param  array  $buckets label, full, values [connected, other]
 * @param  string $title
 *
 * @return string
 */
function mks_st_svg_columns(array $buckets, $title)
{
    $width  = 720;
    $height = 230;
    $left   = 40;
    $right  = 8;
    $top    = 12;
    $bottom = 28;
    $plotW  = $width - $left - $right;
    $plotH  = $height - $top - $bottom;
    $count  = max(1, count($buckets));
    $max    = 0;

    foreach ($buckets as $bucket) {
        $max = max($max, array_sum($bucket['values']));
    }

    $axis  = mks_st_nice_max($max);
    $slot  = $plotW / $count;
    $barW  = max(3, min(34, $slot * 0.62));
    $every = (int) ceil($count / 14);

    $svg = '<svg class="mks-sales-track-chart" viewBox="0 0 ' . $width . ' ' . $height . '" role="img" aria-label="' . e($title) . '"'
        . ' preserveAspectRatio="xMidYMid meet" xmlns="http://www.w3.org/2000/svg"><title>' . e($title) . '</title>';

    for ($i = 0; $i <= 4; $i++) {
        $y     = round($top + $plotH - $plotH * $i / 4, 1);
        $svg  .= '<line class="mks-sales-track-chart-grid" x1="' . $left . '" x2="' . ($width - $right) . '" y1="' . $y . '" y2="' . $y . '"/>';
        $svg  .= '<text class="mks-sales-track-chart-axis" x="' . ($left - 8) . '" y="' . ($y + 3) . '" text-anchor="end">'
            . e(mks_st_number_label((int) round($axis * $i / 4))) . '</text>';
    }

    foreach (array_values($buckets) as $index => $bucket) {
        $x      = round($left + $slot * $index + ($slot - $barW) / 2, 1);
        $base   = $top + $plotH;
        $total  = array_sum($bucket['values']);
        $tip    = $bucket['full'] . ': ' . _l('mks_st_chart_tip', [mks_st_number_label($total), mks_st_number_label($bucket['values'][0])]);
        $svg   .= '<g class="mks-sales-track-chart-bar"><title>' . e($tip) . '</title>';

        foreach ($bucket['values'] as $series => $value) {
            if ($value <= 0) {
                continue;
            }

            $h     = round($plotH * $value / $axis, 1);
            $base -= $h;
            $svg  .= '<rect class="mks-sales-track-chart-s' . $series . '" x="' . $x . '" y="' . round($base, 1) . '" width="' . round($barW, 1) . '" height="' . $h . '" rx="2"/>';
        }

        $svg .= '<rect class="mks-sales-track-chart-hit" x="' . round($left + $slot * $index, 1) . '" y="' . $top . '" width="' . round($slot, 1) . '" height="' . $plotH . '"/></g>';

        if ($index % $every === 0) {
            $svg .= '<text class="mks-sales-track-chart-axis" x="' . round($x + $barW / 2, 1) . '" y="' . ($height - 9) . '" text-anchor="middle">' . e($bucket['label']) . '</text>';
        }
    }

    return $svg . '</svg>';
}

/**
 * Weekday by hour. Shade follows the number of calls; the hover text gives
 * the connect rate.
 *
 * @param  array $heat from mks_st_dash_heatmap()
 *
 * @return string
 */
function mks_st_svg_heatmap(array $heat)
{
    $cell  = 26;
    $gap   = 3;
    $left  = 38;
    $top   = 20;
    $hours = $heat['hours'];
    $days  = [_l('mks_st_day_mon'), _l('mks_st_day_tue'), _l('mks_st_day_wed'), _l('mks_st_day_thu'), _l('mks_st_day_fri'), _l('mks_st_day_sat'), _l('mks_st_day_sun')];
    $max   = 0;

    foreach ($heat['matrix'] as $row) {
        foreach ($row as $value) {
            $max = max($max, $value['calls']);
        }
    }

    $width  = $left + count($hours) * ($cell + $gap);
    $height = $top + 7 * ($cell + $gap);
    $title  = _l('mks_st_heatmap_title');

    $svg = '<svg class="mks-sales-track-heatmap" viewBox="0 0 ' . $width . ' ' . $height . '" role="img" aria-label="' . e($title) . '"'
        . ' xmlns="http://www.w3.org/2000/svg"><title>' . e($title) . '</title>';

    foreach ($hours as $i => $hour) {
        if ($hour % 2 === 0) {
            $svg .= '<text class="mks-sales-track-chart-axis" x="' . ($left + $i * ($cell + $gap) + $cell / 2) . '" y="12" text-anchor="middle">' . (int) $hour . '</text>';
        }
    }

    foreach ($days as $dow => $label) {
        $y    = $top + $dow * ($cell + $gap);
        $svg .= '<text class="mks-sales-track-chart-axis" x="0" y="' . ($y + $cell / 2 + 4) . '">' . e($label) . '</text>';

        foreach ($hours as $i => $hour) {
            $value = isset($heat['matrix'][$dow][$hour]) ? $heat['matrix'][$dow][$hour] : ['calls' => 0, 'connected' => 0];
            $step  = ($max === 0 || $value['calls'] === 0) ? 0 : max(1, (int) ceil($value['calls'] * 5 / $max));
            $tip   = $label . ' ' . str_pad((string) $hour, 2, '0', STR_PAD_LEFT) . ':00: '
                . _l('mks_st_heat_tip', [mks_st_number_label($value['calls']), $value['calls'] > 0 ? (string) round($value['connected'] * 100 / $value['calls']) : '0']);

            $svg .= '<rect class="mks-sales-track-heat-' . $step . '" x="' . ($left + $i * ($cell + $gap)) . '" y="' . $y . '" width="' . $cell . '" height="' . $cell . '" rx="5">'
                . '<title>' . e($tip) . '</title></rect>';
        }
    }

    return $svg . '</svg>';
}

/**
 * A donut of the call mix, with the total in the middle.
 *
 * @param  array  $segments label, value, tone
 * @param  string $center
 * @param  string $caption
 *
 * @return string
 */
function mks_st_svg_donut(array $segments, $center, $caption)
{
    $total  = max(1, array_sum(array_column($segments, 'value')));
    $radius = 54;
    $length = 2 * M_PI * $radius;
    $offset = 0;

    $svg = '<svg class="mks-sales-track-donut" viewBox="0 0 140 140" role="img" aria-label="' . e($caption) . '" xmlns="http://www.w3.org/2000/svg">'
        . '<title>' . e($caption) . '</title>'
        . '<circle class="mks-sales-track-donut-track" cx="70" cy="70" r="' . $radius . '"/>';

    foreach ($segments as $segment) {
        $part = $length * $segment['value'] / $total;
        $svg .= '<circle class="mks-sales-track-donut-seg mks-sales-track-tone-' . e($segment['tone']) . '" cx="70" cy="70" r="' . $radius . '"'
            . ' stroke-dasharray="' . round($part, 2) . ' ' . round($length - $part, 2) . '" stroke-dashoffset="' . round(-$offset, 2) . '"'
            . ' transform="rotate(-90 70 70)"><title>' . e($segment['label'] . ': ' . mks_st_number_label($segment['value'])) . '</title></circle>';
        $offset += $part;
    }

    return $svg . '<text class="mks-sales-track-donut-value" x="70" y="72" text-anchor="middle">' . e($center) . '</text>'
        . '<text class="mks-sales-track-donut-caption" x="70" y="90" text-anchor="middle">' . e($caption) . '</text></svg>';
}
