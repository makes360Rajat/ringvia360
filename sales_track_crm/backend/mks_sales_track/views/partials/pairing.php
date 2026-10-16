<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - the pairing panel: QR code, the 6-digit code, its expiry
 * and the wait for the phone. Shared by the Add Device window and the device
 * page; the script fills it and polls until the phone pairs.
 */
?>
<div class="mks-sales-track-pairing">
    <div class="mks-sales-track-qr mks-sales-track-pairing-qr"></div>
    <p class="mks-sales-track-pair-or"><?= e(_l('mks_st_pair_or_type')); ?></p>
    <div class="mks-sales-track-pair-code mks-sales-track-pairing-code"></div>
    <p class="mks-sales-track-pair-meta">
        <span class="mks-sales-track-pairing-site"></span>
        <span class="mks-sales-track-pair-expiry mks-sales-track-pairing-expiry"></span>
    </p>
    <p class="mks-sales-track-pair-wait mks-sales-track-pairing-wait">
        <span class="mks-sales-track-spinner" aria-hidden="true"></span><?= e(_l('mks_st_pair_waiting')); ?>
    </p>
    <div class="mks-sales-track-pairing-done mks-sales-track-is-hidden">
        <span class="mks-sales-track-pair-done-icon"><i class="fa-solid fa-circle-check" aria-hidden="true"></i></span>
        <h5 class="mks-sales-track-pairing-done-text"></h5>
        <p class="mks-sales-track-muted"><?= e(_l('mks_st_pair_done_sub')); ?></p>
    </div>
    <div class="mks-sales-track-pairing-expired mks-sales-track-is-hidden">
        <span class="mks-sales-track-pair-done-icon is-expired"><i class="fa-solid fa-clock" aria-hidden="true"></i></span>
        <h5><?= e(_l('mks_st_pair_expired')); ?></h5>
    </div>
</div>
