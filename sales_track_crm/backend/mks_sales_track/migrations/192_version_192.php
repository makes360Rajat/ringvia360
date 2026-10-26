<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * Version 1.9.2.
 *
 * Perfex strips the dots from the module Version header (1.9.2 becomes 192)
 * and executes migrations/192_version_192.php with Migration_Version_192 class.
 */
class Migration_Version_192 extends App_module_migration
{
    public function up()
    {
        $CI = &get_instance();

        try {
            require __DIR__ . '/../install.php';
        } catch (\Throwable $e) {
            log_message('error', 'mks_sales_track migration 192 error: ' . $e->getMessage());
        }
    }

    public function down()
    {
    }
}
