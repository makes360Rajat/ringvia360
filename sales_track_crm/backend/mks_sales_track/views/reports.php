<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - Reports. One report at a time, chosen on the left, over a
 * period, team and person; exported to CSV or Excel exactly as shown.
 */

init_head();

$mks_query = function (array $change) use ($key, $filters, $period) {
    $params = array_merge(['report' => $key, 'range' => $filters['range'], 'team' => $filters['team'], 'staff' => $filters['staff']], $change);

    if ($params['range'] === 'custom') {
        $params += ['from' => $period['from'], 'to' => $period['to']];
    }

    return admin_url(MKS_SALES_TRACK_MODULE_NAME . '/reports?' . http_build_query(array_filter($params)));
};

$mks_period_label = $period['from'] === $period['to'] ? _d($period['from']) : _d($period['from']) . ' - ' . _d($period['to']);
?>
<div id="wrapper">
    <div class="content">
        <div class="mks-sales-track mks-sales-track-reports">

            <?php $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/partials/nav', ['nav' => $nav]); ?>

            <div class="mks-sales-track-head">
                <div class="mks-sales-track-head-main">
                    <span class="mks-sales-track-head-icon"><i class="fa-solid fa-chart-column" aria-hidden="true"></i></span>
                    <div>
                        <h4 class="mks-sales-track-title"><?= e(_l($reports[$key]['label'])); ?></h4>
                        <p class="mks-sales-track-sub"><?= e(_l($reports[$key]['sub'])); ?> <span class="mks-sales-track-muted"><?= e($mks_period_label); ?></span></p>
                    </div>
                </div>
                <div class="mks-sales-track-head-actions mks-sales-track-no-print">
                    <a href="<?= e($mks_query(['format' => 'csv'])); ?>" class="btn btn-default mks-sales-track-btn"><i class="fa-solid fa-file-csv" aria-hidden="true"></i><?= e(_l('mks_st_export_csv')); ?></a>
                    <?php if ($can_xlsx) { ?>
                    <a href="<?= e($mks_query(['format' => 'xlsx'])); ?>" class="btn btn-default mks-sales-track-btn"><i class="fa-solid fa-file-excel" aria-hidden="true"></i><?= e(_l('mks_st_export_xlsx')); ?></a>
                    <?php } ?>
                    <button type="button" class="btn btn-default mks-sales-track-btn" onclick="window.print();"><i class="fa-solid fa-print" aria-hidden="true"></i><?= e(_l('mks_st_print')); ?></button>
                </div>
            </div>

            <div class="mks-sales-track-settings-layout mks-sales-track-reports-layout">
                <aside class="mks-sales-track-settings-menu mks-sales-track-no-print">
                    <?php foreach ($reports as $mks_key => $mks_report) { ?>
                    <a href="<?= e($mks_query(['report' => $mks_key])); ?>" class="mks-sales-track-settings-menu-item<?= $mks_key === $key ? ' is-active' : ''; ?>">
                        <i class="<?= e($mks_report['icon']); ?>" aria-hidden="true"></i><span><?= e(_l($mks_report['label'])); ?></span>
                    </a>
                    <?php } ?>
                </aside>

                <div>
                    <form method="get" action="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/reports'); ?>" class="mks-sales-track-card mks-sales-track-filters mks-sales-track-no-print" id="mks-sales-track-report-filters">
                        <input type="hidden" name="report" value="<?= e($key); ?>">
                        <div class="mks-sales-track-filters-row">
                            <div class="mks-sales-track-segment" role="group" aria-label="<?= e(_l('mks_st_filter_range')); ?>">
                                <?php foreach ($ranges as $mks_value => $mks_label) { ?>
                                <a href="<?= e($mks_query(['range' => $mks_value, 'from' => '', 'to' => ''])); ?>" class="mks-sales-track-segment-btn<?= $filters['range'] === $mks_value ? ' is-active' : ''; ?>"><?= e(_l($mks_label)); ?></a>
                                <?php } ?>
                            </div>
                            <span class="mks-sales-track-custom-range">
                                <input type="hidden" name="range" value="<?= e($filters['range']); ?>">
                                <input type="date" name="from" class="form-control" value="<?= e($period['from']); ?>" aria-label="<?= e(_l('mks_st_from')); ?>">
                                <span><?= e(_l('mks_st_to')); ?></span>
                                <input type="date" name="to" class="form-control" value="<?= e($period['to']); ?>" aria-label="<?= e(_l('mks_st_to')); ?>">
                                <button type="submit" name="range" value="custom" class="btn btn-default btn-sm"><?= e(_l('mks_st_apply')); ?></button>
                            </span>
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

                    <div class="mks-sales-track-card mks-sales-track-report-card">
                        <?php if (!$report['rows']) { ?>
                        <div class="mks-sales-track-empty mks-sales-track-empty-sm">
                            <span class="mks-sales-track-empty-icon"><i class="<?= e($reports[$key]['icon']); ?>" aria-hidden="true"></i></span>
                            <p><?= e(_l('mks_st_report_empty')); ?></p>
                        </div>
                        <?php } else { ?>
                        <div class="table-responsive">
                            <table class="mks-sales-track-mini-table mks-sales-track-report-table">
                                <thead>
                                    <tr>
                                        <?php foreach ($report['columns'] as $mks_column) { ?>
                                        <th class="<?= $mks_column['type'] === 'text' ? '' : 'text-right'; ?>"><?= e($mks_column['label']); ?></th>
                                        <?php } ?>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php foreach ($report['rows'] as $mks_row) { ?>
                                    <tr>
                                        <?php foreach ($report['columns'] as $mks_column) { ?>
                                        <td class="<?= $mks_column['type'] === 'text' ? '' : 'text-right'; ?>"><?= e(mks_st_report_cell(isset($mks_row[$mks_column['key']]) ? $mks_row[$mks_column['key']] : null, $mks_column['type'])); ?></td>
                                        <?php } ?>
                                    </tr>
                                    <?php } ?>
                                </tbody>
                                <?php if ($report['totals']) { ?>
                                <tfoot>
                                    <tr>
                                        <?php foreach ($report['columns'] as $mks_column) { ?>
                                        <td class="<?= $mks_column['type'] === 'text' ? '' : 'text-right'; ?>"><?= e(mks_st_report_cell(isset($report['totals'][$mks_column['key']]) ? $report['totals'][$mks_column['key']] : null, $mks_column['type'])); ?></td>
                                        <?php } ?>
                                    </tr>
                                </tfoot>
                                <?php } ?>
                            </table>
                        </div>
                        <?php } ?>
                        <?php if ($report['note'] !== '') { ?>
                        <p class="mks-sales-track-report-note"><i class="fa-solid fa-circle-info" aria-hidden="true"></i> <?= e($report['note']); ?></p>
                        <?php } ?>
                    </div>
                </div>
            </div>

        </div>
    </div>
</div>
<?php init_tail(); ?>
</body>

</html>
