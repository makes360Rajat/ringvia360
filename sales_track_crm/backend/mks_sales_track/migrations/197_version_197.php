<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * Version 1.9.7.
 *
 * Perfex strips the dots from the module Version header (1.9.7 becomes 197)
 * and executes migrations/197_version_197.php with Migration_Version_197 class.
 */
class Migration_Version_197 extends App_module_migration
{
    public function up()
    {
        $CI = &get_instance();

        try {
            require __DIR__ . '/../install.php';
        } catch (\Throwable $e) {
            log_message('error', 'mks_sales_track migration 197 error: ' . $e->getMessage());
        }
    }

    public function down()
    {
    }
}
