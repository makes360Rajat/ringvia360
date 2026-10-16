<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - Add or edit a device. On the device page it is filled
 * with the device's values and gains the SIM choice.
 *
 * @var array $staff_options
 * @var array $form_device   the device being edited, or [] to add
 */
$mks_d = isset($form_device) && is_array($form_device) ? $form_device : [];
?>
<input type="hidden" class="mks-sales-track-form-id" value="<?= isset($mks_d['id']) ? (int) $mks_d['id'] : ''; ?>">
<div class="form-group">
    <label class="control-label" for="mks-st-f-name"><?= e(_l('mks_st_device_name')); ?> <span class="text-danger">*</span></label>
    <input type="text" id="mks-st-f-name" class="form-control" data-field="name" maxlength="100" value="<?= e(isset($mks_d['label']) ? $mks_d['label'] : ''); ?>"
        placeholder="<?= e(_l('mks_st_device_name_placeholder')); ?>">
</div>
<div class="form-group">
    <label class="control-label" for="mks-st-f-description"><?= e(_l('mks_st_device_description')); ?></label>
    <textarea id="mks-st-f-description" class="form-control" data-field="description" rows="2" maxlength="500"><?= e(isset($mks_d['description']) ? $mks_d['description'] : ''); ?></textarea>
</div>
<div class="form-group">
    <label class="control-label" for="mks-st-f-staff"><?= e(_l('mks_st_device_staff')); ?> <span class="text-danger">*</span></label>
    <select id="mks-st-f-staff" class="form-control" data-field="staff_id">
        <option value=""><?= e(_l('mks_st_choose_staff')); ?></option>
        <?php foreach ($staff_options as $mks_id => $mks_name) { ?>
        <option value="<?= (int) $mks_id; ?>"<?= isset($mks_d['staff_id']) && (int) $mks_d['staff_id'] === (int) $mks_id ? ' selected' : ''; ?>><?= e($mks_name); ?></option>
        <?php } ?>
    </select>
</div>
<div class="row">
    <div class="col-sm-6">
        <div class="form-group">
            <label class="control-label" for="mks-st-f-phone"><?= e(_l('mks_st_device_number')); ?></label>
            <input type="text" id="mks-st-f-phone" class="form-control" data-field="phone_number" maxlength="20"
                value="<?= e(isset($mks_d['phone_number']) ? $mks_d['phone_number'] : ''); ?>" placeholder="+91 98140 00000">
        </div>
    </div>
    <div class="col-sm-6">
        <div class="form-group">
            <label class="control-label" for="mks-st-f-asset"><?= e(_l('mks_st_device_asset')); ?></label>
            <input type="text" id="mks-st-f-asset" class="form-control" data-field="asset_tag" maxlength="50"
                value="<?= e(isset($mks_d['asset_tag']) ? $mks_d['asset_tag'] : ''); ?>">
        </div>
    </div>
</div>
<?php if (isset($mks_d['id'])) {
    $mks_sims = mks_st_decode($mks_d['sims']); ?>
<div class="form-group">
    <label class="control-label" for="mks-st-f-sim"><?= e(_l('mks_st_sim_tracked')); ?></label>
    <select id="mks-st-f-sim" class="form-control" data-field="track_sim">
        <option value="0"><?= e(_l('mks_st_all_sims')); ?></option>
        <?php for ($mks_slot = 1; $mks_slot <= 2; $mks_slot++) {
            $mks_label = _l('mks_st_sim_n', (string) $mks_slot);

            foreach ($mks_sims as $mks_sim) {
                if ((int) $mks_sim['slot'] === $mks_slot && $mks_sim['label'] !== '') {
                    $mks_label .= ' (' . $mks_sim['label'] . ')';
                }
            } ?>
        <option value="<?= $mks_slot; ?>"<?= (int) $mks_d['track_sim'] === $mks_slot ? ' selected' : ''; ?>><?= e($mks_label); ?></option>
        <?php } ?>
    </select>
    <p class="mks-sales-track-hint"><?= e(_l('mks_st_sim_hint')); ?></p>
</div>
<?php } ?>
