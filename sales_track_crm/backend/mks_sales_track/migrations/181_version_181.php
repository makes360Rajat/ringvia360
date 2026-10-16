<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * Version 1.8.1.
 *
 * Perfex strips the dots from the module Version header (1.8.1 becomes 181)
 * and refuses an in-place upgrade unless migrations/181_version_181.php exists
 * with exactly this class name. The schema itself lives in the idempotent
 * install.php, so the migration only re-runs it.
 */
class Migration_Version_181 extends App_module_migration
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
