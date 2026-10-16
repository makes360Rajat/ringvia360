<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - the wallboard's secret link, for a sales-floor screen that
 * is not signed in to the CRM.
 *
 *   GET <crm>/mks_sales_track/wallboard/<key>
 *
 * Answers only while Settings > Wallboard allows it and the key matches; the
 * board shows rep names and figures, never customer details.
 */
class Mks_sales_track_wall extends App_Controller
{
    /**
     * @param  string $key
     *
     * @return void
     */
    public function index($key = '')
    {
        if (!function_exists('mks_st_setting') || !mks_st_enabled('enabled') || !mks_st_enabled('wallboard_public')) {
            show_404();
        }

        $expected = (string) mks_st_setting('wallboard_key', '');

        if ($expected === '' || !is_string($key) || !hash_equals($expected, $key)) {
            show_404();
        }

        require_once module_dir_path(MKS_SALES_TRACK_MODULE_NAME, 'helpers/mks_sales_track_lists_helper.php');

        header('X-Robots-Tag: noindex, nofollow');
        header('Referrer-Policy: no-referrer');

        $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/wallboard', ['data' => mks_st_wallboard_data(null), 'refresh' => (int) mks_st_setting('wallboard_refresh', 60)]);
    }
}
