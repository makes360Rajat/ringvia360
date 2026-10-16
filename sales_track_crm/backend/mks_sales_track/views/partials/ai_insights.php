<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - one call's AI insights, loaded into the Insights window.
 *
 * @var array      $event
 * @var array|null $ai
 * @var bool       $can_use  the suggestion may become the call's outcome
 * @var bool       $manager
 */
$mks_a        = $ai ? $ai['analysis'] : [];
$mks_outcomes = mks_st_outcomes();
$mks_score    = (int) $event['ai_score'];
$mks_tone     = $mks_score >= 75 ? 'green' : ($mks_score >= 50 ? 'amber' : 'red');
$mks_list     = function ($items) {
    return $items ? '<ul class="mks-sales-track-ai-list"><li>' . implode('</li><li>', array_map('e', $items)) . '</li></ul>' : '<p class="mks-sales-track-muted">-</p>';
};
?>
<div class="mks-sales-track mks-sales-track-ai">
    <div class="mks-sales-track-ai-head">
        <span class="mks-sales-track-ai-score mks-sales-track-tone-<?= $mks_tone; ?>"><?= $mks_score; ?><small>/100</small></span>
        <div>
            <div class="mks-sales-track-contact-line"><?= mks_st_render_contact($event); ?></div>
            <span class="mks-sales-track-muted mks-sales-track-small"><?= e(mks_st_staff_name($event['staff_id'])); ?>, <?= e(_dt($event['occurred_at'])); ?>, <?= e(mks_st_duration_label($event['duration'])); ?>
                <?php if ($ai && $ai['language']) { ?>, <?= e($ai['language']); ?><?php } ?></span>
            <div class="mks-sales-track-ai-tags">
                <span class="mks-sales-track-pill mks-sales-track-tone-<?= ['hot' => 'red', 'warm' => 'amber', 'cold' => 'blue'][$event['ai_temperature']] ?? 'slate'; ?>"><?= e(_l('mks_st_ai_' . $event['ai_temperature'])); ?></span>
                <span class="mks-sales-track-pill mks-sales-track-tone-<?= ['positive' => 'green', 'neutral' => 'slate', 'negative' => 'red'][$event['ai_sentiment']] ?? 'slate'; ?>"><?= e(_l('mks_st_ai_' . $event['ai_sentiment'])); ?></span>
            </div>
        </div>
    </div>

    <h5><?= e(_l('mks_st_ai_summary')); ?></h5>
    <p><?= e(isset($mks_a['summary']) ? $mks_a['summary'] : ''); ?></p>

    <?php if (!empty($mks_a['flags'])) { ?>
    <div class="mks-sales-track-ai-flags">
        <?php foreach ($mks_a['flags'] as $mks_flag) { ?>
        <p><i class="fa-solid fa-flag" aria-hidden="true"></i> <strong><?= e(_l('mks_st_ai_flag_' . $mks_flag['type'])); ?></strong>
            <?php if ($mks_flag['quote'] !== '') { ?>"<?= e($mks_flag['quote']); ?>"<?php } ?> <?= e($mks_flag['note']); ?></p>
        <?php } ?>
    </div>
    <?php } ?>

    <div class="row">
        <div class="col-md-6">
            <h5><?= e(_l('mks_st_ai_objections')); ?></h5>
            <?= $mks_list(isset($mks_a['objections']) ? $mks_a['objections'] : []); ?>
        </div>
        <div class="col-md-6">
            <h5><?= e(_l('mks_st_ai_next_steps')); ?></h5>
            <?= $mks_list(isset($mks_a['next_steps']) ? $mks_a['next_steps'] : []); ?>
        </div>
    </div>

    <h5><?= e(_l('mks_st_ai_rubric')); ?></h5>
    <table class="mks-sales-track-mini-table">
        <tbody>
            <?php foreach (isset($mks_a['rubric']) ? $mks_a['rubric'] : [] as $mks_mark) { ?>
            <tr>
                <td><?= e($mks_mark['criterion']); ?></td>
                <td class="text-right"><span class="mks-sales-track-pill mks-sales-track-tone-<?= ['red', 'amber', 'green'][$mks_mark['score']]; ?>"><?= (int) $mks_mark['score']; ?>/2</span></td>
                <td class="mks-sales-track-muted"><?= e($mks_mark['note']); ?></td>
            </tr>
            <?php } ?>
        </tbody>
    </table>

    <?php if (!empty($mks_a['suggestion']['outcome']) && isset($mks_outcomes[$mks_a['suggestion']['outcome']])) { ?>
    <div class="mks-sales-track-info mks-sales-track-ai-suggestion">
        <i class="fa-solid fa-lightbulb" aria-hidden="true"></i>
        <div>
            <p><strong><?= e(_l('mks_st_ai_suggests')); ?></strong>
                <span class="mks-sales-track-pill mks-sales-track-tone-<?= e($mks_outcomes[$mks_a['suggestion']['outcome']]['tone']); ?>"><?= e($mks_outcomes[$mks_a['suggestion']['outcome']]['label']); ?></span>
                <?= e($mks_a['suggestion']['note']); ?>
                <?php if ((int) $mks_a['suggestion']['follow_up_days'] > 0) { ?><span class="mks-sales-track-muted"><?= e(_l('mks_st_ai_follow_in', (string) (int) $mks_a['suggestion']['follow_up_days'])); ?></span><?php } ?></p>
            <?php if ($can_use) { ?>
            <button type="button" class="btn btn-primary btn-xs mks-sales-track-ai-use" data-id="<?= (int) $event['id']; ?>"><?= e(_l('mks_st_ai_use')); ?></button>
            <?php } ?>
        </div>
    </div>
    <?php } ?>

    <?php if ($ai && $ai['transcript'] !== '') { ?>
    <details class="mks-sales-track-ai-transcript">
        <summary><?= e(_l('mks_st_ai_transcript')); ?></summary>
        <pre><?= e($ai['transcript']); ?></pre>
    </details>
    <?php } ?>

    <?php if ($manager && $ai) { ?>
    <p class="mks-sales-track-muted mks-sales-track-small"><?= e(_l('mks_st_ai_meta', [$ai['model'], '$' . number_format((float) $ai['cost'], 4), _dt($ai['created_at'])])); ?></p>
    <?php } ?>
</div>
