<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - Follow-ups set from call outcomes. Each one is also a
 * native Perfex reminder on its lead or customer, so Perfex sends the
 * reminder itself; this page shows them all in one place.
 */

init_head();

$mks_tabs = ['due' => 'mks_st_fu_due', 'upcoming' => 'mks_st_fu_upcoming', 'done' => 'mks_st_fu_done'];
?>
<div id="wrapper">
    <div class="content">
        <div class="mks-sales-track mks-sales-track-follow-ups">

            <?php $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/partials/nav', ['nav' => $nav]); ?>

            <div class="mks-sales-track-head">
                <div class="mks-sales-track-head-main">
                    <span class="mks-sales-track-head-icon mks-sales-track-tone-amber"><i class="fa-solid fa-bell" aria-hidden="true"></i></span>
                    <div>
                        <h4 class="mks-sales-track-title"><?= e(_l('mks_st_page_follow_ups')); ?></h4>
                        <p class="mks-sales-track-sub"><?= e(_l('mks_st_page_follow_ups_sub')); ?></p>
                    </div>
                </div>
            </div>

            <div class="mks-sales-track-card">
                <div class="mks-sales-track-card-head">
                    <div class="mks-sales-track-segment" role="group">
                        <?php foreach ($mks_tabs as $mks_value => $mks_label) { ?>
                        <a href="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/follow_ups?tab=' . $mks_value); ?>" class="mks-sales-track-segment-btn<?= $tab === $mks_value ? ' is-active' : ''; ?>"><?= e(_l($mks_label)); ?></a>
                        <?php } ?>
                    </div>
                </div>

                <?php if (!$items) { ?>
                <div class="mks-sales-track-empty mks-sales-track-empty-sm">
                    <span class="mks-sales-track-empty-icon"><i class="fa-solid fa-bell" aria-hidden="true"></i></span>
                    <p><?= e(_l('mks_st_fu_empty')); ?></p>
                </div>
                <?php } else { ?>
                <div class="table-responsive">
                    <table class="mks-sales-track-mini-table">
                        <thead>
                            <tr>
                                <th><?= e(_l('mks_st_follow_up')); ?></th>
                                <th><?= e(_l('mks_st_col_contact')); ?></th>
                                <th><?= e(_l('mks_st_col_outcome')); ?></th>
                                <th><?= e(_l('mks_st_col_staff')); ?></th>
                                <th><?= e(_l('mks_st_from_call')); ?></th>
                                <th></th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($items as $mks_item) {
                                $mks_late = $tab !== 'done' && strtotime($mks_item['follow_up_at']) < time(); ?>
                            <tr>
                                <td><span class="mks-sales-track-pill mks-sales-track-tone-<?= $tab === 'done' ? 'green' : ($mks_late ? 'red' : 'blue'); ?>"><?= e(_dt($mks_item['follow_up_at'])); ?></span></td>
                                <td><?= mks_st_render_contact($mks_item); ?></td>
                                <td><?= mks_st_render_outcome($mks_item, $context); ?></td>
                                <td><?= mks_st_render_staff($mks_item); ?></td>
                                <td><?= mks_st_render_time($mks_item['occurred_at']); ?></td>
                                <td class="text-right"><?= $tab !== 'done' ? mks_st_dial_button($mks_item['number'], (string) $mks_item['contact_name']) : ''; ?></td>
                            </tr>
                            <?php } ?>
                        </tbody>
                    </table>
                </div>
                <?php } ?>
            </div>

            <?php $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/partials/outcome_modal'); ?>

        </div>
    </div>
</div>
<?php init_tail(); ?>
</body>

</html>
