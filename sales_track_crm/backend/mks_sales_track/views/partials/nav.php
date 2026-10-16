<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - the tab bar on every module page.
 *
 * The sidebar carries one item; this bar is how every other page, Settings
 * included, is reached. Items come from mks_st_nav_items(), which hides what
 * the viewer may not use and what is switched off.
 *
 * @var string $nav the active item
 */
$mks_active = isset($nav) ? (string) $nav : '';
?>
<nav class="mks-sales-track-nav" aria-label="<?= e(_l('mks_st_menu')); ?>">
    <a href="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME); ?>" class="mks-sales-track-nav-brand">
        <span class="mks-sales-track-nav-logo"><i class="fa-solid fa-phone-volume" aria-hidden="true"></i></span>
        <span><?= e(_l('mks_st_menu')); ?></span>
    </a>
    <div class="mks-sales-track-nav-links">
        <?php foreach (mks_st_nav_items() as $mks_slug => $mks_item) { ?>
        <a href="<?= e($mks_item['url']); ?>" class="mks-sales-track-nav-link<?= $mks_slug === $mks_active ? ' is-active' : ''; ?>"
            <?= $mks_slug === $mks_active ? 'aria-current="page"' : ''; ?>>
            <i class="<?= e($mks_item['icon']); ?>" aria-hidden="true"></i><span><?= e($mks_item['label']); ?></span>
        </a>
        <?php } ?>
    </div>
</nav>
