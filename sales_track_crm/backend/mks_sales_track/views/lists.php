<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - Call Lists. Managers and team leads build lists from lead
 * filters and follow their progress; reps work through their own leads. Where
 * each lead stands is read from the real calls.
 */

init_head();

$mks_states = [
    'pending' => ['label' => 'mks_st_list_state_pending', 'tone' => 'slate'],
    'tried'   => ['label' => 'mks_st_list_state_tried', 'tone' => 'amber'],
    'reached' => ['label' => 'mks_st_list_state_reached', 'tone' => 'green'],
    'skipped' => ['label' => 'mks_st_list_state_skipped', 'tone' => 'slate'],
];

$mks_items = function (array $list, array $items) use ($mks_states, $manager) {
    ob_start(); ?>
    <div class="table-responsive">
        <table class="mks-sales-track-mini-table mks-sales-track-list-items">
            <thead>
                <tr>
                    <th><?= e(_l('mks_st_col_contact')); ?></th>
                    <th><?= e(_l('mks_st_lead_status')); ?></th>
                    <?php if ($manager) { ?><th><?= e(_l('mks_st_col_staff')); ?></th><?php } ?>
                    <th><?= e(_l('mks_st_list_state')); ?></th>
                    <th><?= e(_l('mks_st_last_call')); ?></th>
                    <th class="text-right"><?= e(_l('options')); ?></th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($items as $item) { ?>
                <tr>
                    <td>
                        <a href="#" onclick="init_lead(<?= (int) $item['lead']; ?>); return false;" class="mks-sales-track-contact-name"><?= e($item['name']); ?></a>
                        <?php if ((string) $item['company'] !== '') { ?><span class="mks-sales-track-muted"><?= e($item['company']); ?></span><?php } ?>
                        <div class="mks-sales-track-muted mks-sales-track-small"><?= e(mks_st_format_number($item['phone'])); ?></div>
                    </td>
                    <td><?= e($item['status']); ?></td>
                    <?php if ($manager) { ?><td><?= e(mks_st_staff_name($item['assigned'])); ?></td><?php } ?>
                    <td>
                        <span class="mks-sales-track-pill mks-sales-track-tone-<?= $mks_states[$item['state']]['tone']; ?>"><?= e(_l($mks_states[$item['state']]['label'])); ?></span>
                        <?php if ($item['outcome'] !== '') { ?><span class="mks-sales-track-muted mks-sales-track-small"><?= e($item['outcome']); ?></span><?php } ?>
                    </td>
                    <td><?= $item['last_at'] ? e(_dt($item['last_at'])) : '<span class="mks-sales-track-muted">-</span>'; ?></td>
                    <td class="text-right mks-sales-track-nowrap">
                        <?= mks_st_dial_button($item['phone'], $item['name']); ?>
                        <?php if (in_array($item['state'], ['pending', 'skipped'], true)) { ?>
                        <button type="button" class="btn btn-default btn-xs mks-sales-track-list-act" data-action="<?= $item['state'] === 'skipped' ? 'unskip' : 'skip'; ?>" data-id="<?= (int) $list['id']; ?>" data-lead="<?= (int) $item['lead']; ?>">
                            <?= e(_l($item['state'] === 'skipped' ? 'mks_st_list_unskip' : 'mks_st_list_skip')); ?></button>
                        <?php } ?>
                        <?php if ($manager && !$item['dnc']) { ?>
                        <button type="button" class="mks-sales-track-icon-btn mks-sales-track-list-act" data-action="dnc" data-number="<?= e($item['phone']); ?>" title="<?= e(_l('mks_st_dnc_add')); ?>" aria-label="<?= e(_l('mks_st_dnc_add')); ?>"><i class="fa-solid fa-phone-slash" aria-hidden="true"></i></button>
                        <?php } ?>
                    </td>
                </tr>
                <?php } ?>
            </tbody>
        </table>
    </div>
    <?php return ob_get_clean();
};
?>
<div id="wrapper">
    <div class="content">
        <div class="mks-sales-track mks-sales-track-lists">

            <?php $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/partials/nav', ['nav' => $nav]); ?>

            <div class="mks-sales-track-head">
                <div class="mks-sales-track-head-main">
                    <span class="mks-sales-track-head-icon"><i class="fa-solid fa-list-ol" aria-hidden="true"></i></span>
                    <div>
                        <h4 class="mks-sales-track-title"><?= e(_l('mks_st_page_lists')); ?></h4>
                        <p class="mks-sales-track-sub"><?= e(_l($manager ? 'mks_st_page_lists_sub' : 'mks_st_page_lists_sub_rep')); ?></p>
                    </div>
                </div>
                <?php if ($manager) { ?>
                <div class="mks-sales-track-head-actions">
                    <button type="button" class="btn btn-primary mks-sales-track-btn" data-toggle="modal" data-target="#mks-sales-track-list-modal"><i class="fa-solid fa-plus" aria-hidden="true"></i><?= e(_l('mks_st_list_new')); ?></button>
                </div>
                <?php } ?>
            </div>

            <?php if (!$rows) { ?>
            <div class="mks-sales-track-card mks-sales-track-empty">
                <span class="mks-sales-track-empty-icon"><i class="fa-solid fa-list-ol" aria-hidden="true"></i></span>
                <h5><?= e(_l('mks_st_list_empty')); ?></h5>
                <p><?= e(_l($manager ? 'mks_st_list_empty_sub' : 'mks_st_list_empty_rep')); ?></p>
            </div>
            <?php } ?>

            <?php foreach ($rows as $mks_row) {
                $mks_list = $mks_row['list'];
                $mks_t    = $mks_row['totals']; ?>
            <div class="mks-sales-track-card mks-sales-track-list-card<?= $mks_list['status'] !== 'active' ? ' is-archived' : ''; ?>">
                <div class="mks-sales-track-list-head">
                    <div>
                        <h5><?= e($mks_list['name']); ?>
                            <?php if ($mks_list['status'] !== 'active') { ?><span class="mks-sales-track-pill mks-sales-track-tone-slate"><?= e(_l('mks_st_list_archived')); ?></span><?php } ?></h5>
                        <p class="mks-sales-track-muted mks-sales-track-small">
                            <?= e(implode(', ', array_map('mks_st_staff_name', $mks_list['staff']))); ?>
                            <?php if ($mks_list['due'] !== '') { ?> - <?= e(_l('mks_st_list_due', _d($mks_list['due']))); ?><?php } ?>
                            <?php if ($mks_list['note'] !== '') { ?> - <?= e($mks_list['note']); ?><?php } ?>
                        </p>
                    </div>
                    <div class="mks-sales-track-list-figures">
                        <span><strong><?= (int) $mks_t['done']; ?></strong>/<?= (int) $mks_t['total']; ?> <?= e(_l('mks_st_list_called')); ?></span>
                        <span><strong><?= (int) $mks_t['reached']; ?></strong> <?= e(_l('mks_st_list_reached')); ?></span>
                        <?php if ($manager) { ?>
                        <a href="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/lists' . ($open === (int) $mks_list['id'] ? '' : '?id=' . (int) $mks_list['id'])); ?>" class="btn btn-default btn-xs"><?= e(_l($open === (int) $mks_list['id'] ? 'mks_st_list_hide' : 'mks_st_list_open')); ?></a>
                        <button type="button" class="btn btn-default btn-xs mks-sales-track-list-act" data-action="<?= $mks_list['status'] === 'active' ? 'archive' : 'reopen'; ?>" data-id="<?= (int) $mks_list['id']; ?>"><?= e(_l($mks_list['status'] === 'active' ? 'mks_st_list_archive' : 'mks_st_list_reopen')); ?></button>
                        <button type="button" class="mks-sales-track-icon-btn mks-sales-track-list-act" data-action="delete" data-id="<?= (int) $mks_list['id']; ?>" data-confirm="<?= e(_l('mks_st_list_delete_confirm')); ?>" title="<?= e(_l('mks_st_delete')); ?>" aria-label="<?= e(_l('mks_st_delete')); ?>"><i class="fa-solid fa-trash-can" aria-hidden="true"></i></button>
                        <?php } ?>
                    </div>
                </div>
                <div class="mks-sales-track-progress"><span style="width: <?= (int) $mks_t['percent']; ?>%"></span></div>
                <?php if ($mks_row['items']) {
                    echo $mks_items($mks_list, $mks_row['items']);
                } ?>
            </div>
            <?php } ?>

            <?php if ($manager) { ?>
            <div class="modal fade mks-sales-track-modal" id="mks-sales-track-list-modal" tabindex="-1" role="dialog" aria-labelledby="mks-sales-track-list-title">
                <div class="modal-dialog modal-lg" role="document">
                    <div class="modal-content">
                        <form id="mks-sales-track-list-form" onsubmit="return false;">
                            <div class="modal-header">
                                <button type="button" class="close" data-dismiss="modal" aria-label="<?= e(_l('mks_st_close')); ?>"><span aria-hidden="true">&times;</span></button>
                                <h4 class="modal-title" id="mks-sales-track-list-title"><?= e(_l('mks_st_list_new')); ?></h4>
                            </div>
                            <div class="modal-body">
                                <div class="row">
                                    <div class="col-md-6 form-group">
                                        <label class="control-label" for="mks-st-l-name"><?= e(_l('mks_st_list_name')); ?></label>
                                        <input type="text" id="mks-st-l-name" name="name" class="form-control" maxlength="80" required>
                                    </div>
                                    <div class="col-md-6 form-group">
                                        <label class="control-label" for="mks-st-l-due"><?= e(_l('mks_st_list_due_label')); ?></label>
                                        <input type="date" id="mks-st-l-due" name="due" class="form-control">
                                    </div>
                                </div>
                                <div class="form-group">
                                    <label class="control-label" for="mks-st-l-note"><?= e(_l('mks_st_list_note')); ?></label>
                                    <input type="text" id="mks-st-l-note" name="note" class="form-control" maxlength="250">
                                </div>
                                <h5 class="mks-sales-track-section-title"><?= e(_l('mks_st_list_which_leads')); ?></h5>
                                <div class="row">
                                    <div class="col-md-4 form-group">
                                        <label class="control-label"><?= e(_l('mks_st_lead_status')); ?></label>
                                        <select name="statuses[]" class="form-control mks-sales-track-list-filter" multiple size="5">
                                            <?php foreach ($statuses as $mks_id => $mks_status) { ?><option value="<?= (int) $mks_id; ?>"><?= e($mks_status['name']); ?></option><?php } ?>
                                        </select>
                                    </div>
                                    <div class="col-md-4 form-group">
                                        <label class="control-label"><?= e(_l('mks_st_set_lead_source')); ?></label>
                                        <select name="sources[]" class="form-control mks-sales-track-list-filter" multiple size="5">
                                            <?php foreach ($sources as $mks_source) { ?><option value="<?= (int) $mks_source['id']; ?>"><?= e($mks_source['name']); ?></option><?php } ?>
                                        </select>
                                    </div>
                                    <div class="col-md-4 form-group">
                                        <label class="control-label"><?= e(_l('mks_st_list_owners')); ?></label>
                                        <select name="owners[]" class="form-control mks-sales-track-list-filter" multiple size="5">
                                            <?php foreach ($staff as $mks_id => $mks_name) { ?><option value="<?= (int) $mks_id; ?>"><?= e($mks_name); ?></option><?php } ?>
                                        </select>
                                    </div>
                                </div>
                                <div class="row">
                                    <div class="col-md-4 form-group">
                                        <label class="control-label" for="mks-st-l-quiet"><?= e(_l('mks_st_list_quiet')); ?></label>
                                        <input type="number" id="mks-st-l-quiet" name="quiet_days" class="form-control mks-sales-track-list-filter" min="0" max="365" value="0">
                                    </div>
                                    <div class="col-md-4 form-group">
                                        <label class="control-label" for="mks-st-l-from"><?= e(_l('mks_st_list_created_from')); ?></label>
                                        <input type="date" id="mks-st-l-from" name="created_from" class="form-control mks-sales-track-list-filter">
                                    </div>
                                    <div class="col-md-4 form-group">
                                        <label class="control-label" for="mks-st-l-to"><?= e(_l('mks_st_to')); ?></label>
                                        <input type="date" id="mks-st-l-to" name="created_to" class="form-control mks-sales-track-list-filter">
                                    </div>
                                </div>
                                <div class="checkbox checkbox-primary">
                                    <input type="hidden" name="open_only" value="0">
                                    <input type="checkbox" id="mks-st-l-open" name="open_only" value="1" class="mks-sales-track-list-filter" checked>
                                    <label for="mks-st-l-open"><?= e(_l('mks_st_list_open_only')); ?></label>
                                </div>
                                <p class="mks-sales-track-list-preview mks-sales-track-muted"></p>
                                <h5 class="mks-sales-track-section-title"><?= e(_l('mks_st_list_who')); ?></h5>
                                <div class="row">
                                    <div class="col-md-6 form-group">
                                        <select name="staff[]" class="form-control" multiple size="5" required aria-label="<?= e(_l('mks_st_list_who')); ?>">
                                            <?php foreach ($staff as $mks_id => $mks_name) { ?><option value="<?= (int) $mks_id; ?>"><?= e($mks_name); ?></option><?php } ?>
                                        </select>
                                    </div>
                                    <div class="col-md-6 form-group">
                                        <div class="radio radio-primary"><input type="radio" id="mks-st-l-rr" name="mode" value="round_robin" checked><label for="mks-st-l-rr"><?= e(_l('mks_st_list_round_robin')); ?></label></div>
                                        <div class="radio radio-primary"><input type="radio" id="mks-st-l-own" name="mode" value="owner"><label for="mks-st-l-own"><?= e(_l('mks_st_list_by_owner')); ?></label></div>
                                    </div>
                                </div>
                            </div>
                            <div class="modal-footer">
                                <button type="button" class="btn btn-default" data-dismiss="modal"><?= e(_l('mks_st_cancel')); ?></button>
                                <button type="submit" class="btn btn-primary"><?= e(_l('mks_st_list_create')); ?></button>
                            </div>
                        </form>
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
