<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - admin screens.
 *
 * Route: admin/mks_sales_track/...   (the sidebar's single item opens index)
 *
 * Every read applies mks_st_scope() in SQL, including single record
 * routes such as the recording stream and the device page, so a known id is
 * never a way around it. Settings stays reachable while the module is
 * switched off, so it can be switched back on.
 */
class Mks_sales_track extends AdminController
{
    public function __construct()
    {
        parent::__construct();

        if (!function_exists('mks_st_ingest') || !function_exists('mks_st_view_columns')) {
            show_error(_l('mks_st_incomplete'));
        }

        $method = strtolower((string) $this->router->fetch_method());

        if ($method === 'settings') {
            if (!mks_st_can_settings()) {
                access_denied(_l('mks_st_menu'));
            }

            return;
        }

        if (!mks_st_enabled()) {
            if (mks_st_can_settings()) {
                set_alert('warning', _l('mks_st_disabled_notice'));
                redirect(admin_url(MKS_SALES_TRACK_MODULE_NAME . '/settings'));
            }

            access_denied(_l('mks_st_menu'));
        }

        if (mks_st_scope() === false) {
            if (mks_st_can_settings()) {
                redirect(admin_url(MKS_SALES_TRACK_MODULE_NAME . '/settings'));
            }

            access_denied(_l('mks_st_menu'));
        }
    }

    /* ---------------------------------------------------------------------
     * Dashboard
     * ------------------------------------------------------------------ */

    /**
     * The hub the sidebar opens: analytics over whatever the viewer may see,
     * narrowed by period, team and person. Reps see themselves, team leads
     * their department, managers everybody.
     *
     * @return void
     */
    public function index()
    {
        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_analytics_helper.php');

        $filters = mks_st_dash_filters([
            'range' => (string) $this->input->get('range'),
            'team'  => (int) $this->input->get('team'),
            'staff' => (int) $this->input->get('staff'),
        ]);

        $scope  = mks_st_scope();
        $period = mks_st_dash_period($filters['range']);
        $ids    = mks_st_dash_staff_ids($filters);
        $sort   = (string) $this->input->get('sort');
        $kpis   = mks_st_dash_kpis($period, $ids);
        $board  = mks_st_dash_leaderboard($period, $ids, $sort);
        $heat   = mks_st_dash_heatmap($period, $ids);
        $states = ['pending' => 0, 'online' => 0, 'idle' => 0, 'offline' => 0, 'paused' => 0];

        foreach (mks_st_devices_list($ids) as $device) {
            $state = mks_st_device_state($device);

            if (isset($states[$state])) {
                $states[$state]++;
            }
        }

        $data = [
            'title'         => _l('mks_st_page_dashboard'),
            'filters'       => $filters,
            'period'        => $period,
            'ranges'        => mks_st_dash_ranges(),
            'teams'         => mks_st_dash_teams(),
            'staff_options' => $scope === null ? mks_st_staff_options() : (count($scope) > 1 ? mks_st_staff_options($scope) : []),
            'own'           => mks_st_scope_is_own(),
            'tiles'         => $kpis['tiles'],
            'totals'        => $kpis['totals'],
            'trend_svg'     => mks_st_svg_columns(mks_st_dash_trend($period, $ids), _l($period['single_day'] ? 'mks_st_trend_by_hour' : 'mks_st_trend_by_day')),
            'mix'           => mks_st_dash_mix($kpis['totals']),
            'heat'          => $heat,
            'heat_svg'      => mks_st_svg_heatmap($heat),
            'board'         => $board,
            'sort'          => in_array($sort, ['calls', 'connected', 'talk'], true) ? $sort : 'calls',
            'targets'       => mks_st_dash_targets($board, $period),
            'targets_set'   => (int) mks_st_setting('target_calls') + (int) mks_st_setting('target_connected') + (int) mks_st_setting('target_talk_minutes') > 0
                || (array) mks_st_setting('target_overrides', []) !== [],
            'latest'        => mks_st_dash_latest($ids),
            'to_convert'    => mks_st_scope_is_own() ? [] : mks_st_ready_to_convert($ids),
            'states'        => $states,
            'demo'          => (string) get_option('mks_sales_track_demo') === '1',
            'nav'           => 'dashboard',
            'context'       => ['play' => mks_st_can('play_recordings'), 'delete' => false, 'view' => 'dashboard'],
        ];

        mks_st_page_config(['page' => 'dashboard']);

        $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/dashboard', $data);
    }

    /* ---------------------------------------------------------------------
     * Activity lists
     * ------------------------------------------------------------------ */

    public function calls()
    {
        $this->mks_list('calls');
    }

    public function recordings()
    {
        $this->mks_list('recordings');
    }

    public function whatsapp_calls()
    {
        $this->mks_list('whatsapp_calls');
    }

    public function sms()
    {
        $this->mks_list('sms');
    }

    /**
     * Server side data for a list. The table file reads $mks_view.
     *
     * @param  string $view
     *
     * @return void
     */
    public function table($view = '')
    {
        if (!isset(mks_st_pages()[$view]) || !$this->input->is_ajax_request()) {
            show_404();
        }

        if (mks_st_enabled('ai_enabled')) {
            require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_ai_helper.php');
        }

        $this->app->get_table_data(module_views_path(MKS_SALES_TRACK_MODULE_NAME, 'tables/events'), [
            'mks_view' => $view,
        ]);
    }

    /* ---------------------------------------------------------------------
     * Reports
     * ------------------------------------------------------------------ */

    /**
     * One report on screen, or exported with ?format=csv or ?format=xlsx.
     *
     * @return void
     */
    public function reports()
    {
        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_reports_helper.php');

        $reports = mks_st_reports();
        $key     = (string) $this->input->get('report');
        $key     = isset($reports[$key]) ? $key : 'team';
        $range   = (string) $this->input->get('range');
        $filters = mks_st_dash_filters([
            'range' => $range === 'custom' ? 'today' : ($range === '' ? '7d' : $range),
            'team'  => (int) $this->input->get('team'),
            'staff' => (int) $this->input->get('staff'),
        ]);
        $period  = mks_st_dash_period($filters['range']);

        // A custom range: two valid dates, at most a year apart.
        $from = (string) $this->input->get('from');
        $to   = (string) $this->input->get('to');

        if ($range === 'custom' && preg_match('/^\d{4}-\d{2}-\d{2}$/', $from) && preg_match('/^\d{4}-\d{2}-\d{2}$/', $to)
            && strtotime($from) && strtotime($to) && $from <= $to && (strtotime($to) - strtotime($from)) <= 366 * 86400) {
            $filters['range'] = 'custom';
            $period           = ['from' => $from, 'to' => $to, 'days' => (int) round((strtotime($to) - strtotime($from)) / 86400) + 1];
            $period['single_day'] = $period['days'] === 1;
        }

        $scope  = mks_st_scope();
        $ids    = mks_st_dash_staff_ids($filters);
        $report = mks_st_report($key, $period, $ids);
        $format = (string) $this->input->get('format');
        $name   = 'sales-track-' . $key . '-' . $period['from'] . '-to-' . $period['to'];

        if ($format === 'csv' || $format === 'xlsx') {
            $matrix = mks_st_report_matrix($report);
            $bytes  = $format === 'csv' ? mks_st_report_csv($matrix) : mks_st_report_xlsx($matrix, _l($reports[$key]['label']));

            if ($bytes === false) {
                show_error(_l('mks_st_xlsx_unavailable'));
            }

            log_activity('Sales Track: report exported [' . $key . ', ' . $period['from'] . ' to ' . $period['to'] . ', ' . $format . ']');

            header('Content-Type: ' . ($format === 'csv' ? 'text/csv; charset=UTF-8' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'));
            header('Content-Disposition: attachment; filename="' . $name . '.' . $format . '"');
            header('Content-Length: ' . strlen($bytes));
            header('Cache-Control: private, no-store');
            echo $bytes;
            exit;
        }

        $data = [
            'title'         => _l('mks_st_page_reports'),
            'reports'       => $reports,
            'key'           => $key,
            'report'        => $report,
            'period'        => $period,
            'filters'       => $filters,
            'ranges'        => mks_st_dash_ranges(),
            'teams'         => mks_st_dash_teams(),
            'staff_options' => $scope === null ? mks_st_staff_options() : (count($scope) > 1 ? mks_st_staff_options($scope) : []),
            'can_xlsx'      => class_exists('ZipArchive'),
            'nav'           => 'reports',
        ];

        mks_st_page_config(['page' => 'reports']);

        $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/reports', $data);
    }

    /**
     * The scheduled email as the signed in person would receive it today.
     *
     * @return void
     */
    public function report_preview()
    {
        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_reports_helper.php');

        $kind  = in_array($this->input->get('kind'), ['daily', 'weekly', 'monthly'], true) ? $this->input->get('kind') : 'daily';
        $range = $kind === 'daily' ? ['from' => date('Y-m-d'), 'to' => date('Y-m-d')]
            : ($kind === 'weekly' ? ['from' => date('Y-m-d', strtotime('-7 days')), 'to' => date('Y-m-d', strtotime('-1 day'))]
            : ['from' => date('Y-m-01', strtotime('first day of last month')), 'to' => date('Y-m-t', strtotime('first day of last month'))]);

        $body = mks_st_report_email_body($kind, $range, mks_st_scope() === false ? [] : mks_st_scope());

        echo '<!DOCTYPE html><html><head><meta charset="utf-8"><title>' . e($body['subject']) . '</title></head><body style="margin:24px">' . $body['html'] . '</body></html>';
    }

    /**
     * Send today's report to the signed in person now, to check the mail
     * settings and the layout.
     *
     * @return void
     */
    public function report_test()
    {
        $this->mks_require_post();

        if (!mks_st_can_settings()) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_no_permission')], 403);
        }

        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_reports_helper.php');

        $saved = mks_st_setting('report_skip_empty');
        mks_st_settings(false, array_merge(mks_st_settings(), ['report_skip_empty' => 0]));

        $sent = mks_st_report_email('daily', ['from' => date('Y-m-d'), 'to' => date('Y-m-d')], (int) get_staff_user_id(), mks_st_scope());

        mks_st_settings(false, array_merge(mks_st_settings(), ['report_skip_empty' => $saved]));

        mks_st_json(['success' => $sent, 'message' => _l($sent ? 'mks_st_report_test_sent' : 'mks_st_report_test_failed')], $sent ? 200 : 502);
    }

    /* ---------------------------------------------------------------------
     * Missed calls and follow-ups
     * ------------------------------------------------------------------ */

    /**
     * The callback queue: missed calls waiting to be returned, the ones past
     * their time, and the ones returned in the last seven days.
     *
     * @return void
     */
    public function missed_calls()
    {
        $tab   = (string) $this->input->get('tab');
        $tab   = in_array($tab, ['open', 'overdue', 'resolved'], true) ? $tab : 'open';
        $table = mks_st_events_table();
        $scope = mks_st_scope_sql('e.staff_id');
        $now   = $this->db->escape(date('Y-m-d H:i:s'));
        $week  = $this->db->escape(date('Y-m-d H:i:s', strtotime('-7 days')));

        $where = [
            'open'     => "e.callback_state IN ('open', 'escalated')",
            'overdue'  => "e.callback_state IN ('open', 'escalated') AND e.callback_due_at < " . $now,
            'resolved' => "e.callback_state = 'resolved' AND e.callback_at >= " . $week,
        ];

        $rows = $this->db->query('SELECT e.id, (SELECT COUNT(*) FROM ' . $table . " x WHERE x.number_key = e.number_key AND x.direction = 'outgoing'"
            . ' AND x.occurred_at > e.occurred_at) AS attempts FROM ' . $table . ' e WHERE ' . $where[$tab] . ' ' . $scope
            . ' ORDER BY ' . ($tab === 'resolved' ? 'e.callback_at DESC' : 'e.callback_due_at ASC') . ' LIMIT 300')->result_array();

        $attempts = array_column($rows, 'attempts', 'id');
        $details  = mks_st_events_detail(array_map('intval', array_keys($attempts)));
        $items    = [];

        foreach (array_keys($attempts) as $id) {
            if (isset($details[$id])) {
                $items[] = $details[$id] + ['attempts' => (int) $attempts[$id]];
            }
        }

        $counts = $this->db->query("SELECT SUM(e.callback_state IN ('open', 'escalated')) AS open,"
            . " SUM(e.callback_state IN ('open', 'escalated') AND e.callback_due_at < " . $now . ') AS overdue,'
            . " SUM(e.callback_state = 'resolved' AND e.callback_at >= " . $this->db->escape(date('Y-m-d') . ' 00:00:00') . ') AS today,'
            . " AVG(CASE WHEN e.callback_state = 'resolved' AND e.callback_at >= " . $week . ' THEN TIMESTAMPDIFF(MINUTE, e.occurred_at, e.callback_at) END) AS minutes'
            . ' FROM ' . $table . ' e WHERE e.callback_state IS NOT NULL ' . $scope)->row_array();

        $data = [
            'title'   => _l('mks_st_page_missed_calls'),
            'tab'     => $tab,
            'items'   => $items,
            'counts'  => $counts,
            'nav'     => 'missed_calls',
            'context' => ['play' => mks_st_can('play_recordings'), 'delete' => false, 'view' => 'missed_calls', 'outcome' => false],
        ];

        mks_st_page_config(['page' => 'queue', 'urls' => ['resolve' => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/callback_resolve')],
            'text' => ['failed' => _l('mks_st_request_failed')]]);

        $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/missed_calls', $data);
    }

    /**
     * Follow-ups set from call outcomes. Done means somebody has since had a
     * connected call with that number.
     *
     * @return void
     */
    public function follow_ups()
    {
        $tab   = (string) $this->input->get('tab');
        $tab   = in_array($tab, ['due', 'upcoming', 'done'], true) ? $tab : 'due';
        $table = mks_st_events_table();
        $t     = mks_st_connected_seconds();
        $eod   = $this->db->escape(date('Y-m-d') . ' 23:59:59');
        $done  = '(e.number_key IS NOT NULL AND EXISTS (SELECT 1 FROM ' . $table . ' x WHERE x.number_key = e.number_key AND x.id <> e.id'
            . " AND x.kind IN ('call', 'whatsapp_call') AND x.duration >= " . $t . ' AND x.occurred_at > e.outcome_at))';

        $where = [
            'due'      => 'e.follow_up_at <= ' . $eod . ' AND NOT ' . $done,
            'upcoming' => 'e.follow_up_at > ' . $eod . ' AND NOT ' . $done,
            'done'     => $done . ' AND e.follow_up_at >= ' . $this->db->escape(date('Y-m-d H:i:s', strtotime('-30 days'))),
        ];

        $ids = array_map('intval', array_column($this->db->query('SELECT e.id FROM ' . $table . ' e WHERE e.follow_up_at IS NOT NULL AND '
            . $where[$tab] . ' ' . mks_st_scope_sql('e.staff_id') . ' ORDER BY e.follow_up_at ' . ($tab === 'done' ? 'DESC' : 'ASC') . ' LIMIT 300')->result_array(), 'id'));

        $details = mks_st_events_detail($ids);
        $items   = [];

        foreach ($ids as $id) {
            if (isset($details[$id])) {
                $items[] = $details[$id];
            }
        }

        $data = [
            'title'   => _l('mks_st_page_follow_ups'),
            'tab'     => $tab,
            'items'   => $items,
            'nav'     => 'follow_ups',
            'context' => ['play' => mks_st_can('play_recordings'), 'delete' => false, 'view' => 'follow_ups', 'outcome' => true],
        ];

        mks_st_page_config(['page' => 'follow_ups'] + $this->mks_outcome_config());

        $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/follow_ups', $data);
    }

    /**
     * Set or change a call's outcome from the CRM. Same effects as the phone.
     *
     * @return void
     */
    public function outcome_save()
    {
        $this->mks_require_post();

        $event = mks_st_event_get((int) $this->input->post('id'));

        if (!$event || !mks_st_event_visible($event)) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_not_found')], 404);
        }

        $follow = trim((string) $this->input->post('follow_up'));
        $stamp  = $follow !== '' ? strtotime($follow) : false;

        $result = mks_st_apply_outcome($event, [
            'outcome'      => (string) $this->input->post('outcome'),
            'note'         => (string) $this->input->post('note'),
            'follow_up_at' => $stamp ? $stamp * 1000 : '',
            'lead_status'  => (int) $this->input->post('lead_status'),
            'create_lead'  => $this->input->post('create_lead') === '1',
        ], (int) get_staff_user_id());

        if (!$result['ok']) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_api_' . $result['error'])], 422);
        }

        mks_st_json(['success' => true, 'message' => _l('mks_st_outcome_saved')]);
    }

    /**
     * Click-to-call: ask the signed in member of staff's own phone to dial.
     *
     * @return void
     */
    public function dial()
    {
        $this->mks_require_post();

        $result = mks_st_dial((string) $this->input->post('number'), (string) $this->input->post('name'), (int) get_staff_user_id());

        mks_st_json(['success' => $result['ok'], 'pushed' => $result['pushed'], 'message' => _l($result['message'])], $result['ok'] ? 200 : 422);
    }

    /**
     * Clear a missed call by hand: returned some other way.
     *
     * @return void
     */
    public function callback_resolve()
    {
        $this->mks_require_post();

        $event = mks_st_event_get((int) $this->input->post('id'));

        if (!$event || !mks_st_event_visible($event) || !in_array($event['callback_state'], ['open', 'escalated'], true)) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_not_found')], 404);
        }

        $this->db->where('id', (int) $event['id'])->update(mks_st_events_table(), [
            'callback_state' => 'resolved',
            'callback_at'    => date('Y-m-d H:i:s'),
            'callback_by'    => (int) get_staff_user_id(),
        ]);

        mks_st_json(['success' => true]);
    }

    /* ---------------------------------------------------------------------
     * Devices
     * ------------------------------------------------------------------ */

    /**
     * @return void
     */
    public function devices()
    {
        $manager = mks_st_can('manage_devices');

        $data = [
            'title'         => _l('mks_st_page_devices'),
            'devices'       => mks_st_devices_list($manager ? null : mks_st_scope()),
            'can_manage'    => $manager,
            'can_pair'      => mks_st_enabled('api_enabled'),
            'staff_options' => $manager ? mks_st_staff_options() : [],
            'demo'          => (string) get_option('mks_sales_track_demo') === '1',
            'can_demo'      => is_admin(),
            'site_url'      => site_url(),
            'nav'           => 'devices',
        ];

        mks_st_page_config(['page' => 'devices', 'urls' => $this->mks_device_urls(), 'text' => $this->mks_device_text()]);

        $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/devices', $data);
    }

    /**
     * One device: overview, health, activity, sync history, commands.
     *
     * @param  int $id
     *
     * @return void
     */
    public function device($id = 0)
    {
        $device = $this->mks_visible_device((int) $id);

        if (!$device) {
            show_404();
        }

        $live = mks_st_can('manage_devices') ? mks_st_pairing_live_code($device['id']) : null;

        $data = [
            'title'      => $device['label'],
            'device'     => $device,
            'state'      => mks_st_device_state($device),
            'owner'      => mks_st_staff_name($device['staff_id']),
            'health'     => mks_st_decode($device['health']),
            'sims'       => mks_st_decode($device['sims']),
            'sync_log'   => mks_st_decode($device['sync_log']),
            'commands'   => mks_st_decode($device['commands']),
            'activity'   => mks_st_device_activity($device['id']),
            'live_code'  => $live,
            'live_qr'    => $live ? mks_st_qr_data_uri($this->mks_qr_payload($live['secret'], $device)) : '',
            'can_manage' => mks_st_can('manage_devices'),
            'can_pair'   => mks_st_enabled('api_enabled'),
            'staff_options' => mks_st_can('manage_devices') ? mks_st_staff_options() : [],
            'outdated'   => $device['app_version'] !== '' && mks_st_app_update_required($device['app_version']),
            'nav'        => 'devices',
        ];

        mks_st_page_config([
            'page'   => 'device',
            'device' => (int) $device['id'],
            'urls'   => $this->mks_device_urls(),
            'text'   => $this->mks_device_text(),
            'code'   => $live ? ['id' => $live['id'], 'expires_in' => $live['expires'] - time()] : null,
        ]);

        $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/device', $data);
    }

    /**
     * Add a device (no id) or edit one. Adding issues its first pairing code.
     *
     * @return void
     */
    public function device_save()
    {
        $this->mks_require_manager();

        $id     = (int) $this->input->post('id');
        $fields = mks_st_clean_device_form((array) $this->input->post());

        if (!is_array($fields)) {
            mks_st_json(['success' => false, 'message' => _l($fields)], 422);
        }

        if ($id > 0) {
            $device = mks_st_device_get($id);

            if (!$device) {
                mks_st_json(['success' => false, 'message' => _l('mks_st_not_found')], 404);
            }

            $sim = (int) $this->input->post('track_sim');

            $fields['track_sim'] = ($sim >= 1 && $sim <= 4) ? $sim : 0;

            $this->db->where('id', $id);
            $this->db->update(mks_st_devices_table(), $fields);

            if ((int) $device['staff_id'] !== (int) $fields['staff_id']) {
                log_activity('Sales Track: phone reassigned [' . $fields['label'] . ', from ' . mks_st_staff_name($device['staff_id'])
                    . ' to ' . mks_st_staff_name($fields['staff_id']) . ']');
            }

            mks_st_json(['success' => true, 'id' => $id]);
        }

        $id = mks_st_device_create($fields, (int) get_staff_user_id());

        if ($id <= 0) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_request_failed')], 500);
        }

        log_activity('Sales Track: device added [' . $fields['label'] . ', Staff: ' . mks_st_staff_name($fields['staff_id']) . ']');

        mks_st_json(array_merge(['success' => true, 'id' => $id, 'url' => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/device/' . $id)],
            $this->mks_issue_code(mks_st_device_get($id))));
    }

    /**
     * A fresh pairing code for a device. On a bound device it is a handset
     * swap: the old phone keeps working until the new one enters the code.
     *
     * @return void
     */
    public function device_code()
    {
        $this->mks_require_manager();

        $device = mks_st_device_get((int) $this->input->post('id'));

        if (!$device) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_not_found')], 404);
        }

        if (!mks_st_enabled('api_enabled')) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_api_off_notice')], 409);
        }

        if (!mks_st_staff_active($device['staff_id'])) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_staff_inactive')], 422);
        }

        log_activity('Sales Track: pairing code issued [' . $device['label'] . ']');

        mks_st_json(array_merge(['success' => true], $this->mks_issue_code($device)));
    }

    /**
     * Polled by the pairing window until the phone has paired.
     *
     * @return void
     */
    public function pair_status()
    {
        if (!mks_st_can('manage_devices')) {
            mks_st_json(['success' => false], 403);
        }

        $id = (string) $this->input->get('id');

        if (!preg_match('/^[a-f0-9]{16}$/', $id)) {
            mks_st_json(['success' => false], 400);
        }

        mks_st_json(array_merge(['success' => true], mks_st_pairing_status($id)));
    }

    /**
     * Pause, resume, revoke, delete, or send a command.
     *
     * @return void
     */
    public function device_action()
    {
        $this->mks_require_manager();

        $device = mks_st_device_get((int) $this->input->post('id'));
        $action = (string) $this->input->post('action');
        $me     = (int) get_staff_user_id();

        if (!$device) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_not_found')], 404);
        }

        switch ($action) {
            case 'pause':
            case 'resume':
                if (!in_array($device['status'], ['active', 'paused'], true)) {
                    mks_st_json(['success' => false, 'message' => _l('mks_st_err_not_bound')], 409);
                }

                $this->db->where('id', (int) $device['id'])->update(mks_st_devices_table(), ['status' => $action === 'pause' ? 'paused' : 'active']);
                log_activity('Sales Track: phone ' . ($action === 'pause' ? 'paused' : 'resumed') . ' [' . $device['label'] . ']');
                mks_st_json(['success' => true]);

                // no break
            case 'revoke':
                mks_st_device_revoke((int) $device['id'], $me);
                mks_st_json(['success' => true]);

                // no break
            case 'delete':
                if (!in_array($device['status'], ['revoked', 'pending'], true)) {
                    mks_st_json(['success' => false, 'message' => _l('mks_st_revoke_first')], 409);
                }

                mks_st_pairing_forget_device((int) $device['id']);
                $this->db->where('id', (int) $device['id'])->delete(mks_st_devices_table());
                log_activity('Sales Track: device deleted [' . $device['label'] . ']');
                mks_st_json(['success' => true, 'url' => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/devices')]);

                // no break
            default:
                if (strpos($action, 'command:') === 0 && substr($action, 8) !== 'dial') {
                    $sent = mks_st_device_command_add($device, substr($action, 8), $me);

                    if ($sent === false) {
                        mks_st_json(['success' => false, 'message' => _l('mks_st_err_not_bound')], 409);
                    }

                    $pushed = mks_st_push_wake(mks_st_device_get($device['id']), $sent, substr($action, 8));

                    mks_st_json(['success' => true, 'message' => _l($pushed ? 'mks_st_command_pushed' : 'mks_st_command_queued')]);
                }

                if ($action === 'push_test') {
                    if (empty($device['push_token'])) {
                        mks_st_json(['success' => false, 'message' => _l('mks_st_push_no_token')], 409);
                    }

                    require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_push_helper.php');

                    $sent = mks_st_fcm_send($device, ['type' => 'ping', 'sent' => (string) time()], 60);

                    mks_st_json(['success' => $sent['ok'], 'message' => $sent['ok'] ? _l('mks_st_push_ok') : _l('mks_st_push_failed', $sent['error'])], $sent['ok'] ? 200 : 502);
                }
        }

        mks_st_json(['success' => false, 'message' => _l('mks_st_request_failed')], 400);
    }

    /* ---------------------------------------------------------------------
     * Recordings and records
     * ------------------------------------------------------------------ */

    /**
     * Stream a recording, with range support for seeking: from this server
     * while the file is here, from Google Drive through the CRM once it has
     * moved. Best Pitches in the library are open to everybody who uses Sales
     * Track; everything else follows the viewer's scope and Play Recordings.
     * Downloads follow Settings > Recording Storage.
     *
     * @param  int $id
     *
     * @return void
     */
    public function recording($id = 0)
    {
        $event = mks_st_event_get((int) $id);

        if (!$event || $event['recording_status'] !== 'stored') {
            show_404();
        }

        $library = (int) $event['best_pitch'] === 2 && mks_st_scope() !== false;

        if (!$library && (!mks_st_event_visible($event) || !mks_st_can('play_recordings'))) {
            show_404();
        }

        $download = $this->input->get('download') === '1';

        if ($download && !mks_st_can_download()) {
            show_404();
        }

        mks_st_recording_audit($event, $download);

        $formats = mks_st_recording_formats();
        $ext     = !empty($event['recording_file']) ? strtolower(pathinfo($event['recording_file'], PATHINFO_EXTENSION)) : (string) array_search($event['recording_mime'], $formats, true);
        $name    = $download ? 'call-' . date('Y-m-d-His', strtotime($event['occurred_at'])) . '-' . (int) $event['id'] . '.' . ($ext ?: 'audio') : null;
        $path    = !empty($event['recording_file']) ? mks_st_recording_path($event['recording_file']) : false;

        if ($path !== false) {
            mks_st_stream_file($path, isset($formats[$ext]) ? $formats[$ext] : 'application/octet-stream', $name);
        }

        if (!empty($event['drive_file_id'])) {
            require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_drive_helper.php');

            if (mks_st_drive_stream($event, (string) ($event['recording_mime'] ?: 'application/octet-stream'), $name)) {
                exit;
            }

            show_error(_l('mks_st_drive_unreachable'), 502);
        }

        show_404();
    }

    /* ---------------------------------------------------------------------
     * Best Pitches
     * ------------------------------------------------------------------ */

    /**
     * The learning library, open to everybody who uses Sales Track, and the
     * nominations waiting for whoever manages it.
     *
     * @return void
     */
    public function pitches()
    {
        $category = (string) $this->input->get('category');
        $cats     = mks_st_pitch_categories();

        if (!in_array($category, $cats, true)) {
            $category = '';
        }

        $this->db->select('id')->where('best_pitch', 2)->where('recording_status', 'stored');

        if ($category !== '') {
            $this->db->where('pitch_category', $category);
        }

        $library = mks_st_events_detail(array_map('intval', array_column($this->db->order_by('pitch_at', 'desc')->limit(100)
            ->get(mks_st_events_table())->result_array(), 'id')));

        $nominated = [];

        if (mks_st_can_pitches()) {
            $nominated = mks_st_events_detail(array_map('intval', array_column($this->db->query('SELECT e.id FROM ' . mks_st_events_table()
                . " e WHERE e.best_pitch = 1 AND e.recording_status = 'stored' " . mks_st_scope_sql('e.staff_id')
                . ' ORDER BY e.pitch_at DESC LIMIT 50')->result_array(), 'id')));
        }

        $data = [
            'title'      => _l('mks_st_page_pitches'),
            'library'    => array_values($library),
            'nominated'  => array_values($nominated),
            'categories' => $cats,
            'category'   => $category,
            'manager'    => mks_st_can_pitches(),
            'nav'        => 'pitches',
        ];

        mks_st_page_config(['page' => 'pitches', 'pitch' => $this->mks_pitch_config()]);

        $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/pitches', $data);
    }

    /**
     * Nominate a call, add it to the library, edit it, reject or remove it.
     *
     * @return void
     */
    public function pitch_save()
    {
        $this->mks_require_post();

        $event  = mks_st_event_get((int) $this->input->post('id'));
        $action = (string) $this->input->post('action');

        if (!$event || !mks_st_event_visible($event) || $event['recording_status'] !== 'stored') {
            mks_st_json(['success' => false, 'message' => _l('mks_st_not_found')], 404);
        }

        $manager = mks_st_can_pitches();
        $fields  = [
            'pitch_category' => in_array((string) $this->input->post('category'), mks_st_pitch_categories(), true) ? (string) $this->input->post('category') : null,
            'pitch_note'     => mks_st_clean_body((string) $this->input->post('note'), 1000) ?: null,
            'pitch_moments'  => json_encode(mks_st_parse_moments((string) $this->input->post('moments'))),
            'pitch_by'       => (int) get_staff_user_id(),
            'pitch_at'       => date('Y-m-d H:i:s'),
        ];

        if ($action === 'nominate' && !$manager) {
            if (!mks_st_enabled('pitch_nominate') || (int) $event['best_pitch'] !== 0) {
                mks_st_json(['success' => false, 'message' => _l('mks_st_no_permission')], 403);
            }

            $fields['best_pitch'] = 1;
        } elseif (in_array($action, ['approve', 'nominate'], true) && $manager) {
            $fields['best_pitch'] = 2;
        } elseif (in_array($action, ['reject', 'remove'], true) && $manager) {
            $fields = ['best_pitch' => 0, 'pitch_category' => null, 'pitch_note' => null, 'pitch_moments' => null, 'pitch_by' => null, 'pitch_at' => null];
        } else {
            mks_st_json(['success' => false, 'message' => _l('mks_st_no_permission')], 403);
        }

        $this->db->where('id', (int) $event['id'])->update(mks_st_events_table(), $fields);

        log_activity('Sales Track: best pitch ' . $action . ' [#' . (int) $event['id'] . ']');

        mks_st_json(['success' => true, 'message' => _l($fields['best_pitch'] === 2 ? 'mks_st_pitch_added' : ($fields['best_pitch'] === 1 ? 'mks_st_pitch_nominated' : 'mks_st_pitch_removed'))]);
    }

    /* ---------------------------------------------------------------------
     * Call lists and do-not-call
     * ------------------------------------------------------------------ */

    /**
     * Managers and team leads see every list they may and build new ones;
     * reps see the leads assigned to them on each active list.
     *
     * @return void
     */
    public function lists()
    {
        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_lists_helper.php');

        $manager = mks_st_can_lists();
        $me      = (int) get_staff_user_id();
        $open    = (int) $this->input->get('id');
        $rows    = [];

        foreach (mks_st_lists() as $id => $header) {
            if (!mks_st_list_visible($header) || (!$manager && $header['status'] !== 'active')) {
                continue;
            }

            $list   = mks_st_list_get($id);
            $items  = mks_st_list_items($list, $manager ? null : $me);
            $rows[] = ['list' => $list, 'totals' => mks_st_list_totals($items), 'items' => $id === $open || !$manager ? $items : []];
        }

        usort($rows, function ($a, $b) {
            return strcmp($b['list']['created_at'], $a['list']['created_at']);
        });

        $data = [
            'title'    => _l('mks_st_page_lists'),
            'rows'     => $rows,
            'open'     => $open,
            'manager'  => $manager,
            'statuses' => mks_st_lead_statuses(),
            'sources'  => $manager ? $this->db->select('id, name')->order_by('name')->get(db_prefix() . 'leads_sources')->result_array() : [],
            'staff'    => $manager ? mks_st_staff_options(mks_st_scope() ?: null) : [],
            'nav'      => 'lists',
        ];

        mks_st_page_config(['page' => 'lists', 'urls' => [
            'save'    => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/list_save'),
            'action'  => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/list_action'),
            'preview' => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/list_preview'),
        ]]);

        $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/lists', $data);
    }

    /**
     * The filters a manager is choosing, from the form.
     *
     * @return array
     */
    private function mks_list_filters()
    {
        return [
            'statuses'     => (array) $this->input->post('statuses'),
            'sources'      => (array) $this->input->post('sources'),
            'owners'       => (array) $this->input->post('owners'),
            'quiet_days'   => max(0, min(365, (int) $this->input->post('quiet_days'))),
            'created_from' => (string) $this->input->post('created_from'),
            'created_to'   => (string) $this->input->post('created_to'),
            'open_only'    => (string) $this->input->post('open_only') === '1',
        ];
    }

    /**
     * How many leads the chosen filters select.
     *
     * @return void
     */
    public function list_preview()
    {
        $this->mks_require_post();
        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_lists_helper.php');

        if (!mks_st_can_lists()) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_no_permission')], 403);
        }

        $count = count(mks_st_list_leads($this->mks_list_filters()));

        mks_st_json(['success' => true, 'count' => $count, 'message' => _l('mks_st_list_preview_count', (string) $count) . ($count >= MKS_ST_LIST_MAX ? ' ' . _l('mks_st_list_capped', (string) MKS_ST_LIST_MAX) : '')]);
    }

    /**
     * Create a list.
     *
     * @return void
     */
    public function list_save()
    {
        $this->mks_require_post();
        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_lists_helper.php');

        if (!mks_st_can_lists()) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_no_permission')], 403);
        }

        // Only people the creator may manage can be put on a list.
        $scope = mks_st_scope();
        $staff = array_values(array_filter(array_map('intval', (array) $this->input->post('staff')), function ($id) use ($scope) {
            return $id > 0 && ($scope === null || in_array($id, $scope, true));
        }));

        $result = mks_st_list_create([
            'name'    => (string) $this->input->post('name'),
            'note'    => (string) $this->input->post('note'),
            'due'     => (string) $this->input->post('due'),
            'staff'   => $staff,
            'mode'    => $this->input->post('mode') === 'owner' ? 'owner' : 'round_robin',
            'filters' => $this->mks_list_filters(),
        ], (int) get_staff_user_id());

        if (!$result['ok']) {
            mks_st_json(['success' => false, 'message' => _l($result['error'])], 422);
        }

        log_activity('Sales Track: call list created [#' . $result['id'] . ', ' . $result['count'] . ' leads]');

        mks_st_json(['success' => true, 'id' => $result['id'], 'message' => _l('mks_st_list_created', (string) $result['count'])]);
    }

    /**
     * Archive, reopen or delete a list; skip or restore a lead; put a number
     * on the do-not-call list or take it off.
     *
     * @return void
     */
    public function list_action()
    {
        $this->mks_require_post();
        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_lists_helper.php');

        $action = (string) $this->input->post('action');
        $list   = mks_st_list_get((int) $this->input->post('id'));

        if ($action === 'dnc' || $action === 'undnc') {
            if (!mks_st_can_lists()) {
                mks_st_json(['success' => false, 'message' => _l('mks_st_no_permission')], 403);
            }

            $number = (string) $this->input->post('number');
            $key    = mks_st_lst_key($number);
            $lines  = array_values(array_filter(preg_split('/[\r\n]+/', (string) mks_st_setting('dnc_numbers', '')), function ($line) use ($key) {
                return mks_st_lst_key($line) !== $key;
            }));

            if ($key === '') {
                mks_st_json(['success' => false, 'message' => _l('mks_st_not_found')], 422);
            }

            if ($action === 'dnc') {
                $lines[] = mks_st_lst_number($number);
            }

            mks_st_option_put(MKS_SALES_TRACK_OPTION, json_encode(array_merge(mks_st_settings(), ['dnc_numbers' => implode("\n", array_slice($lines, -500))])), 1);
            log_activity('Sales Track: do not call ' . ($action === 'dnc' ? 'added' : 'removed') . ' [' . mks_st_format_number($number) . ']');

            mks_st_json(['success' => true, 'message' => _l($action === 'dnc' ? 'mks_st_dnc_added' : 'mks_st_dnc_removed')]);
        }

        if (!$list || !mks_st_list_visible($list)) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_not_found')], 404);
        }

        if (in_array($action, ['skip', 'unskip'], true)) {
            $lead  = (int) $this->input->post('lead');
            $owner = isset($list['assign'][$lead]) ? (int) $list['assign'][$lead] : 0;

            if (!mks_st_can_lists() && $owner !== (int) get_staff_user_id()) {
                mks_st_json(['success' => false, 'message' => _l('mks_st_no_permission')], 403);
            }

            mks_st_list_skip($list, $lead, $action === 'skip');
            mks_st_json(['success' => true, 'message' => _l($action === 'skip' ? 'mks_st_list_skipped' : 'mks_st_list_unskipped')]);
        }

        if (!mks_st_can_lists() || !in_array($action, ['archive', 'reopen', 'delete'], true)) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_no_permission')], 403);
        }

        mks_st_list_change($list['id'], $action);
        log_activity('Sales Track: call list ' . $action . ' [#' . (int) $list['id'] . ']');

        mks_st_json(['success' => true, 'message' => _l(['archive' => 'mks_st_list_archived_msg', 'reopen' => 'mks_st_list_reopened', 'delete' => 'mks_st_list_deleted'][$action])]);
    }

    /* ---------------------------------------------------------------------
     * Wallboard
     * ------------------------------------------------------------------ */

    /**
     * The sales-floor screen for a signed in manager or team lead.
     *
     * @return void
     */
    public function wallboard()
    {
        $scope = mks_st_scope();

        if ($scope === false || mks_st_scope_is_own()) {
            access_denied(_l('mks_st_menu'));
        }

        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_lists_helper.php');

        $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/wallboard', ['data' => mks_st_wallboard_data($scope), 'refresh' => (int) mks_st_setting('wallboard_refresh', 60)]);
    }

    /**
     * The Gemini models this key may use, for the model picker in Settings.
     *
     * @return void
     */
    public function ai_models()
    {
        $this->mks_require_post();

        if (!mks_st_can_settings()) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_no_permission')], 403);
        }

        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_ai_helper.php');

        $models = mks_st_ai_models();

        if (is_string($models)) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_ai_models_failed', $models)], 502);
        }

        mks_st_json(['success' => true, 'models' => $models, 'message' => _l('mks_st_ai_models_loaded', (string) count($models))]);
    }

    /* ---------------------------------------------------------------------
     * AI insights
     * ------------------------------------------------------------------ */

    /**
     * One call's insights, as a fragment for the Insights window.
     *
     * @param  int $id
     *
     * @return void
     */
    public function ai_view($id = 0)
    {
        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_ai_helper.php');

        $detail = mks_st_events_detail([(int) $id]);
        $event  = isset($detail[(int) $id]) ? $detail[(int) $id] : null;

        if (!$event || $event['ai_status'] !== 'done' || !mks_st_ai_visible($event)) {
            show_404();
        }

        $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/partials/ai_insights', [
            'event'    => $event,
            'ai'       => mks_st_ai_get($event['id']),
            'can_use'  => $event['outcome'] === null && mks_st_enabled('ai_suggest') && mks_st_event_visible($event),
            'manager'  => !mks_st_scope_is_own(),
        ]);
    }

    /**
     * Send one call to Gemini now.
     *
     * @return void
     */
    public function ai_analyse()
    {
        $this->mks_require_post();

        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_ai_helper.php');

        $event = mks_st_event_get((int) $this->input->post('id'));

        if (!$event || !mks_st_ai_can_run($event)) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_no_permission')], 403);
        }

        if (!mks_st_ai_ready()) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_ai_not_ready')], 409);
        }

        // A long call takes Gemini a while; the session lock is released so
        // the rest of the CRM keeps working meanwhile.
        @set_time_limit(180);
        session_write_close();

        $result = mks_st_ai_analyse($event);

        mks_st_json(['success' => $result['ok'], 'message' => $result['ok'] ? _l('mks_st_ai_done') : _l('mks_st_ai_failed', $result['error'])], $result['ok'] ? 200 : 422);
    }

    /**
     * Use the AI's suggested outcome, confirmed by a person.
     *
     * @return void
     */
    public function ai_use_suggestion()
    {
        $this->mks_require_post();

        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_ai_helper.php');

        $event = mks_st_event_get((int) $this->input->post('id'));
        $ai    = $event ? mks_st_ai_get($event['id']) : null;

        if (!$event || !$ai || !mks_st_event_visible($event) || $event['outcome'] !== null || empty($ai['analysis']['suggestion']['outcome'])) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_not_found')], 404);
        }

        $suggestion = $ai['analysis']['suggestion'];
        $result     = mks_st_apply_outcome($event, [
            'outcome'      => $suggestion['outcome'],
            'note'         => $suggestion['note'],
            'follow_up_at' => (int) $suggestion['follow_up_days'] > 0 ? strtotime(date('Y-m-d', strtotime('+' . (int) $suggestion['follow_up_days'] . ' days')) . ' 10:00:00') * 1000 : '',
        ], (int) get_staff_user_id());

        mks_st_json(['success' => $result['ok'], 'message' => $result['ok'] ? _l('mks_st_outcome_saved') : _l('mks_st_api_' . $result['error'])], $result['ok'] ? 200 : 422);
    }

    /**
     * Check the Gemini key and model from Settings.
     *
     * @return void
     */
    public function ai_test()
    {
        $this->mks_require_post();

        if (!mks_st_can_settings()) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_no_permission')], 403);
        }

        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_ai_helper.php');

        if (mks_st_ai_key() === null) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_ai_no_key')], 409);
        }

        $result = mks_st_ai_test();

        mks_st_json(['success' => $result === true, 'message' => $result === true ? _l('mks_st_ai_key_ok') : _l('mks_st_ai_failed', $result)], $result === true ? 200 : 502);
    }

    /* ---------------------------------------------------------------------
     * Google Drive connection
     * ------------------------------------------------------------------ */

    /**
     * Send the administrator to Google to approve access.
     *
     * @return void
     */
    public function drive_connect()
    {
        if (!mks_st_can_settings(true)) {
            access_denied(_l('mks_st_menu'));
        }

        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_drive_helper.php');

        $state = bin2hex(random_bytes(16));
        $this->session->set_userdata('mks_st_drive_state', $state);

        $url = mks_st_drive_auth_url($state);

        if ($url === null) {
            set_alert('warning', _l('mks_st_drive_client_first'));
            redirect(admin_url(MKS_SALES_TRACK_MODULE_NAME . '/settings?section=storage'));
        }

        redirect($url);
    }

    /**
     * Google sends the administrator back here with a code.
     *
     * @return void
     */
    public function drive_callback()
    {
        if (!mks_st_can_settings(true)) {
            access_denied(_l('mks_st_menu'));
        }

        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_drive_helper.php');

        $state    = (string) $this->input->get('state');
        $expected = (string) $this->session->userdata('mks_st_drive_state');

        $this->session->unset_userdata('mks_st_drive_state');

        if ($expected === '' || !hash_equals($expected, $state)) {
            set_alert('danger', _l('mks_st_drive_state_failed'));
        } elseif ((string) $this->input->get('error') !== '') {
            set_alert('warning', _l('mks_st_drive_declined'));
        } else {
            $result = mks_st_drive_connect((string) $this->input->get('code'));

            if ($result === true) {
                log_activity('Sales Track: Google Drive connected');
                set_alert('success', _l('mks_st_drive_connected'));
            } else {
                set_alert('danger', _l('mks_st_drive_connect_failed', $result));
            }
        }

        redirect(admin_url(MKS_SALES_TRACK_MODULE_NAME . '/settings?section=storage'));
    }

    /**
     * @return void
     */
    public function drive_disconnect()
    {
        $this->mks_require_post();

        if (!mks_st_can_settings(true)) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_no_permission')], 403);
        }

        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_drive_helper.php');

        mks_st_drive_disconnect();
        log_activity('Sales Track: Google Drive disconnected');

        mks_st_json(['success' => true, 'message' => _l('mks_st_drive_disconnected')]);
    }

    /**
     * @return void
     */
    public function event_delete()
    {
        $this->mks_require_post();

        if (!mks_st_can('delete')) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_no_permission')], 403);
        }

        $event = mks_st_event_get((int) $this->input->post('id'));

        if (!$event || !mks_st_event_visible($event)) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_not_found')], 404);
        }

        mks_st_event_delete($event);

        mks_st_json(['success' => true]);
    }

    /**
     * Load or remove the demo data. Administrators only.
     *
     * @return void
     */
    public function demo()
    {
        $this->mks_require_post();

        if (!is_admin()) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_no_permission')], 403);
        }

        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_demo_helper.php');

        if ($this->input->post('action') === 'remove') {
            mks_st_json(['success' => true, 'message' => _l('mks_st_demo_removed', mks_st_number_label(mks_st_demo_remove()))]);
        }

        $loaded = mks_st_demo_load((int) get_staff_user_id());

        if ($loaded === false) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_demo_failed')], 500);
        }

        mks_st_json(['success' => true, 'message' => _l('mks_st_demo_loaded', mks_st_number_label($loaded))]);
    }

    /* ---------------------------------------------------------------------
     * Settings
     * ------------------------------------------------------------------ */

    /**
     * The module's own settings page, drawn from config/settings_schema.php.
     *
     * @return void
     */
    public function settings()
    {
        if (strtolower((string) $this->input->method()) === 'post') {
            if (!mks_st_can_settings(true)) {
                access_denied(_l('mks_st_menu'));
            }

            $saved = mks_st_save_settings($this->input->post('mks_st'));

            // Perfex shows one alert per type, so every warning goes in one.
            if ($saved['errors']) {
                set_alert('warning', implode(' ', array_map('_l', array_unique($saved['errors']))));
            } else {
                set_alert('success', _l('mks_st_settings_saved'));
            }

            $section = (string) $this->input->post('mks_st_section');

            redirect(admin_url(MKS_SALES_TRACK_MODULE_NAME . '/settings' . (preg_match('/^[a-z_]+$/', $section) ? '?section=' . $section : '')));
        }

        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_push_helper.php');
        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_drive_helper.php');
        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_ai_helper.php');

        $schema  = mks_st_settings_schema();
        $section = (string) $this->input->get('section');

        $data = [
            'title'    => _l('mks_st_page_settings'),
            'schema'   => $schema,
            'values'   => mks_st_settings(),
            'section'  => isset($schema['sections'][$section]) ? $section : (string) key($schema['sections']),
            'can_edit' => mks_st_can_settings(true),
            'saved_at' => (string) get_option('mks_sales_track_saved_at'),
            'fcm'      => mks_st_fcm_status(),
            'drive'    => mks_st_drive_state(),
            'ai_spent' => mks_st_ai_spent(),
            'ai_count' => (int) $this->db->where('ai_status', 'done')->count_all_results(mks_st_events_table()),
            'storage'  => $this->mks_storage_counts(),
            'nav'      => 'settings',
        ];

        mks_st_page_config(['page' => 'settings', 'text' => ['copied' => _l('mks_st_copied')]]);

        $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/settings', $data);
    }

    /* ---------------------------------------------------------------------
     * Internals
     * ------------------------------------------------------------------ */

    /**
     * @param  string $view
     *
     * @return void
     */
    private function mks_list($view)
    {
        $page  = mks_st_pages()[$view];
        $scope = mks_st_scope();

        $data = [
            'title'       => _l($page['label']),
            'view'        => $view,
            'page'        => $page,
            'tracking_on' => mks_st_enabled($page['setting']),
            'columns'     => mks_st_view_columns($view),
            'ranges'      => mks_st_range_options(),
            'directions'  => mks_st_direction_filters($view),
            'staff'       => $scope === null ? mks_st_staff_options() : (count($scope) > 1 ? mks_st_staff_options($scope) : []),
            'phones'      => mks_st_device_options($scope),
            'outcomes'    => mks_st_outcomes(false),
            'pitch_categories' => mks_st_pitch_categories(),
            'demo'        => (string) get_option('mks_sales_track_demo') === '1',
            'nav'         => $view,
        ];

        if (mks_st_enabled('ai_enabled')) {
            require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_ai_helper.php');
        }

        mks_st_page_config($this->mks_outcome_config() + ['pitch' => $this->mks_pitch_config()] + ['ai' => [
            'view'    => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/ai_view/'),
            'run'     => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/ai_analyse'),
            'use'     => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/ai_use_suggestion'),
            'working' => _l('mks_st_ai_working'),
        ]] + [
            'page'  => 'list',
            'view'  => $view,
            'table' => mks_st_view_table_config($view),
            'urls'  => [
                'table'  => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/table/' . $view),
                'delete' => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/event_delete'),
            ],
            'text'  => [
                'confirmDelete' => _l('mks_st_confirm_delete_event'),
                'failed'        => _l('mks_st_request_failed'),
                'deleted'       => _l('mks_st_deleted'),
                'cannotPlay'    => _l('mks_st_cannot_play'),
            ],
        ]);

        $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/events', $data);
    }

    /**
     * Recordings by where they are, for Settings > Recording Storage.
     *
     * @return array server, drive, waiting, expired
     */
    private function mks_storage_counts()
    {
        $row = $this->db->query("SELECT SUM(recording_status = 'stored' AND recording_file IS NOT NULL) AS server,"
            . " SUM(recording_status = 'stored' AND drive_file_id IS NOT NULL) AS drive,"
            . " SUM(recording_status = 'stored' AND drive_file_id IS NULL AND recording_file IS NOT NULL AND source <> 'demo') AS waiting,"
            . " SUM(recording_status = 'expired') AS expired FROM " . mks_st_events_table())->row_array();

        return array_map('intval', (array) $row);
    }

    /**
     * What the Best Pitch window needs.
     *
     * @return array
     */
    private function mks_pitch_config()
    {
        return [
            'url'     => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/pitch_save'),
            'manager' => mks_st_can_pitches(),
        ];
    }

    /**
     * What the outcome window needs: the outcome list, Perfex's lead statuses
     * and where to save.
     *
     * @return array
     */
    private function mks_outcome_config()
    {
        return [
            'outcome' => [
                'url'       => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/outcome_save'),
                'followUps' => array_keys(array_filter(mks_st_outcomes(), function ($outcome) {
                    return !empty($outcome['follow_up']);
                })),
                'noteRequired' => mks_st_enabled('note_required'),
                'choose'       => _l('mks_st_choose_outcome'),
            ],
        ];
    }

    /**
     * A new code for a device, with its QR image.
     *
     * @param  array $device
     *
     * @return array
     */
    private function mks_issue_code(array $device)
    {
        $code = mks_st_pairing_create($device['id'], (int) get_staff_user_id());

        return [
            'code_id'    => $code['id'],
            'code'       => substr($code['code'], 0, 3) . ' ' . substr($code['code'], 3),
            'qr'         => mks_st_qr_data_uri($this->mks_qr_payload($code['secret'], $device)),
            'expires_in' => $code['expires'] - time(),
            'site'       => site_url(),
            'name'       => $device['label'],
            'staff'      => mks_st_staff_name($device['staff_id']),
        ];
    }

    /**
     * @param  string $secret
     * @param  array  $device
     *
     * @return string
     */
    private function mks_qr_payload($secret, array $device)
    {
        return (string) json_encode([
            'app'    => MKS_SALES_TRACK_MODULE_NAME,
            'v'      => 2,
            'url'    => site_url(),
            'api'    => site_url(MKS_SALES_TRACK_API_PATH),
            'code'   => $secret,
            'device' => $device['label'],
            'staff'  => mks_st_staff_name($device['staff_id']),
        ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    }

    /**
     * A device the viewer may open, or null.
     *
     * @param  int $id
     *
     * @return array|null
     */
    private function mks_visible_device($id)
    {
        $device = mks_st_device_get($id);

        if (!$device) {
            return null;
        }

        return (mks_st_can('manage_devices') || mks_st_scope_allows($device['staff_id'])) ? $device : null;
    }

    /**
     * @return array
     */
    private function mks_device_urls()
    {
        $base = admin_url(MKS_SALES_TRACK_MODULE_NAME . '/');

        return [
            'save'   => $base . 'device_save',
            'code'   => $base . 'device_code',
            'status' => $base . 'pair_status',
            'action' => $base . 'device_action',
            'device' => $base . 'device/',
            'demo'   => $base . 'demo',
        ];
    }

    /**
     * Strings the device screens' script needs. Placeholders are named, not
     * %s: _l() would consume a %s before the script ever saw it.
     *
     * @return array
     */
    private function mks_device_text()
    {
        return [
            'copied'         => _l('mks_st_copied'),
            'failed'         => _l('mks_st_request_failed'),
            'confirmRevoke'  => _l('mks_st_confirm_revoke'),
            'confirmDelete'  => _l('mks_st_confirm_delete_device'),
            'confirmCode'    => _l('mks_st_confirm_regenerate'),
            'confirmDemoIn'  => _l('mks_st_confirm_demo_load'),
            'confirmDemoOut' => _l('mks_st_confirm_demo_remove'),
            'expiresIn'      => _l('mks_st_pair_expires_in', '{t}'),
            'paired'         => _l('mks_st_pair_done', '{name}'),
            'working'        => _l('mks_st_working'),
        ];
    }

    /**
     * @return void
     */
    private function mks_require_manager()
    {
        $this->mks_require_post();

        if (!mks_st_can('manage_devices')) {
            mks_st_json(['success' => false, 'message' => _l('mks_st_no_permission')], 403);
        }
    }

    /**
     * @return void
     */
    private function mks_require_post()
    {
        if (strtolower((string) $this->input->method()) !== 'post') {
            mks_st_json(['success' => false, 'message' => _l('mks_st_request_failed')], 405);
        }
    }
}
