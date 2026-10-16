<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - workflow.
 *
 * What happens after a call: its outcome and note, the lead status that
 * follows, a lead created from an unknown number, a follow-up kept as a
 * native Perfex reminder, the callback queue for missed calls, the alerts a
 * phone raises, and the cron run that escalates and watches.
 *
 * The same functions serve the phone (through the API) and the CRM screens,
 * so an outcome set on the phone and one set in the browser have exactly the
 * same effects. On the API there is no signed in member of staff, so every
 * write names its actor explicitly instead of trusting get_staff_user_id().
 */

/* =========================================================================
 * OUTCOMES
 * ====================================================================== */

/**
 * The outcome list from Settings, keyed by outcome key.
 *
 * @param  bool $activeOnly
 *
 * @return array
 */
function mks_st_outcomes($activeOnly = true)
{
    $out = [];

    foreach ((array) mks_st_setting('outcomes', []) as $outcome) {
        if (is_array($outcome) && isset($outcome['key']) && (!$activeOnly || !empty($outcome['active']))) {
            $out[$outcome['key']] = $outcome;
        }
    }

    return $out;
}

/**
 * Lead statuses from Perfex, in Perfex's own order.
 *
 * @return array id => name, color, isdefault
 */
function mks_st_lead_statuses()
{
    static $cache = null;

    if ($cache === null) {
        $CI    = &get_instance();
        $cache = [];

        foreach ($CI->db->order_by('statusorder', 'asc')->get(db_prefix() . 'leads_status')->result_array() as $row) {
            $cache[(int) $row['id']] = ['name' => $row['name'], 'color' => $row['color'], 'isdefault' => (int) $row['isdefault']];
        }
    }

    return $cache;
}

/**
 * Lead sources from Perfex.
 *
 * @return array id => name
 */
function mks_st_lead_sources()
{
    static $cache = null;

    if ($cache === null) {
        $CI    = &get_instance();
        $cache = [];

        foreach ($CI->db->order_by('name', 'asc')->get(db_prefix() . 'leads_sources')->result_array() as $row) {
            $cache[(int) $row['id']] = $row['name'];
        }
    }

    return $cache;
}

/**
 * Record an outcome for a call and carry out everything that follows from it.
 *
 * @param  array $event
 * @param  array $input outcome, note, follow_up_at, lead_status, create_lead
 * @param  int   $actor staff id setting it (the phone's owner, or the CRM user)
 *
 * @return array ok, error (code), lead_id
 */
function mks_st_apply_outcome(array $event, array $input, $actor)
{
    $CI = &get_instance();

    if (!in_array($event['kind'], ['call', 'whatsapp_call'], true)) {
        return ['ok' => false, 'error' => 'not_a_call'];
    }

    $outcomes = mks_st_outcomes();
    $key      = isset($input['outcome']) && is_scalar($input['outcome']) ? (string) $input['outcome'] : '';

    if (!isset($outcomes[$key])) {
        return ['ok' => false, 'error' => 'invalid_outcome'];
    }

    $outcome = $outcomes[$key];
    $note    = mks_st_clean_body(isset($input['note']) ? $input['note'] : '', 2000);

    if ($note === '' && mks_st_enabled('note_required')) {
        return ['ok' => false, 'error' => 'note_required'];
    }

    $followUp = null;

    if (isset($input['follow_up_at']) && $input['follow_up_at'] !== '' && $input['follow_up_at'] !== null) {
        $ms = mks_st_clean_time($input['follow_up_at']);

        if ($ms === null || $ms < (time() - 86400) * 1000 || $ms > (time() + 366 * 86400) * 1000) {
            return ['ok' => false, 'error' => 'invalid_follow_up'];
        }

        $followUp = date('Y-m-d H:i:s', (int) floor($ms / 1000));
    }

    $statuses = mks_st_lead_statuses();
    $status   = isset($input['lead_status']) && is_numeric($input['lead_status']) ? (int) $input['lead_status'] : 0;

    if ($status > 0 && !isset($statuses[$status])) {
        return ['ok' => false, 'error' => 'invalid_status'];
    }

    // An unknown number can become a lead in the same step.
    if (!empty($input['create_lead']) && $event['rel_type'] === null && $event['number'] !== null) {
        $name   = is_array($input['create_lead']) && isset($input['create_lead']['name']) ? $input['create_lead']['name'] : '';
        $leadId = mks_st_create_lead_from_event($event, $name, $actor);

        if ($leadId > 0) {
            $event = mks_st_event_get($event['id']);
        }
    }

    $leadId = $event['rel_type'] === 'lead' ? (int) $event['rel_id'] : (int) $event['lead_id'];
    $actorName = mks_st_staff_name($actor);

    if ($leadId > 0 && !$CI->db->select('id')->where('id', $leadId)->get(db_prefix() . 'leads')->row()) {
        $leadId = 0;
    }

    if ($leadId > 0) {
        mks_st_lead_activity($leadId, 'mks_st_act_outcome', $actor, $actorName, [$outcome['label'], $note !== '' ? '. ' . $note : '']);

        $target = $status > 0 ? $status : (int) $outcome['lead_status'];

        if ($key === 'converted') {
            $target = mks_st_converted(array_merge($event, ['outcome_note' => $note]), $leadId, $actor, $target);
        }

        if ($target > 0) {
            mks_st_set_lead_status($leadId, $target, $actor, $actorName);
        }
    }

    // A changed follow-up replaces its reminder, unless it has already fired.
    $reminderId = (int) $event['reminder_id'];

    if ($reminderId > 0 && $followUp !== $event['follow_up_at']) {
        $CI->db->where('id', $reminderId)->where('isnotified', 0)->delete(db_prefix() . 'reminders');
        $reminderId = 0;
    }

    if ($followUp !== null && $reminderId === 0) {
        $reminderId = mks_st_follow_up_reminder($event, $leadId, $followUp, $outcome['label'], $note, $actor);
    }

    $CI->db->where('id', (int) $event['id']);
    $CI->db->update(mks_st_events_table(), [
        'outcome'      => $key,
        'outcome_note' => $note !== '' ? $note : null,
        'outcome_at'   => date('Y-m-d H:i:s'),
        'outcome_by'   => (int) $actor,
        'follow_up_at' => $followUp,
        'reminder_id'  => $reminderId > 0 ? $reminderId : null,
    ]);

    return ['ok' => true, 'lead_id' => $leadId];
}

/**
 * The Converted outcome. Returns the status to set now, or 0.
 *
 * In review mode the lead is left for a manager to convert with Perfex's own
 * Convert To Customer, and managers are told, including when the number is
 * already one of the customers' contacts. In status mode the lead simply
 * moves to the chosen status, for CRMs that run on leads alone.
 *
 * @param  array $event
 * @param  int   $leadId
 * @param  int   $actor
 * @param  int   $requested status the caller asked for, if any
 *
 * @return int
 */
function mks_st_converted(array $event, $leadId, $actor, $requested)
{
    if (mks_st_setting('converted_action') === 'status') {
        $status = (int) mks_st_setting('converted_status', 0);

        if ($status <= 0) {
            foreach (mks_st_lead_statuses() as $id => $row) {
                if ($row['isdefault'] === 1) {
                    $status = $id;
                }
            }
        }

        return $status > 0 ? $status : $requested;
    }

    $CI     = &get_instance();
    $lead   = $CI->db->select('name')->where('id', $leadId)->get(db_prefix() . 'leads')->row();
    $params = [$lead ? $lead->name : '#' . $leadId, mks_st_staff_name($actor)];
    $key    = ($event['rel_type'] === 'customer' && mks_st_enabled('match_customers')) ? 'mks_st_note_ready_to_convert_customer' : 'mks_st_note_ready_to_convert';

    mks_st_notify(mks_st_managers(), $key, $params, 'leads/index/' . (int) $leadId, false);

    return $requested;
}

/**
 * Create a lead for an unknown number, by the rules in Settings.
 *
 * Goes through core's Leads_model, so Perfex's own hooks, activity log and
 * assignment notification all happen, and our lead_created hook links every
 * earlier call with this number to the new lead.
 *
 * @param  array  $event
 * @param  string $name
 * @param  int    $actor
 *
 * @return int lead id, 0 on failure
 */
function mks_st_create_lead_from_event(array $event, $name, $actor)
{
    $CI = &get_instance();

    $status = (int) mks_st_setting('lead_status', 0) ?: (int) get_option('leads_default_status');
    $source = (int) mks_st_setting('lead_source', 0) ?: (int) get_option('leads_default_source');

    if ($status <= 0) {
        $status = (int) key(mks_st_lead_statuses());
    }

    if ($source <= 0) {
        $source = (int) key(mks_st_lead_sources());
    }

    switch (mks_st_setting('lead_assign')) {
        case 'fixed':
            $assigned = (int) mks_st_setting('lead_assign_staff', 0);
            break;

        case 'none':
            $assigned = 0;
            break;

        default:
            $assigned = (int) $event['staff_id'];
    }

    $name = mks_st_clean_line($name, 191);

    if ($name === '') {
        $name = $event['contact_name'] !== null && $event['contact_name'] !== '' ? $event['contact_name'] : 'Caller ' . mks_st_format_number($event['number']);
    }

    $CI->load->model('leads_model');

    $id = (int) $CI->leads_model->add([
        'name'        => $name,
        'phonenumber' => (string) $event['number'],
        'status'      => $status,
        'source'      => $source,
        'assigned'    => $assigned,
        'description' => 'Created from a ' . ($event['kind'] === 'whatsapp_call' ? 'WhatsApp call' : 'call') . ' by Sales Track.',
        'address'     => '',
        'email'       => '',
    ]);

    if ($id > 0) {
        // Core names whoever is signed in, and on the API nobody is. The name
        // is looked up first: a lookup between where() and update() would
        // run its own query on the half-built one.
        $actorName = mks_st_staff_name($actor);

        $CI->db->where('id', $id)->update(db_prefix() . 'leads', ['addedfrom' => (int) $actor]);
        $CI->db->where('leadid', $id)->where('staffid', 0)->where('full_name', '')
            ->update(db_prefix() . 'lead_activity_log', ['staffid' => (int) $actor, 'full_name' => $actorName]);
        mks_st_rematch_lead($id);
    }

    return $id;
}

/**
 * Move a lead to a status the way core does, naming the real actor.
 *
 * @param  int    $leadId
 * @param  int    $status
 * @param  int    $actor
 * @param  string $actorName
 *
 * @return void
 */
function mks_st_set_lead_status($leadId, $status, $actor, $actorName)
{
    $CI       = &get_instance();
    $statuses = mks_st_lead_statuses();
    $lead     = $CI->db->select('status')->where('id', (int) $leadId)->get(db_prefix() . 'leads')->row();

    if (!$lead || !isset($statuses[$status]) || (int) $lead->status === (int) $status) {
        return;
    }

    $old = isset($statuses[(int) $lead->status]) ? $statuses[(int) $lead->status]['name'] : '';

    $CI->db->where('id', (int) $leadId);
    $CI->db->update(db_prefix() . 'leads', ['status' => (int) $status, 'last_status_change' => date('Y-m-d H:i:s')]);

    $CI->db->insert(db_prefix() . 'lead_activity_log', [
        'date'            => date('Y-m-d H:i:s'),
        'description'     => 'not_lead_activity_status_updated',
        'leadid'          => (int) $leadId,
        'staffid'         => (int) $actor,
        'additional_data' => serialize([$actorName, $old, $statuses[$status]['name']]),
        'full_name'       => $actorName,
    ]);

    hooks()->do_action('lead_status_changed', ['lead_id' => (int) $leadId, 'old_status' => $old, 'new_status' => $statuses[$status]['name']]);
}

/**
 * One line in the lead's own activity log. Like core, the line is a language
 * key with its values serialised alongside, so it reads in any language.
 *
 * @param  int    $leadId
 * @param  string $key
 * @param  int    $actor
 * @param  string $actorName
 * @param  array  $params
 *
 * @return void
 */
function mks_st_lead_activity($leadId, $key, $actor, $actorName, array $params = [])
{
    $CI = &get_instance();

    $CI->db->insert(db_prefix() . 'lead_activity_log', [
        'date'            => date('Y-m-d H:i:s'),
        'description'     => $key,
        'leadid'          => (int) $leadId,
        'staffid'         => (int) $actor,
        'additional_data' => $params ? serialize(array_map('strval', $params)) : '',
        'full_name'       => $actorName,
    ]);
}

/**
 * A follow-up as a native Perfex reminder on the lead or customer, so Perfex's
 * own cron, notifications and reminder lists handle it.
 *
 * Without a lead or customer there is nothing to hang a Perfex reminder on;
 * the follow-up then lives on the call alone.
 *
 * @return int reminder id, 0 when none was made
 */
function mks_st_follow_up_reminder(array $event, $leadId, $date, $label, $note, $actor)
{
    $CI = &get_instance();

    if ($leadId > 0) {
        $relType = 'lead';
        $relId   = (int) $leadId;
    } elseif ($event['rel_type'] === 'customer' && mks_st_enabled('match_customers')) {
        $relType = 'customer';
        $relId   = (int) $event['rel_id'];
    } else {
        return 0;
    }

    $description = 'Sales Track follow-up: ' . $label . ($note !== '' ? '. ' . $note : '') . ' (' . mks_st_format_number($event['number']) . ')';

    $CI->db->insert(db_prefix() . 'reminders', [
        'description'     => nl2br(e($description)),
        'date'            => $date,
        'isnotified'      => 0,
        'rel_id'          => $relId,
        'staff'           => (int) $event['staff_id'],
        'rel_type'        => $relType,
        'notify_by_email' => mks_st_enabled('follow_up_email') ? 1 : 0,
        'creator'         => (int) $actor,
    ]);

    $id = (int) $CI->db->insert_id();

    if ($id > 0 && $relType === 'lead') {
        $CI->db->insert(db_prefix() . 'lead_activity_log', [
            'date'            => date('Y-m-d H:i:s'),
            'description'     => 'not_activity_new_reminder_created',
            'leadid'          => $relId,
            'staffid'         => (int) $actor,
            'additional_data' => serialize([mks_st_staff_name($event['staff_id']), _dt($date)]),
            'full_name'       => mks_st_staff_name($actor),
        ]);
    }

    return $id;
}

/**
 * Leads waiting for a manager to convert them: a Converted outcome on one of
 * their calls, and not yet converted in Perfex.
 *
 * @param  int[]|null $ids
 *
 * @return array
 */
function mks_st_ready_to_convert($ids)
{
    $CI = &get_instance();
    $p  = db_prefix();

    return $CI->db->query('SELECT l.id, l.name, MAX(e.outcome_at) AS at, MAX(e.staff_id) AS staff_id,'
        . " MAX(e.rel_type = 'customer') AS is_customer"
        . ' FROM ' . mks_st_events_table() . ' e'
        . ' JOIN ' . $p . "leads l ON l.id = IF(e.rel_type = 'lead', e.rel_id, e.lead_id)"
        . " WHERE e.outcome = 'converted' AND l.date_converted IS NULL " . mks_st_scope_sql('e.staff_id', $ids)
        . ' GROUP BY l.id, l.name ORDER BY at DESC LIMIT 10')->result_array();
}

/* =========================================================================
 * PEOPLE TO TELL
 * ====================================================================== */

/**
 * Administrators and everybody with View All Activity.
 *
 * @return int[]
 */
function mks_st_managers()
{
    $CI = &get_instance();
    $p  = db_prefix();

    $rows = $CI->db->query('SELECT staffid FROM ' . $p . 'staff WHERE active = 1 AND (admin = 1 OR staffid IN ('
        . 'SELECT staff_id FROM ' . $p . "staff_permissions WHERE feature = 'mks_sales_track' AND capability = 'view'))")->result_array();

    return array_map('intval', array_column($rows, 'staffid'));
}

/**
 * Team leads of a member of staff: people with View Team Activity who share
 * a Perfex department with them.
 *
 * @param  int $staffId
 *
 * @return int[]
 */
function mks_st_team_leads_of($staffId)
{
    $CI = &get_instance();
    $p  = db_prefix();

    $rows = $CI->db->query('SELECT DISTINCT b.staffid FROM ' . $p . 'staff_departments a'
        . ' JOIN ' . $p . 'staff_departments b ON b.departmentid = a.departmentid'
        . ' JOIN ' . $p . 'staff s ON s.staffid = b.staffid AND s.active = 1'
        . ' JOIN ' . $p . "staff_permissions sp ON sp.staff_id = b.staffid AND sp.feature = 'mks_sales_track' AND sp.capability = 'view_team'"
        . ' WHERE a.staffid = ' . (int) $staffId . ' AND b.staffid <> ' . (int) $staffId)->result_array();

    return array_map('intval', array_column($rows, 'staffid'));
}

/**
 * Who hears about something a member of staff did or missed. Team leads fall
 * back to managers when the person has none.
 *
 * @param  int    $staffId
 * @param  string $mode team_leads, managers or both
 *
 * @return int[]
 */
function mks_st_recipients($staffId, $mode)
{
    $leads = $mode === 'managers' ? [] : mks_st_team_leads_of($staffId);

    if ($mode === 'team_leads' && $leads) {
        return $leads;
    }

    return array_values(array_unique(array_merge($leads, mks_st_managers())));
}

/**
 * A Perfex notification, and optionally an email through the CRM's own SMTP.
 * The text is a language key with its values serialised, the way core's own
 * notifications are stored, so each person reads it in their language.
 *
 * @param  int[]  $staffIds
 * @param  string $key
 * @param  array  $params
 * @param  string $link  admin path
 * @param  bool   $email
 *
 * @return void
 */
function mks_st_notify(array $staffIds, $key, array $params, $link, $email)
{
    $CI       = &get_instance();
    $notified = [];
    $params   = array_map('strval', $params);
    $text     = _l($key, $params);

    foreach (array_unique(array_map('intval', $staffIds)) as $staffId) {
        if ($staffId <= 0) {
            continue;
        }

        if (add_notification(['description' => $key, 'additional_data' => serialize($params), 'touserid' => $staffId, 'link' => $link, 'fromcompany' => 1])) {
            $notified[] = $staffId;
        }

        if ($email) {
            $row = $CI->db->select('email')->where('staffid', $staffId)->where('active', 1)->get(db_prefix() . 'staff')->row();

            if ($row && $row->email !== '') {
                $CI->load->model('emails_model');
                $CI->emails_model->send_simple_email($row->email, 'Sales Track: ' . mb_substr($text, 0, 80, 'UTF-8'),
                    e($text) . '<br><br><a href="' . admin_url($link) . '">' . admin_url($link) . '</a>');
            }
        }
    }

    if ($notified && function_exists('pusher_trigger_notification')) {
        pusher_trigger_notification($notified);
    }
}

/* =========================================================================
 * CALLBACK QUEUE
 * ====================================================================== */

/**
 * Opening and closing time of a working day, or null on a day off.
 *
 * @param  int $day any time on that day
 *
 * @return array|null [start, end] timestamps
 */
function mks_st_work_window($day)
{
    $days = array_map('intval', (array) mks_st_setting('working_days', [1, 2, 3, 4, 5]));

    if (!in_array((int) date('N', $day), $days, true)) {
        return null;
    }

    $date = date('Y-m-d', $day);

    return [
        strtotime($date . ' ' . mks_st_setting('work_start', '09:30') . ':00'),
        strtotime($date . ' ' . mks_st_setting('work_end', '18:30') . ':00'),
    ];
}

/**
 * When a missed call has to be returned by: the callback time counted in
 * working hours only, so a call missed at 9 PM is due the next morning.
 *
 * @param  string $occurred Y-m-d H:i:s
 *
 * @return string Y-m-d H:i:s
 */
function mks_st_callback_due($occurred)
{
    $left   = max(1, (int) mks_st_setting('callback_minutes', 30)) * 60;
    $cursor = strtotime($occurred);

    for ($i = 0; $i < 30; $i++) {
        $window = mks_st_work_window($cursor);

        if ($window === null || $cursor >= $window[1]) {
            $cursor = strtotime(date('Y-m-d', $cursor) . ' 00:00:00 +1 day');

            continue;
        }

        $cursor = max($cursor, $window[0]);

        if ($cursor + $left <= $window[1]) {
            return date('Y-m-d H:i:s', $cursor + $left);
        }

        $left  -= $window[1] - $cursor;
        $cursor = strtotime(date('Y-m-d', $cursor) . ' 00:00:00 +1 day');
    }

    return date('Y-m-d H:i:s', strtotime($occurred) + $left);
}

/**
 * After a sync: every connected call clears the open missed calls from its
 * number that came before it, whoever made it; and a missed call imported
 * after its own callback is cleared straight away.
 *
 * @param  array $rows the events just stored
 *
 * @return void
 */
function mks_st_callbacks_settle(array $rows)
{
    $CI    = &get_instance();
    $table = mks_st_events_table();
    $t     = mks_st_connected_seconds();

    foreach ($rows as $row) {
        if ($row['number_key'] === null || !in_array($row['kind'], ['call', 'whatsapp_call'], true) || (int) $row['duration'] < $t) {
            continue;
        }

        $CI->db->where('number_key', $row['number_key'])
            ->where_in('callback_state', ['open', 'escalated'])
            ->where('occurred_at <=', $row['occurred_at'])
            ->update($table, ['callback_state' => 'resolved', 'callback_at' => $row['occurred_at'], 'callback_by' => (int) $row['staff_id']]);
    }

    foreach ($rows as $row) {
        if ($row['callback_state'] !== 'open') {
            continue;
        }

        $later = $CI->db->query('SELECT occurred_at, staff_id FROM ' . $table . ' WHERE number_key = ' . $CI->db->escape($row['number_key'])
            . " AND kind IN ('call', 'whatsapp_call') AND duration >= " . $t . ' AND occurred_at > ' . $CI->db->escape($row['occurred_at'])
            . ' ORDER BY occurred_at ASC LIMIT 1')->row_array();

        if ($later) {
            $CI->db->where('device_id', (int) $row['device_id'])->where('uid', $row['uid'])
                ->update($table, ['callback_state' => 'resolved', 'callback_at' => $later['occurred_at'], 'callback_by' => (int) $later['staff_id']]);
        }
    }
}

/* =========================================================================
 * DEVICE ALERTS
 * ====================================================================== */

/**
 * Alert types a phone can raise, or the CRM raises about a phone.
 *
 * @return array type => setting that governs telling people
 */
function mks_st_alert_types()
{
    return [
        'call_log_deleted' => 'alert_tamper',
        'sms_deleted'      => 'alert_tamper',
        'clock_changed'    => 'alert_tamper',
        'app_data_cleared' => 'alert_tamper',
        'permission_lost'  => 'alert_permissions',
        'silent'           => 'alert_silent_hours',
    ];
}

/**
 * Keep an alert on the device and tell the right people, at most once every
 * six hours per device and type.
 *
 * @param  array  $device
 * @param  string $type
 * @param  string $detail
 *
 * @return bool kept
 */
function mks_st_device_alert(array $device, $type, $detail)
{
    $types = mks_st_alert_types();

    if (!isset($types[$type])) {
        return false;
    }

    $CI     = &get_instance();
    $alerts = mks_st_decode(isset($device['alerts']) ? $device['alerts'] : '');
    $detail = mks_st_clean_line($detail, 200);
    $quiet  = false;

    foreach ($alerts as $alert) {
        if ($alert['type'] === $type && strtotime($alert['t']) > time() - 6 * 3600) {
            $quiet = true;
            break;
        }
    }

    array_unshift($alerts, ['t' => date('Y-m-d H:i:s'), 'type' => $type, 'detail' => $detail]);

    $CI->db->where('id', (int) $device['id']);
    $CI->db->update(mks_st_devices_table(), ['alerts' => json_encode(array_slice($alerts, 0, 30))]);

    if (!$quiet && mks_st_enabled($types[$type])) {
        mks_st_notify(mks_st_recipients((int) $device['staff_id'], (string) mks_st_setting('alert_to', 'managers')),
            'mks_st_note_alert_' . $type, [$device['label'], mks_st_staff_name($device['staff_id']), $detail !== '' ? ': ' . $detail : ''],
            MKS_SALES_TRACK_MODULE_NAME . '/device/' . (int) $device['id'], mks_st_enabled('alert_email'));
    }

    return true;
}

/**
 * Permissions that were granted on the last heartbeat and are not any more.
 *
 * @param  array $device
 * @param  array $health cleaned new health
 *
 * @return void
 */
function mks_st_device_health_check(array $device, array $health)
{
    $before = mks_st_decode($device['health']);
    $before = isset($before['permissions']) ? $before['permissions'] : [];
    $now    = isset($health['permissions']) ? $health['permissions'] : [];
    $lost   = [];

    foreach ($now as $key => $granted) {
        if (!$granted && !empty($before[$key])) {
            $lost[] = $key;
        }
    }

    if ($lost) {
        mks_st_device_alert($device, 'permission_lost', implode(', ', $lost));
    }
}

/* =========================================================================
 * CRON
 * ====================================================================== */

/**
 * Escalate missed calls past their callback time, and flag phones that have
 * gone quiet in working hours. Runs with Perfex's cron, at most every four
 * minutes.
 *
 * @return void
 */
function mks_st_cron_run()
{
    $last = (int) get_option('mks_sales_track_cron_at');

    if ($last > time() - 240) {
        return;
    }

    mks_st_option_put('mks_sales_track_cron_at', (string) time(), 0);

    $CI    = &get_instance();
    $table = mks_st_events_table();

    if (mks_st_enabled('escalate')) {
        $overdue = $CI->db->query('SELECT id, staff_id, number, number_raw, contact_name, occurred_at FROM ' . $table
            . " WHERE callback_state = 'open' AND callback_due_at < " . $CI->db->escape(date('Y-m-d H:i:s'))
            . ' ORDER BY callback_due_at ASC LIMIT 200')->result_array();

        foreach ($overdue as $call) {
            $who = $call['contact_name'] ?: mks_st_format_number($call['number'] ?: $call['number_raw']);

            mks_st_notify(mks_st_recipients((int) $call['staff_id'], (string) mks_st_setting('escalate_to', 'team_leads')), 'mks_st_note_missed',
                [$who, mks_st_staff_name($call['staff_id']), _dt($call['occurred_at'])], MKS_SALES_TRACK_MODULE_NAME . '/missed_calls', mks_st_enabled('escalate_email'));

            $CI->db->where('id', (int) $call['id'])->update($table, ['callback_state' => 'escalated', 'escalated_at' => date('Y-m-d H:i:s')]);
        }
    }

    // Recordings: Drive uploads, server copies whose time is up, retention.
    require_once __DIR__ . '/mks_sales_track_drive_helper.php';
    mks_st_storage_run();

    // AI insights for new recordings, by the rule in Settings.
    if (mks_st_enabled('ai_enabled')) {
        require_once __DIR__ . '/mks_sales_track_ai_helper.php';
        mks_st_ai_run();
    }

    // Scheduled email reports (and the weekly AI coaching that rides with
    // them), when any is switched on.
    if (mks_st_enabled('report_daily') || mks_st_enabled('report_weekly') || mks_st_enabled('report_monthly')
        || (mks_st_enabled('ai_enabled') && mks_st_enabled('ai_coaching'))) {
        require_once __DIR__ . '/mks_sales_track_reports_helper.php';
        mks_st_reports_run();
    }

    $hours  = (int) mks_st_setting('alert_silent_hours', 2);
    $window = mks_st_work_window(time());

    if ($hours > 0 && $window !== null && time() >= $window[0] + $hours * 3600 && time() <= $window[1]) {
        $quiet = $CI->db->query('SELECT * FROM ' . mks_st_devices_table() . " WHERE status = 'active' AND last_seen_at IS NOT NULL"
            . ' AND last_seen_at < ' . $CI->db->escape(date('Y-m-d H:i:s', time() - $hours * 3600)))->result_array();

        foreach ($quiet as $device) {
            mks_st_device_alert($device, 'silent', 'last seen ' . _dt($device['last_seen_at']));
        }
    }
}

/* =========================================================================
 * AFTER A SYNC: LAST CONTACT AND LEADS BY RULE
 * ====================================================================== */

/**
 * Calls just stored: bring the leads' Last Contact up to date and create
 * leads for unknown numbers when the rules in Settings say so.
 *
 * @param  array $device
 * @param  array $rows   the rows just written, keyed by uid
 *
 * @return void
 */
function mks_st_after_calls(array $device, array $rows)
{
    // Demo data must never create real leads or move a real lead's Last
    // Contact: removing the demo could not undo either.
    $rows = array_filter($rows, function ($row) {
        return !isset($row['source']) || $row['source'] !== 'demo';
    });

    if (!$rows) {
        return;
    }

    $settings = mks_st_settings();
    $leads    = [];
    $created  = [];

    if (!empty($settings['auto_lead'])) {
        foreach ($rows as $row) {
            if (isset($created[$row['number_key']]) || !mks_st_auto_lead_wanted($row, $settings, $device['paired_at'])) {
                continue;
            }

            $event = mks_st_event_by_uid($device['id'], $row['uid']);

            // An earlier row in this batch may have created the lead already.
            if (!$event || $event['rel_type'] !== null) {
                continue;
            }

            $created[$row['number_key']] = true;

            $leadId = mks_st_create_lead_from_event($event, '', (int) $device['staff_id']);

            if ($leadId > 0) {
                mks_st_lead_activity($leadId, 'mks_st_act_auto_lead', (int) $device['staff_id'], mks_st_staff_name($device['staff_id']));
                $leads[$leadId] = true;
            }
        }
    }

    if (empty($settings['update_last_contact'])) {
        return;
    }

    $t = mks_st_connected_seconds();

    foreach ($rows as $row) {
        if (in_array($row['kind'], ['call', 'whatsapp_call'], true) && (int) $row['duration'] >= $t) {
            if ($row['rel_type'] === 'lead') {
                $leads[(int) $row['rel_id']] = true;
            } elseif (!empty($row['lead_id'])) {
                $leads[(int) $row['lead_id']] = true;
            }
        }
    }

    foreach (array_keys($leads) as $leadId) {
        mks_st_lead_last_contact($leadId);
    }
}

/**
 * Would the rules in Settings create a lead from this call?
 *
 * @param  array       $row       an event row
 * @param  array       $settings
 * @param  string|null $pairedAt  when the phone paired; earlier calls came in as history
 *
 * @return bool
 */
function mks_st_auto_lead_wanted(array $row, array $settings, $pairedAt)
{
    if ($row['rel_type'] !== null || $row['number'] === null || $row['number_key'] === null) {
        return false;
    }

    if ($row['kind'] !== 'call' && !($row['kind'] === 'whatsapp_call' && !empty($settings['auto_lead_whatsapp']))) {
        return false;
    }

    $direction = (string) $settings['auto_lead_direction'];

    if (!in_array($row['direction'], $direction === 'both' ? ['incoming', 'outgoing'] : [$direction], true)) {
        return false;
    }

    if ((int) $row['duration'] < max((int) $settings['auto_lead_min_seconds'], (int) $settings['connected_seconds'], 1)) {
        return false;
    }

    if (empty($settings['auto_lead_history']) && $pairedAt !== null && $pairedAt !== '' && $row['occurred_at'] < $pairedAt) {
        return false;
    }

    if (!empty($settings['auto_lead_working_hours'])) {
        $at     = strtotime($row['occurred_at']);
        $window = mks_st_work_window($at);

        if ($window === null || $at < $window[0] || $at > $window[1]) {
            return false;
        }
    }

    return true;
}

/**
 * Set a lead's Last Contact to its latest connected call, never moving it
 * backwards.
 *
 * @param  int $leadId
 *
 * @return void
 */
function mks_st_lead_last_contact($leadId)
{
    if (!mks_st_enabled('update_last_contact')) {
        return;
    }

    $CI     = &get_instance();
    $latest = $CI->db->query('SELECT MAX(occurred_at) AS at FROM ' . mks_st_events_table()
        . " WHERE kind IN ('call', 'whatsapp_call') AND duration >= " . mks_st_connected_seconds()
        . " AND ((rel_type = 'lead' AND rel_id = " . (int) $leadId . ') OR lead_id = ' . (int) $leadId . ')')->row_array();

    if (empty($latest['at'])) {
        return;
    }

    $CI->db->where('id', (int) $leadId);
    $CI->db->group_start()->where('lastcontact IS NULL', null, false)->or_where('lastcontact <', $latest['at'])->group_end();
    $CI->db->update(db_prefix() . 'leads', ['lastcontact' => $latest['at']]);
}

/* =========================================================================
 * CALLS TABS ON LEADS AND CUSTOMERS
 * ====================================================================== */

/**
 * The calls, WhatsApp calls and SMS of one lead or customer that the viewer
 * may see, newest first.
 *
 * @param  string $rel   lead or customer
 * @param  int    $relId
 * @param  int    $limit
 *
 * @return array events, totals
 */
function mks_st_crm_events($rel, $relId, $limit = 50)
{
    $CI = &get_instance();

    if ($rel === 'lead') {
        $match = "((e.rel_type = 'lead' AND e.rel_id = " . (int) $relId . ') OR e.lead_id = ' . (int) $relId . ')';
    } elseif ($rel === 'customer' && mks_st_customer_visible()) {
        $match = "(e.rel_type = 'customer' AND e.rel_id = " . (int) $relId . ')';
    } else {
        return ['events' => [], 'totals' => ['calls' => 0, 'talk' => 0, 'last' => null]];
    }

    $where = 'WHERE ' . $match . " AND e.kind IN ('call', 'whatsapp_call', 'sms', 'whatsapp_message', 'notification') " . mks_st_scope_sql('e.staff_id');
    $table = mks_st_events_table();

    $totals = $CI->db->query("SELECT SUM(e.kind IN ('call', 'whatsapp_call')) AS calls,"
        . " COALESCE(SUM(CASE WHEN e.kind IN ('call', 'whatsapp_call') THEN e.duration ELSE 0 END), 0) AS talk,"
        . ' MAX(e.occurred_at) AS last FROM ' . $table . ' e ' . $where)->row_array();

    $ids    = array_map('intval', array_column($CI->db->query('SELECT e.id FROM ' . $table . ' e ' . $where
        . ' ORDER BY e.occurred_at DESC LIMIT ' . (int) $limit)->result_array(), 'id'));
    $detail = mks_st_events_detail($ids);
    $events = [];

    foreach ($ids as $id) {
        if (isset($detail[$id])) {
            $events[] = $detail[$id];
        }
    }

    return ['events' => $events, 'totals' => ['calls' => (int) $totals['calls'], 'talk' => (int) $totals['talk'], 'last' => $totals['last']]];
}

/* =========================================================================
 * CLICK TO CALL
 * ====================================================================== */

/**
 * The signed in member of staff's own phone, if it can take commands.
 *
 * @return array|null
 */
function mks_st_my_phone()
{
    static $phone = false;

    if ($phone === false) {
        $CI    = &get_instance();
        $phone = $CI->db->where('staff_id', (int) get_staff_user_id())->where('status', 'active')
            ->order_by('last_seen_at', 'desc')->limit(1)->get(mks_st_devices_table())->row_array() ?: null;
    }

    return $phone;
}

/**
 * What the page script needs for Call buttons.
 *
 * @return array
 */
function mks_st_dial_config()
{
    $phone = mks_st_enabled('click_to_call') ? mks_st_my_phone() : null;

    return [
        'enabled' => $phone !== null,
        'url'     => admin_url(MKS_SALES_TRACK_MODULE_NAME . '/dial'),
        'text'    => ['confirm' => _l('mks_st_dial_confirm_text', '{number}'), 'failed' => _l('mks_st_request_failed')],
    ];
}

/**
 * A Call button, or nothing when click-to-call is off or the viewer has no
 * phone paired.
 *
 * @param  string|null $number
 * @param  string      $name
 * @param  bool        $small
 *
 * @return string
 */
function mks_st_dial_button($number, $name = '', $small = true)
{
    $digits = preg_replace('/[^\d+]/', '', (string) $number);

    if (strlen(ltrim($digits, '+')) < 6 || !mks_st_enabled('click_to_call') || mks_st_my_phone() === null) {
        return '';
    }

    require_once __DIR__ . '/mks_sales_track_lists_helper.php';

    if (mks_st_is_dnc($digits)) {
        return '<span class="mks-sales-track-pill mks-sales-track-tone-red mks-sales-track-dnc" title="' . e(_l('mks_st_dnc_hint')) . '">'
            . '<i class="fa-solid fa-ban" aria-hidden="true"></i>' . e(_l('mks_st_dnc')) . '</span>';
    }

    return '<button type="button" class="btn btn-default ' . ($small ? 'btn-xs ' : '') . 'mks-sales-track-dial" data-number="' . e($digits) . '"'
        . ' data-name="' . e((string) $name) . '" title="' . e(_l('mks_st_call_from_phone')) . '">'
        . '<i class="fa-solid fa-phone" aria-hidden="true"></i> ' . e(_l('mks_st_call')) . '</button>';
}

/**
 * Ask the signed in member of staff's phone to dial a number.
 *
 * @param  string $number
 * @param  string $name
 * @param  int    $actor
 *
 * @return array ok, message (language key), pushed
 */
function mks_st_dial($number, $name, $actor)
{
    require_once __DIR__ . '/mks_sales_track_lists_helper.php';

    if (mks_st_is_dnc($number)) {
        return ['ok' => false, 'message' => 'mks_st_dial_dnc', 'pushed' => false];
    }

    $digits = preg_replace('/[^\d+]/', '', (string) $number);

    if (!mks_st_enabled('click_to_call')) {
        return ['ok' => false, 'message' => 'mks_st_dial_off', 'pushed' => false];
    }

    if (strlen(ltrim($digits, '+')) < 6 || strlen($digits) > 20) {
        return ['ok' => false, 'message' => 'mks_st_dial_bad_number', 'pushed' => false];
    }

    $phone = mks_st_my_phone();

    if ($phone === null) {
        return ['ok' => false, 'message' => 'mks_st_dial_no_phone', 'pushed' => false];
    }

    $params = ['number' => $digits, 'name' => mks_st_clean_line($name, 100)];
    $id     = mks_st_device_command_add($phone, 'dial', $actor, $params);

    if ($id === false) {
        return ['ok' => false, 'message' => 'mks_st_dial_no_phone', 'pushed' => false];
    }

    $pushed  = false;
    $message = 'mks_st_dial_queued';

    if (!empty($phone['push_token']) && (string) get_option('mks_sales_track_fcm') !== '') {
        require_once __DIR__ . '/mks_sales_track_push_helper.php';

        $sent    = mks_st_fcm_send($phone, ['type' => 'command', 'id' => $id, 'command' => 'dial', 'number' => $digits, 'name' => $params['name']], 120);
        $pushed  = $sent['ok'];
        $message = $pushed ? 'mks_st_dial_sent' : 'mks_st_dial_push_failed';
    }

    return ['ok' => true, 'message' => $message, 'pushed' => $pushed];
}

/**
 * Wake a phone so it collects a queued command at once. Quietly does nothing
 * without Firebase.
 *
 * @param  array  $device
 * @param  string $id
 * @param  string $type
 *
 * @return bool pushed
 */
function mks_st_push_wake(array $device, $id, $type)
{
    if (empty($device['push_token']) || (string) get_option('mks_sales_track_fcm') === '') {
        return false;
    }

    require_once __DIR__ . '/mks_sales_track_push_helper.php';

    return mks_st_fcm_send($device, ['type' => 'command', 'id' => $id, 'command' => $type], 300)['ok'];
}

/* =========================================================================
 * BEST PITCHES AND THE LISTENING LOG
 * ====================================================================== */

/**
 * The Best Pitch categories from Settings.
 *
 * @return string[]
 */
function mks_st_pitch_categories()
{
    return array_values(array_filter(array_map('trim', preg_split('/[\r\n]+/', (string) mks_st_setting('pitch_categories', '')))));
}

/**
 * Moments worth hearing, one per line: "1:20 The opening question", or a
 * number of seconds. At most twenty, in time order.
 *
 * @param  string $text
 *
 * @return array [t, label]
 */
function mks_st_parse_moments($text)
{
    $out = [];

    foreach (preg_split('/[\r\n]+/', (string) $text) as $line) {
        if (preg_match('/^\s*(?:(\d{1,3}):)?(\d{1,2}|\d+)\s*(.*)$/u', $line, $m) && trim($line) !== '') {
            $seconds = $m[1] !== '' ? (int) $m[1] * 60 + (int) $m[2] : (int) $m[2];
            $label   = mb_substr(trim(strip_tags($m[3])), 0, 80, 'UTF-8');

            if ($m[1] !== '' && (int) $m[2] > 59) {
                continue;
            }

            $out[] = ['t' => $seconds, 'label' => $label];
        }
    }

    usort($out, function ($a, $b) {
        return $a['t'] - $b['t'];
    });

    return array_slice($out, 0, 20);
}

/**
 * Write who played or downloaded a recording to Perfex's activity log. A
 * player asks for one recording many times while seeking, so a listen is
 * logged once per person and recording every ten minutes.
 *
 * @param  array $event
 * @param  bool  $download
 *
 * @return void
 */
function mks_st_recording_audit(array $event, $download)
{
    if (!mks_st_enabled('audit_recordings')) {
        return;
    }

    $range = isset($_SERVER['HTTP_RANGE']) ? (string) $_SERVER['HTTP_RANGE'] : '';

    if (!$download && $range !== '' && !preg_match('/^bytes=0-/', $range)) {
        return;
    }

    $CI   = &get_instance();
    $key  = ($download ? 'd' : 'p') . (int) $event['id'];
    $seen = (array) $CI->session->userdata('mks_st_listened');

    if (isset($seen[$key]) && $seen[$key] > time() - 600) {
        return;
    }

    $seen[$key] = time();
    $CI->session->set_userdata('mks_st_listened', array_slice($seen, -100, null, true));

    log_activity('Sales Track: recording ' . ($download ? 'downloaded' : 'played') . ' [#' . (int) $event['id'] . ', '
        . mks_st_staff_name($event['staff_id']) . ', ' . mks_st_format_number($event['number'] ?: $event['number_raw']) . ', ' . $event['occurred_at'] . ']');
}
