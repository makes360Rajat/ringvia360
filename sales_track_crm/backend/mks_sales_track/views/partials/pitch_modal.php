<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - the Best Pitch window: managers add a call to the library
 * (or remove it); reps nominate one of their own for a manager to approve.
 */
?>
<div class="modal fade mks-sales-track-modal" id="mks-sales-track-pitch-modal" tabindex="-1" role="dialog" aria-labelledby="mks-sales-track-pitch-title">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
                <button type="button" class="close" data-dismiss="modal" aria-label="<?= e(_l('mks_st_close')); ?>"><span aria-hidden="true">&times;</span></button>
                <h4 class="modal-title" id="mks-sales-track-pitch-title"><i class="fa-solid fa-star" aria-hidden="true"></i> <?= e(_l('mks_st_best_pitch')); ?></h4>
            </div>
            <div class="modal-body">
                <input type="hidden" id="mks-st-p-id" value="">
                <div class="form-group">
                    <label class="control-label" for="mks-st-p-category"><?= e(_l('mks_st_pitch_category')); ?></label>
                    <select id="mks-st-p-category" class="form-control">
                        <option value=""><?= e(_l('mks_st_pitch_no_category')); ?></option>
                        <?php foreach (mks_st_pitch_categories() as $mks_category) { ?>
                        <option value="<?= e($mks_category); ?>"><?= e($mks_category); ?></option>
                        <?php } ?>
                    </select>
                </div>
                <div class="form-group">
                    <label class="control-label" for="mks-st-p-note"><?= e(_l('mks_st_pitch_why')); ?></label>
                    <textarea id="mks-st-p-note" class="form-control" rows="3" maxlength="1000"></textarea>
                </div>
                <div class="form-group">
                    <label class="control-label" for="mks-st-p-moments"><?= e(_l('mks_st_pitch_moments')); ?></label>
                    <textarea id="mks-st-p-moments" class="form-control mks-sales-track-mono" rows="4" placeholder="0:45 <?= e(_l('mks_st_pitch_moment_example')); ?>"></textarea>
                    <p class="mks-sales-track-hint"><?= e(_l('mks_st_pitch_moments_hint')); ?></p>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-default mks-sales-track-danger mks-sales-track-is-hidden" data-pitch-action="remove"><?= e(_l('mks_st_pitch_remove')); ?></button>
                <button type="button" class="btn btn-default" data-dismiss="modal"><?= e(_l('mks_st_cancel')); ?></button>
                <button type="button" class="btn btn-primary" data-pitch-action="<?= mks_st_can_pitches() ? 'approve' : 'nominate'; ?>">
                    <?= e(_l(mks_st_can_pitches() ? 'mks_st_pitch_add' : 'mks_st_pitch_nominate')); ?>
                </button>
            </div>
        </div>
    </div>
</div>
