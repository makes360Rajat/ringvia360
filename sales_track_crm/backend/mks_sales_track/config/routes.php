<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - routes.
 *
 * The admin screens (admin/mks_sales_track/...) are routed by Perfex itself
 * and need nothing here. These are the phone app endpoints, served by the
 * public Mks_sales_track_api controller, whose _remap() holds the whitelist.
 */
$route['mks_sales_track/api/v1/(:any)'] = 'mks_sales_track_api/$1';

// The wallboard's secret link, for a sales-floor screen that is not signed in.
$route['mks_sales_track/wallboard/(:any)'] = 'mks_sales_track_wall/index/$1';
