<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - one activity list.
 *
 * Calls, Recordings, WhatsApp Calls and SMS share this view and
 * differ only in their column set and filters. Everything inside #wrapper >
 * .content, including the floating player: content after that container stays
 * in the DOM but never renders.
 */

init_head();

$mks_headings = [];

foreach ($columns as $mks_column) {
    $mks_headings[] = [
        'name'     => $mks_column['label'],
        'th_attrs' => ['class' => 'mks-sales-track-th-' . $mks_column['key']],
    ];
}

$mks_tile_count = $view === 'recordings' ? 4 : 5;
?>
<div id="wrapper">
    <div class="content">
        <div class="mks-sales-track mks-sales-track-list" data-view="<?= e($view); ?>">

            <?php $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/partials/nav', ['nav' => $nav]); ?>

            <div class="mks-sales-track-head">
                <div class="mks-sales-track-head-main">
                    <span class="mks-sales-track-head-icon mks-sales-track-head-icon-<?= e(str_replace('_', '-', $view)); ?>">
                        <i class="<?= e($page['icon']); ?>" aria-hidden="true"></i>
                    </span>
                    <div>
                        <h4 class="mks-sales-track-title"><?= e(_l($page['label'])); ?></h4>
                        <p class="mks-sales-track-sub"><?= e(_l($page['sub'])); ?></p>
                    </div>
                </div>
                <div class="mks-sales-track-head-actions">
                    <a href="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/devices'); ?>" class="btn btn-default mks-sales-track-btn">
                        <i class="fa-solid fa-mobile-screen-button" aria-hidden="true"></i><?= e(_l('mks_st_page_devices')); ?>
                    </a>
                </div>
            </div>

            <?php if ($demo) { ?>
            <div class="mks-sales-track-banner mks-sales-track-tone-violet">
                <i class="fa-solid fa-flask" aria-hidden="true"></i>
                <span><?= e(_l('mks_st_demo_banner')); ?></span>
            </div>
            <?php } ?>

            <?php if (!$tracking_on) { ?>
            <div class="mks-sales-track-banner mks-sales-track-tone-amber">
                <i class="fa-solid fa-circle-info" aria-hidden="true"></i>
                <span><?= e(_l('mks_st_tracking_off_banner')); ?></span>
            </div>
            <?php } ?>

            <div class="mks-sales-track-card mks-sales-track-filters">
                <div class="mks-sales-track-filters-row">
                    <div class="mks-sales-track-segment" id="mks-sales-track-range" role="group" aria-label="<?= e(_l('mks_st_filter_range')); ?>">
                        <?php foreach ($ranges as $mks_value => $mks_label) { ?>
                        <button type="button" class="mks-sales-track-segment-btn<?= $mks_value === '7d' ? ' is-active' : ''; ?>"
                            data-value="<?= e($mks_value); ?>"><?= e($mks_label); ?></button>
                        <?php } ?>
                    </div>
                    <div class="mks-sales-track-dates mks-sales-track-is-hidden" id="mks-sales-track-dates">
                        <input type="date" class="form-control" id="mks-st-from" value="<?= date('Y-m-d', strtotime('-6 days')); ?>"
                            aria-label="<?= e(_l('mks_st_from')); ?>">
                        <span class="mks-sales-track-dates-sep"><?= e(_l('mks_st_to')); ?></span>
                        <input type="date" class="form-control" id="mks-st-to" value="<?= date('Y-m-d'); ?>"
                            aria-label="<?= e(_l('mks_st_to')); ?>">
                    </div>
                </div>

                <div class="mks-sales-track-filters-row mks-sales-track-selects">
                    <?php if (count($staff) > 0) { ?>
                    <label class="mks-sales-track-select">
                        <i class="fa-solid fa-user" aria-hidden="true"></i>
                        <select id="mks-st-staff" aria-label="<?= e(_l('mks_st_col_staff')); ?>">
                            <option value=""><?= e(_l('mks_st_all_staff')); ?></option>
                            <?php foreach ($staff as $mks_id => $mks_name) { ?>
                            <option value="<?= (int) $mks_id; ?>"><?= e($mks_name); ?></option>
                            <?php } ?>
                        </select>
                    </label>
                    <?php } ?>

                    <?php if (count($directions) > 0) { ?>
                    <label class="mks-sales-track-select">
                        <i class="fa-solid fa-arrows-rotate" aria-hidden="true"></i>
                        <select id="mks-st-direction" aria-label="<?= e(_l('mks_st_col_direction')); ?>">
                            <option value=""><?= e(_l('mks_st_all_directions')); ?></option>
                            <?php foreach ($directions as $mks_value => $mks_label) { ?>
                            <option value="<?= e($mks_value); ?>"><?= e($mks_label); ?></option>
                            <?php } ?>
                        </select>
                    </label>
                    <?php } ?>

                    <label class="mks-sales-track-select">
                        <i class="fa-solid fa-address-book" aria-hidden="true"></i>
                        <select id="mks-st-match" aria-label="<?= e(_l('mks_st_col_contact')); ?>">
                            <option value=""><?= e(_l('mks_st_match_all')); ?></option>
                            <option value="lead"><?= e(_l('mks_st_match_leads')); ?></option>
                            <option value="customer"><?= e(_l('mks_st_match_customers')); ?></option>
                            <option value="staff"><?= e(_l('mks_st_match_staff')); ?></option>
                            <option value="unknown"><?= e(_l('mks_st_match_unknown')); ?></option>
                        </select>
                    </label>

                    <?php if (count($phones) > 1) { ?>
                    <label class="mks-sales-track-select">
                        <i class="fa-solid fa-mobile-screen-button" aria-hidden="true"></i>
                        <select id="mks-st-device" aria-label="<?= e(_l('mks_st_col_phone')); ?>">
                            <option value=""><?= e(_l('mks_st_all_phones')); ?></option>
                            <?php foreach ($phones as $mks_id => $mks_label) { ?>
                            <option value="<?= (int) $mks_id; ?>"><?= e($mks_label); ?></option>
                            <?php } ?>
                        </select>
                    </label>
                    <?php } ?>

                    <?php if (in_array($view, ['calls', 'whatsapp_calls'], true)) { ?>
                    <label class="mks-sales-track-select">
                        <i class="fa-solid fa-list-check" aria-hidden="true"></i>
                        <select id="mks-st-outcome" aria-label="<?= e(_l('mks_st_col_outcome')); ?>">
                            <option value=""><?= e(_l('mks_st_all_outcomes')); ?></option>
                            <option value="none"><?= e(_l('mks_st_no_outcome')); ?></option>
                            <?php foreach ($outcomes as $mks_key => $mks_outcome) { ?>
                            <option value="<?= e($mks_key); ?>"><?= e($mks_outcome['label']); ?></option>
                            <?php } ?>
                        </select>
                    </label>
                    <?php } ?>

                    <button type="button" class="mks-sales-track-link-btn mks-sales-track-reset" id="mks-sales-track-reset">
                        <i class="fa-solid fa-rotate-left" aria-hidden="true"></i><?= e(_l('mks_st_reset_filters')); ?>
                    </button>
                </div>

                <input type="hidden" id="mks-st-range" value="7d">
            </div>

            <div class="mks-sales-track-kpis" id="mks-sales-track-kpis" aria-live="polite">
                <?php for ($mks_i = 0; $mks_i < $mks_tile_count; $mks_i++) { ?>
                <div class="mks-sales-track-kpi is-loading"><span class="mks-sales-track-skeleton"></span></div>
                <?php } ?>
            </div>

            <div class="mks-sales-track-card mks-sales-track-table-card">
                <?php render_datatable($mks_headings, 'mks-sales-track-events', ['mks-sales-track-table']); ?>
            </div>

            <?php if (in_array($view, ['calls', 'whatsapp_calls'], true)) {
                $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/partials/outcome_modal');
            } ?>

            <?php if (in_array($view, ['calls', 'recordings'], true)) {
                $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/partials/pitch_modal');
            } ?>

            <?php if (mks_st_enabled('ai_enabled') && in_array($view, ['calls', 'recordings'], true)) { ?>
            <div class="modal fade mks-sales-track-modal" id="mks-sales-track-ai-modal" tabindex="-1" role="dialog" aria-labelledby="mks-sales-track-ai-title">
                <div class="modal-dialog modal-lg" role="document">
                    <div class="modal-content">
                        <div class="modal-header">
                            <button type="button" class="close" data-dismiss="modal" aria-label="<?= e(_l('mks_st_close')); ?>"><span aria-hidden="true">&times;</span></button>
                            <h4 class="modal-title" id="mks-sales-track-ai-title"><i class="fa-solid fa-wand-magic-sparkles" aria-hidden="true"></i> <?= e(_l('mks_st_ai_insights')); ?></h4>
                        </div>
                        <div class="modal-body" id="mks-sales-track-ai-body"></div>
                    </div>
                </div>
            </div>
            <?php } ?>

            <div class="mks-sales-track-player" id="mks-sales-track-player" aria-hidden="true">
                <button type="button" class="mks-sales-track-player-main" id="mks-sales-track-player-toggle"
                    aria-label="<?= e(_l('mks_st_play')); ?>">
                    <i class="fa-solid fa-play" aria-hidden="true"></i>
                </button>
                <div class="mks-sales-track-player-body">
                    <div class="mks-sales-track-player-meta">
                        <span class="mks-sales-track-player-title" id="mks-sales-track-player-title"></span>
                        <span class="mks-sales-track-player-sub" id="mks-sales-track-player-sub"></span>
                    </div>
                    <div class="mks-sales-track-player-track">
                        <span class="mks-sales-track-player-time" id="mks-sales-track-player-current">0:00</span>
                        <input type="range" class="mks-sales-track-player-seek" id="mks-sales-track-player-seek"
                            min="0" max="1000" step="1" value="0" aria-label="<?= e(_l('mks_st_seek')); ?>">
                        <span class="mks-sales-track-player-time" id="mks-sales-track-player-total">0:00</span>
                    </div>
                </div>
                <button type="button" class="mks-sales-track-player-pill" id="mks-sales-track-player-speed"
                    title="<?= e(_l('mks_st_speed')); ?>">1x</button>
                <a class="mks-sales-track-player-icon" id="mks-sales-track-player-download" href="#"
                    title="<?= e(_l('mks_st_download')); ?>" aria-label="<?= e(_l('mks_st_download')); ?>">
                    <i class="fa-solid fa-download" aria-hidden="true"></i>
                </a>
                <button type="button" class="mks-sales-track-player-icon" id="mks-sales-track-player-close"
                    aria-label="<?= e(_l('mks_st_close')); ?>">
                    <i class="fa-solid fa-xmark" aria-hidden="true"></i>
                </button>
                <audio id="mks-sales-track-audio" preload="none"></audio>
            </div>

        </div>
    </div>
</div>
<?php init_tail(); ?>
</body>

</html>
