<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - Devices.
 *
 * A device is created here first, with a name, description and the member of
 * staff it belongs to; it then waits for a phone to enter its 6-digit code.
 * Each card opens the device's own page.
 */

init_head();

$mks_state_tones = ['online' => 'green', 'idle' => 'amber', 'offline' => 'red', 'pending' => 'blue', 'paused' => 'slate', 'revoked' => 'slate'];
?>
<div id="wrapper">
    <div class="content">
        <div class="mks-sales-track mks-sales-track-devices">

            <?php $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/partials/nav', ['nav' => $nav]); ?>

            <div class="mks-sales-track-head">
                <div class="mks-sales-track-head-main">
                    <span class="mks-sales-track-head-icon mks-sales-track-head-icon-devices"><i class="fa-solid fa-mobile-screen-button" aria-hidden="true"></i></span>
                    <div>
                        <h4 class="mks-sales-track-title"><?= e(_l('mks_st_page_devices')); ?></h4>
                        <p class="mks-sales-track-sub"><?= e(_l('mks_st_page_devices_sub')); ?></p>
                    </div>
                </div>
                <div class="mks-sales-track-head-actions">
                    <?php if ($can_demo) { ?>
                    <button type="button" class="btn btn-default mks-sales-track-btn mks-sales-track-demo" data-action="<?= $demo ? 'remove' : 'load'; ?>">
                        <i class="fa-solid fa-flask" aria-hidden="true"></i><?= e(_l($demo ? 'mks_st_demo_remove' : 'mks_st_demo_load')); ?>
                    </button>
                    <?php } ?>
                    <?php if ($can_manage) { ?>
                    <button type="button" class="btn btn-primary mks-sales-track-btn" id="mks-sales-track-add-device">
                        <i class="fa-solid fa-plus" aria-hidden="true"></i><?= e(_l('mks_st_add_device')); ?>
                    </button>
                    <?php } ?>
                </div>
            </div>

            <?php if ($demo) { ?>
            <div class="mks-sales-track-banner mks-sales-track-tone-violet">
                <i class="fa-solid fa-flask" aria-hidden="true"></i><span><?= e(_l('mks_st_demo_banner')); ?></span>
            </div>
            <?php } ?>

            <?php if (!$can_pair) { ?>
            <div class="mks-sales-track-banner mks-sales-track-tone-amber">
                <i class="fa-solid fa-circle-info" aria-hidden="true"></i><span><?= e(_l('mks_st_api_off_notice')); ?></span>
            </div>
            <?php } ?>

            <div class="mks-sales-track-card mks-sales-track-connect">
                <ol class="mks-sales-track-steps">
                    <li><span class="mks-sales-track-step-no">1</span><span><?= e(_l('mks_st_step_add')); ?></span></li>
                    <li><span class="mks-sales-track-step-no">2</span><span><?= e(_l('mks_st_step_install')); ?></span></li>
                    <li><span class="mks-sales-track-step-no">3</span><span><?= e(_l('mks_st_step_code')); ?></span></li>
                </ol>
                <div class="mks-sales-track-address">
                    <span class="mks-sales-track-address-label"><?= e(_l('mks_st_server_address')); ?></span>
                    <code id="mks-sales-track-site-url"><?= e($site_url); ?></code>
                    <button type="button" class="mks-sales-track-icon-btn mks-sales-track-copy" data-copy="#mks-sales-track-site-url"
                        title="<?= e(_l('mks_st_copy')); ?>" aria-label="<?= e(_l('mks_st_copy')); ?>"><i class="fa-solid fa-copy" aria-hidden="true"></i></button>
                </div>
            </div>

            <?php if (count($devices) === 0) { ?>
            <div class="mks-sales-track-card mks-sales-track-empty">
                <span class="mks-sales-track-empty-icon"><i class="fa-solid fa-mobile-screen-button" aria-hidden="true"></i></span>
                <h5><?= e(_l('mks_st_no_devices')); ?></h5>
                <p><?= e(_l('mks_st_no_devices_sub')); ?></p>
            </div>
            <?php } else { ?>
            <div class="mks-sales-track-device-grid">
                <?php foreach ($devices as $mks_device) {
                    $mks_state  = mks_st_device_state($mks_device);
                    $mks_health = mks_st_decode($mks_device['health']);
                    $mks_perms  = isset($mks_health['permissions']) && is_array($mks_health['permissions']) ? $mks_health['permissions'] : [];
                    $mks_owner  = trim($mks_device['firstname'] . ' ' . $mks_device['lastname']);
                    $mks_ios    = $mks_device['platform'] === 'ios';
                    $mks_bound  = $mks_state !== 'pending';
                    $mks_missing = count(array_filter($mks_perms, function ($granted) {
                        return !$granted;
                    }));
                    $mks_meta = array_filter([
                        trim($mks_device['manufacturer'] . ' ' . $mks_device['model']),
                        $mks_device['app_version'] !== '' ? _l('mks_st_app_version', $mks_device['app_version']) : '',
                    ]);
                ?>
                <a href="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/device/' . (int) $mks_device['id']); ?>"
                    class="mks-sales-track-device mks-sales-track-device-<?= e($mks_state); ?>">
                    <div class="mks-sales-track-device-top">
                        <span class="mks-sales-track-device-icon<?= $mks_ios ? ' is-ios' : ''; ?><?= $mks_bound ? '' : ' is-pending'; ?>">
                            <i class="<?= $mks_bound ? 'fa-brands ' . ($mks_ios ? 'fa-apple' : 'fa-android') : 'fa-solid fa-hashtag'; ?>" aria-hidden="true"></i>
                        </span>
                        <div class="mks-sales-track-device-name">
                            <strong><?= e($mks_device['label']); ?></strong>
                            <span><?= e($mks_bound ? implode('  |  ', $mks_meta) : _l('mks_st_waiting_for_phone_sub')); ?></span>
                        </div>
                        <span class="mks-sales-track-pill mks-sales-track-tone-<?= $mks_state_tones[$mks_state]; ?>">
                            <span class="mks-sales-track-dot"></span><?= e(_l('mks_st_state_' . $mks_state)); ?>
                        </span>
                    </div>

                    <?php if ((string) $mks_device['description'] !== '') { ?>
                    <p class="mks-sales-track-device-desc"><?= e($mks_device['description']); ?></p>
                    <?php } ?>

                    <div class="mks-sales-track-person mks-sales-track-device-owner">
                        <?= staff_profile_image($mks_device['staff_id'], ['mks-sales-track-avatar'], 'small', ['alt' => $mks_owner]); ?>
                        <span class="mks-sales-track-person-name"><?= e($mks_owner !== '' ? $mks_owner : _l('mks_st_removed_staff')); ?></span>
                        <?php if (isset($mks_device['staff_active']) && (int) $mks_device['staff_active'] !== 1) { ?>
                        <span class="mks-sales-track-pill mks-sales-track-tone-red"><?= e(_l('mks_st_staff_inactive_short')); ?></span>
                        <?php } ?>
                    </div>

                    <?php if ($mks_bound) { ?>
                    <dl class="mks-sales-track-facts">
                        <div><dt><?= e(_l('mks_st_last_sync')); ?></dt><dd><?= e(mks_st_relative_time($mks_device['last_sync_at'])); ?></dd></div>
                        <div><dt><?= e(_l('mks_st_events_stored')); ?></dt><dd><?= e(mks_st_number_label($mks_device['events_count'])); ?></dd></div>
                        <div><dt><?= e(_l('mks_st_battery')); ?></dt><dd><?= isset($mks_health['battery']) ? (int) $mks_health['battery'] . '%' : '-'; ?></dd></div>
                    </dl>
                    <?php if ($mks_missing > 0) { ?>
                    <p class="mks-sales-track-device-error"><i class="fa-solid fa-triangle-exclamation" aria-hidden="true"></i><?= e(_l('mks_st_permissions_missing', (string) $mks_missing)); ?></p>
                    <?php } ?>
                    <?php } else { ?>
                    <p class="mks-sales-track-device-note"><i class="fa-solid fa-hashtag" aria-hidden="true"></i> <?= e(_l('mks_st_open_for_code')); ?></p>
                    <?php } ?>
                </a>
                <?php } ?>
            </div>
            <?php } ?>

            <?php if ($can_manage) { ?>
            <div class="modal fade mks-sales-track-modal" id="mks-sales-track-device-modal" tabindex="-1" role="dialog" aria-labelledby="mks-sales-track-device-modal-title">
                <div class="modal-dialog" role="document">
                    <div class="modal-content">
                        <div class="modal-header">
                            <button type="button" class="close" data-dismiss="modal" aria-label="<?= e(_l('mks_st_close')); ?>"><span aria-hidden="true">&times;</span></button>
                            <h4 class="modal-title" id="mks-sales-track-device-modal-title"><?= e(_l('mks_st_add_device')); ?></h4>
                        </div>
                        <div class="modal-body">
                            <div class="mks-sales-track-device-form" data-step="form">
                                <?php $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/partials/device_form', ['staff_options' => $staff_options, 'form_device' => []]); ?>
                            </div>
                            <div class="mks-sales-track-is-hidden" data-step="pair">
                                <?php $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/partials/pairing'); ?>
                            </div>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-default" data-dismiss="modal"><?= e(_l('mks_st_close')); ?></button>
                            <button type="button" class="btn btn-primary mks-sales-track-device-save" data-step="form"><?= e(_l('mks_st_add_and_code')); ?></button>
                            <a href="#" class="btn btn-primary mks-sales-track-is-hidden mks-sales-track-device-open" data-step="pair"><?= e(_l('mks_st_open_device')); ?></a>
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
