<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - uninstaller.
 *
 * Self-contained on purpose: nothing here may call a module helper, because
 * the module's own files are not guaranteed to be loaded at this point.
 *
 * Uninstalling keeps every table, recording and setting unless "Delete All
 * Sales Track Data On Uninstall" was ticked first. Deactivating or reinstalling
 * a module is often a diagnostic step, not a decision to discard a call history.
 */

if (!isset($CI)) {
    $CI = &get_instance();
}

$mks_st_purge = false;
$mks_st_row   = $CI->db->select('value')->where('name', 'mks_sales_track_settings')->get(db_prefix() . 'options')->row();

if ($mks_st_row) {
    $mks_st_settings = json_decode((string) $mks_st_row->value, true);
    $mks_st_purge    = is_array($mks_st_settings) && !empty($mks_st_settings['purge_on_uninstall']);
}

if ($mks_st_purge) {
    $CI->db->query('DROP TABLE IF EXISTS `' . db_prefix() . 'mks_sales_track_ai`');
    $CI->db->query('DROP TABLE IF EXISTS `' . db_prefix() . 'mks_sales_track_events`');
    $CI->db->query('DROP TABLE IF EXISTS `' . db_prefix() . 'mks_sales_track_devices`');

    $CI->db->like('name', 'mks_sales_track_', 'after');
    $CI->db->delete(db_prefix() . 'options');

    // Recordings live outside the module folder. Only this one folder is ever
    // walked, and every path is checked to sit inside it before deletion.
    $mks_st_root = realpath(FCPATH . 'uploads/mks_sales_track');

    if ($mks_st_root !== false && basename($mks_st_root) === 'mks_sales_track' && is_dir($mks_st_root)) {
        $mks_st_items = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($mks_st_root, FilesystemIterator::SKIP_DOTS),
            RecursiveIteratorIterator::CHILD_FIRST
        );

        foreach ($mks_st_items as $mks_st_item) {
            $mks_st_path = $mks_st_item->getPathname();

            if (strpos($mks_st_path, $mks_st_root . DIRECTORY_SEPARATOR) !== 0) {
                continue;
            }

            if ($mks_st_item->isDir() && !$mks_st_item->isLink()) {
                @rmdir($mks_st_path);
            } else {
                @unlink($mks_st_path);
            }
        }

        @rmdir($mks_st_root);
    }
}
