<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - Missed Calls: the callback queue.
 *
 * A missed call stays here until anyone has a connected call with that
 * number, or somebody marks it returned. Past its callback time it is
 * escalated by the cron run, as set under Settings > Missed Calls.
 */

init_head();

$mks_tabs = ['open' => 'mks_st_queue_open', 'overdue' => 'mks_st_queue_overdue', 'resolved' => 'mks_st_queue_resolved'];
?>
<div id="wrapper">
    <div class="content">
        <div class="mks-sales-track mks-sales-track-queue">

            <?php $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/partials/nav', ['nav' => $nav]); ?>

            <div class="mks-sales-track-head">
                <div class="mks-sales-track-head-main">
                    <span class="mks-sales-track-head-icon mks-sales-track-tone-red"><i class="fa-solid fa-phone-slash" aria-hidden="true"></i></span>
                    <div>
                        <h4 class="mks-sales-track-title"><?= e(_l('mks_st_page_missed_calls')); ?></h4>
                        <p class="mks-sales-track-sub"><?= e(_l('mks_st_page_missed_calls_sub', (string) (int) mks_st_setting('callback_minutes', 30))); ?></p>
                    </div>
                </div>
            </div>

            <div class="mks-sales-track-kpis">
                <div class="mks-sales-track-kpi mks-sales-track-tone-amber">
                    <span class="mks-sales-track-kpi-icon"><i class="fa-solid fa-phone-slash" aria-hidden="true"></i></span>
                    <div class="mks-sales-track-kpi-body"><span class="mks-sales-track-kpi-label"><?= e(_l('mks_st_queue_open')); ?></span>
                        <span class="mks-sales-track-kpi-value"><?= e(mks_st_number_label($counts['open'])); ?></span></div>
                </div>
                <div class="mks-sales-track-kpi mks-sales-track-tone-red">
                    <span class="mks-sales-track-kpi-icon"><i class="fa-solid fa-clock" aria-hidden="true"></i></span>
                    <div class="mks-sales-track-kpi-body"><span class="mks-sales-track-kpi-label"><?= e(_l('mks_st_queue_overdue')); ?></span>
                        <span class="mks-sales-track-kpi-value"><?= e(mks_st_number_label($counts['overdue'])); ?></span></div>
                </div>
                <div class="mks-sales-track-kpi mks-sales-track-tone-green">
                    <span class="mks-sales-track-kpi-icon"><i class="fa-solid fa-circle-check" aria-hidden="true"></i></span>
                    <div class="mks-sales-track-kpi-body"><span class="mks-sales-track-kpi-label"><?= e(_l('mks_st_returned_today')); ?></span>
                        <span class="mks-sales-track-kpi-value"><?= e(mks_st_number_label($counts['today'])); ?></span></div>
                </div>
                <div class="mks-sales-track-kpi mks-sales-track-tone-violet">
                    <span class="mks-sales-track-kpi-icon"><i class="fa-solid fa-bolt" aria-hidden="true"></i></span>
                    <div class="mks-sales-track-kpi-body"><span class="mks-sales-track-kpi-label"><?= e(_l('mks_st_avg_callback')); ?></span>
                        <span class="mks-sales-track-kpi-value"><?= $counts['minutes'] !== null ? e(mks_st_duration_label((int) round($counts['minutes'] * 60))) : '-'; ?></span>
                        <span class="mks-sales-track-kpi-hint"><?= e(_l('mks_st_last_7_days')); ?></span></div>
                </div>
            </div>

            <div class="mks-sales-track-card">
                <div class="mks-sales-track-card-head">
                    <div class="mks-sales-track-segment" role="group">
                        <?php foreach ($mks_tabs as $mks_value => $mks_label) { ?>
                        <a href="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/missed_calls?tab=' . $mks_value); ?>" class="mks-sales-track-segment-btn<?= $tab === $mks_value ? ' is-active' : ''; ?>"><?= e(_l($mks_label)); ?></a>
                        <?php } ?>
                    </div>
                </div>

                <?php if (!$items) { ?>
                <div class="mks-sales-track-empty mks-sales-track-empty-sm">
                    <span class="mks-sales-track-empty-icon"><i class="fa-solid fa-circle-check" aria-hidden="true"></i></span>
                    <p><?= e(_l($tab === 'resolved' ? 'mks_st_queue_none_resolved' : 'mks_st_queue_empty')); ?></p>
                </div>
                <?php } else { ?>
                <div class="table-responsive">
                    <table class="mks-sales-track-mini-table mks-sales-track-queue-table">
                        <thead>
                            <tr>
                                <th><?= e(_l('mks_st_col_contact')); ?></th>
                                <th><?= e(_l('mks_st_col_staff')); ?></th>
                                <th><?= e(_l('mks_st_missed_at')); ?></th>
                                <th><?= e(_l($tab === 'resolved' ? 'mks_st_returned_at' : 'mks_st_due')); ?></th>
                                <th><?= e(_l('mks_st_attempts')); ?></th>
                                <th></th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($items as $mks_item) {
                                $mks_late = $mks_item['callback_state'] !== 'resolved' && strtotime($mks_item['callback_due_at']) < time(); ?>
                            <tr id="mks-sales-track-queue-<?= (int) $mks_item['id']; ?>">
                                <td><?= mks_st_render_contact($mks_item); ?></td>
                                <td><?= mks_st_render_staff($mks_item); ?></td>
                                <td><?= mks_st_render_time($mks_item['occurred_at']); ?>
                                    <?php if ($mks_item['kind'] === 'whatsapp_call') { ?><span class="mks-sales-track-pill mks-sales-track-tone-green"><i class="fa-brands fa-whatsapp" aria-hidden="true"></i></span><?php } ?></td>
                                <td>
                                    <?php if ($mks_item['callback_state'] === 'resolved') { ?>
                                    <?= e(_dt($mks_item['callback_at'])); ?> <small class="mks-sales-track-muted"><?= e(mks_st_staff_name($mks_item['callback_by'])); ?></small>
                                    <?php } else { ?>
                                    <span class="mks-sales-track-pill mks-sales-track-tone-<?= $mks_late ? 'red' : 'amber'; ?>"><?= e($mks_late ? _l('mks_st_overdue_since', mks_st_relative_time($mks_item['callback_due_at'])) : _dt($mks_item['callback_due_at'])); ?></span>
                                    <?php if ($mks_item['callback_state'] === 'escalated') { ?><span class="mks-sales-track-pill mks-sales-track-tone-violet"><?= e(_l('mks_st_escalated')); ?></span><?php } ?>
                                    <?php } ?>
                                </td>
                                <td><?= (int) $mks_item['attempts']; ?></td>
                                <td class="text-right">
                                    <?php if ($mks_item['callback_state'] !== 'resolved') { ?>
                                    <?= mks_st_dial_button($mks_item['number'], (string) $mks_item['contact_name']); ?>
                                    <button type="button" class="btn btn-default btn-xs mks-sales-track-resolve" data-id="<?= (int) $mks_item['id']; ?>">
                                        <i class="fa-solid fa-check" aria-hidden="true"></i> <?= e(_l('mks_st_mark_returned')); ?>
                                    </button>
                                    <?php } ?>
                                </td>
                            </tr>
                            <?php } ?>
                        </tbody>
                    </table>
                </div>
                <?php } ?>
            </div>

        </div>
    </div>
</div>
<?php init_tail(); ?>
</body>

</html>
