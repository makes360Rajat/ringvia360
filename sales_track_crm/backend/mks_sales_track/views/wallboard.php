<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - the wallboard: today's figures for a sales-floor screen.
 * A page of its own, dark, large and refreshing itself. Rep names and figures
 * only: no customer appears here.
 *
 * @var array $data
 * @var int   $refresh seconds
 */
$mks_max = $data['board'] ? max(array_column($data['board'], 'calls')) : 0;
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="refresh" content="<?= (int) $refresh; ?>">
    <meta name="robots" content="noindex, nofollow">
    <title><?= e(_l('mks_st_wallboard')); ?> - <?= e(get_option('companyname')); ?></title>
    <style>
        * { box-sizing: border-box; }
        body { margin: 0; padding: 3vh 3vw; min-height: 100vh; background: #0b1220; color: #e2e8f0; font-family: -apple-system, "Segoe UI", Roboto, Arial, sans-serif; }
        header { display: flex; align-items: baseline; justify-content: space-between; margin-bottom: 3vh; }
        h1 { margin: 0; font-size: 3.2vh; font-weight: 700; color: #f8fafc; }
        .clock { font-size: 2.6vh; color: #94a3b8; }
        .tiles { display: grid; grid-template-columns: repeat(5, 1fr); gap: 1.6vw; margin-bottom: 3vh; }
        .tile { padding: 2.4vh 1.4vw; border-radius: 18px; background: #111a2e; }
        .tile span { display: block; font-size: 1.8vh; color: #94a3b8; text-transform: uppercase; letter-spacing: .06em; }
        .tile strong { display: block; margin-top: .8vh; font-size: 6vh; line-height: 1; color: #f8fafc; }
        .tile.alert strong { color: #fca5a5; }
        .grid { display: grid; grid-template-columns: 2fr 1fr; gap: 1.6vw; }
        .panel { padding: 2.4vh 1.6vw; border-radius: 18px; background: #111a2e; }
        .panel h2 { margin: 0 0 2vh; font-size: 2.2vh; color: #94a3b8; font-weight: 600; text-transform: uppercase; letter-spacing: .06em; }
        .row { display: grid; grid-template-columns: 3vw 1fr 8vw 8vw 10vw; align-items: center; gap: 1vw; padding: 1.1vh 0; border-bottom: 1px solid #1e293b; font-size: 2.4vh; }
        .rank { color: #64748b; font-weight: 700; }
        .bar { height: .9vh; margin-top: .6vh; border-radius: 99px; background: #1e293b; overflow: hidden; }
        .bar i { display: block; height: 100%; border-radius: 99px; background: #38bdf8; }
        .num { text-align: right; font-weight: 700; color: #f8fafc; }
        .muted { color: #64748b; }
        .feed div { display: flex; justify-content: space-between; padding: 1.1vh 0; border-bottom: 1px solid #1e293b; font-size: 2.1vh; }
        .in { color: #4ade80; } .out { color: #38bdf8; } .miss { color: #f87171; }
        .empty { padding: 4vh 0; color: #64748b; font-size: 2.4vh; text-align: center; }
    </style>
</head>
<body>
    <header>
        <h1><?= e(get_option('companyname')); ?>: <?= e(_l('mks_st_wallboard_today')); ?></h1>
        <div class="clock"><?= e(_dt(date('Y-m-d H:i:s'))); ?></div>
    </header>

    <div class="tiles">
        <div class="tile"><span><?= e(_l('mks_st_kpi_calls')); ?></span><strong><?= (int) $data['calls']; ?></strong></div>
        <div class="tile"><span><?= e(_l('mks_st_kpi_connected')); ?></span><strong><?= (int) $data['connected']; ?></strong></div>
        <div class="tile"><span><?= e(_l('mks_st_kpi_talk_time')); ?></span><strong><?= e(mks_st_duration_label($data['talk'])); ?></strong></div>
        <div class="tile"><span><?= e(_l('mks_st_kpi_missed')); ?></span><strong><?= (int) $data['missed']; ?></strong></div>
        <div class="tile<?= $data['open'] > 0 ? ' alert' : ''; ?>"><span><?= e(_l('mks_st_wallboard_to_return')); ?></span><strong><?= (int) $data['open']; ?></strong></div>
    </div>

    <div class="grid">
        <div class="panel">
            <h2><?= e(_l('mks_st_leaderboard')); ?></h2>
            <?php if (!$data['board']) { ?><div class="empty"><?= e(_l('mks_st_wallboard_quiet')); ?></div><?php } ?>
            <?php foreach ($data['board'] as $mks_i => $mks_row) { ?>
            <div class="row">
                <span class="rank"><?= $mks_i + 1; ?></span>
                <div><?= e($mks_row['name']); ?><div class="bar"><i style="width: <?= $mks_max > 0 ? (int) round($mks_row['calls'] * 100 / $mks_max) : 0; ?>%"></i></div></div>
                <span class="num"><?= (int) $mks_row['calls']; ?> <small class="muted"><?= e(_l('mks_st_kpi_calls')); ?></small></span>
                <span class="num"><?= (int) $mks_row['connected']; ?> <small class="muted"><?= e(_l('mks_st_wallboard_reached')); ?></small></span>
                <span class="num"><?= e(mks_st_duration_label($mks_row['talk'])); ?><?php if ($mks_row['target'] !== null) { ?> <small class="muted"><?= (int) $mks_row['target']; ?>%</small><?php } ?></span>
            </div>
            <?php } ?>
        </div>
        <div class="panel feed">
            <h2><?= e(_l('mks_st_wallboard_latest')); ?></h2>
            <?php if (!$data['latest']) { ?><div class="empty">-</div><?php } ?>
            <?php foreach ($data['latest'] as $mks_call) {
                $mks_class = $mks_call['direction'] === 'incoming' ? 'in' : ($mks_call['direction'] === 'outgoing' ? 'out' : 'miss'); ?>
            <div><span><span class="<?= $mks_class; ?>">&#9679;</span> <?= e($mks_call['name']); ?></span>
                <span class="muted"><?= e(date('H:i', strtotime($mks_call['occurred_at']))); ?>, <?= e(mks_st_duration_label($mks_call['duration'])); ?></span></div>
            <?php } ?>
        </div>
    </div>
</body>
</html>
