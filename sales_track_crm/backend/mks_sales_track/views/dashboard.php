<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - Dashboard, the page the single sidebar item opens.
 *
 * Analytics over what the viewer may see: a rep sees themselves, a team lead
 * their department, a manager everybody. Filters are plain links and a GET
 * form, so every view of the dashboard has its own address.
 */

init_head();

$mks_query = function (array $change) use ($filters, $sort) {
    $params = array_filter(array_merge(['range' => $filters['range'], 'team' => $filters['team'], 'staff' => $filters['staff'], 'sort' => $sort], $change));

    return admin_url(MKS_SALES_TRACK_MODULE_NAME . ($params ? '?' . http_build_query($params) : ''));
};

$mks_state_meta = [
    'online'  => ['tone' => 'green', 'label' => 'mks_st_state_online'],
    'idle'    => ['tone' => 'amber', 'label' => 'mks_st_state_idle'],
    'offline' => ['tone' => 'red', 'label' => 'mks_st_state_offline'],
    'pending' => ['tone' => 'blue', 'label' => 'mks_st_state_pending'],
    'paused'  => ['tone' => 'slate', 'label' => 'mks_st_state_paused'],
];

$mks_period_label = $period['single_day'] ? _d($period['from']) : _d($period['from']) . ' - ' . _d($period['to']);

$mks_bar = function ($done, $target) {
    $share = $target > 0 ? min(100, (int) round($done * 100 / $target)) : 0;
    $tone  = $share >= 100 ? 'green' : ($share >= 70 ? 'blue' : 'amber');

    return '<span class="mks-sales-track-progress mks-sales-track-tone-' . $tone . '"><span style="width: ' . $share . '%"></span></span>';
};
?>
<div id="wrapper">
    <div class="content">
        <div class="mks-sales-track mks-sales-track-dashboard">

            <?php $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/partials/nav', ['nav' => $nav]); ?>

            <div class="mks-sales-track-head">
                <div class="mks-sales-track-head-main">
                    <span class="mks-sales-track-head-icon"><i class="fa-solid fa-gauge-high" aria-hidden="true"></i></span>
                    <div>
                        <h4 class="mks-sales-track-title"><?= e(_l($own ? 'mks_st_my_dashboard' : 'mks_st_page_dashboard')); ?></h4>
                        <p class="mks-sales-track-sub"><?= e($mks_period_label); ?> <span class="mks-sales-track-muted"><?= e(_l('mks_st_compared_with', _d($period['prev_from']) . ($period['single_day'] ? '' : ' - ' . _d($period['prev_to'])))); ?></span></p>
                    </div>
                </div>
                <div class="mks-sales-track-head-actions">
                    <?php if (mks_st_scope() !== false && !mks_st_scope_is_own()) { ?>
                    <a href="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/wallboard'); ?>" target="_blank" rel="noopener" class="btn btn-default mks-sales-track-btn"><i class="fa-solid fa-tv" aria-hidden="true"></i><?= e(_l('mks_st_wallboard')); ?></a>
                    <?php } ?>
                    <?php if (mks_st_can_settings()) { ?>
                    <a href="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/settings'); ?>" class="btn btn-default mks-sales-track-btn">
                        <i class="fa-solid fa-sliders" aria-hidden="true"></i><?= e(_l('mks_st_page_settings')); ?>
                    </a>
                    <?php } ?>
                </div>
            </div>

            <?php if ($demo) { ?>
            <div class="mks-sales-track-banner mks-sales-track-tone-violet">
                <i class="fa-solid fa-flask" aria-hidden="true"></i><span><?= e(_l('mks_st_demo_banner')); ?></span>
            </div>
            <?php } ?>

            <form method="get" action="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME); ?>" class="mks-sales-track-card mks-sales-track-filters mks-sales-track-dash-filters" id="mks-sales-track-dash-filters">
                <div class="mks-sales-track-filters-row">
                    <div class="mks-sales-track-segment" role="group" aria-label="<?= e(_l('mks_st_filter_range')); ?>">
                        <?php foreach ($ranges as $mks_value => $mks_label) { ?>
                        <a href="<?= e($mks_query(['range' => $mks_value])); ?>"
                            class="mks-sales-track-segment-btn<?= $filters['range'] === $mks_value ? ' is-active' : ''; ?>"><?= e(_l($mks_label)); ?></a>
                        <?php } ?>
                    </div>
                    <input type="hidden" name="range" value="<?= e($filters['range']); ?>">
                    <input type="hidden" name="sort" value="<?= e($sort); ?>">

                    <?php if ($teams) { ?>
                    <label class="mks-sales-track-select">
                        <i class="fa-solid fa-users" aria-hidden="true"></i>
                        <select name="team" class="mks-sales-track-autosubmit" aria-label="<?= e(_l('mks_st_team')); ?>">
                            <option value=""><?= e(_l('mks_st_all_teams')); ?></option>
                            <?php foreach ($teams as $mks_id => $mks_name) { ?>
                            <option value="<?= (int) $mks_id; ?>"<?= $filters['team'] === (int) $mks_id ? ' selected' : ''; ?>><?= e($mks_name); ?></option>
                            <?php } ?>
                        </select>
                    </label>
                    <?php } ?>

                    <?php if ($staff_options) { ?>
                    <label class="mks-sales-track-select">
                        <i class="fa-solid fa-user" aria-hidden="true"></i>
                        <select name="staff" class="mks-sales-track-autosubmit" aria-label="<?= e(_l('mks_st_col_staff')); ?>">
                            <option value=""><?= e(_l('mks_st_all_staff')); ?></option>
                            <?php foreach ($staff_options as $mks_id => $mks_name) { ?>
                            <option value="<?= (int) $mks_id; ?>"<?= $filters['staff'] === (int) $mks_id ? ' selected' : ''; ?>><?= e($mks_name); ?></option>
                            <?php } ?>
                        </select>
                    </label>
                    <?php } ?>
                </div>
            </form>

            <div class="mks-sales-track-kpis mks-sales-track-kpis-dash">
                <?php foreach ($tiles as $mks_tile) { ?>
                <div class="mks-sales-track-kpi mks-sales-track-tone-<?= e($mks_tile['tone']); ?>">
                    <span class="mks-sales-track-kpi-icon"><i class="<?= e($mks_tile['icon']); ?>" aria-hidden="true"></i></span>
                    <div class="mks-sales-track-kpi-body">
                        <span class="mks-sales-track-kpi-label"><?= e($mks_tile['label']); ?></span>
                        <span class="mks-sales-track-kpi-value"><?= e($mks_tile['value']); ?></span>
                        <span class="mks-sales-track-kpi-foot">
                            <?php if ($mks_tile['delta']) {
                                $mks_d = $mks_tile['delta']; ?>
                            <span class="mks-sales-track-delta <?= $mks_d['direction'] === 'flat' ? 'is-flat' : ($mks_d['good'] ? 'is-good' : 'is-bad'); ?>"
                                title="<?= e(_l('mks_st_vs_previous')); ?>">
                                <i class="fa-solid <?= $mks_d['direction'] === 'up' ? 'fa-arrow-up' : ($mks_d['direction'] === 'down' ? 'fa-arrow-down' : 'fa-minus'); ?>" aria-hidden="true"></i><?= e($mks_d['label']); ?>
                            </span>
                            <?php } ?>
                            <?php if ($mks_tile['hint'] !== '') { ?>
                            <span class="mks-sales-track-kpi-hint"><?= e($mks_tile['hint']); ?></span>
                            <?php } ?>
                        </span>
                    </div>
                </div>
                <?php } ?>
            </div>

            <div class="mks-sales-track-dash-grid">
                <div class="mks-sales-track-card">
                    <div class="mks-sales-track-card-head">
                        <h5><?= e(_l($period['single_day'] ? 'mks_st_trend_by_hour' : 'mks_st_trend_by_day')); ?></h5>
                        <span class="mks-sales-track-legend">
                            <span><i class="mks-sales-track-swatch mks-sales-track-chart-s0"></i><?= e(_l('mks_st_kpi_connected')); ?></span>
                            <span><i class="mks-sales-track-swatch mks-sales-track-chart-s1"></i><?= e(_l('mks_st_not_connected')); ?></span>
                        </span>
                    </div>
                    <?= $trend_svg; ?>
                </div>

                <div class="mks-sales-track-card">
                    <div class="mks-sales-track-card-head"><h5><?= e(_l('mks_st_call_mix')); ?></h5></div>
                    <?php if (!$mix) { ?>
                    <p class="mks-sales-track-device-note"><?= e(_l('mks_st_no_activity')); ?></p>
                    <?php } else { ?>
                    <div class="mks-sales-track-mix">
                        <?= mks_st_svg_donut($mix, mks_st_number_label($totals['calls']), _l('mks_st_kpi_calls')); ?>
                        <ul class="mks-sales-track-mix-legend">
                            <?php foreach ($mix as $mks_segment) { ?>
                            <li class="mks-sales-track-tone-<?= e($mks_segment['tone']); ?>">
                                <span class="mks-sales-track-dot"></span>
                                <span class="mks-sales-track-mix-label"><?= e($mks_segment['label']); ?></span>
                                <strong><?= e(mks_st_number_label($mks_segment['value'])); ?></strong>
                                <small><?= e((string) round($mks_segment['value'] * 100 / max(1, $totals['calls']))); ?>%</small>
                            </li>
                            <?php } ?>
                        </ul>
                    </div>
                    <?php } ?>
                </div>
            </div>

            <div class="mks-sales-track-dash-grid">
                <div class="mks-sales-track-card">
                    <div class="mks-sales-track-card-head">
                        <h5><?= e(_l('mks_st_heatmap_title')); ?></h5>
                        <?php if ($heat['wide']) { ?><span class="mks-sales-track-muted mks-sales-track-small"><?= e(_l('mks_st_last_30_days')); ?></span><?php } ?>
                    </div>
                    <div class="mks-sales-track-heatmap-wrap"><?= $heat_svg; ?></div>
                    <?php if ($heat['best']) { ?>
                    <p class="mks-sales-track-insight">
                        <i class="fa-solid fa-lightbulb" aria-hidden="true"></i>
                        <?= e(_l('mks_st_best_hour', [str_pad((string) $heat['best']['hour'], 2, '0', STR_PAD_LEFT) . ':00', str_pad((string) ($heat['best']['hour'] + 1), 2, '0', STR_PAD_LEFT) . ':00', (string) round($heat['best']['rate'] * 100)])); ?>
                    </p>
                    <?php } ?>
                </div>

                <div class="mks-sales-track-card">
                    <div class="mks-sales-track-card-head"><h5><?= e(_l($own ? 'mks_st_my_targets' : 'mks_st_targets')); ?></h5></div>
                    <?php if (!$targets && $targets_set) { ?>
                    <p class="mks-sales-track-device-note"><?= e(_l('mks_st_no_activity')); ?></p>
                    <?php } elseif (!$targets) { ?>
                    <p class="mks-sales-track-device-note"><?= e(_l('mks_st_no_targets')); ?></p>
                    <?php if (mks_st_can_settings()) { ?>
                    <a href="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/settings?section=targets'); ?>" class="mks-sales-track-link-btn"><?= e(_l('mks_st_set_targets')); ?></a>
                    <?php } ?>
                    <?php } elseif ($targets['workdays'] === 0) { ?>
                    <p class="mks-sales-track-device-note"><?= e(_l('mks_st_day_off')); ?></p>
                    <?php } else { ?>
                    <ul class="mks-sales-track-targets">
                        <?php foreach ($targets['rows'] as $mks_row) {
                            if ($mks_row['target'] === 0) {
                                continue;
                            } ?>
                        <li>
                            <div class="mks-sales-track-targets-line">
                                <span><?= e($mks_row['label']); ?></span>
                                <strong><?= e($mks_row['time'] ? mks_st_duration_label($mks_row['done']) . ' / ' . mks_st_duration_label($mks_row['target'])
                                    : mks_st_number_label($mks_row['done']) . ' / ' . mks_st_number_label($mks_row['target'])); ?></strong>
                            </div>
                            <?= $mks_bar($mks_row['done'], $mks_row['target']); ?>
                        </li>
                        <?php } ?>
                    </ul>
                    <?php if (!$own && $targets['with_target'] > 0) { ?>
                    <p class="mks-sales-track-insight"><i class="fa-solid fa-trophy" aria-hidden="true"></i><?= e(_l('mks_st_on_target', [(string) $targets['on_target'], (string) $targets['with_target']])); ?></p>
                    <?php } ?>
                    <?php } ?>
                </div>
            </div>

            <?php if ($to_convert) { ?>
            <div class="mks-sales-track-card mks-sales-track-convert">
                <div class="mks-sales-track-card-head">
                    <h5><i class="fa-solid fa-trophy" aria-hidden="true"></i> <?= e(_l('mks_st_ready_to_convert')); ?></h5>
                    <span class="mks-sales-track-muted mks-sales-track-small"><?= e(_l('mks_st_ready_to_convert_hint')); ?></span>
                </div>
                <ul class="mks-sales-track-convert-list">
                    <?php foreach ($to_convert as $mks_lead) { ?>
                    <li>
                        <a href="#" onclick="init_lead(<?= (int) $mks_lead['id']; ?>); return false;" class="mks-sales-track-contact-name"><?= e($mks_lead['name']); ?></a>
                        <?php if ((int) $mks_lead['is_customer'] === 1 && mks_st_customer_visible()) { ?>
                        <span class="mks-sales-track-pill mks-sales-track-tone-amber"><?= e(_l('mks_st_already_customer')); ?></span>
                        <?php } ?>
                        <span class="mks-sales-track-muted"><?= e(mks_st_staff_name($mks_lead['staff_id'])); ?>, <?= e(mks_st_relative_time($mks_lead['at'])); ?></span>
                    </li>
                    <?php } ?>
                </ul>
            </div>
            <?php } ?>

            <?php if (count($board) > 1) { ?>
            <div class="mks-sales-track-card">
                <div class="mks-sales-track-card-head">
                    <h5><?= e(_l('mks_st_leaderboard')); ?></h5>
                    <div class="mks-sales-track-segment mks-sales-track-segment-sm" role="group" aria-label="<?= e(_l('mks_st_rank_by')); ?>">
                        <?php foreach (['calls' => 'mks_st_kpi_calls', 'connected' => 'mks_st_kpi_connected', 'talk' => 'mks_st_kpi_talk_time'] as $mks_value => $mks_label) { ?>
                        <a href="<?= e($mks_query(['sort' => $mks_value])); ?>" class="mks-sales-track-segment-btn<?= $sort === $mks_value ? ' is-active' : ''; ?>"><?= e(_l($mks_label)); ?></a>
                        <?php } ?>
                    </div>
                </div>
                <div class="table-responsive">
                    <table class="mks-sales-track-mini-table mks-sales-track-board">
                        <thead>
                            <tr>
                                <th>#</th>
                                <th><?= e(_l('mks_st_col_staff')); ?></th>
                                <th><?= e(_l('mks_st_kpi_calls')); ?></th>
                                <th><?= e(_l('mks_st_kpi_connected')); ?></th>
                                <th><?= e(_l('mks_st_kpi_talk_time')); ?></th>
                                <th><?= e(_l('mks_st_average_call')); ?></th>
                                <th><?= e(_l('mks_st_kpi_missed')); ?></th>
                                <th><?= e(_l('mks_st_kpi_clients')); ?></th>
                                <th><?= e(_l('mks_st_page_whatsapp_calls')); ?></th>
                                <th><?= e(_l('mks_st_page_sms')); ?></th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($board as $mks_rank => $mks_person) { ?>
                            <tr>
                                <td class="mks-sales-track-rank"><?= $mks_rank < 3 && $mks_person[$sort] > 0 ? '<i class="fa-solid fa-trophy mks-sales-track-rank-' . ($mks_rank + 1) . '" aria-hidden="true"></i>' : (int) ($mks_rank + 1); ?></td>
                                <td>
                                    <a href="<?= e($mks_query(['staff' => (int) $mks_person['staff_id']])); ?>" class="mks-sales-track-person">
                                        <?= staff_profile_image($mks_person['staff_id'], ['mks-sales-track-avatar'], 'small', ['alt' => $mks_person['name']]); ?>
                                        <span class="mks-sales-track-person-name"><?= e($mks_person['name']); ?></span>
                                    </a>
                                </td>
                                <td class="mks-sales-track-board-target">
                                    <strong><?= e(mks_st_number_label($mks_person['calls'])); ?></strong>
                                    <?php if ($mks_person['target']['calls'] > 0) { ?>
                                    <small>/ <?= e(mks_st_number_label($mks_person['target']['calls'])); ?></small>
                                    <?= $mks_bar($mks_person['calls'], $mks_person['target']['calls']); ?>
                                    <?php } ?>
                                </td>
                                <td><?= e(mks_st_number_label($mks_person['connected'])); ?> <small class="mks-sales-track-muted"><?= $mks_person['calls'] > 0 ? (int) round($mks_person['connected'] * 100 / $mks_person['calls']) . '%' : ''; ?></small></td>
                                <td><?= e(mks_st_duration_label($mks_person['talk'])); ?></td>
                                <td><?= $mks_person['connected'] > 0 ? e(mks_st_duration_label((int) round($mks_person['talk'] / $mks_person['connected']))) : '<span class="mks-sales-track-muted">-</span>'; ?></td>
                                <td class="<?= $mks_person['missed'] > 0 ? 'mks-sales-track-danger' : ''; ?>"><?= e(mks_st_number_label($mks_person['missed'])); ?></td>
                                <td><?= e(mks_st_number_label($mks_person['clients'])); ?></td>
                                <td><?= e(mks_st_number_label($mks_person['whatsapp'])); ?></td>
                                <td><?= e(mks_st_number_label($mks_person['sms'])); ?></td>
                            </tr>
                            <?php } ?>
                        </tbody>
                    </table>
                </div>
            </div>
            <?php } ?>

            <div class="mks-sales-track-dash-grid">
                <div class="mks-sales-track-card mks-sales-track-dash-latest">
                    <div class="mks-sales-track-card-head">
                        <h5><?= e(_l('mks_st_latest_activity')); ?></h5>
                        <a href="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/calls'); ?>" class="mks-sales-track-link-btn"><?= e(_l('mks_st_view_all')); ?></a>
                    </div>
                    <?php if (!$latest) { ?>
                    <div class="mks-sales-track-empty mks-sales-track-empty-sm">
                        <span class="mks-sales-track-empty-icon"><i class="fa-solid fa-phone" aria-hidden="true"></i></span>
                        <p><?= e(_l('mks_st_no_activity')); ?></p>
                    </div>
                    <?php } else { ?>
                    <ul class="mks-sales-track-feed">
                        <?php 
                        $mks_kind_icons = [
                            'call'             => 'fa-solid fa-phone',
                            'whatsapp_call'    => 'fa-brands fa-whatsapp',
                            'sms'              => 'fa-solid fa-message',
                            'whatsapp_message' => 'fa-brands fa-whatsapp',
                            'notification'     => 'fa-solid fa-bell',
                        ];
                        foreach ($latest as $mks_event) {
                            $mks_kind_icon = isset($mks_kind_icons[$mks_event['kind']]) ? $mks_kind_icons[$mks_event['kind']] : 'fa-solid fa-message'; ?>
                        <li class="mks-sales-track-feed-item">
                            <span class="mks-sales-track-feed-kind mks-sales-track-feed-kind-<?= e($mks_event['kind']); ?>"><i class="<?= $mks_kind_icon; ?>" aria-hidden="true"></i></span>
                            <div class="mks-sales-track-feed-main"><?= mks_st_render_contact($mks_event); ?></div>
                            <div class="mks-sales-track-feed-dir"><?= mks_st_render_direction($mks_event); ?></div>
                            <div class="mks-sales-track-feed-staff"><?= mks_st_render_staff($mks_event); ?></div>
                            <div class="mks-sales-track-feed-time"><?= mks_st_render_time($mks_event['occurred_at']); ?></div>
                            <div class="mks-sales-track-feed-dur"><?= mks_st_render_cell('duration', $mks_event, $context); ?></div>
                        </li>
                        <?php } ?>
                    </ul>
                    <?php } ?>
                </div>

                <div class="mks-sales-track-card mks-sales-track-dash-phones">
                    <div class="mks-sales-track-card-head">
                        <h5><?= e(_l('mks_st_phones')); ?></h5>
                        <a href="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/devices'); ?>" class="mks-sales-track-link-btn"><?= e(_l('mks_st_page_devices')); ?></a>
                    </div>
                    <ul class="mks-sales-track-states">
                        <?php foreach ($mks_state_meta as $mks_state => $mks_meta) { ?>
                        <li class="mks-sales-track-tone-<?= $mks_meta['tone']; ?>">
                            <span class="mks-sales-track-dot"></span>
                            <span class="mks-sales-track-states-label"><?= e(_l($mks_meta['label'])); ?></span>
                            <strong><?= e(mks_st_number_label($states[$mks_state])); ?></strong>
                        </li>
                        <?php } ?>
                    </ul>
                </div>
            </div>

        </div>
    </div>
</div>
<?php init_tail(); ?>
</body>

</html>
