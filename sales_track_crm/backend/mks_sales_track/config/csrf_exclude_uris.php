<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - CSRF exclusions.
 *
 * Perfex 3.4.1 loads this file for every module through
 * application/hooks/InitModules.php and merges it into the CSRF exclusion
 * list, so nobody has to edit application/config/config.php.
 *
 * Only the phone API is excluded. A phone has no session and no form; its
 * per-device token is what protects these endpoints. Every screen in the CRM
 * keeps CSRF protection.
 */
return [
    'mks_sales_track/api/v1/.+',
];
