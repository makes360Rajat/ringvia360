<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - demo data.
 *
 * Lets the screens be reviewed before any phone app exists. Every demo event
 * goes through mks_st_ingest(), the same path a phone's sync takes, so number
 * matching, exclusions, tracking switches and the SMS text rule all apply to
 * it exactly as they will to real data.
 *
 * Demo rows are marked source = 'demo' and demo devices carry the asset tag
 * DEMO plus the reserved device uid prefix demo-, which real phones are
 * refused, so removing the demo can never touch real activity.
 *
 * Loaded on demand by the controller only; nothing here runs on a normal page.
 */

/**
 * Replace any existing demo data with a fresh ten working days of it.
 *
 * @param  int $by staff id loading it
 *
 * @return int|false events stored
 */
function mks_st_demo_load($by)
{
    $CI = &get_instance();

    mks_st_demo_remove();

    $staff = $CI->db->select('staffid, firstname, lastname')
        ->where('active', 1)
        ->order_by('staffid', 'asc')
        ->limit(3)
        ->get(db_prefix() . 'staff')
        ->result_array();

    if (!$staff) {
        return false;
    }

    $people = mks_st_demo_people();
    $phones = [
        ['platform' => 'android', 'manufacturer' => 'Samsung', 'model' => 'Galaxy S24', 'os' => '14'],
        ['platform' => 'android', 'manufacturer' => 'Xiaomi', 'model' => 'Redmi Note 13 Pro', 'os' => '14'],
        ['platform' => 'ios', 'manufacturer' => 'Apple', 'model' => 'iPhone 15', 'os' => '18.1'],
    ];

    $stored  = 0;
    $wav     = mks_st_demo_wav(5);
    $wavPath = tempnam(sys_get_temp_dir(), 'mks_st_demo_');

    if ($wavPath === false || file_put_contents($wavPath, $wav) === false) {
        return false;
    }

    foreach ($staff as $index => $member) {
        $phone  = $phones[$index % count($phones)];
        $device = mks_st_demo_device($member, $phone, $index, $by);

        if (!$device) {
            continue;
        }

        $events = mks_st_demo_events((int) $member['staffid'], $people, $phone['platform'] === 'ios');

        foreach (array_chunk($events, MKS_ST_BATCH_MAX) as $batch) {
            $result = mks_st_ingest($device, $batch, 'demo');

            if ($result === false) {
                continue;
            }

            $stored += count($result['stored']);

            foreach ($result['recordings_wanted'] as $uid) {
                $event = mks_st_event_by_uid($device['id'], $uid);

                if ($event) {
                    mks_st_store_recording($event, $wavPath, 'wav', 'audio/wav', false);
                }
            }
        }

        mks_st_demo_outcomes($device);
    }

    @unlink($wavPath);

    // One device still waiting for its phone, so that state can be seen too.
    $CI->db->insert(mks_st_devices_table(), [
        'staff_id'    => (int) $staff[0]['staffid'],
        'label'       => 'Sales Phone 04',
        'description' => 'Spare handset for the new hire, not handed over yet.',
        'asset_tag'   => 'DEMO',
        'status'      => 'pending',
        'platform'    => 'android',
        'created_at'  => date('Y-m-d H:i:s'),
        'created_by'  => (int) $by,
    ]);

    mks_st_option_put('mks_sales_track_demo', '1', 1);

    log_activity('Sales Track: demo data loaded [' . $stored . ' events]');

    return $stored;
}

/**
 * Remove every demo phone, demo event and demo recording.
 *
 * @return int events removed
 */
function mks_st_demo_remove()
{
    $CI     = &get_instance();
    $events = mks_st_events_table();

    $files = $CI->db->select('recording_file')
        ->where('source', 'demo')
        ->where('recording_file IS NOT NULL', null, false)
        ->get($events)
        ->result_array();

    foreach ($files as $file) {
        mks_st_recording_unlink($file['recording_file']);
    }

    $CI->db->where('source', 'demo');
    $CI->db->delete($events);
    $removed = (int) $CI->db->affected_rows();

    $CI->db->group_start();
    $CI->db->like('device_uid', 'demo-', 'after');
    $CI->db->or_where('asset_tag', 'DEMO');
    $CI->db->group_end();
    $CI->db->delete(mks_st_devices_table());

    $CI->db->where('name', 'mks_sales_track_demo');
    $CI->db->delete(db_prefix() . 'options');

    return $removed;
}

/**
 * A demo phone for one member of staff, written directly because pairing a
 * reserved uid through the API is deliberately impossible.
 *
 * @param  array $member
 * @param  array $phone
 * @param  int   $index
 * @param  int   $by
 *
 * @return array|null
 */
function mks_st_demo_device(array $member, array $phone, $index, $by)
{
    $CI  = &get_instance();
    $ios = $phone['platform'] === 'ios';

    $health = [
        'permissions' => $ios ? [
            'contacts' => true,
        ] : [
            'call_log'             => true,
            'phone_state'          => true,
            'contacts'             => true,
            'sms'                  => true,
            'notifications'        => $index !== 1,
            'recordings'           => true,
            'battery_unrestricted' => $index !== 1,
        ],
        'battery'     => [82, 47, 64][$index % 3],
        'charging'    => $index === 2,
        'queue'       => [0, 6, 0][$index % 3],
        'network'     => $index === 1 ? 'mobile' : 'wifi',
        'reported_at' => date('Y-m-d H:i:s'),
    ];

    if ($index === 1) {
        $health['last_error'] = 'WhatsApp call access is off on this phone.';
    }

    $syncs = [];

    for ($i = 0; $i < 8; $i++) {
        $syncs[] = [
            't'   => date('Y-m-d H:i:s', strtotime('-' . ($i * 15 + [3, 95, 12][$index % 3]) . ' minutes')),
            'st'  => mt_rand(0, 6),
            'dup' => $i === 2 ? 1 : 0,
            'sk'  => 0,
            're'  => 0,
            'app' => '1.0.0',
        ];
    }

    $CI->db->insert(mks_st_devices_table(), [
        'staff_id'     => (int) $member['staffid'],
        'device_uid'   => 'demo-' . (int) $member['staffid'],
        'token_hash'   => hash('sha256', bin2hex(random_bytes(32))),
        'platform'     => $phone['platform'],
        'label'        => 'Sales Phone 0' . ($index + 1),
        'description'  => $phone['manufacturer'] . ' ' . $phone['model'] . ' issued to the inside sales team.',
        'phone_number' => '+9198140000' . str_pad((string) ($index + 11), 2, '0', STR_PAD_LEFT),
        'asset_tag'    => 'DEMO',
        'sync_log'     => json_encode($syncs),
        'created_at'   => date('Y-m-d H:i:s', strtotime('-15 days')),
        'created_by'   => (int) $by,
        'manufacturer' => $phone['manufacturer'],
        'model'        => $phone['model'],
        'os_version'   => $phone['os'],
        'app_version'  => '1.0.0',
        'sims'         => $ios ? null : json_encode([
            ['slot' => 1, 'label' => 'Jio', 'number' => ''],
            ['slot' => 2, 'label' => 'Airtel', 'number' => ''],
        ]),
        'track_sim'    => 0,
        'health'       => json_encode($health),
        'status'       => 'active',
        'paired_at'    => date('Y-m-d H:i:s', strtotime('-14 days')),
        'paired_by'    => (int) $by,
        'last_seen_at' => date('Y-m-d H:i:s', strtotime('-' . [3, 95, 12][$index % 3] . ' minutes')),
        'last_sync_at' => date('Y-m-d H:i:s', strtotime('-' . [3, 95, 12][$index % 3] . ' minutes')),
        'last_ip'      => '127.0.0.1',
    ]);

    $id = (int) $CI->db->insert_id();

    return $id > 0 ? mks_st_device_get($id) : null;
}

/**
 * The people on the other end: real leads and contacts first, so matching
 * can be seen working, then invented numbers to fill out the picture.
 *
 * @return array name, number
 */
function mks_st_demo_people()
{
    $CI     = &get_instance();
    $people = [];

    $leads = $CI->db->select('name, phonenumber')
        ->where('phonenumber IS NOT NULL', null, false)
        ->where('phonenumber <>', '')
        ->order_by('id', 'desc')
        ->limit(8)
        ->get(db_prefix() . 'leads')
        ->result_array();

    foreach ($leads as $lead) {
        $people[] = ['name' => '', 'number' => $lead['phonenumber']];
    }

    $contacts = $CI->db->select('firstname, lastname, phonenumber')
        ->where('phonenumber <>', '')
        ->order_by('id', 'desc')
        ->limit(3)
        ->get(db_prefix() . 'contacts')
        ->result_array();

    foreach ($contacts as $contact) {
        $people[] = ['name' => '', 'number' => $contact['phonenumber']];
    }

    $invented = [
        ['Rahul Mehta', '+91 98765 41230'],
        ['Priya Nair', '+91 99887 10234'],
        ['Harpreet Singh', '+91 98140 56721'],
        ['Neha Kapoor', '+91 97790 33418'],
        ['Vikram Rao', '+91 90410 77652'],
        ['Simran Gill', '+91 98722 90134'],
        ['Arjun Malhotra', '+91 99150 26473'],
        ['Pooja Iyer', '+91 98100 64529'],
        ['', '+91 70870 11983'],
        ['', '+91 62830 45120'],
        ['', '+91 88720 30951'],
        ['Karan Bedi', '+91 98880 17345'],
    ];

    foreach ($invented as $person) {
        $people[] = ['name' => $person[0], 'number' => $person[1]];
    }

    return $people;
}

/**
 * Outcomes on about half of a demo phone's connected calls, some with
 * follow-ups, written straight onto the rows: demo data never creates Perfex
 * leads or reminders, so removing it leaves nothing behind.
 *
 * @param  array $device
 *
 * @return void
 */
function mks_st_demo_outcomes(array $device)
{
    $CI    = &get_instance();
    $notes = [
        'interested'     => ['Wants a quotation by Friday.', 'Asked for the brochure on WhatsApp.', 'Comparing with one other vendor.'],
        'call_back'      => ['Busy in a meeting, call after 4.', 'Asked to call back next week.', 'Travelling, call on Monday.'],
        'not_interested' => ['Budget frozen this quarter.', 'Already using another provider.'],
        'no_answer'      => ['', 'Phone switched off.'],
        'wrong_number'   => ['Not the person we were looking for.'],
        'converted'      => ['Confirmed the order on the call.'],
    ];
    $keys  = ['interested', 'interested', 'call_back', 'call_back', 'not_interested', 'no_answer', 'wrong_number', 'converted'];
    $calls = $CI->db->query('SELECT id, occurred_at FROM ' . mks_st_events_table() . ' WHERE device_id = ' . (int) $device['id']
        . " AND kind = 'call' AND duration >= " . mks_st_connected_seconds() . ' ORDER BY occurred_at')->result_array();

    foreach ($calls as $call) {
        if (mt_rand(1, 100) > 50) {
            continue;
        }

        $key    = $keys[mt_rand(0, count($keys) - 1)];
        $note   = $notes[$key][mt_rand(0, count($notes[$key]) - 1)];
        $follow = null;

        if (in_array($key, ['interested', 'call_back'], true) && mt_rand(1, 100) <= 60) {
            $follow = date('Y-m-d H:i:s', strtotime($call['occurred_at']) + mt_rand(1, 6) * 86400 + 3600);
        }

        $CI->db->where('id', (int) $call['id'])->update(mks_st_events_table(), [
            'outcome'      => $key,
            'outcome_note' => $note !== '' ? $note : null,
            'outcome_at'   => date('Y-m-d H:i:s', strtotime($call['occurred_at']) + 120),
            'outcome_by'   => (int) $device['staff_id'],
            'follow_up_at' => $follow,
        ]);
    }
}

/**
 * Ten working days of activity for one person, in the shape a phone sends.
 *
 * @param  int   $staff_id
 * @param  array $people
 * @param  bool  $ios      an iPhone can only log the calls it places itself
 *
 * @return array
 */
function mks_st_demo_events($staff_id, array $people, $ios)
{
    $events = [];
    $seq    = 0;
    $sms    = [
        'Thank you for your time today. Sharing the details shortly.',
        'Reminder: our meeting is at 11 AM tomorrow.',
        'Please call back when free.',
        'Received with thanks.',
    ];

    $day = 0;

    for ($back = 0; $day < 10 && $back < 20; $back++) {
        $date = strtotime(date('Y-m-d', strtotime('-' . $back . ' days')));

        // Saturday and Sunday are off at Makes360.
        if ((int) date('N', $date) >= 6) {
            continue;
        }

        $day++;
        $isToday = $back === 0;
        $limit   = $isToday ? time() - 600 : $date + 66600;

        // Before the working day has begun there is nothing to show for
        // today: demo calls are never dated in the future.
        if ($limit <= $date + 34200) {
            continue;
        }
        $calls   = $ios ? mt_rand(3, 6) : mt_rand(8, 14);

        for ($i = 0; $i < $calls; $i++) {
            $person = $people[mt_rand(0, count($people) - 1)];
            $roll   = mt_rand(1, 100);

            if ($ios) {
                $direction = 'outgoing';
            } elseif ($roll <= 50) {
                $direction = 'outgoing';
            } elseif ($roll <= 80) {
                $direction = 'incoming';
            } elseif ($roll <= 94) {
                $direction = 'missed';
            } else {
                $direction = 'rejected';
            }

            $duration = 0;

            if ($direction === 'incoming' || ($direction === 'outgoing' && mt_rand(1, 100) > 25)) {
                $duration = mt_rand(1, 100) <= 70 ? mt_rand(25, 240) : mt_rand(240, 720);
            }

            $time = mt_rand($date + 34200, max($date + 34201, $limit));

            $events[] = [
                'uid'       => 'demo-' . $staff_id . '-c-' . (++$seq),
                'kind'      => 'call',
                'direction' => $direction,
                'number'    => $person['number'],
                'name'      => $person['name'],
                'time'      => $time * 1000,
                'duration'  => $duration,
                'sim'       => $ios ? null : (mt_rand(1, 100) <= 85 ? 1 : 2),
                'source'    => $ios ? 'app' : 'auto',
                'recording' => !$ios && $duration > 0 && $back <= 3 && mt_rand(1, 100) <= 45,
            ];
        }

        if ($ios) {
            continue;
        }

        for ($i = 0, $n = mt_rand(1, 3); $i < $n; $i++) {
            $person    = $people[mt_rand(0, count($people) - 1)];
            $direction = ['incoming', 'outgoing', 'outgoing', 'missed'][mt_rand(0, 3)];

            $events[] = [
                'uid'       => 'demo-' . $staff_id . '-w-' . (++$seq),
                'kind'      => 'whatsapp_call',
                'direction' => $direction,
                'number'    => $person['number'],
                'name'      => $person['name'],
                'time'      => mt_rand($date + 34200, max($date + 34201, $limit)) * 1000,
                'duration'  => $direction === 'missed' ? 0 : mt_rand(40, 900),
                'media'     => mt_rand(1, 100) <= 80 ? 'voice' : 'video',
                'app'       => mt_rand(1, 100) <= 70 ? 'com.whatsapp.w4b' : 'com.whatsapp',
            ];
        }

        for ($i = 0, $n = mt_rand(2, 4); $i < $n; $i++) {
            $person = $people[mt_rand(0, count($people) - 1)];

            $events[] = [
                'uid'       => 'demo-' . $staff_id . '-s-' . (++$seq),
                'kind'      => 'sms',
                'direction' => mt_rand(0, 1) ? 'incoming' : 'outgoing',
                'number'    => $person['number'],
                'name'      => $person['name'],
                'time'      => mt_rand($date + 34200, max($date + 34201, $limit)) * 1000,
                'text'      => $sms[mt_rand(0, count($sms) - 1)],
                'sim'       => 1,
            ];
        }

    }

    return $events;
}

/**
 * A short, quiet two tone WAV so the player has something real to play.
 *
 * @param  int $seconds
 *
 * @return string
 */
function mks_st_demo_wav($seconds)
{
    $rate    = 8000;
    $samples = $rate * (int) $seconds;
    $half    = (int) ($rate / 2);
    $data    = '';

    for ($i = 0; $i < $samples; $i++) {
        $t    = $i / $rate;
        $freq = (intdiv($i, $half) % 2 === 0) ? 440.0 : 554.37;
        $pos  = $i % $half;

        // Fade each half second in and out so the tone never clicks.
        $envelope = min(1, $pos / 400) * min(1, ($half - $pos) / 400);
        $value    = (int) round(sin(2 * M_PI * $freq * $t) * 2600 * $envelope);

        $data .= pack('v', $value & 0xFFFF);
    }

    return 'RIFF' . pack('V', 36 + strlen($data)) . 'WAVE'
        . 'fmt ' . pack('V', 16) . pack('v', 1) . pack('v', 1)
        . pack('V', $rate) . pack('V', $rate * 2) . pack('v', 2) . pack('v', 16)
        . 'data' . pack('V', strlen($data)) . $data;
}
