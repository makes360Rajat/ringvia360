<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - settings schema.
 *
 * The single definition of every setting. The settings page renders from it,
 * saving cleans by it, defaults come from it, tooling/settings_doc.php writes
 * docs/SETTINGS.md from it, and the gates fail when the two drift apart.
 *
 * Adding a setting: add it here with section, type, default and its language
 * keys; if the phones need it, add it to mks_st_device_config(); bump
 * MKS_SALES_TRACK_SCHEMA_REV so existing installs are seeded.
 *
 * Field types
 *   switch    0 or 1
 *   number    integer, clamped to min..max
 *   text      single line, cleaned by 'clean': digits, version, url
 *   textarea  list, cleaned by 'clean': numbers
 *   choice    one of 'options' (value => language key), drawn as cards
 *   pin       write only: 4 to 8 digits, stored as a salted PBKDF2 hash in the
 *             'store' keys, never sent back to the browser
 *   days      ISO weekdays (1 Monday to 7 Sunday), as a list
 *   staff_targets  per person daily targets that override the defaults:
 *             staff id => calls, connected, talk (minutes); blank means default
 *   outcomes  the after-call outcome list: key, label, tone, follow_up,
 *             lead_status, active. The converted outcome is fixed: it can be
 *             renamed but never removed
 *   lead_status, lead_source, staff  a Perfex lead status, lead source or
 *             active staff member by id; 0 means Perfex's own default (or none)
 *   time      HH:MM, 24 hour
 *   secret    write only: a single secret (an OAuth client secret), kept
 *             encrypted in the option named by 'option', never in this JSON
 *   secret_json  write only: a Google service account key, validated and
 *             kept encrypted in its own option, never in this JSON and never
 *             sent back to the browser
 *   internal  stored but never shown (hashes and salts)
 *
 * 'app' => true marks settings the phones receive through the config call.
 * 'since' records the version a setting arrived in.
 */
return [
    'sections' => [
        'general'    => ['label' => 'mks_st_sec_general', 'icon' => 'fa-solid fa-gear', 'intro' => 'mks_st_sec_general_intro'],
        'tracking'   => ['label' => 'mks_st_sec_tracking', 'icon' => 'fa-solid fa-satellite-dish', 'intro' => 'mks_st_sec_tracking_intro'],
        'outcomes'   => ['label' => 'mks_st_sec_outcomes', 'icon' => 'fa-solid fa-list-check', 'intro' => 'mks_st_sec_outcomes_intro'],
        'leads'      => ['label' => 'mks_st_sec_leads', 'icon' => 'fa-solid fa-user-plus', 'intro' => 'mks_st_sec_leads_intro'],
        'missed'     => ['label' => 'mks_st_sec_missed', 'icon' => 'fa-solid fa-phone-slash', 'intro' => 'mks_st_sec_missed_intro'],
        'targets'    => ['label' => 'mks_st_sec_targets', 'icon' => 'fa-solid fa-bullseye', 'intro' => 'mks_st_sec_targets_intro'],
        'alerts'     => ['label' => 'mks_st_sec_alerts', 'icon' => 'fa-solid fa-bell', 'intro' => 'mks_st_sec_alerts_intro'],
        'calling'    => ['label' => 'mks_st_sec_calling', 'icon' => 'fa-solid fa-phone-volume', 'intro' => 'mks_st_sec_calling_intro'],
        'reports'    => ['label' => 'mks_st_sec_reports', 'icon' => 'fa-solid fa-envelope', 'intro' => 'mks_st_sec_reports_intro'],
        'storage'    => ['label' => 'mks_st_sec_storage', 'icon' => 'fa-solid fa-hard-drive', 'intro' => 'mks_st_sec_storage_intro'],
        'ai'         => ['label' => 'mks_st_sec_ai', 'icon' => 'fa-solid fa-wand-magic-sparkles', 'intro' => 'mks_st_sec_ai_intro'],
        'popup'      => ['label' => 'mks_st_sec_popup', 'icon' => 'fa-solid fa-id-card', 'intro' => 'mks_st_sec_popup_intro'],
        'wallboard'  => ['label' => 'mks_st_sec_wallboard', 'icon' => 'fa-solid fa-tv', 'intro' => 'mks_st_sec_wallboard_intro'],
        'privacy'    => ['label' => 'mks_st_sec_privacy', 'icon' => 'fa-solid fa-user-shield', 'intro' => 'mks_st_sec_privacy_intro'],
        'recordings' => ['label' => 'mks_st_sec_recordings', 'icon' => 'fa-solid fa-microphone', 'intro' => 'mks_st_sec_recordings_intro'],
        'devices'    => ['label' => 'mks_st_sec_devices', 'icon' => 'fa-solid fa-mobile-screen-button', 'intro' => 'mks_st_sec_devices_intro'],
    ],

    'fields' => [
        /* General */
        'enabled' => [
            'section' => 'general', 'type' => 'switch', 'default' => 1, 'since' => '1.0.0',
            'label' => 'mks_st_set_enabled', 'hint' => 'mks_st_set_enabled_hint',
        ],
        'sidebar' => [
            'section' => 'general', 'type' => 'switch', 'default' => 1, 'since' => '1.0.0',
            'label' => 'mks_st_set_sidebar', 'hint' => 'mks_st_set_sidebar_hint',
        ],
        'country_code' => [
            'section' => 'general', 'type' => 'text', 'default' => '91', 'clean' => 'digits', 'max_length' => 4,
            'prefix' => '+', 'since' => '1.0.0', 'app' => true,
            'label' => 'mks_st_set_country_code', 'hint' => 'mks_st_set_country_code_hint',
        ],
        'match_digits' => [
            'section' => 'general', 'type' => 'number', 'default' => 10, 'min' => 6, 'max' => 15,
            'unit' => 'mks_st_unit_digits', 'since' => '1.0.0', 'app' => true,
            'label' => 'mks_st_set_match_digits', 'hint' => 'mks_st_set_match_digits_hint',
        ],
        'connected_seconds' => [
            'section' => 'general', 'type' => 'number', 'default' => 5, 'min' => 0, 'max' => 120,
            'unit' => 'mks_st_unit_seconds', 'since' => '1.1.0',
            'label' => 'mks_st_set_connected_seconds', 'hint' => 'mks_st_set_connected_seconds_hint',
        ],
        'match_customers' => [
            'section' => 'general', 'type' => 'switch', 'default' => 1, 'since' => '1.3.0',
            'label' => 'mks_st_set_match_customers', 'hint' => 'mks_st_set_match_customers_hint',
        ],
        'customer_visibility' => [
            'section' => 'general', 'type' => 'choice', 'default' => 'managers', 'since' => '1.3.0',
            'options' => ['managers' => 'mks_st_cv_managers', 'customer_access' => 'mks_st_cv_customer_access', 'everyone' => 'mks_st_cv_everyone'],
            'label' => 'mks_st_set_customer_visibility', 'hint' => 'mks_st_set_customer_visibility_hint',
        ],
        'exclude_internal' => [
            'section' => 'general', 'type' => 'switch', 'default' => 1, 'since' => '1.2.0',
            'label' => 'mks_st_set_exclude_internal', 'hint' => 'mks_st_set_exclude_internal_hint',
        ],
        'purge_on_uninstall' => [
            'section' => 'general', 'type' => 'switch', 'default' => 0, 'danger' => true, 'since' => '1.0.0',
            'label' => 'mks_st_set_purge', 'hint' => 'mks_st_set_purge_hint',
        ],

        /* Tracking */
        'track_calls' => [
            'section' => 'tracking', 'type' => 'switch', 'default' => 1, 'since' => '1.0.0', 'app' => true,
            'label' => 'mks_st_set_track_calls', 'hint' => 'mks_st_set_track_calls_hint',
        ],
        'track_recordings' => [
            'section' => 'tracking', 'type' => 'switch', 'default' => 1, 'since' => '1.0.0', 'app' => true,
            'label' => 'mks_st_set_track_recordings', 'hint' => 'mks_st_set_track_recordings_hint',
        ],
        'track_whatsapp_calls' => [
            'section' => 'tracking', 'type' => 'switch', 'default' => 1, 'since' => '1.0.0', 'app' => true,
            'label' => 'mks_st_set_track_whatsapp', 'hint' => 'mks_st_set_track_whatsapp_hint',
        ],
        'track_sms' => [
            'section' => 'tracking', 'type' => 'switch', 'default' => 1, 'since' => '1.0.0', 'app' => true,
            'label' => 'mks_st_set_track_sms', 'hint' => 'mks_st_set_track_sms_hint',
        ],
        'history_days' => [
            'section' => 'tracking', 'type' => 'number', 'default' => 7, 'min' => 0, 'max' => 90,
            'unit' => 'mks_st_unit_days', 'since' => '1.0.0', 'app' => true,
            'label' => 'mks_st_set_history_days', 'hint' => 'mks_st_set_history_days_hint',
        ],

        /* Privacy */
        'sms_text' => [
            'section' => 'privacy', 'type' => 'choice', 'default' => 'all', 'since' => '1.0.0', 'app' => true,
            'options' => ['all' => 'mks_st_sms_text_all', 'crm' => 'mks_st_sms_text_crm', 'none' => 'mks_st_sms_text_none'],
            'label' => 'mks_st_set_sms_text', 'hint' => 'mks_st_set_sms_text_hint',
        ],
        'excluded_numbers' => [
            'section' => 'privacy', 'type' => 'textarea', 'default' => '', 'clean' => 'numbers', 'since' => '1.0.0', 'app' => true,
            'placeholder' => '+91 98765 43210',
            'label' => 'mks_st_set_excluded', 'hint' => 'mks_st_set_excluded_hint',
        ],

        /* Recordings */
        'dnc_numbers' => [
            'section' => 'privacy', 'type' => 'textarea', 'default' => '', 'clean' => 'numbers', 'since' => '1.8.0', 'app' => true,
            'placeholder' => '+91 98765 43210',
            'label' => 'mks_st_set_dnc', 'hint' => 'mks_st_set_dnc_hint',
        ],
        'recording_max_mb' => [
            'section' => 'recordings', 'type' => 'number', 'default' => 25, 'min' => 1, 'max' => 200,
            'unit' => 'mks_st_unit_mb', 'since' => '1.0.0', 'app' => true,
            'label' => 'mks_st_set_recording_max', 'hint' => 'mks_st_set_recording_max_hint',
        ],
        'recording_wifi_only' => [
            'section' => 'recordings', 'type' => 'switch', 'default' => 0, 'since' => '1.0.0', 'app' => true,
            'label' => 'mks_st_set_wifi_only', 'hint' => 'mks_st_set_wifi_only_hint',
        ],

        /* Devices and app */
        'api_enabled' => [
            'section' => 'devices', 'type' => 'switch', 'default' => 1, 'since' => '1.0.0',
            'label' => 'mks_st_set_api_enabled', 'hint' => 'mks_st_set_api_enabled_hint',
        ],
        'sync_minutes' => [
            'section' => 'devices', 'type' => 'number', 'default' => 15, 'min' => 5, 'max' => 240,
            'unit' => 'mks_st_unit_minutes', 'since' => '1.0.0', 'app' => true,
            'label' => 'mks_st_set_sync_minutes', 'hint' => 'mks_st_set_sync_minutes_hint',
        ],
        'pair_minutes' => [
            'section' => 'devices', 'type' => 'number', 'default' => 60, 'min' => 5, 'max' => 1440,
            'unit' => 'mks_st_unit_minutes', 'since' => '1.0.0',
            'label' => 'mks_st_set_pair_minutes', 'hint' => 'mks_st_set_pair_minutes_hint',
        ],
        'one_phone_per_staff' => [
            'section' => 'devices', 'type' => 'switch', 'default' => 1, 'since' => '1.1.0',
            'label' => 'mks_st_set_one_phone', 'hint' => 'mks_st_set_one_phone_hint',
        ],
        'revoke_on_deactivate' => [
            'section' => 'devices', 'type' => 'switch', 'default' => 1, 'since' => '1.1.0',
            'label' => 'mks_st_set_revoke_on_deactivate', 'hint' => 'mks_st_set_revoke_on_deactivate_hint',
        ],
        'min_app_version' => [
            'section' => 'devices', 'type' => 'text', 'default' => '', 'clean' => 'version', 'max_length' => 20,
            'placeholder' => '1.0.0', 'since' => '1.1.0', 'app' => true,
            'label' => 'mks_st_set_min_version', 'hint' => 'mks_st_set_min_version_hint',
        ],
        'app_url_android' => [
            'section' => 'devices', 'type' => 'text', 'default' => '', 'clean' => 'url', 'max_length' => 300,
            'placeholder' => 'https://play.google.com/store/apps/details?id=...', 'since' => '1.1.0', 'app' => true,
            'label' => 'mks_st_set_app_url_android', 'hint' => 'mks_st_set_app_url_hint',
        ],
        'app_url_ios' => [
            'section' => 'devices', 'type' => 'text', 'default' => '', 'clean' => 'url', 'max_length' => 300,
            'placeholder' => 'https://apps.apple.com/app/...', 'since' => '1.1.0', 'app' => true,
            'label' => 'mks_st_set_app_url_ios', 'hint' => 'mks_st_set_app_url_hint',
        ],
        'app_lock_enabled' => [
            'section' => 'devices', 'type' => 'switch', 'default' => 0, 'since' => '1.1.0', 'app' => true,
            'label' => 'mks_st_set_app_lock', 'hint' => 'mks_st_set_app_lock_hint',
        ],
        'app_lock_pin' => [
            'section' => 'devices', 'type' => 'pin', 'default' => '', 'store' => ['app_lock_hash', 'app_lock_salt'],
            'since' => '1.1.0', 'app' => true,
            'label' => 'mks_st_set_app_pin', 'hint' => 'mks_st_set_app_pin_hint',
        ],
        'app_lock_hash' => [
            'section' => 'devices', 'type' => 'internal', 'default' => '', 'since' => '1.1.0',
        ],
        'app_lock_salt' => [
            'section' => 'devices', 'type' => 'internal', 'default' => '', 'since' => '1.1.0',
        ],

        /* Targets */
        'working_days' => [
            'section' => 'targets', 'type' => 'days', 'default' => [1, 2, 3, 4, 5], 'since' => '1.2.0',
            'label' => 'mks_st_set_working_days', 'hint' => 'mks_st_set_working_days_hint',
        ],
        'target_calls' => [
            'section' => 'targets', 'type' => 'number', 'default' => 0, 'min' => 0, 'max' => 500,
            'unit' => 'mks_st_unit_per_day', 'since' => '1.2.0',
            'label' => 'mks_st_set_target_calls', 'hint' => 'mks_st_set_target_calls_hint',
        ],
        'target_connected' => [
            'section' => 'targets', 'type' => 'number', 'default' => 0, 'min' => 0, 'max' => 500,
            'unit' => 'mks_st_unit_per_day', 'since' => '1.2.0',
            'label' => 'mks_st_set_target_connected', 'hint' => 'mks_st_set_target_connected_hint',
        ],
        'target_talk_minutes' => [
            'section' => 'targets', 'type' => 'number', 'default' => 0, 'min' => 0, 'max' => 600,
            'unit' => 'mks_st_unit_minutes_per_day', 'since' => '1.2.0',
            'label' => 'mks_st_set_target_talk', 'hint' => 'mks_st_set_target_talk_hint',
        ],
        'target_overrides' => [
            'section' => 'targets', 'type' => 'staff_targets', 'default' => [], 'since' => '1.2.0',
            'label' => 'mks_st_set_target_overrides', 'hint' => 'mks_st_set_target_overrides_hint',
        ],

        /* Outcomes */
        'outcomes' => [
            'section' => 'outcomes', 'type' => 'outcomes', 'since' => '1.3.0', 'app' => true,
            'default' => [
                ['key' => 'interested', 'label' => 'Interested', 'tone' => 'green', 'follow_up' => 1, 'lead_status' => 0, 'active' => 1],
                ['key' => 'call_back', 'label' => 'Call Back', 'tone' => 'blue', 'follow_up' => 1, 'lead_status' => 0, 'active' => 1],
                ['key' => 'not_interested', 'label' => 'Not Interested', 'tone' => 'slate', 'follow_up' => 0, 'lead_status' => 0, 'active' => 1],
                ['key' => 'wrong_number', 'label' => 'Wrong Number', 'tone' => 'red', 'follow_up' => 0, 'lead_status' => 0, 'active' => 1],
                ['key' => 'no_answer', 'label' => 'No Answer', 'tone' => 'amber', 'follow_up' => 1, 'lead_status' => 0, 'active' => 1],
                ['key' => 'converted', 'label' => 'Converted', 'tone' => 'violet', 'follow_up' => 0, 'lead_status' => 0, 'active' => 1],
            ],
            'label' => 'mks_st_set_outcomes', 'hint' => 'mks_st_set_outcomes_hint',
        ],
        'outcome_ask' => [
            'section' => 'outcomes', 'type' => 'choice', 'default' => 'connected', 'since' => '1.3.0', 'app' => true,
            'options' => ['connected' => 'mks_st_ask_connected', 'connected_only' => 'mks_st_ask_connected_only', 'all' => 'mks_st_ask_all'],
            'label' => 'mks_st_set_outcome_ask', 'hint' => 'mks_st_set_outcome_ask_hint',
        ],
        'outcome_mandatory' => [
            'section' => 'outcomes', 'type' => 'switch', 'default' => 0, 'since' => '1.3.0', 'app' => true,
            'label' => 'mks_st_set_outcome_mandatory', 'hint' => 'mks_st_set_outcome_mandatory_hint',
        ],
        'note_required' => [
            'section' => 'outcomes', 'type' => 'switch', 'default' => 0, 'since' => '1.3.0', 'app' => true,
            'label' => 'mks_st_set_note_required', 'hint' => 'mks_st_set_note_required_hint',
        ],
        'converted_action' => [
            'section' => 'outcomes', 'type' => 'choice', 'default' => 'review', 'since' => '1.3.0',
            'options' => ['review' => 'mks_st_conv_review', 'status' => 'mks_st_conv_status'],
            'label' => 'mks_st_set_converted_action', 'hint' => 'mks_st_set_converted_action_hint',
        ],
        'converted_status' => [
            'section' => 'outcomes', 'type' => 'lead_status', 'default' => 0, 'since' => '1.3.0',
            'label' => 'mks_st_set_converted_status', 'hint' => 'mks_st_set_converted_status_hint',
        ],

        /* Leads from calls */
        'lead_create_phone' => [
            'section' => 'leads', 'type' => 'switch', 'default' => 1, 'since' => '1.3.0', 'app' => true,
            'label' => 'mks_st_set_lead_create_phone', 'hint' => 'mks_st_set_lead_create_phone_hint',
        ],
        'lead_status' => [
            'section' => 'leads', 'type' => 'lead_status', 'default' => 0, 'since' => '1.3.0',
            'label' => 'mks_st_set_lead_status', 'hint' => 'mks_st_set_lead_status_hint',
        ],
        'lead_source' => [
            'section' => 'leads', 'type' => 'lead_source', 'default' => 0, 'since' => '1.3.0',
            'label' => 'mks_st_set_lead_source', 'hint' => 'mks_st_set_lead_source_hint',
        ],
        'lead_assign' => [
            'section' => 'leads', 'type' => 'choice', 'default' => 'handler', 'since' => '1.3.0',
            'options' => ['handler' => 'mks_st_assign_handler', 'fixed' => 'mks_st_assign_fixed', 'none' => 'mks_st_assign_none'],
            'label' => 'mks_st_set_lead_assign', 'hint' => 'mks_st_set_lead_assign_hint',
        ],
        'lead_assign_staff' => [
            'section' => 'leads', 'type' => 'staff', 'default' => 0, 'since' => '1.3.0',
            'label' => 'mks_st_set_lead_assign_staff', 'hint' => 'mks_st_set_lead_assign_staff_hint',
        ],
        'auto_lead' => [
            'section' => 'leads', 'type' => 'switch', 'default' => 0, 'since' => '1.4.0',
            'label' => 'mks_st_set_auto_lead', 'hint' => 'mks_st_set_auto_lead_hint',
        ],
        'auto_lead_direction' => [
            'section' => 'leads', 'type' => 'choice', 'default' => 'both', 'since' => '1.4.0',
            'options' => ['both' => 'mks_st_auto_both', 'incoming' => 'mks_st_auto_incoming', 'outgoing' => 'mks_st_auto_outgoing'],
            'label' => 'mks_st_set_auto_lead_direction', 'hint' => 'mks_st_set_auto_lead_direction_hint',
        ],
        'auto_lead_min_seconds' => [
            'section' => 'leads', 'type' => 'number', 'default' => 30, 'min' => 0, 'max' => 600,
            'unit' => 'mks_st_unit_seconds', 'since' => '1.4.0',
            'label' => 'mks_st_set_auto_lead_min', 'hint' => 'mks_st_set_auto_lead_min_hint',
        ],
        'auto_lead_whatsapp' => [
            'section' => 'leads', 'type' => 'switch', 'default' => 1, 'since' => '1.4.0',
            'label' => 'mks_st_set_auto_lead_whatsapp', 'hint' => 'mks_st_set_auto_lead_whatsapp_hint',
        ],
        'auto_lead_working_hours' => [
            'section' => 'leads', 'type' => 'switch', 'default' => 0, 'since' => '1.4.0',
            'label' => 'mks_st_set_auto_lead_hours', 'hint' => 'mks_st_set_auto_lead_hours_hint',
        ],
        'auto_lead_history' => [
            'section' => 'leads', 'type' => 'switch', 'default' => 0, 'since' => '1.4.0',
            'label' => 'mks_st_set_auto_lead_history', 'hint' => 'mks_st_set_auto_lead_history_hint',
        ],
        'update_last_contact' => [
            'section' => 'leads', 'type' => 'switch', 'default' => 1, 'since' => '1.4.0',
            'label' => 'mks_st_set_last_contact', 'hint' => 'mks_st_set_last_contact_hint',
        ],
        'crm_tabs' => [
            'section' => 'leads', 'type' => 'switch', 'default' => 1, 'since' => '1.4.0',
            'label' => 'mks_st_set_crm_tabs', 'hint' => 'mks_st_set_crm_tabs_hint',
        ],
        'follow_up_email' => [
            'section' => 'leads', 'type' => 'switch', 'default' => 1, 'since' => '1.3.0',
            'label' => 'mks_st_set_follow_up_email', 'hint' => 'mks_st_set_follow_up_email_hint',
        ],

        /* Missed calls */
        'callback_minutes' => [
            'section' => 'missed', 'type' => 'number', 'default' => 30, 'min' => 5, 'max' => 1440,
            'unit' => 'mks_st_unit_minutes', 'since' => '1.3.0',
            'label' => 'mks_st_set_callback_minutes', 'hint' => 'mks_st_set_callback_minutes_hint',
        ],
        'work_start' => [
            'section' => 'missed', 'type' => 'time', 'default' => '09:30', 'since' => '1.3.0',
            'label' => 'mks_st_set_work_start', 'hint' => 'mks_st_set_work_start_hint',
        ],
        'work_end' => [
            'section' => 'missed', 'type' => 'time', 'default' => '18:30', 'since' => '1.3.0',
            'label' => 'mks_st_set_work_end', 'hint' => 'mks_st_set_work_end_hint',
        ],
        'callback_whatsapp' => [
            'section' => 'missed', 'type' => 'switch', 'default' => 1, 'since' => '1.3.0',
            'label' => 'mks_st_set_callback_whatsapp', 'hint' => 'mks_st_set_callback_whatsapp_hint',
        ],
        'escalate' => [
            'section' => 'missed', 'type' => 'switch', 'default' => 1, 'since' => '1.3.0',
            'label' => 'mks_st_set_escalate', 'hint' => 'mks_st_set_escalate_hint',
        ],
        'escalate_to' => [
            'section' => 'missed', 'type' => 'choice', 'default' => 'team_leads', 'since' => '1.3.0',
            'options' => ['team_leads' => 'mks_st_to_team_leads', 'managers' => 'mks_st_to_managers', 'both' => 'mks_st_to_both'],
            'label' => 'mks_st_set_escalate_to', 'hint' => 'mks_st_set_escalate_to_hint',
        ],
        'escalate_email' => [
            'section' => 'missed', 'type' => 'switch', 'default' => 1, 'since' => '1.3.0',
            'label' => 'mks_st_set_escalate_email', 'hint' => 'mks_st_set_escalate_email_hint',
        ],

        /* Alerts */
        'alert_tamper' => [
            'section' => 'alerts', 'type' => 'switch', 'default' => 1, 'since' => '1.3.0',
            'label' => 'mks_st_set_alert_tamper', 'hint' => 'mks_st_set_alert_tamper_hint',
        ],
        'alert_permissions' => [
            'section' => 'alerts', 'type' => 'switch', 'default' => 1, 'since' => '1.3.0',
            'label' => 'mks_st_set_alert_permissions', 'hint' => 'mks_st_set_alert_permissions_hint',
        ],
        'alert_silent_hours' => [
            'section' => 'alerts', 'type' => 'number', 'default' => 2, 'min' => 0, 'max' => 24,
            'unit' => 'mks_st_unit_hours', 'since' => '1.3.0',
            'label' => 'mks_st_set_alert_silent', 'hint' => 'mks_st_set_alert_silent_hint',
        ],
        'alert_to' => [
            'section' => 'alerts', 'type' => 'choice', 'default' => 'managers', 'since' => '1.3.0',
            'options' => ['team_leads' => 'mks_st_to_team_leads', 'managers' => 'mks_st_to_managers', 'both' => 'mks_st_to_both'],
            'label' => 'mks_st_set_alert_to', 'hint' => 'mks_st_set_alert_to_hint',
        ],
        'alert_email' => [
            'section' => 'alerts', 'type' => 'switch', 'default' => 0, 'since' => '1.3.0',
            'label' => 'mks_st_set_alert_email', 'hint' => 'mks_st_set_alert_email_hint',
        ],

        /* Click to call */
        'click_to_call' => [
            'section' => 'calling', 'type' => 'switch', 'default' => 0, 'since' => '1.4.0', 'app' => true,
            'label' => 'mks_st_set_click_to_call', 'hint' => 'mks_st_set_click_to_call_hint',
        ],
        'dial_confirm' => [
            'section' => 'calling', 'type' => 'switch', 'default' => 0, 'since' => '1.4.0', 'app' => true,
            'label' => 'mks_st_set_dial_confirm', 'hint' => 'mks_st_set_dial_confirm_hint',
        ],
        'fcm_key' => [
            'section' => 'calling', 'type' => 'secret_json', 'default' => '', 'since' => '1.4.0',
            'label' => 'mks_st_set_fcm_key', 'hint' => 'mks_st_set_fcm_key_hint',
        ],

        /* Email reports */
        'report_daily' => [
            'section' => 'reports', 'type' => 'switch', 'default' => 1, 'since' => '1.5.0',
            'label' => 'mks_st_set_report_daily', 'hint' => 'mks_st_set_report_daily_hint',
        ],
        'report_daily_time' => [
            'section' => 'reports', 'type' => 'time', 'default' => '19:00', 'since' => '1.5.0',
            'label' => 'mks_st_set_report_daily_time', 'hint' => 'mks_st_set_report_time_hint',
        ],
        'report_weekly' => [
            'section' => 'reports', 'type' => 'switch', 'default' => 1, 'since' => '1.5.0',
            'label' => 'mks_st_set_report_weekly', 'hint' => 'mks_st_set_report_weekly_hint',
        ],
        'report_weekly_day' => [
            'section' => 'reports', 'type' => 'choice', 'default' => 'mon', 'since' => '1.5.0',
            'options' => ['mon' => 'mks_st_wd_mon', 'tue' => 'mks_st_wd_tue', 'wed' => 'mks_st_wd_wed', 'thu' => 'mks_st_wd_thu',
                'fri' => 'mks_st_wd_fri', 'sat' => 'mks_st_wd_sat', 'sun' => 'mks_st_wd_sun'],
            'label' => 'mks_st_set_report_weekly_day', 'hint' => 'mks_st_set_report_weekly_day_hint',
        ],
        'report_weekly_time' => [
            'section' => 'reports', 'type' => 'time', 'default' => '09:00', 'since' => '1.5.0',
            'label' => 'mks_st_set_report_weekly_time', 'hint' => 'mks_st_set_report_time_hint',
        ],
        'report_monthly' => [
            'section' => 'reports', 'type' => 'switch', 'default' => 1, 'since' => '1.5.0',
            'label' => 'mks_st_set_report_monthly', 'hint' => 'mks_st_set_report_monthly_hint',
        ],
        'report_monthly_time' => [
            'section' => 'reports', 'type' => 'time', 'default' => '09:00', 'since' => '1.5.0',
            'label' => 'mks_st_set_report_monthly_time', 'hint' => 'mks_st_set_report_time_hint',
        ],
        'report_to' => [
            'section' => 'reports', 'type' => 'choice', 'default' => 'both', 'since' => '1.5.0',
            'options' => ['both' => 'mks_st_to_both', 'managers' => 'mks_st_to_managers', 'team_leads' => 'mks_st_to_team_leads'],
            'label' => 'mks_st_set_report_to', 'hint' => 'mks_st_set_report_to_hint',
        ],
        'report_reps' => [
            'section' => 'reports', 'type' => 'switch', 'default' => 1, 'since' => '1.5.0',
            'label' => 'mks_st_set_report_reps', 'hint' => 'mks_st_set_report_reps_hint',
        ],
        'storage_mode' => [
            'section' => 'storage', 'type' => 'choice', 'default' => 'server', 'since' => '1.6.0',
            'options' => ['server' => 'mks_st_store_server', 'drive' => 'mks_st_store_drive'],
            'label' => 'mks_st_set_storage_mode', 'hint' => 'mks_st_set_storage_mode_hint',
        ],
        'recording_keep_days' => [
            'section' => 'storage', 'type' => 'number', 'default' => 90, 'min' => 0, 'max' => 3650,
            'unit' => 'mks_st_unit_days', 'since' => '1.6.0',
            'label' => 'mks_st_set_keep_days', 'hint' => 'mks_st_set_keep_days_hint',
        ],
        'drive_client_id' => [
            'section' => 'storage', 'type' => 'text', 'default' => '', 'max_length' => 200, 'since' => '1.6.0',
            'placeholder' => '1234567890-abc.apps.googleusercontent.com',
            'label' => 'mks_st_set_drive_client_id', 'hint' => 'mks_st_set_drive_client_id_hint',
        ],
        'drive_client_secret' => [
            'section' => 'storage', 'type' => 'secret', 'default' => '', 'option' => 'mks_sales_track_drive_secret', 'since' => '1.6.0',
            'label' => 'mks_st_set_drive_secret', 'hint' => 'mks_st_set_drive_secret_hint',
        ],
        'drive_folder' => [
            'section' => 'storage', 'type' => 'text', 'default' => 'Sales Track', 'max_length' => 80, 'since' => '1.6.0',
            'label' => 'mks_st_set_drive_folder', 'hint' => 'mks_st_set_drive_folder_hint',
        ],
        'drive_keep_days' => [
            'section' => 'storage', 'type' => 'number', 'default' => 7, 'min' => 0, 'max' => 90,
            'unit' => 'mks_st_unit_days', 'since' => '1.6.0',
            'label' => 'mks_st_set_drive_keep', 'hint' => 'mks_st_set_drive_keep_hint',
        ],
        'recording_download' => [
            'section' => 'storage', 'type' => 'choice', 'default' => 'managers', 'since' => '1.6.0',
            'options' => ['managers' => 'mks_st_dl_managers', 'play' => 'mks_st_dl_play'],
            'label' => 'mks_st_set_download', 'hint' => 'mks_st_set_download_hint',
        ],
        'audit_recordings' => [
            'section' => 'storage', 'type' => 'switch', 'default' => 1, 'since' => '1.6.0',
            'label' => 'mks_st_set_audit', 'hint' => 'mks_st_set_audit_hint',
        ],
        'pitch_nominate' => [
            'section' => 'storage', 'type' => 'switch', 'default' => 1, 'since' => '1.6.0',
            'label' => 'mks_st_set_pitch_nominate', 'hint' => 'mks_st_set_pitch_nominate_hint',
        ],
        'pitch_categories' => [
            'section' => 'storage', 'type' => 'textarea', 'default' => "Opening\nDiscovery\nObjection Handling\nClosing\nFollow-up\nProduct Demo",
            'clean' => 'lines', 'since' => '1.6.0',
            'label' => 'mks_st_set_pitch_categories', 'hint' => 'mks_st_set_pitch_categories_hint',
        ],
        'ai_enabled' => [
            'section' => 'ai', 'type' => 'switch', 'default' => 0, 'since' => '1.7.0',
            'label' => 'mks_st_set_ai_enabled', 'hint' => 'mks_st_set_ai_enabled_hint',
        ],
        'gemini_key' => [
            'section' => 'ai', 'type' => 'secret', 'default' => '', 'option' => 'mks_sales_track_gemini_key', 'since' => '1.7.0',
            'label' => 'mks_st_set_gemini_key', 'hint' => 'mks_st_set_gemini_key_hint',
        ],
        'gemini_model' => [
            'section' => 'ai', 'type' => 'text', 'default' => 'gemini-3.1-flash-lite', 'clean' => 'model', 'max_length' => 60, 'since' => '1.7.0',
            'label' => 'mks_st_set_gemini_model', 'hint' => 'mks_st_set_gemini_model_hint',
        ],
        'ai_auto' => [
            'section' => 'ai', 'type' => 'choice', 'default' => 'crm', 'since' => '1.7.0',
            'options' => ['crm' => 'mks_st_ai_auto_crm', 'all' => 'mks_st_ai_auto_all', 'manual' => 'mks_st_ai_auto_manual'],
            'label' => 'mks_st_set_ai_auto', 'hint' => 'mks_st_set_ai_auto_hint',
        ],
        'ai_min_seconds' => [
            'section' => 'ai', 'type' => 'number', 'default' => 60, 'min' => 0, 'max' => 3600,
            'unit' => 'mks_st_unit_seconds', 'since' => '1.7.0',
            'label' => 'mks_st_set_ai_min', 'hint' => 'mks_st_set_ai_min_hint',
        ],
        'ai_max_minutes' => [
            'section' => 'ai', 'type' => 'number', 'default' => 20, 'min' => 1, 'max' => 60,
            'unit' => 'mks_st_unit_minutes', 'since' => '1.7.0',
            'label' => 'mks_st_set_ai_max', 'hint' => 'mks_st_set_ai_max_hint',
        ],
        'ai_budget' => [
            'section' => 'ai', 'type' => 'number', 'default' => 10, 'min' => 0, 'max' => 10000,
            'unit' => 'mks_st_unit_usd_month', 'since' => '1.7.0',
            'label' => 'mks_st_set_ai_budget', 'hint' => 'mks_st_set_ai_budget_hint',
        ],
        'ai_price_audio' => [
            'section' => 'ai', 'type' => 'text', 'default' => '0.50', 'clean' => 'decimal', 'max_length' => 10, 'since' => '1.7.0',
            'label' => 'mks_st_set_ai_price_audio', 'hint' => 'mks_st_set_ai_price_hint',
        ],
        'ai_price_text' => [
            'section' => 'ai', 'type' => 'text', 'default' => '0.25', 'clean' => 'decimal', 'max_length' => 10, 'since' => '1.7.0',
            'label' => 'mks_st_set_ai_price_text', 'hint' => 'mks_st_set_ai_price_hint',
        ],
        'ai_price_output' => [
            'section' => 'ai', 'type' => 'text', 'default' => '1.50', 'clean' => 'decimal', 'max_length' => 10, 'since' => '1.7.0',
            'label' => 'mks_st_set_ai_price_output', 'hint' => 'mks_st_set_ai_price_hint',
        ],
        'ai_rubric' => [
            'section' => 'ai', 'type' => 'textarea', 'clean' => 'lines', 'since' => '1.7.0',
            'default' => "Greeted the customer and introduced themselves\nAsked about the customer's needs\nExplained the offer clearly\nHandled objections calmly\nAgreed a clear next step",
            'label' => 'mks_st_set_ai_rubric', 'hint' => 'mks_st_set_ai_rubric_hint',
        ],
        'ai_competitors' => [
            'section' => 'ai', 'type' => 'textarea', 'default' => '', 'clean' => 'lines', 'since' => '1.7.0',
            'label' => 'mks_st_set_ai_competitors', 'hint' => 'mks_st_set_ai_competitors_hint',
        ],
        'ai_keywords' => [
            'section' => 'ai', 'type' => 'textarea', 'default' => '', 'clean' => 'lines', 'since' => '1.7.0',
            'label' => 'mks_st_set_ai_keywords', 'hint' => 'mks_st_set_ai_keywords_hint',
        ],
        'ai_alerts' => [
            'section' => 'ai', 'type' => 'switch', 'default' => 1, 'since' => '1.7.0',
            'label' => 'mks_st_set_ai_alerts', 'hint' => 'mks_st_set_ai_alerts_hint',
        ],
        'ai_suggest' => [
            'section' => 'ai', 'type' => 'switch', 'default' => 1, 'since' => '1.7.0',
            'label' => 'mks_st_set_ai_suggest', 'hint' => 'mks_st_set_ai_suggest_hint',
        ],
        'ai_rep_view' => [
            'section' => 'ai', 'type' => 'switch', 'default' => 1, 'since' => '1.7.0',
            'label' => 'mks_st_set_ai_rep_view', 'hint' => 'mks_st_set_ai_rep_view_hint',
        ],
        'ai_coaching' => [
            'section' => 'ai', 'type' => 'switch', 'default' => 1, 'since' => '1.7.0',
            'label' => 'mks_st_set_ai_coaching', 'hint' => 'mks_st_set_ai_coaching_hint',
        ],
        'directory_enabled' => [
            'section' => 'popup', 'type' => 'switch', 'default' => 1, 'since' => '1.8.0', 'app' => true,
            'label' => 'mks_st_set_directory', 'hint' => 'mks_st_set_directory_hint',
        ],
        'popup_incoming' => [
            'section' => 'popup', 'type' => 'switch', 'default' => 1, 'since' => '1.8.0', 'app' => true,
            'label' => 'mks_st_set_popup_in', 'hint' => 'mks_st_set_popup_in_hint',
        ],
        'popup_outgoing' => [
            'section' => 'popup', 'type' => 'switch', 'default' => 1, 'since' => '1.8.0', 'app' => true,
            'label' => 'mks_st_set_popup_out', 'hint' => 'mks_st_set_popup_out_hint',
        ],
        'directory_leads' => [
            'section' => 'popup', 'type' => 'choice', 'default' => 'all', 'since' => '1.8.0',
            'options' => ['all' => 'mks_st_dir_leads_all', 'own' => 'mks_st_dir_leads_own', 'none' => 'mks_st_dir_none'],
            'label' => 'mks_st_set_dir_leads', 'hint' => 'mks_st_set_dir_leads_hint',
        ],
        'directory_customers' => [
            'section' => 'popup', 'type' => 'choice', 'default' => 'visible', 'since' => '1.8.0',
            'options' => ['visible' => 'mks_st_dir_cust_visible', 'all' => 'mks_st_dir_cust_all', 'none' => 'mks_st_dir_none'],
            'label' => 'mks_st_set_dir_customers', 'hint' => 'mks_st_set_dir_customers_hint',
        ],
        'directory_staff' => [
            'section' => 'popup', 'type' => 'switch', 'default' => 1, 'since' => '1.8.0',
            'label' => 'mks_st_set_dir_staff', 'hint' => 'mks_st_set_dir_staff_hint',
        ],
        'directory_extra' => [
            'section' => 'popup', 'type' => 'textarea', 'default' => '', 'clean' => 'lines', 'since' => '1.8.0',
            'placeholder' => '+91 98765 43210, Head Office, Supplier',
            'label' => 'mks_st_set_dir_extra', 'hint' => 'mks_st_set_dir_extra_hint',
        ],
        'wallboard_public' => [
            'section' => 'wallboard', 'type' => 'switch', 'default' => 0, 'since' => '1.8.0',
            'label' => 'mks_st_set_wall_public', 'hint' => 'mks_st_set_wall_public_hint',
        ],
        'wallboard_refresh' => [
            'section' => 'wallboard', 'type' => 'number', 'default' => 60, 'min' => 15, 'max' => 600,
            'unit' => 'mks_st_unit_seconds', 'since' => '1.8.0',
            'label' => 'mks_st_set_wall_refresh', 'hint' => 'mks_st_set_wall_refresh_hint',
        ],
        'wallboard_key' => [
            'section' => 'wallboard', 'type' => 'internal', 'default' => '', 'since' => '1.8.0',
        ],
        'report_skip_empty' => [
            'section' => 'reports', 'type' => 'switch', 'default' => 1, 'since' => '1.5.0',
            'label' => 'mks_st_set_report_skip_empty', 'hint' => 'mks_st_set_report_skip_empty_hint',
        ],
    ],
];
