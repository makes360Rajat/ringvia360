<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - one device: pairing, overview, health, activity, sync
 * history and commands.
 */

init_head();

$mks_tones = ['online' => 'green', 'idle' => 'amber', 'offline' => 'red', 'pending' => 'blue', 'paused' => 'slate', 'revoked' => 'slate'];
$mks_perm_labels = [
    'call_log'             => _l('mks_st_perm_call_log'),
    'phone_state'          => _l('mks_st_perm_phone_state'),
    'contacts'             => _l('mks_st_perm_contacts'),
    'sms'                  => _l('mks_st_perm_sms'),
    'notifications'        => _l('mks_st_perm_notifications'),
    'recordings'           => _l('mks_st_perm_recordings'),
    'battery_unrestricted' => _l('mks_st_perm_battery'),
];
$mks_perms = isset($health['permissions']) && is_array($health['permissions']) ? $health['permissions'] : [];
$mks_bound = $state !== 'pending' && $state !== 'revoked';
$mks_sim   = _l('mks_st_all_sims');

if ((int) $device['track_sim'] > 0) {
    $mks_sim = _l('mks_st_sim_n', (string) (int) $device['track_sim']);
}

$mks_fact = function ($label, $value) {
    return '<div><dt>' . e($label) . '</dt><dd>' . ($value === '' ? '<span class="mks-sales-track-muted">-</span>' : e($value)) . '</dd></div>';
};
?>
<div id="wrapper">
    <div class="content">
        <div class="mks-sales-track mks-sales-track-device-page" data-device="<?= (int) $device['id']; ?>">

            <?php $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/partials/nav', ['nav' => $nav]); ?>

            <a href="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/devices'); ?>" class="mks-sales-track-back">
                <i class="fa-solid fa-arrow-left" aria-hidden="true"></i><?= e(_l('mks_st_page_devices')); ?>
            </a>

            <div class="mks-sales-track-head">
                <div class="mks-sales-track-head-main">
                    <span class="mks-sales-track-head-icon mks-sales-track-head-icon-devices">
                        <i class="<?= $mks_bound ? 'fa-brands ' . ($device['platform'] === 'ios' ? 'fa-apple' : 'fa-android') : 'fa-solid fa-hashtag'; ?>" aria-hidden="true"></i>
                    </span>
                    <div>
                        <h4 class="mks-sales-track-title">
                            <?= e($device['label']); ?>
                            <span class="mks-sales-track-pill mks-sales-track-tone-<?= $mks_tones[$state]; ?>"><span class="mks-sales-track-dot"></span><?= e(_l('mks_st_state_' . $state)); ?></span>
                        </h4>
                        <p class="mks-sales-track-sub"><?= e($device['description'] !== '' ? $device['description'] : $owner); ?></p>
                    </div>
                </div>
                <?php if ($can_manage) { ?>
                <div class="mks-sales-track-head-actions">
                    <button type="button" class="btn btn-default mks-sales-track-btn" data-toggle="modal" data-target="#mks-sales-track-device-modal">
                        <i class="fa-solid fa-pen" aria-hidden="true"></i><?= e(_l('mks_st_edit')); ?>
                    </button>
                    <?php if ($state !== 'revoked' && $can_pair) { ?>
                    <button type="button" class="btn btn-default mks-sales-track-btn mks-sales-track-device-code" data-bound="<?= $mks_bound ? '1' : '0'; ?>">
                        <i class="fa-solid fa-hashtag" aria-hidden="true"></i><?= e(_l($mks_bound ? 'mks_st_regenerate_code' : 'mks_st_new_code')); ?>
                    </button>
                    <?php } ?>
                    <?php if ($state === 'revoked' && $can_pair) { ?>
                    <button type="button" class="btn btn-default mks-sales-track-btn mks-sales-track-device-code" data-bound="0">
                        <i class="fa-solid fa-hashtag" aria-hidden="true"></i><?= e(_l('mks_st_pair_again')); ?>
                    </button>
                    <?php } ?>
                    <?php if (in_array($device['status'], ['active', 'paused'], true)) { ?>
                    <button type="button" class="btn btn-default mks-sales-track-btn mks-sales-track-device-act" data-action="<?= $device['status'] === 'paused' ? 'resume' : 'pause'; ?>">
                        <i class="fa-solid <?= $device['status'] === 'paused' ? 'fa-play' : 'fa-pause'; ?>" aria-hidden="true"></i><?= e(_l($device['status'] === 'paused' ? 'mks_st_resume' : 'mks_st_pause')); ?>
                    </button>
                    <button type="button" class="btn btn-default mks-sales-track-btn mks-sales-track-danger mks-sales-track-device-act" data-action="revoke">
                        <i class="fa-solid fa-ban" aria-hidden="true"></i><?= e(_l('mks_st_revoke')); ?>
                    </button>
                    <?php } else { ?>
                    <button type="button" class="btn btn-default mks-sales-track-btn mks-sales-track-danger mks-sales-track-device-act" data-action="delete">
                        <i class="fa-solid fa-trash-can" aria-hidden="true"></i><?= e(_l('mks_st_delete')); ?>
                    </button>
                    <?php } ?>
                </div>
                <?php } ?>
            </div>

            <?php if ($device['status'] === 'paused') { ?>
            <div class="mks-sales-track-banner mks-sales-track-tone-slate">
                <i class="fa-solid fa-pause" aria-hidden="true"></i><span><?= e(_l('mks_st_paused_banner')); ?></span>
            </div>
            <?php } ?>

            <?php if ($outdated) { ?>
            <div class="mks-sales-track-banner mks-sales-track-tone-amber">
                <i class="fa-solid fa-triangle-exclamation" aria-hidden="true"></i><span><?= e(_l('mks_st_outdated_banner', $device['app_version'])); ?></span>
            </div>
            <?php } ?>

            <?php if ($can_manage) { ?>
            <div class="mks-sales-track-card mks-sales-track-device-pairing<?= $live_code ? '' : ' mks-sales-track-is-hidden'; ?>" id="mks-sales-track-device-pairing"
                data-code="<?= $live_code ? e(substr($live_code['code'], 0, 3) . ' ' . substr($live_code['code'], 3)) : ''; ?>"
                data-qr="<?= e($live_qr); ?>" data-site="<?= e(site_url()); ?>">
                <div class="mks-sales-track-card-head"><h5><?= e(_l('mks_st_pairing_code')); ?></h5></div>
                <?php $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/partials/pairing'); ?>
            </div>
            <?php } ?>

            <div class="mks-sales-track-device-layout">
                <div class="mks-sales-track-card">
                    <div class="mks-sales-track-card-head"><h5><?= e(_l('mks_st_overview')); ?></h5></div>
                    <dl class="mks-sales-track-facts mks-sales-track-facts-wide">
                        <?= $mks_fact(_l('mks_st_device_staff'), $owner); ?>
                        <?= $mks_fact(_l('mks_st_phone_model'), trim($device['manufacturer'] . ' ' . $device['model'])); ?>
                        <?= $mks_fact(_l('mks_st_os'), $device['os_version'] !== '' ? ($device['platform'] === 'ios' ? 'iOS ' : 'Android ') . $device['os_version'] : ''); ?>
                        <?= $mks_fact(_l('mks_st_app'), $device['app_version']); ?>
                        <?= $mks_fact(_l('mks_st_device_number'), mks_st_format_number($device['phone_number'])); ?>
                        <?= $mks_fact(_l('mks_st_sim_tracked'), $mks_sim); ?>
                        <?= $mks_fact(_l('mks_st_device_asset'), (string) $device['asset_tag']); ?>
                        <?= $mks_fact(_l('mks_st_paired_at'), $device['paired_at'] ? _dt($device['paired_at']) : ''); ?>
                        <?= $mks_fact(_l('mks_st_last_seen'), $device['last_seen_at'] ? mks_st_relative_time($device['last_seen_at']) : ''); ?>
                        <?= $mks_fact(_l('mks_st_last_sync'), $device['last_sync_at'] ? mks_st_relative_time($device['last_sync_at']) : ''); ?>
                        <?= $mks_fact(_l('mks_st_created'), $device['created_at'] ? _dt($device['created_at']) : ''); ?>
                        <?= $mks_fact(_l('mks_st_last_ip'), (string) $device['last_ip']); ?>
                        <?= $mks_fact(_l('mks_st_push'), !empty($device['push_token']) ? _l('mks_st_push_registered') . ($device['push_at'] ? ', ' . mks_st_relative_time($device['push_at']) : '') : _l('mks_st_push_not_registered')); ?>
                    </dl>
                </div>

                <div class="mks-sales-track-card">
                    <div class="mks-sales-track-card-head"><h5><?= e(_l('mks_st_health')); ?></h5></div>
                    <?php if (!$mks_perms) { ?>
                    <p class="mks-sales-track-device-note"><?= e(_l($mks_bound ? 'mks_st_no_health_yet' : 'mks_st_health_after_pairing')); ?></p>
                    <?php } else { ?>
                    <div class="mks-sales-track-perms">
                        <?php foreach ($mks_perm_labels as $mks_key => $mks_label) {
                            if (!array_key_exists($mks_key, $mks_perms)) {
                                continue;
                            } ?>
                        <span class="mks-sales-track-perm <?= $mks_perms[$mks_key] ? 'is-on' : 'is-off'; ?>"><i class="fa-solid <?= $mks_perms[$mks_key] ? 'fa-check' : 'fa-xmark'; ?>" aria-hidden="true"></i><?= e($mks_label); ?></span>
                        <?php } ?>
                    </div>
                    <dl class="mks-sales-track-facts">
                        <?= $mks_fact(_l('mks_st_battery'), isset($health['battery']) ? (int) $health['battery'] . '%' . (!empty($health['charging']) ? ' +' : '') : ''); ?>
                        <?= $mks_fact(_l('mks_st_network'), isset($health['network']) ? _l('mks_st_network_' . $health['network']) : ''); ?>
                        <?= $mks_fact(_l('mks_st_waiting_sync'), isset($health['queue']) ? mks_st_number_label($health['queue']) : ''); ?>
                        <?= $mks_fact(_l('mks_st_recordings_waiting'), isset($health['recordings_queue']) ? mks_st_number_label($health['recordings_queue']) : ''); ?>
                        <?= $mks_fact(_l('mks_st_reported'), isset($health['reported_at']) ? mks_st_relative_time($health['reported_at']) : ''); ?>
                    </dl>
                    <?php } ?>
                    <?php if (!empty($health['last_error'])) { ?>
                    <p class="mks-sales-track-device-error"><i class="fa-solid fa-triangle-exclamation" aria-hidden="true"></i><?= e($health['last_error']); ?></p>
                    <?php } ?>
                </div>

                <div class="mks-sales-track-card">
                    <div class="mks-sales-track-card-head"><h5><?= e(_l('mks_st_activity')); ?></h5></div>
                    <table class="mks-sales-track-mini-table">
                        <thead><tr><th></th><th><?= e(_l('mks_st_range_today')); ?></th><th><?= e(_l('mks_st_range_7d')); ?></th></tr></thead>
                        <tbody>
                            <?php foreach (['call' => 'mks_st_page_calls', 'whatsapp_call' => 'mks_st_page_whatsapp_calls', 'sms' => 'mks_st_page_sms'] as $mks_kind => $mks_label) { ?>
                            <tr>
                                <td><?= e(_l($mks_label)); ?></td>
                                <td><?= e(mks_st_number_label(isset($activity[$mks_kind]) ? $activity[$mks_kind]['today'] : 0)); ?></td>
                                <td><?= e(mks_st_number_label(isset($activity[$mks_kind]) ? $activity[$mks_kind]['week'] : 0)); ?></td>
                            </tr>
                            <?php } ?>
                        </tbody>
                    </table>
                </div>

                <?php if ($can_manage && in_array($device['status'], ['active', 'paused'], true)) { ?>
                <div class="mks-sales-track-card">
                    <div class="mks-sales-track-card-head"><h5><?= e(_l('mks_st_commands')); ?></h5></div>
                    <p class="mks-sales-track-hint"><?= e(_l('mks_st_commands_hint')); ?></p>
                    <div class="mks-sales-track-command-buttons">
                        <button type="button" class="btn btn-default mks-sales-track-btn mks-sales-track-device-act" data-action="command:sync_now">
                            <i class="fa-solid fa-arrows-rotate" aria-hidden="true"></i><?= e(_l('mks_st_cmd_sync_now')); ?>
                        </button>
                        <button type="button" class="btn btn-default mks-sales-track-btn mks-sales-track-device-act" data-action="command:recheck_permissions">
                            <i class="fa-solid fa-user-shield" aria-hidden="true"></i><?= e(_l('mks_st_cmd_recheck_permissions')); ?>
                        </button>
                        <?php if (!empty($device['push_token']) && (string) get_option('mks_sales_track_fcm') !== '') { ?>
                        <button type="button" class="btn btn-default mks-sales-track-btn mks-sales-track-device-act" data-action="push_test">
                            <i class="fa-solid fa-bolt" aria-hidden="true"></i><?= e(_l('mks_st_cmd_push_test')); ?>
                        </button>
                        <?php } ?>
                    </div>
                    <?php if ($commands) { ?>
                    <ul class="mks-sales-track-command-list">
                        <?php foreach (array_slice($commands, 0, 6) as $mks_command) { ?>
                        <li>
                            <span><?= e(_l('mks_st_cmd_' . $mks_command['type'])); ?></span>
                            <span class="mks-sales-track-pill mks-sales-track-tone-<?= ['pending' => 'amber', 'delivered' => 'blue', 'done' => 'green', 'failed' => 'red', 'expired' => 'slate'][$mks_command['status']]; ?>">
                                <?= e(_l('mks_st_cmd_state_' . $mks_command['status'])); ?></span>
                            <small class="mks-sales-track-muted"><?= e(mks_st_relative_time($mks_command['created'])); ?></small>
                        </li>
                        <?php } ?>
                    </ul>
                    <?php } ?>
                </div>
                <?php } ?>
            </div>

            <?php $mks_alerts = mks_st_decode($device['alerts']); ?>
            <?php if ($mks_alerts) { ?>
            <div class="mks-sales-track-card">
                <div class="mks-sales-track-card-head"><h5><?= e(_l('mks_st_alerts')); ?></h5></div>
                <ul class="mks-sales-track-alert-list">
                    <?php foreach (array_slice($mks_alerts, 0, 10) as $mks_alert) { ?>
                    <li>
                        <i class="fa-solid fa-triangle-exclamation" aria-hidden="true"></i>
                        <span><strong><?= e(_l('mks_st_alert_' . $mks_alert['type'])); ?></strong><?= $mks_alert['detail'] !== '' ? ': ' . e($mks_alert['detail']) : ''; ?></span>
                        <small class="mks-sales-track-muted"><?= e(_dt($mks_alert['t'])); ?></small>
                    </li>
                    <?php } ?>
                </ul>
            </div>
            <?php } ?>

            <div class="mks-sales-track-card">
                <div class="mks-sales-track-card-head"><h5><?= e(_l('mks_st_sync_history')); ?></h5></div>
                <?php if (!$sync_log) { ?>
                <p class="mks-sales-track-device-note"><?= e(_l('mks_st_no_syncs')); ?></p>
                <?php } else { ?>
                <div class="table-responsive">
                    <table class="mks-sales-track-mini-table">
                        <thead>
                            <tr>
                                <th><?= e(_l('mks_st_col_time')); ?></th>
                                <th><?= e(_l('mks_st_sync_stored')); ?></th>
                                <th><?= e(_l('mks_st_sync_duplicate')); ?></th>
                                <th><?= e(_l('mks_st_sync_skipped')); ?></th>
                                <th><?= e(_l('mks_st_sync_rejected')); ?></th>
                                <th><?= e(_l('mks_st_app')); ?></th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($sync_log as $mks_sync) { ?>
                            <tr>
                                <td><?= e(_dt($mks_sync['t'])); ?></td>
                                <td><?= (int) $mks_sync['st']; ?></td>
                                <td><?= (int) $mks_sync['dup']; ?></td>
                                <td><?= (int) $mks_sync['sk']; ?></td>
                                <td class="<?= (int) $mks_sync['re'] > 0 ? 'mks-sales-track-danger' : ''; ?>"><?= (int) $mks_sync['re']; ?></td>
                                <td><?= e($mks_sync['app']); ?></td>
                            </tr>
                            <?php } ?>
                        </tbody>
                    </table>
                </div>
                <?php } ?>
            </div>

            <?php if ($can_manage) { ?>
            <div class="modal fade mks-sales-track-modal" id="mks-sales-track-device-modal" tabindex="-1" role="dialog" aria-labelledby="mks-sales-track-edit-title">
                <div class="modal-dialog" role="document">
                    <div class="modal-content">
                        <div class="modal-header">
                            <button type="button" class="close" data-dismiss="modal" aria-label="<?= e(_l('mks_st_close')); ?>"><span aria-hidden="true">&times;</span></button>
                            <h4 class="modal-title" id="mks-sales-track-edit-title"><?= e(_l('mks_st_edit_device')); ?></h4>
                        </div>
                        <div class="modal-body mks-sales-track-device-form" data-step="form">
                            <?php $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/partials/device_form', ['staff_options' => $staff_options, 'form_device' => $device]); ?>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-default" data-dismiss="modal"><?= e(_l('mks_st_cancel')); ?></button>
                            <button type="button" class="btn btn-primary mks-sales-track-device-save" data-step="form"><?= e(_l('mks_st_save')); ?></button>
                        </div>
                    </div>
                </div>
            </div>
            <?php } ?>

        </div>
    </div>
</div>
<?php init_tail(); ?>
</body>

</html>
