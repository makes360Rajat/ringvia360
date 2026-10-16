<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - Settings, drawn entirely from config/settings_schema.php.
 *
 * One form; sections switch on the left without a reload and the active one
 * is posted back so the page reopens where you were. Every switch posts a
 * hidden 0 BEFORE its checkbox: an unticked box posts nothing, and PHP keeps
 * the last value sent under a name.
 *
 * PIN fields are write only: the stored hash is never printed.
 */

init_head();

$mks_disabled = $can_edit ? '' : ' disabled';

if (!function_exists('mks_st_settings_field')) {
    /**
     * @param  string $key
     * @param  array  $field
     * @param  array  $values
     * @param  string $disabled
     *
     * @return void
     */
    function mks_st_settings_field($key, array $field, array $values, $disabled)
    {
        $id   = 'mks_st_' . $key;
        $name = 'mks_st[' . $key . ']';
        $hint = isset($field['hint']) ? _l($field['hint']) : '';

        if ($key === 'recording_max_mb') {
            $hint = _l($field['hint'], (string) mks_st_recording_limit_mb());
        }

        $stack = in_array($field['type'], ['textarea', 'choice', 'staff_targets', 'outcomes', 'secret_json'], true);
        ?>
        <div class="mks-sales-track-setting<?= $stack ? ' mks-sales-track-setting-stack' : ''; ?><?= !empty($field['danger']) ? ' mks-sales-track-setting-danger' : ''; ?>">
            <div class="mks-sales-track-setting-text">
                <label for="<?= e($id); ?>" class="mks-sales-track-setting-label"><?= e(_l($field['label'])); ?></label>
                <?php if ($hint !== '') { ?>
                <p class="mks-sales-track-hint"><?= e($hint); ?></p>
                <?php } ?>
            </div>
            <?php switch ($field['type']) {
                case 'switch': ?>
            <label class="mks-sales-track-switch">
                <input type="hidden" name="<?= e($name); ?>" value="0">
                <input type="checkbox" id="<?= e($id); ?>" name="<?= e($name); ?>" value="1"<?= !empty($values[$key]) ? ' checked' : ''; ?><?= $disabled; ?>>
                <span class="mks-sales-track-switch-ui" aria-hidden="true"></span>
            </label>
            <?php break;

                case 'number': ?>
            <div class="mks-sales-track-input-unit">
                <input type="number" id="<?= e($id); ?>" name="<?= e($name); ?>" class="form-control" min="<?= (int) $field['min']; ?>"
                    max="<?= (int) $field['max']; ?>" value="<?= (int) $values[$key]; ?>"<?= $disabled; ?>>
                <span><?= e(_l($field['unit'])); ?></span>
            </div>
            <?php break;

                case 'text': ?>
            <div class="mks-sales-track-input-unit<?= isset($field['prefix']) ? ' mks-sales-track-input-prefix' : ' mks-sales-track-input-wide'; ?>">
                <?php if (isset($field['prefix'])) { ?><span><?= e($field['prefix']); ?></span><?php } ?>
                <input type="text" id="<?= e($id); ?>" name="<?= e($name); ?>" class="form-control" value="<?= e((string) $values[$key]); ?>"
                    maxlength="<?= (int) (isset($field['max_length']) ? $field['max_length'] : 255); ?>"
                    placeholder="<?= e(isset($field['placeholder']) ? $field['placeholder'] : ''); ?>"<?= $disabled; ?>>
            </div>
            <?php break;

                case 'textarea': ?>
            <textarea id="<?= e($id); ?>" name="<?= e($name); ?>" class="form-control mks-sales-track-mono" rows="5" spellcheck="false"
                placeholder="<?= e(isset($field['placeholder']) ? $field['placeholder'] : ''); ?>"<?= $disabled; ?>><?= e((string) $values[$key]); ?></textarea>
            <?php break;

                case 'choice': ?>
            <div class="mks-sales-track-choices" role="radiogroup">
                <?php foreach ($field['options'] as $mks_value => $mks_label) { ?>
                <label class="mks-sales-track-choice">
                    <input type="radio" name="<?= e($name); ?>" value="<?= e($mks_value); ?>"<?= (string) $values[$key] === (string) $mks_value ? ' checked' : ''; ?><?= $disabled; ?>>
                    <span class="mks-sales-track-choice-ui">
                        <strong><?= e(_l($mks_label)); ?></strong>
                        <small><?= e(_l($mks_label . '_hint')); ?></small>
                    </span>
                </label>
                <?php } ?>
            </div>
            <?php break;

                case 'days':
                    $mks_selected = array_map('intval', (array) $values[$key]); ?>
            <div class="mks-sales-track-days" role="group">
                <input type="hidden" name="<?= e($name); ?>[]" value="">
                <?php foreach ([1 => 'mks_st_day_mon', 2 => 'mks_st_day_tue', 3 => 'mks_st_day_wed', 4 => 'mks_st_day_thu', 5 => 'mks_st_day_fri', 6 => 'mks_st_day_sat', 7 => 'mks_st_day_sun'] as $mks_day => $mks_label) { ?>
                <label class="mks-sales-track-day">
                    <input type="checkbox" name="<?= e($name); ?>[]" value="<?= $mks_day; ?>"<?= in_array($mks_day, $mks_selected, true) ? ' checked' : ''; ?><?= $disabled; ?>>
                    <span><?= e(_l($mks_label)); ?></span>
                </label>
                <?php } ?>
            </div>
            <?php break;

                case 'staff_targets':
                    $mks_overrides = (array) $values[$key]; ?>
            <div class="table-responsive">
                <table class="mks-sales-track-mini-table mks-sales-track-targets-table">
                    <thead>
                        <tr>
                            <th><?= e(_l('mks_st_col_staff')); ?></th>
                            <th><?= e(_l('mks_st_kpi_calls')); ?></th>
                            <th><?= e(_l('mks_st_kpi_connected')); ?></th>
                            <th><?= e(_l('mks_st_target_talk_short')); ?></th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach (mks_st_staff_options() as $mks_staff_id => $mks_staff_name) {
                            $mks_own = isset($mks_overrides[(string) $mks_staff_id]) ? (array) $mks_overrides[(string) $mks_staff_id] : []; ?>
                        <tr>
                            <td><?= e($mks_staff_name); ?></td>
                            <?php foreach (['calls' => 'target_calls', 'connected' => 'target_connected', 'talk' => 'target_talk_minutes'] as $mks_metric => $mks_default_key) { ?>
                            <td>
                                <input type="number" class="form-control input-sm" min="0" max="<?= $mks_metric === 'talk' ? 600 : 500; ?>"
                                    name="<?= e($name); ?>[<?= (int) $mks_staff_id; ?>][<?= $mks_metric; ?>]"
                                    value="<?= isset($mks_own[$mks_metric]) ? (int) $mks_own[$mks_metric] : ''; ?>"
                                    placeholder="<?= (int) $values[$mks_default_key]; ?>"<?= $disabled; ?>>
                            </td>
                            <?php } ?>
                        </tr>
                        <?php } ?>
                    </tbody>
                </table>
            </div>
            <?php break;

                case 'outcomes':
                    $mks_rows = array_merge((array) $values[$key], [[], []]);
                    $mks_statuses = mks_st_lead_statuses(); ?>
            <div class="table-responsive">
                <table class="mks-sales-track-mini-table mks-sales-track-outcomes-table">
                    <thead>
                        <tr>
                            <th><?= e(_l('mks_st_outcome_label')); ?></th>
                            <th><?= e(_l('mks_st_outcome_tone')); ?></th>
                            <th><?= e(_l('mks_st_outcome_follow')); ?></th>
                            <th><?= e(_l('mks_st_outcome_status')); ?></th>
                            <th><?= e(_l('mks_st_outcome_active')); ?></th>
                            <th><?= e(_l('mks_st_outcome_remove')); ?></th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($mks_rows as $mks_i => $mks_row) {
                            $mks_base  = $name . '[' . $mks_i . ']';
                            $mks_fixed = isset($mks_row['key']) && $mks_row['key'] === 'converted'; ?>
                        <tr<?= isset($mks_row['key']) ? '' : ' class="mks-sales-track-new-row"'; ?>>
                            <td>
                                <input type="hidden" name="<?= e($mks_base); ?>[key]" value="<?= e(isset($mks_row['key']) ? $mks_row['key'] : ''); ?>">
                                <input type="text" class="form-control input-sm" name="<?= e($mks_base); ?>[label]" maxlength="40"
                                    value="<?= e(isset($mks_row['label']) ? $mks_row['label'] : ''); ?>"
                                    placeholder="<?= e(_l(isset($mks_row['key']) ? 'mks_st_outcome_label' : 'mks_st_outcome_new')); ?>"<?= $disabled; ?>>
                            </td>
                            <td>
                                <select class="form-control input-sm" name="<?= e($mks_base); ?>[tone]"<?= $disabled; ?>>
                                    <?php foreach (['blue', 'green', 'amber', 'red', 'violet', 'slate'] as $mks_tone) { ?>
                                    <option value="<?= $mks_tone; ?>"<?= isset($mks_row['tone']) && $mks_row['tone'] === $mks_tone ? ' selected' : ''; ?>><?= e(_l('mks_st_tone_' . $mks_tone)); ?></option>
                                    <?php } ?>
                                </select>
                            </td>
                            <td class="text-center">
                                <input type="hidden" name="<?= e($mks_base); ?>[follow_up]" value="0">
                                <input type="checkbox" name="<?= e($mks_base); ?>[follow_up]" value="1"<?= !empty($mks_row['follow_up']) ? ' checked' : ''; ?><?= $disabled; ?>>
                            </td>
                            <td>
                                <select class="form-control input-sm" name="<?= e($mks_base); ?>[lead_status]"<?= $disabled; ?>>
                                    <option value="0"><?= e(_l('mks_st_status_unchanged')); ?></option>
                                    <?php foreach ($mks_statuses as $mks_id => $mks_status) { ?>
                                    <option value="<?= (int) $mks_id; ?>"<?= isset($mks_row['lead_status']) && (int) $mks_row['lead_status'] === (int) $mks_id ? ' selected' : ''; ?>><?= e($mks_status['name']); ?></option>
                                    <?php } ?>
                                </select>
                            </td>
                            <td class="text-center">
                                <?php if ($mks_fixed) { ?>
                                <input type="hidden" name="<?= e($mks_base); ?>[active]" value="1"><i class="fa-solid fa-lock mks-sales-track-muted" title="<?= e(_l('mks_st_outcome_fixed')); ?>"></i>
                                <?php } else { ?>
                                <input type="hidden" name="<?= e($mks_base); ?>[active]" value="0">
                                <input type="checkbox" name="<?= e($mks_base); ?>[active]" value="1"<?= !isset($mks_row['key']) || !empty($mks_row['active']) ? ' checked' : ''; ?><?= $disabled; ?>>
                                <?php } ?>
                            </td>
                            <td class="text-center">
                                <?php if ($mks_fixed) { ?>
                                <i class="fa-solid fa-lock mks-sales-track-muted" title="<?= e(_l('mks_st_outcome_fixed')); ?>"></i>
                                <?php } elseif (isset($mks_row['key'])) { ?>
                                <input type="checkbox" name="<?= e($mks_base); ?>[remove]" value="1"<?= $disabled; ?>>
                                <?php } ?>
                            </td>
                        </tr>
                        <?php } ?>
                    </tbody>
                </table>
            </div>
            <?php break;

                case 'lead_status':
                case 'lead_source':
                case 'staff':
                    $mks_options = $field['type'] === 'lead_status'
                        ? array_map(function ($row) {
                            return $row['name'];
                        }, mks_st_lead_statuses())
                        : ($field['type'] === 'lead_source' ? mks_st_lead_sources() : mks_st_staff_options()); ?>
            <select id="<?= e($id); ?>" name="<?= e($name); ?>" class="form-control mks-sales-track-select-wide"<?= $disabled; ?>>
                <option value="0"><?= e(_l($field['type'] === 'staff' ? 'mks_st_nobody' : 'mks_st_perfex_default')); ?></option>
                <?php foreach ($mks_options as $mks_id => $mks_label) { ?>
                <option value="<?= (int) $mks_id; ?>"<?= (int) $values[$key] === (int) $mks_id ? ' selected' : ''; ?>><?= e($mks_label); ?></option>
                <?php } ?>
            </select>
            <?php break;

                case 'time': ?>
            <input type="time" id="<?= e($id); ?>" name="<?= e($name); ?>" class="form-control mks-sales-track-time" value="<?= e((string) $values[$key]); ?>"<?= $disabled; ?>>
            <?php break;

                case 'secret':
                    $mks_saved = (string) get_option($field['option']) !== ''; ?>
            <div class="mks-sales-track-pin">
                <input type="password" id="<?= e($id); ?>" name="<?= e($name); ?>" class="form-control mks-sales-track-input-secret" autocomplete="new-password"
                    placeholder="<?= e(_l($mks_saved ? 'mks_st_pin_keep' : 'mks_st_secret_new')); ?>"<?= $disabled; ?>>
                <span class="mks-sales-track-pill mks-sales-track-tone-<?= $mks_saved ? 'green' : 'slate'; ?>"><?= e(_l($mks_saved ? 'mks_st_secret_saved' : 'mks_st_secret_not_saved')); ?></span>
                <?php if ($mks_saved) { ?>
                <label class="mks-sales-track-pin-clear"><input type="checkbox" name="mks_st[<?= e($key); ?>_clear]" value="1"<?= $disabled; ?>> <?= e(_l('mks_st_secret_remove')); ?></label>
                <?php } ?>
            </div>
            <?php break;

                case 'secret_json':
                    $mks_fcm = function_exists('mks_st_fcm_status') ? mks_st_fcm_status() : ['configured' => false]; ?>
            <div class="mks-sales-track-secret">
                <?php if ($mks_fcm['configured']) { ?>
                <p class="mks-sales-track-secret-status">
                    <span class="mks-sales-track-pill mks-sales-track-tone-green"><?= e(_l('mks_st_fcm_saved')); ?></span>
                    <span><?= e($mks_fcm['project_id']); ?></span>
                    <small class="mks-sales-track-muted"><?= e($mks_fcm['client_email']); ?></small>
                </p>
                <?php } ?>
                <textarea id="<?= e($id); ?>" name="<?= e($name); ?>" class="form-control mks-sales-track-mono" rows="4" spellcheck="false" autocomplete="off"
                    placeholder="<?= e(_l($mks_fcm['configured'] ? 'mks_st_fcm_replace' : 'mks_st_fcm_paste')); ?>"<?= $disabled; ?>></textarea>
                <?php if ($mks_fcm['configured']) { ?>
                <label class="mks-sales-track-pin-clear">
                    <input type="checkbox" name="mks_st[<?= e($key); ?>_clear]" value="1"<?= $disabled; ?>> <?= e(_l('mks_st_fcm_remove')); ?>
                </label>
                <?php } ?>
            </div>
            <?php break;

                case 'pin':
                    $mks_is_set = $values[$field['store'][0]] !== ''; ?>
            <div class="mks-sales-track-pin">
                <input type="password" id="<?= e($id); ?>" name="<?= e($name); ?>" class="form-control" inputmode="numeric" autocomplete="new-password"
                    pattern="\d{4,8}" maxlength="8" placeholder="<?= e(_l($mks_is_set ? 'mks_st_pin_keep' : 'mks_st_pin_new')); ?>"<?= $disabled; ?>>
                <span class="mks-sales-track-pill mks-sales-track-tone-<?= $mks_is_set ? 'green' : 'slate'; ?>">
                    <?= e(_l($mks_is_set ? 'mks_st_pin_is_set' : 'mks_st_pin_not_set')); ?>
                </span>
                <?php if ($mks_is_set) { ?>
                <label class="mks-sales-track-pin-clear">
                    <input type="checkbox" name="mks_st[<?= e($key); ?>_clear]" value="1"<?= $disabled; ?>> <?= e(_l('mks_st_pin_remove')); ?>
                </label>
                <?php } ?>
            </div>
            <?php break;
            } ?>
        </div>
        <?php
    }
}
?>
<div id="wrapper">
    <div class="content">
        <div class="mks-sales-track mks-sales-track-settings-page">

            <?php $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/partials/nav', ['nav' => $nav]); ?>

            <div class="mks-sales-track-head">
                <div class="mks-sales-track-head-main">
                    <span class="mks-sales-track-head-icon"><i class="fa-solid fa-sliders" aria-hidden="true"></i></span>
                    <div>
                        <h4 class="mks-sales-track-title"><?= e(_l('mks_st_page_settings')); ?></h4>
                        <p class="mks-sales-track-sub"><?= e(_l('mks_st_settings_intro')); ?></p>
                    </div>
                </div>
                <?php if ($saved_at !== '' && ctype_digit($saved_at)) { ?>
                <span class="mks-sales-track-muted mks-sales-track-saved"><?= e(_l('mks_st_last_saved', _dt(date('Y-m-d H:i:s', (int) $saved_at)))); ?></span>
                <?php } ?>
            </div>

            <?php if (!$can_edit) { ?>
            <div class="mks-sales-track-banner mks-sales-track-tone-amber">
                <i class="fa-solid fa-lock" aria-hidden="true"></i><span><?= e(_l('mks_st_settings_read_only')); ?></span>
            </div>
            <?php } ?>

            <?= form_open(admin_url(MKS_SALES_TRACK_MODULE_NAME . '/settings'), ['id' => 'mks-sales-track-settings-form']); ?>
            <input type="hidden" name="mks_st_section" id="mks-sales-track-section" value="<?= e($section); ?>">

            <div class="mks-sales-track-settings-layout">
                <aside class="mks-sales-track-settings-menu" role="tablist" aria-orientation="vertical">
                    <?php foreach ($schema['sections'] as $mks_key => $mks_section) { ?>
                    <button type="button" role="tab" class="mks-sales-track-settings-menu-item<?= $mks_key === $section ? ' is-active' : ''; ?>"
                        data-section="<?= e($mks_key); ?>" aria-selected="<?= $mks_key === $section ? 'true' : 'false'; ?>">
                        <i class="<?= e($mks_section['icon']); ?>" aria-hidden="true"></i><span><?= e(_l($mks_section['label'])); ?></span>
                    </button>
                    <?php } ?>
                </aside>

                <div class="mks-sales-track-card mks-sales-track-settings-body">
                    <?php foreach ($schema['sections'] as $mks_key => $mks_section) { ?>
                    <section class="mks-sales-track-settings-panel<?= $mks_key === $section ? '' : ' mks-sales-track-is-hidden'; ?>"
                        data-section="<?= e($mks_key); ?>" role="tabpanel">
                        <h5 class="mks-sales-track-panel-title"><?= e(_l($mks_section['label'])); ?></h5>
                        <p class="mks-sales-track-panel-intro"><?= e(_l($mks_section['intro'])); ?></p>

                        <?php foreach ($schema['fields'] as $mks_field_key => $mks_field) {
                            if ($mks_field['section'] === $mks_key && $mks_field['type'] !== 'internal') {
                                mks_st_settings_field($mks_field_key, $mks_field, $values, $mks_disabled);
                            }
                        } ?>

                        <?php if ($mks_key === 'devices') { ?>
                        <div class="mks-sales-track-setting mks-sales-track-setting-stack">
                            <div class="mks-sales-track-setting-text">
                                <span class="mks-sales-track-setting-label"><?= e(_l('mks_st_api_address')); ?></span>
                                <p class="mks-sales-track-hint"><?= e(_l('mks_st_api_address_hint')); ?></p>
                            </div>
                            <div class="mks-sales-track-address">
                                <code id="mks-sales-track-api-url"><?= e(site_url(MKS_SALES_TRACK_API_PATH)); ?></code>
                                <button type="button" class="mks-sales-track-icon-btn mks-sales-track-copy" data-copy="#mks-sales-track-api-url"
                                    title="<?= e(_l('mks_st_copy')); ?>" aria-label="<?= e(_l('mks_st_copy')); ?>">
                                    <i class="fa-solid fa-copy" aria-hidden="true"></i>
                                </button>
                            </div>
                        </div>
                        <div class="mks-sales-track-info">
                            <i class="fa-solid fa-circle-info" aria-hidden="true"></i>
                            <div><p><?= e(_l('mks_st_app_lock_note')); ?></p></div>
                        </div>
                        <?php } ?>

                        <?php if ($mks_key === 'wallboard') { ?>
                        <div class="mks-sales-track-info">
                            <i class="fa-solid fa-tv" aria-hidden="true"></i>
                            <div>
                                <p><a href="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/wallboard'); ?>" target="_blank" rel="noopener" class="btn btn-default btn-sm"><i class="fa-solid fa-tv" aria-hidden="true"></i> <?= e(_l('mks_st_wallboard_open')); ?></a></p>
                                <?php if (mks_st_enabled('wallboard_public') && (string) mks_st_setting('wallboard_key', '') !== '') { ?>
                                <p class="mks-sales-track-address">
                                    <span class="mks-sales-track-address-label"><?= e(_l('mks_st_wallboard_link')); ?></span>
                                    <code id="mks-sales-track-wall-link"><?= e(site_url(MKS_SALES_TRACK_MODULE_NAME . '/wallboard/' . mks_st_setting('wallboard_key', ''))); ?></code>
                                    <button type="button" class="mks-sales-track-icon-btn mks-sales-track-copy" data-copy="#mks-sales-track-wall-link" title="<?= e(_l('mks_st_copy')); ?>" aria-label="<?= e(_l('mks_st_copy')); ?>"><i class="fa-solid fa-copy" aria-hidden="true"></i></button>
                                </p>
                                <label class="mks-sales-track-pin-clear"><input type="checkbox" name="mks_st[wallboard_new_link]" value="1"<?= $disabled ?? ''; ?>> <?= e(_l('mks_st_wallboard_new_link')); ?></label>
                                <?php } else { ?>
                                <p class="mks-sales-track-muted"><?= e(_l('mks_st_wallboard_link_off')); ?></p>
                                <?php } ?>
                            </div>
                        </div>
                        <?php } ?>

                        <?php if ($mks_key === 'ai') { ?>
                        <div class="mks-sales-track-info">
                            <i class="fa-solid fa-wand-magic-sparkles" aria-hidden="true"></i>
                            <div>
                                <p><?= e(_l('mks_st_ai_spend_line', ['$' . number_format($ai_spent, 2), '$' . (int) mks_st_setting('ai_budget', 0), mks_st_number_label($ai_count)])); ?></p>
                                <p><?= e(_l('mks_st_ai_privacy_note')); ?></p>
                                <p><button type="button" class="btn btn-default btn-sm mks-sales-track-ai-test" data-url="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/ai_test'); ?>"><i class="fa-solid fa-plug" aria-hidden="true"></i> <?= e(_l('mks_st_ai_test_key')); ?></button>
                                    <button type="button" class="btn btn-default btn-sm mks-sales-track-ai-models" data-url="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/ai_models'); ?>"><i class="fa-solid fa-list" aria-hidden="true"></i> <?= e(_l('mks_st_ai_load_models')); ?></button></p>
                                <datalist id="mks-sales-track-models"></datalist>
                            </div>
                        </div>
                        <?php } ?>

                        <?php if ($mks_key === 'storage') { ?>
                        <div class="mks-sales-track-info mks-sales-track-drive-panel">
                            <i class="fa-brands fa-google-drive" aria-hidden="true"></i>
                            <div>
                                <strong><?= e(_l('mks_st_drive_title')); ?></strong>
                                <?php if ($drive['connected']) { ?>
                                <p><span class="mks-sales-track-pill mks-sales-track-tone-green"><?= e(_l('mks_st_drive_is_connected')); ?></span>
                                    <?= e($drive['account']); ?> <small class="mks-sales-track-muted"><?= e(_l('mks_st_since', _dt($drive['since']))); ?></small></p>
                                <?php } else { ?>
                                <p><?= e(_l('mks_st_drive_steps')); ?></p>
                                <?php } ?>
                                <p class="mks-sales-track-address">
                                    <span class="mks-sales-track-address-label"><?= e(_l('mks_st_drive_redirect')); ?></span>
                                    <code id="mks-sales-track-drive-redirect"><?= e(admin_url(MKS_SALES_TRACK_MODULE_NAME . '/drive_callback')); ?></code>
                                    <button type="button" class="mks-sales-track-icon-btn mks-sales-track-copy" data-copy="#mks-sales-track-drive-redirect" title="<?= e(_l('mks_st_copy')); ?>" aria-label="<?= e(_l('mks_st_copy')); ?>"><i class="fa-solid fa-copy" aria-hidden="true"></i></button>
                                </p>
                                <p>
                                    <?php if ($drive['connected']) { ?>
                                    <button type="button" class="btn btn-default btn-sm mks-sales-track-drive-disconnect" data-url="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/drive_disconnect'); ?>"><i class="fa-solid fa-link-slash" aria-hidden="true"></i> <?= e(_l('mks_st_drive_disconnect')); ?></button>
                                    <?php } elseif ($drive['client']) { ?>
                                    <a href="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/drive_connect'); ?>" class="btn btn-primary btn-sm"><i class="fa-solid fa-plug" aria-hidden="true"></i> <?= e(_l('mks_st_drive_connect')); ?></a>
                                    <?php } else { ?>
                                    <span class="mks-sales-track-muted"><?= e(_l('mks_st_drive_client_first')); ?></span>
                                    <?php } ?>
                                </p>
                                <p class="mks-sales-track-muted"><?= e(_l('mks_st_storage_counts', [mks_st_number_label($storage['server']), mks_st_number_label($storage['drive']), mks_st_number_label($storage['waiting']), mks_st_number_label($storage['expired'])])); ?>
                                <?php if (!empty($drive['status']['error'])) { ?><br><span class="mks-sales-track-danger"><?= e(_l('mks_st_drive_last_error', $drive['status']['error'])); ?></span><?php } ?></p>
                            </div>
                        </div>
                        <?php } ?>

                        <?php if ($mks_key === 'reports') { ?>
                        <div class="mks-sales-track-info">
                            <i class="fa-solid fa-envelope" aria-hidden="true"></i>
                            <div>
                                <p><?= e(_l('mks_st_reports_mail_note')); ?></p>
                                <p>
                                    <a href="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/report_preview?kind=daily'); ?>" target="_blank" rel="noopener" class="btn btn-default btn-sm"><i class="fa-solid fa-eye" aria-hidden="true"></i> <?= e(_l('mks_st_report_preview')); ?></a>
                                    <button type="button" class="btn btn-default btn-sm mks-sales-track-report-test" data-url="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/report_test'); ?>"><i class="fa-solid fa-paper-plane" aria-hidden="true"></i> <?= e(_l('mks_st_report_send_me')); ?></button>
                                </p>
                            </div>
                        </div>
                        <?php } ?>

                        <?php if ($mks_key === 'recordings') { ?>
                        <div class="mks-sales-track-info">
                            <i class="fa-solid fa-circle-info" aria-hidden="true"></i>
                            <div>
                                <strong><?= e(_l('mks_st_formats_title')); ?></strong>
                                <p><?= e(_l('mks_st_formats_text')); ?></p>
                                <p><?= e(_l('mks_st_storage_text')); ?></p>
                            </div>
                        </div>
                        <?php } ?>
                    </section>
                    <?php } ?>

                    <?php if ($can_edit) { ?>
                    <div class="mks-sales-track-settings-footer">
                        <button type="submit" class="btn btn-primary mks-sales-track-btn">
                            <i class="fa-solid fa-check" aria-hidden="true"></i><?= e(_l('mks_st_save_settings')); ?>
                        </button>
                    </div>
                    <?php } ?>
                </div>
            </div>
            <?= form_close(); ?>

        </div>
    </div>
</div>
<?php init_tail(); ?>
</body>

</html>
