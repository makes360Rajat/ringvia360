<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - the Set Outcome window, shared by the lists and the
 * Follow-ups page. Saving goes through the same code as the phone's popup.
 */
$mks_outcomes = mks_st_outcomes();
$mks_statuses = mks_st_lead_statuses();
?>
<div class="modal fade mks-sales-track-modal" id="mks-sales-track-outcome-modal" tabindex="-1" role="dialog" aria-labelledby="mks-sales-track-outcome-title">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
                <button type="button" class="close" data-dismiss="modal" aria-label="<?= e(_l('mks_st_close')); ?>"><span aria-hidden="true">&times;</span></button>
                <h4 class="modal-title" id="mks-sales-track-outcome-title"><?= e(_l('mks_st_set_outcome')); ?></h4>
            </div>
            <div class="modal-body">
                <input type="hidden" id="mks-st-o-id" value="">
                <div class="form-group">
                    <label class="control-label"><?= e(_l('mks_st_col_outcome')); ?></label>
                    <div class="mks-sales-track-outcome-choices" role="radiogroup">
                        <?php foreach ($mks_outcomes as $mks_key => $mks_outcome) { ?>
                        <label class="mks-sales-track-outcome-choice mks-sales-track-tone-<?= e($mks_outcome['tone']); ?>">
                            <input type="radio" name="mks_st_o_outcome" value="<?= e($mks_key); ?>">
                            <span><?= e($mks_outcome['label']); ?></span>
                        </label>
                        <?php } ?>
                    </div>
                </div>
                <div class="form-group">
                    <label class="control-label" for="mks-st-o-note"><?= e(_l('mks_st_note')); ?></label>
                    <textarea id="mks-st-o-note" class="form-control" rows="3" maxlength="2000"></textarea>
                </div>
                <div class="row">
                    <div class="col-sm-6">
                        <div class="form-group">
                            <label class="control-label" for="mks-st-o-follow"><?= e(_l('mks_st_follow_up')); ?></label>
                            <input type="datetime-local" id="mks-st-o-follow" class="form-control">
                        </div>
                    </div>
                    <div class="col-sm-6">
                        <div class="form-group">
                            <label class="control-label" for="mks-st-o-status"><?= e(_l('mks_st_lead_status')); ?></label>
                            <select id="mks-st-o-status" class="form-control">
                                <option value="0"><?= e(_l('mks_st_status_unchanged')); ?></option>
                                <?php foreach ($mks_statuses as $mks_id => $mks_status) { ?>
                                <option value="<?= (int) $mks_id; ?>"><?= e($mks_status['name']); ?></option>
                                <?php } ?>
                            </select>
                        </div>
                    </div>
                </div>
                <label class="mks-sales-track-check mks-sales-track-is-hidden" id="mks-st-o-lead-wrap">
                    <input type="checkbox" id="mks-st-o-lead" value="1"> <?= e(_l('mks_st_create_lead_too')); ?>
                </label>
                <p class="mks-sales-track-hint"><?= e(_l('mks_st_outcome_hint')); ?></p>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-default" data-dismiss="modal"><?= e(_l('mks_st_cancel')); ?></button>
                <button type="button" class="btn btn-primary" id="mks-st-o-save"><?= e(_l('mks_st_save')); ?></button>
            </div>
        </div>
    </div>
</div>
