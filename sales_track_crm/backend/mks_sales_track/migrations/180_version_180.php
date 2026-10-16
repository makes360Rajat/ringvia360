<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * Version 1.8.0.
 *
 * Perfex strips the dots from the module Version header (1.8.0 becomes 180)
 * and refuses an in-place upgrade unless migrations/180_version_180.php exists
 * with exactly this class name. The schema itself lives in the idempotent
 * install.php, so the migration only re-runs it.
 *
 * Keep exactly one migration file, and keep minor and patch single digit:
 * 1.0.10 would collapse to 1010 and break in-place upgrades.
 */
class Migration_Version_180 extends App_module_migration
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
