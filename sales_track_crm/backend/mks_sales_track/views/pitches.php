<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - Best Pitches: calls worth learning from, open to everybody
 * who uses Sales Track, with the moments worth hearing. Managers see the
 * nominations waiting for them on top.
 */

init_head();

$mks_card = function (array $event, $nominated) use ($manager) {
    $moments = mks_st_decode($event['pitch_moments']);
    $src     = admin_url(MKS_SALES_TRACK_MODULE_NAME . '/recording/' . (int) $event['id']);
    $who     = mks_st_event_visible($event) ? mks_st_render_contact($event) : '<span class="mks-sales-track-muted">' . e(_l('mks_st_pitch_private')) . '</span>';

    ob_start(); ?>
    <div class="mks-sales-track-card mks-sales-track-pitch-card" data-id="<?= (int) $event['id']; ?>">
        <div class="mks-sales-track-pitch-head">
            <?= mks_st_render_staff($event); ?>
            <?php if ((string) $event['pitch_category'] !== '') { ?><span class="mks-sales-track-pill mks-sales-track-tone-violet"><?= e($event['pitch_category']); ?></span><?php } ?>
            <span class="mks-sales-track-muted mks-sales-track-small"><?= e(_dt($event['occurred_at'])); ?>, <?= e(mks_st_duration_label($event['duration'])); ?></span>
        </div>
        <div class="mks-sales-track-pitch-who"><?= $who; ?></div>
        <?php if ((string) $event['pitch_note'] !== '') { ?><p class="mks-sales-track-pitch-note"><?= e($event['pitch_note']); ?></p><?php } ?>
        <?php if (mks_st_event_playable($event)) { ?>
        <audio controls preload="none" src="<?= e($src); ?>" class="mks-sales-track-pitch-audio"></audio>
        <?php } ?>
        <?php if ($moments) { ?>
        <div class="mks-sales-track-moments">
            <?php foreach ($moments as $moment) { ?>
            <button type="button" class="mks-sales-track-moment" data-t="<?= (int) $moment['t']; ?>">
                <i class="fa-solid fa-play" aria-hidden="true"></i><?= e(floor($moment['t'] / 60) . ':' . str_pad((string) ($moment['t'] % 60), 2, '0', STR_PAD_LEFT)); ?>
                <span><?= e($moment['label']); ?></span>
            </button>
            <?php } ?>
        </div>
        <?php } ?>
        <?php if ($manager) { ?>
        <div class="mks-sales-track-pitch-actions">
            <?php if ($nominated) { ?>
            <button type="button" class="btn btn-primary btn-xs mks-sales-track-pitch-act" data-action="approve" data-id="<?= (int) $event['id']; ?>"><?= e(_l('mks_st_pitch_approve')); ?></button>
            <button type="button" class="btn btn-default btn-xs mks-sales-track-pitch-act" data-action="reject" data-id="<?= (int) $event['id']; ?>"><?= e(_l('mks_st_pitch_reject')); ?></button>
            <?php } else { ?>
            <button type="button" class="btn btn-default btn-xs mks-sales-track-pitch-act" data-action="remove" data-id="<?= (int) $event['id']; ?>"><?= e(_l('mks_st_pitch_remove')); ?></button>
            <?php } ?>
        </div>
        <?php } ?>
    </div>
    <?php return ob_get_clean();
};
?>
<div id="wrapper">
    <div class="content">
        <div class="mks-sales-track mks-sales-track-pitches">

            <?php $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/partials/nav', ['nav' => $nav]); ?>

            <div class="mks-sales-track-head">
                <div class="mks-sales-track-head-main">
                    <span class="mks-sales-track-head-icon mks-sales-track-tone-amber"><i class="fa-solid fa-star" aria-hidden="true"></i></span>
                    <div>
                        <h4 class="mks-sales-track-title"><?= e(_l('mks_st_page_pitches')); ?></h4>
                        <p class="mks-sales-track-sub"><?= e(_l('mks_st_page_pitches_sub')); ?></p>
                    </div>
                </div>
            </div>

            <?php if ($nominated) { ?>
            <h5 class="mks-sales-track-section-title"><?= e(_l('mks_st_pitch_waiting', (string) count($nominated))); ?></h5>
            <div class="mks-sales-track-pitch-grid">
                <?php foreach ($nominated as $mks_event) {
                    echo $mks_card($mks_event, true);
                } ?>
            </div>
            <?php } ?>

            <?php if ($categories) { ?>
            <div class="mks-sales-track-segment mks-sales-track-pitch-filter" role="group">
                <a href="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/pitches'); ?>" class="mks-sales-track-segment-btn<?= $category === '' ? ' is-active' : ''; ?>"><?= e(_l('mks_st_all')); ?></a>
                <?php foreach ($categories as $mks_category) { ?>
                <a href="<?= admin_url(MKS_SALES_TRACK_MODULE_NAME . '/pitches?category=' . rawurlencode($mks_category)); ?>" class="mks-sales-track-segment-btn<?= $category === $mks_category ? ' is-active' : ''; ?>"><?= e($mks_category); ?></a>
                <?php } ?>
            </div>
            <?php } ?>

            <?php if (!$library) { ?>
            <div class="mks-sales-track-card mks-sales-track-empty">
                <span class="mks-sales-track-empty-icon"><i class="fa-solid fa-star" aria-hidden="true"></i></span>
                <h5><?= e(_l('mks_st_pitch_empty')); ?></h5>
                <p><?= e(_l('mks_st_pitch_empty_sub')); ?></p>
            </div>
            <?php } else { ?>
            <div class="mks-sales-track-pitch-grid">
                <?php foreach ($library as $mks_event) {
                    echo $mks_card($mks_event, false);
                } ?>
            </div>
            <?php } ?>

        </div>
    </div>
</div>
<?php init_tail(); ?>
</body>

</html>
