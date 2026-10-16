<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - the Setup > Settings entry. Settings live on the module's
 * own page; this only points there. Perfex's Save button is switched off for
 * this group (without_submit_button).
 */
?>
<div class="clearfix">
    <a href="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/settings'); ?>" class="btn btn-primary pull-right">
        <i class="fa-solid fa-sliders" aria-hidden="true"></i> <?= e(_l('mks_st_open_settings')); ?>
    </a>
    <h4 class="bold no-mtop"><?= e(_l('mks_st_menu')); ?></h4>
    <p class="text-muted no-mbot"><?= e(_l('mks_st_settings_moved')); ?></p>
</div>
