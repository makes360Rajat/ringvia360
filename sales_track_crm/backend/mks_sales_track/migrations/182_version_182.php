<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * Version 1.8.2.
 *
 * Perfex strips the dots from the module Version header (1.8.2 becomes 182)
 * and refuses an in-place upgrade unless migrations/182_version_182.php exists
 * with exactly this class name. The schema itself lives in the idempotent
 * install.php, so the migration only re-runs it.
 */
class Migration_Version_182 extends App_module_migration
{
    public function up()
    {
        $CI = &get_instance();

        require __DIR__ . '/../install.php';
    }

    public function down()
    {
        // Nothing to reverse: the installer never removes anything.
    }
}
