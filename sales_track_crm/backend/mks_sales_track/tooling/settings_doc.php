<?php

/**
 * MKS Sales Track - writes docs/SETTINGS.md from config/settings_schema.php.
 *
 *   php tooling/settings_doc.php           write docs/SETTINGS.md
 *   php tooling/settings_doc.php --check   exit 1 if the file is out of date
 *
 * The schema is the one place a setting is defined, so the reference is
 * generated rather than written by hand, and the gates fail when someone
 * changes the schema without regenerating it.
 */

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

if (!defined('BASEPATH')) {
    define('BASEPATH', __DIR__);
}

$root   = dirname(__DIR__);
$schema = include $root . '/config/settings_schema.php';
$lang   = [];

include $root . '/language/english/mks_sales_track_lang.php';

$text = function ($key) use ($lang) {
    $value = isset($lang[$key]) ? $lang[$key] : $key;

    return str_replace(['%%', '%s', '|'], ['%', 'N', '/'], $value);
};

$out   = [];
$out[] = '# Sales Track - Settings Reference';
$out[] = '';
$out[] = 'Generated from `config/settings_schema.php` by `php tooling/settings_doc.php`.';
$out[] = 'Do not edit by hand: change the schema and regenerate. The gates fail when';
$out[] = 'this file and the schema disagree.';
$out[] = '';
$out[] = 'Settings live on Sales Track > Settings, stored as one autoloaded JSON option';
$out[] = '(`mks_sales_track_settings`). "Phones" marks settings sent to every paired';
$out[] = 'phone through the config call.';

foreach ($schema['sections'] as $sectionKey => $section) {
    $out[] = '';
    $out[] = '## ' . $text($section['label']);
    $out[] = '';
    $out[] = $text($section['intro']);
    $out[] = '';
    $out[] = '| Setting | Key | Type | Default | Phones | Since | What it does |';
    $out[] = '| --- | --- | --- | --- | --- | --- | --- |';

    foreach ($schema['fields'] as $key => $field) {
        if ($field['section'] !== $sectionKey || $field['type'] === 'internal') {
            continue;
        }

        $type = $field['type'];

        if ($type === 'number') {
            $type .= ' ' . $field['min'] . '-' . $field['max'] . (isset($field['unit']) ? ' ' . $text($field['unit']) : '');
        } elseif ($type === 'choice') {
            $type .= ': ' . implode(', ', array_keys($field['options']));
        } elseif (isset($field['clean'])) {
            $type .= ' (' . $field['clean'] . ')';
        }

        $default = $field['default'];

        if ($field['type'] === 'switch') {
            $default = $default ? 'On' : 'Off';
        } elseif ($field['type'] === 'days') {
            $names   = [1 => 'Mon', 2 => 'Tue', 3 => 'Wed', 4 => 'Thu', 5 => 'Fri', 6 => 'Sat', 7 => 'Sun'];
            $default = implode(', ', array_map(function ($day) use ($names) {
                return $names[$day];
            }, $default));
        } elseif ($field['type'] === 'outcomes') {
            $default = implode(', ', array_column($default, 'label'));
        } elseif (in_array($field['type'], ['lead_status', 'lead_source'], true) && (int) $default === 0) {
            $default = '(Perfex default)';
        } elseif (is_array($default) || $default === '' || ($field['type'] === 'staff' && (int) $default === 0)) {
            $default = '(none)';
        }

        $out[] = '| ' . $text($field['label']) . ' | `' . $key . '` | ' . $type . ' | ' . $default . ' | '
            . (!empty($field['app']) ? 'Yes' : '') . ' | ' . $field['since'] . ' | ' . $text($field['hint']) . ' |';
    }
}

$out[] = '';

$doc  = implode("\n", $out);
$path = $root . '/docs/SETTINGS.md';

if (in_array('--check', $argv, true)) {
    if (!is_file($path) || file_get_contents($path) !== $doc) {
        fwrite(STDERR, "docs/SETTINGS.md is out of date: run php tooling/settings_doc.php\n");
        exit(1);
    }

    echo "docs/SETTINGS.md matches the schema\n";
    exit(0);
}

file_put_contents($path, $doc);
echo "Wrote docs/SETTINGS.md (" . count($schema['fields']) . " schema fields)\n";
