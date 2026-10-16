<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - server side data for the five activity lists.
 *
 * Included by App::get_table_data(), which extracts $mks_view and echoes
 * $output as JSON. Columns, search, scope and filters all come from the view
 * helper, so the KPI tiles added to the same response describe exactly the
 * rows the table shows.
 *
 * Every selected column carries an explicit alias: data_tables_init() runs a
 * SHOW COLUMNS query per draw for any qualified column without one.
 */

$mks_view    = isset($mks_view) ? (string) $mks_view : 'calls';
$mks_columns = mks_st_view_columns($mks_view);
$mks_from    = mks_st_events_from();
$mks_filters = mks_st_posted_filters();

$aColumns = [];
$searchAs = [];

foreach ($mks_columns as $mks_index => $mks_column) {
    $aColumns[] = $mks_column['select'] . ' as mks_c' . $mks_index;

    if (isset($mks_column['search'])) {
        $searchAs[$mks_index] = $mks_column['search'];
    }
}

$mks_result = data_tables_init(
    $aColumns,
    'e.id',
    $mks_from['table'],
    $mks_from['joins'],
    mks_st_view_where($mks_view, $mks_filters),
    [],
    '',
    $searchAs
);

$output           = $mks_result['output'];
$output['aaData'] = mks_st_view_rows($mks_result['rResult'], $mks_view);

$mks_search = get_instance()->input->post('search');

$output['mks_st_summary'] = mks_st_view_summary(
    $mks_view,
    $mks_filters,
    is_array($mks_search) && isset($mks_search['value']) ? (string) $mks_search['value'] : ''
);
