<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - installer.
 *
 * Idempotent and cumulative: safe on activation, from the migration on an
 * upgrade, and from the admin_init self-heal when files were uploaded over an
 * older copy. Every CREATE is guarded, existing settings always win over the
 * shipped defaults, and nothing here ever drops or rewrites data.
 *
 * Two tables, both strictly required:
 *   devices  one row per company phone, created in the CRM before a phone
 *            pairs with its code. Each holds its own revocable token and is
 *            written on every sync, which an option cannot do safely while
 *            several phones report at once.
 *   events   one row per call, WhatsApp call, SMS or notification. A time
 *            series that grows every day cannot live in tbloptions.
 *
 * Everything else is an option: the settings blob, the pairing store, the
 * salt used to hash excluded numbers for the phones.
 */

if (!isset($CI)) {
    $CI = &get_instance();
}

$mks_st_charset = $CI->db->char_set;
$mks_st_collate = $CI->db->dbcollat;
$mks_st_devices = db_prefix() . 'mks_sales_track_devices';
$mks_st_events  = db_prefix() . 'mks_sales_track_events';

if (!$CI->db->table_exists($mks_st_devices)) {
    $CI->db->query('CREATE TABLE `' . $mks_st_devices . '` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `staff_id` int(11) NOT NULL,
        `device_uid` varchar(64) DEFAULT NULL,
        `token_hash` char(64) DEFAULT NULL,
        `platform` varchar(10) NOT NULL DEFAULT \'android\',
        `label` varchar(100) NOT NULL DEFAULT \'\',
        `description` text DEFAULT NULL,
        `phone_number` varchar(20) DEFAULT NULL,
        `asset_tag` varchar(50) DEFAULT NULL,
        `manufacturer` varchar(60) NOT NULL DEFAULT \'\',
        `model` varchar(100) NOT NULL DEFAULT \'\',
        `os_version` varchar(30) NOT NULL DEFAULT \'\',
        `app_version` varchar(30) NOT NULL DEFAULT \'\',
        `sims` text DEFAULT NULL,
        `track_sim` tinyint(3) unsigned NOT NULL DEFAULT 0,
        `health` text DEFAULT NULL,
        `status` varchar(10) NOT NULL DEFAULT \'pending\',
        `commands` text DEFAULT NULL,
        `sync_log` text DEFAULT NULL,
        `created_at` datetime DEFAULT NULL,
        `created_by` int(11) DEFAULT NULL,
        `paired_at` datetime DEFAULT NULL,
        `paired_by` int(11) DEFAULT NULL,
        `revoked_at` datetime DEFAULT NULL,
        `revoked_by` int(11) DEFAULT NULL,
        `last_seen_at` datetime DEFAULT NULL,
        `last_sync_at` datetime DEFAULT NULL,
        `last_ip` varchar(45) DEFAULT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `device_uid` (`device_uid`),
        KEY `token_hash` (`token_hash`),
        KEY `staff_id` (`staff_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=' . $mks_st_charset . ' COLLATE=' . $mks_st_collate . ';');
}

if (!$CI->db->table_exists($mks_st_events)) {
    $CI->db->query('CREATE TABLE `' . $mks_st_events . '` (
        `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        `device_id` int(11) NOT NULL,
        `staff_id` int(11) NOT NULL,
        `uid` varchar(80) NOT NULL,
        `kind` varchar(20) NOT NULL,
        `direction` varchar(12) NOT NULL DEFAULT \'unknown\',
        `media` varchar(10) DEFAULT NULL,
        `source` varchar(10) NOT NULL DEFAULT \'auto\',
        `number_raw` varchar(50) DEFAULT NULL,
        `number` varchar(20) DEFAULT NULL,
        `number_key` varchar(15) DEFAULT NULL,
        `contact_name` varchar(191) DEFAULT NULL,
        `sim_slot` tinyint(3) unsigned DEFAULT NULL,
        `app_package` varchar(100) DEFAULT NULL,
        `app_name` varchar(100) DEFAULT NULL,
        `title` varchar(255) DEFAULT NULL,
        `body` text DEFAULT NULL,
        `occurred_at` datetime NOT NULL,
        `duration` int(10) unsigned NOT NULL DEFAULT 0,
        `rel_type` varchar(10) DEFAULT NULL,
        `rel_id` int(11) DEFAULT NULL,
        `contact_id` int(11) DEFAULT NULL,
        `recording_status` varchar(10) NOT NULL DEFAULT \'none\',
        `recording_file` varchar(255) DEFAULT NULL,
        `recording_size` int(10) unsigned DEFAULT NULL,
        `recording_mime` varchar(50) DEFAULT NULL,
        `recording_at` datetime DEFAULT NULL,
        `received_at` datetime NOT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `device_uid` (`device_id`, `uid`),
        KEY `kind_time` (`kind`, `occurred_at`),
        KEY `staff_kind_time` (`staff_id`, `kind`, `occurred_at`),
        KEY `number_key` (`number_key`),
        KEY `rel` (`rel_type`, `rel_id`),
        KEY `recording` (`recording_status`)
    ) ENGINE=InnoDB DEFAULT CHARSET=' . $mks_st_charset . ' COLLATE=' . $mks_st_collate . ';');
}

/*
| Revision 2 (1.1.0): devices are created in the CRM before a phone pairs, so
| the phone binding columns become nullable, and the device record gains its
| description, SIM number, asset tag, command queue and sync history. Every
| step checks first, so it is safe on a fresh table and on an upgraded one.
*/
$mks_st_new_columns = [
    'description'  => 'text DEFAULT NULL AFTER `label`',
    'phone_number' => 'varchar(20) DEFAULT NULL AFTER `description`',
    'asset_tag'    => 'varchar(50) DEFAULT NULL AFTER `phone_number`',
    'commands'     => 'text DEFAULT NULL AFTER `status`',
    'sync_log'     => 'text DEFAULT NULL AFTER `commands`',
    'created_at'   => 'datetime DEFAULT NULL AFTER `sync_log`',
    'created_by'   => 'int(11) DEFAULT NULL AFTER `created_at`',
];

foreach ($mks_st_new_columns as $mks_st_column => $mks_st_definition) {
    if (!$CI->db->field_exists($mks_st_column, $mks_st_devices)) {
        $CI->db->query('ALTER TABLE `' . $mks_st_devices . '` ADD `' . $mks_st_column . '` ' . $mks_st_definition);
    }
}

// field_data() does not report nullability, so SHOW COLUMNS is read directly.
foreach ($CI->db->query('SHOW COLUMNS FROM `' . $mks_st_devices . '`')->result_array() as $mks_st_field) {
    if (in_array($mks_st_field['Field'], ['device_uid', 'token_hash', 'paired_at'], true) && $mks_st_field['Null'] !== 'YES') {
        $mks_st_type = $mks_st_field['Field'] === 'paired_at' ? 'datetime' : ($mks_st_field['Field'] === 'token_hash' ? 'char(64)' : 'varchar(64)');
        $CI->db->query('ALTER TABLE `' . $mks_st_devices . '` MODIFY `' . $mks_st_field['Field'] . '` ' . $mks_st_type . ' DEFAULT NULL');
    }
}

// Devices from 1.0.0 were paired phones; they keep their place as active
// devices, named after the phone and dated by their pairing.
$CI->db->query('UPDATE `' . $mks_st_devices . '` SET `created_at` = `paired_at` WHERE `created_at` IS NULL');

/*
| Revision 4 (1.3.0): each call can carry an outcome, a note and a follow-up
| (linked to a native Perfex reminder); a missed call carries its place in the
| callback queue; a number that is both a customer contact and a lead keeps
| the lead too; devices keep their recent alerts.
*/
$mks_st_event_columns = [
    'lead_id'         => 'int(11) DEFAULT NULL AFTER `contact_id`',
    'outcome'         => 'varchar(40) DEFAULT NULL AFTER `recording_at`',
    'outcome_note'    => 'text DEFAULT NULL AFTER `outcome`',
    'outcome_at'      => 'datetime DEFAULT NULL AFTER `outcome_note`',
    'outcome_by'      => 'int(11) DEFAULT NULL AFTER `outcome_at`',
    'follow_up_at'    => 'datetime DEFAULT NULL AFTER `outcome_by`',
    'reminder_id'     => 'int(11) DEFAULT NULL AFTER `follow_up_at`',
    'callback_state'  => 'varchar(10) DEFAULT NULL AFTER `reminder_id`',
    'callback_due_at' => 'datetime DEFAULT NULL AFTER `callback_state`',
    'callback_at'     => 'datetime DEFAULT NULL AFTER `callback_due_at`',
    'callback_by'     => 'int(11) DEFAULT NULL AFTER `callback_at`',
    'escalated_at'    => 'datetime DEFAULT NULL AFTER `callback_by`',
];

foreach ($mks_st_event_columns as $mks_st_column => $mks_st_definition) {
    if (!$CI->db->field_exists($mks_st_column, $mks_st_events)) {
        $CI->db->query('ALTER TABLE `' . $mks_st_events . '` ADD `' . $mks_st_column . '` ' . $mks_st_definition);
    }
}

$mks_st_event_keys = [];

foreach ($CI->db->query('SHOW INDEX FROM `' . $mks_st_events . '`')->result_array() as $mks_st_index) {
    $mks_st_event_keys[$mks_st_index['Key_name']] = true;
}

foreach ([
    'callback' => '(`callback_state`, `callback_due_at`)',
    'follow_up' => '(`follow_up_at`)',
    'outcome' => '(`outcome`)',
    'lead_id' => '(`lead_id`)',
] as $mks_st_key => $mks_st_columns) {
    if (!isset($mks_st_event_keys[$mks_st_key])) {
        $CI->db->query('ALTER TABLE `' . $mks_st_events . '` ADD KEY `' . $mks_st_key . '` ' . $mks_st_columns);
    }
}

if (!$CI->db->field_exists('alerts', $mks_st_devices)) {
    $CI->db->query('ALTER TABLE `' . $mks_st_devices . '` ADD `alerts` text DEFAULT NULL AFTER `sync_log`');
}

/*
| Revision 5 (1.4.0): a phone registers its Firebase messaging token, so
| click-to-call and other commands reach it at once instead of at its next
| check-in.
*/
if (!$CI->db->field_exists('push_token', $mks_st_devices)) {
    $CI->db->query('ALTER TABLE `' . $mks_st_devices . '` ADD `push_token` varchar(512) DEFAULT NULL AFTER `alerts`');
}

if (!$CI->db->field_exists('push_at', $mks_st_devices)) {
    $CI->db->query('ALTER TABLE `' . $mks_st_devices . '` ADD `push_at` datetime DEFAULT NULL AFTER `push_token`');
}

/*
| Revision 7 (1.6.0): a recording can live on Google Drive (its file id, when
| it got there, and failed attempts), and a call can be a Best Pitch:
| nominated (1) or in the library (2), with a category, a note and the moments
| worth hearing.
*/
foreach ([
    'drive_file_id'  => 'varchar(100) DEFAULT NULL AFTER `recording_at`',
    'drive_at'       => 'datetime DEFAULT NULL AFTER `drive_file_id`',
    'drive_attempts' => 'tinyint(3) NOT NULL DEFAULT 0 AFTER `drive_at`',
    'best_pitch'     => 'tinyint(1) NOT NULL DEFAULT 0 AFTER `escalated_at`',
    'pitch_category' => 'varchar(60) DEFAULT NULL AFTER `best_pitch`',
    'pitch_note'     => 'text DEFAULT NULL AFTER `pitch_category`',
    'pitch_moments'  => 'text DEFAULT NULL AFTER `pitch_note`',
    'pitch_by'       => 'int(11) DEFAULT NULL AFTER `pitch_moments`',
    'pitch_at'       => 'datetime DEFAULT NULL AFTER `pitch_by`',
] as $mks_st_column => $mks_st_definition) {
    if (!$CI->db->field_exists($mks_st_column, $mks_st_events)) {
        $CI->db->query('ALTER TABLE `' . $mks_st_events . '` ADD `' . $mks_st_column . '` ' . $mks_st_definition);
    }
}

$mks_st_event_keys = [];

foreach ($CI->db->query('SHOW INDEX FROM `' . $mks_st_events . '`')->result_array() as $mks_st_index) {
    $mks_st_event_keys[$mks_st_index['Key_name']] = true;
}

foreach (['best_pitch' => '(`best_pitch`, `pitch_at`)', 'drive' => '(`recording_status`, `drive_file_id`)'] as $mks_st_key => $mks_st_columns) {
    if (!isset($mks_st_event_keys[$mks_st_key])) {
        $CI->db->query('ALTER TABLE `' . $mks_st_events . '` ADD KEY `' . $mks_st_key . '` ' . $mks_st_columns);
    }
}

/*
| Revision 8 (1.7.0): AI call insights. The few figures lists sort and filter
| on (status, score, sentiment, temperature, flags, cost) sit on the event; the
| transcript and the full analysis live in a third table, because they run to
| tens of kilobytes per call and every list read of the events table would
| otherwise carry them.
*/
foreach ([
    'ai_status'      => 'varchar(12) DEFAULT NULL AFTER `pitch_at`',
    'ai_at'          => 'datetime DEFAULT NULL AFTER `ai_status`',
    'ai_score'       => 'tinyint(3) DEFAULT NULL AFTER `ai_at`',
    'ai_sentiment'   => 'varchar(10) DEFAULT NULL AFTER `ai_score`',
    'ai_temperature' => 'varchar(6) DEFAULT NULL AFTER `ai_sentiment`',
    'ai_flags'       => 'varchar(120) DEFAULT NULL AFTER `ai_temperature`',
    'ai_cost'        => 'decimal(10,6) DEFAULT NULL AFTER `ai_flags`',
    'ai_note'        => 'varchar(255) DEFAULT NULL AFTER `ai_cost`',
] as $mks_st_column => $mks_st_definition) {
    if (!$CI->db->field_exists($mks_st_column, $mks_st_events)) {
        $CI->db->query('ALTER TABLE `' . $mks_st_events . '` ADD `' . $mks_st_column . '` ' . $mks_st_definition);
    }
}

if (!isset($mks_st_event_keys['ai'])) {
    $CI->db->query('ALTER TABLE `' . $mks_st_events . '` ADD KEY `ai` (`ai_status`, `occurred_at`)');
}

$mks_st_ai = db_prefix() . 'mks_sales_track_ai';

if (!$CI->db->table_exists($mks_st_ai)) {
    $CI->db->query('CREATE TABLE `' . $mks_st_ai . '` (
        `event_id` int(11) NOT NULL,
        `model` varchar(60) NOT NULL DEFAULT \'\',
        `language` varchar(40) DEFAULT NULL,
        `transcript` mediumtext DEFAULT NULL,
        `analysis` mediumtext DEFAULT NULL,
        `tokens_in` int(11) NOT NULL DEFAULT 0,
        `tokens_out` int(11) NOT NULL DEFAULT 0,
        `cost` decimal(10,6) NOT NULL DEFAULT 0,
        `created_at` datetime NOT NULL,
        PRIMARY KEY (`event_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=' . $mks_st_charset . ' COLLATE=' . $mks_st_collate . ';');
}

/*
| Settings. Existing values win; only keys this installation has never seen
| are seeded, so an upgrade gains new settings without resetting old ones.
*/
if (function_exists('mks_st_setting_defaults') && function_exists('mks_st_option_put')) {
    $mks_st_defaults = mks_st_setting_defaults();
    $mks_st_stored   = json_decode((string) get_option(MKS_SALES_TRACK_OPTION), true);
    $mks_st_stored   = is_array($mks_st_stored) ? $mks_st_stored : [];

    mks_st_option_put(
        MKS_SALES_TRACK_OPTION,
        json_encode(array_merge($mks_st_defaults, array_intersect_key($mks_st_stored, $mks_st_defaults))),
        1
    );

    if ((string) get_option('mks_sales_track_salt') === '') {
        mks_st_option_put('mks_sales_track_salt', bin2hex(random_bytes(16)), 1);
    }

    mks_st_option_put('mks_sales_track_version', MKS_SALES_TRACK_VERSION, 1);
    mks_st_option_put('mks_sales_track_schema_rev', MKS_SALES_TRACK_SCHEMA_REV, 1);
}

if (function_exists('mks_st_ensure_upload_root')) {
    mks_st_ensure_upload_root();
}

if (function_exists('mks_st_cleanup_duplicate_events')) {
    mks_st_cleanup_duplicate_events();
}
