<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - the Calls tab on a lead or customer: every call, WhatsApp
 * call and SMS with them that the viewer may see, newest first.
 *
 * Recordings play in the browser's own audio element here: the lead window is
 * loaded into Perfex's modal, outside the module's own pages.
 *
 * @var string $mks_rel     lead or customer
 * @var int    $mks_rel_id
 * @var array  $mks_numbers [number, name] to offer Call buttons for
 */
$mks_data     = mks_st_crm_events($mks_rel, $mks_rel_id);
$mks_outcomes = mks_st_outcomes(false);
$mks_play     = mks_st_can('play_recordings');
?>
<div class="mks-sales-track mks-sales-track-crm-tab">
    <div class="mks-sales-track-crm-head">
        <div class="mks-sales-track-crm-stats">
            <span><strong><?= e(mks_st_number_label($mks_data['totals']['calls'])); ?></strong> <?= e(_l('mks_st_kpi_calls')); ?></span>
            <span><strong><?= e(mks_st_duration_label($mks_data['totals']['talk'])); ?></strong> <?= e(_l('mks_st_kpi_talk_time')); ?></span>
            <span><?= e(_l('mks_st_last_call')); ?> <strong><?= $mks_data['totals']['last'] ? e(mks_st_relative_time($mks_data['totals']['last'])) : '-'; ?></strong></span>
        </div>
        <div class="mks-sales-track-crm-dial">
            <?php foreach ($mks_numbers as $mks_number) { ?>
            <?= mks_st_dial_button($mks_number['number'], $mks_number['name'], false); ?>
            <?php } ?>
        </div>
    </div>

    <?php if (!$mks_data['events']) { ?>
    <p class="mks-sales-track-device-note"><?= e(_l('mks_st_tab_empty')); ?></p>
    <?php } else { ?>
    <div class="table-responsive">
        <table class="mks-sales-track-mini-table mks-sales-track-crm-table">
            <thead>
                <tr>
                    <th><?= e(_l('mks_st_col_direction')); ?></th>
                    <th><?= e(_l('mks_st_col_time')); ?></th>
                    <th><?= e(_l('mks_st_col_duration')); ?></th>
                    <th><?= e(_l('mks_st_col_staff')); ?></th>
                    <th><?= e(_l('mks_st_col_outcome')); ?></th>
                    <th><?= e(_l('mks_st_col_recording')); ?></th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($mks_data['events'] as $mks_event) { ?>
                <tr>
                    <td><?= mks_st_render_direction($mks_event); ?>
                        <?php if (in_array($mks_event['kind'], ['whatsapp_call', 'whatsapp_message'], true)) { ?><i class="fa-brands fa-whatsapp mks-sales-track-wa" aria-hidden="true"></i><?php } ?>
                        <?php if ($mks_event['kind'] === 'notification') { ?><i class="fa-solid fa-bell mks-sales-track-notif" aria-hidden="true"></i><?php } ?>
                        <?php if (in_array($mks_event['kind'], ['sms', 'whatsapp_message', 'notification'], true) && (string) $mks_event['body'] !== '') { ?>
                        <div class="mks-sales-track-crm-sms"><?= e(mb_strimwidth((string) $mks_event['body'], 0, 120, '...', 'UTF-8')); ?></div>
                        <?php } ?>
                    </td>
                    <td><?= mks_st_render_time($mks_event['occurred_at']); ?></td>
                    <td><?= in_array($mks_event['kind'], ['sms', 'whatsapp_message', 'notification'], true) ? '' : e(mks_st_duration_label($mks_event['duration'])); ?></td>
                    <td><?= mks_st_render_staff($mks_event); ?></td>
                    <td>
                        <?php if ($mks_event['outcome'] !== null) {
                            $mks_o = isset($mks_outcomes[$mks_event['outcome']]) ? $mks_outcomes[$mks_event['outcome']] : ['label' => $mks_event['outcome'], 'tone' => 'slate']; ?>
                        <span class="mks-sales-track-pill mks-sales-track-tone-<?= e($mks_o['tone']); ?>"><?= e($mks_o['label']); ?></span>
                        <?php if ((string) $mks_event['outcome_note'] !== '') { ?><div class="mks-sales-track-outcome-note"><?= e($mks_event['outcome_note']); ?></div><?php } ?>
                        <?php } ?>
                    </td>
                    <td>
                        <?php if ($mks_play && $mks_event['recording_status'] === 'stored') {
                            $mks_src = admin_url(MKS_SALES_TRACK_MODULE_NAME . '/recording/' . (int) $mks_event['id']);
                            if (mks_st_recording_playable($mks_event['recording_file'])) { ?>
                        <audio controls preload="none" src="<?= e($mks_src); ?>" class="mks-sales-track-crm-audio"></audio>
                        <?php } else { ?>
                        <a href="<?= e($mks_src . '?download=1'); ?>"><i class="fa-solid fa-download" aria-hidden="true"></i> <?= e(_l('mks_st_download')); ?></a>
                        <?php }
                        } ?>
                    </td>
                </tr>
                <?php } ?>
            </tbody>
        </table>
    </div>
    <?php if ($mks_data['totals']['calls'] > count($mks_data['events'])) { ?>
    <p class="mks-sales-track-muted mks-sales-track-small"><?= e(_l('mks_st_tab_latest', (string) count($mks_data['events']))); ?></p>
    <?php } ?>
    <?php } ?>
</div>
