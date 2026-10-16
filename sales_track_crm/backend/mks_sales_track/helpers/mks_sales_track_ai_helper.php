<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - AI call insights with Google Gemini.
 *
 * Loaded on demand by the screens, the API-free cron run and Settings.
 * Gemini is called over raw cURL, without streaming, as in the other MKS
 * modules. What reaches the model is decided here, in PHP, never by prompt:
 * the one call's recording, its direction and length, the rep's name, and
 * the module's own settings (rubric, outcome list, competitor and keyword
 * lists). No lead, customer or other record is ever sent.
 *
 * The model returns JSON against a schema; the score is worked out here from
 * the rubric marks rather than trusted from the model. Every call is costed
 * from the usage Gemini reports and counted against the monthly cap before
 * the next one starts.
 */

require_once __DIR__ . '/mks_sales_track_drive_helper.php';

/** Largest recording sent inline (Gemini's request limit is 20 MB). */
define('MKS_ST_AI_MAX_BYTES', 18 * 1048576);

/**
 * @return string
 */
function mks_st_ai_table()
{
    return db_prefix() . 'mks_sales_track_ai';
}

/**
 * @return string|null the Gemini API key
 */
function mks_st_ai_key()
{
    $raw = (string) get_option('mks_sales_track_gemini_key');

    if ($raw === '') {
        return null;
    }

    $CI  = &get_instance();
    $key = $CI->encryption->decrypt($raw);

    return is_string($key) && $key !== '' ? $key : null;
}

/**
 * Switched on, a key saved, and money left this month.
 *
 * @return bool
 */
function mks_st_ai_ready()
{
    return mks_st_enabled('ai_enabled') && mks_st_ai_key() !== null && mks_st_ai_spent() < (float) mks_st_setting('ai_budget', 0);
}

/* =========================================================================
 * SPEND
 * ====================================================================== */

/**
 * US dollars spent on Gemini this calendar month.
 *
 * @return float
 */
function mks_st_ai_spent()
{
    $spend = json_decode((string) get_option('mks_sales_track_ai_spend'), true);
    $month = date('Y-m');

    return is_array($spend) && isset($spend[$month]) ? (float) $spend[$month] : 0.0;
}

/**
 * @param  float $usd
 *
 * @return void
 */
function mks_st_ai_add_spend($usd)
{
    $spend = json_decode((string) get_option('mks_sales_track_ai_spend'), true);
    $spend = is_array($spend) ? $spend : [];
    $month = date('Y-m');

    $spend[$month] = round((isset($spend[$month]) ? (float) $spend[$month] : 0) + (float) $usd, 6);

    mks_st_option_put('mks_sales_track_ai_spend', json_encode(array_slice($spend, -12, null, true)), 0);
}

/**
 * The cost of one request from the usage Gemini reported. Audio input,
 * other input and output (thinking included) are priced separately.
 *
 * @param  array $usage usageMetadata
 *
 * @return array cost, in, out
 */
function mks_st_ai_cost(array $usage)
{
    $audio = 0;
    $input = isset($usage['promptTokenCount']) ? (int) $usage['promptTokenCount'] : 0;

    if (isset($usage['promptTokensDetails']) && is_array($usage['promptTokensDetails'])) {
        foreach ($usage['promptTokensDetails'] as $detail) {
            if (isset($detail['modality'], $detail['tokenCount']) && strtoupper($detail['modality']) === 'AUDIO') {
                $audio += (int) $detail['tokenCount'];
            }
        }
    }

    $output = (isset($usage['candidatesTokenCount']) ? (int) $usage['candidatesTokenCount'] : 0) + (isset($usage['thoughtsTokenCount']) ? (int) $usage['thoughtsTokenCount'] : 0);
    $cost   = ($audio * (float) mks_st_setting('ai_price_audio', '1.00') + max(0, $input - $audio) * (float) mks_st_setting('ai_price_text', '0.30')
        + $output * (float) mks_st_setting('ai_price_output', '2.50')) / 1000000;

    return ['cost' => round($cost, 6), 'in' => $input, 'out' => $output];
}

/**
 * What a call of this length should cost, to check the cap before sending.
 * Gemini counts audio at 32 tokens a second.
 *
 * @param  int $seconds
 *
 * @return float
 */
function mks_st_ai_estimate($seconds)
{
    $audio  = (int) $seconds * 32;
    $output = max(1500, (int) $seconds * 5);

    return ($audio * (float) mks_st_setting('ai_price_audio', '1.00') + 1500 * (float) mks_st_setting('ai_price_text', '0.30')
        + $output * (float) mks_st_setting('ai_price_output', '2.50')) / 1000000;
}

/* =========================================================================
 * GEMINI
 * ====================================================================== */

/**
 * One generateContent request.
 *
 * @param  array $payload
 *
 * @return array status, json, error
 */
function mks_st_ai_request(array $payload)
{
    $key   = mks_st_ai_key();
    $model = (string) mks_st_setting('gemini_model', 'gemini-2.5-flash');

    if ($key === null) {
        return ['status' => 0, 'json' => null, 'headers' => [], 'error' => 'no_key'];
    }

    if (strpos($model, 'gemini-2.5-flash') === 0) {
        // Thinking is billed as output and adds nothing to a transcript.
        $payload['generationConfig']['thinkingConfig'] = ['thinkingBudget' => 0];
    }

    return mks_st_google_request('POST', mks_st_google_url('gemini') . '/v1beta/models/' . rawurlencode($model) . ':generateContent',
        ['Content-Type: application/json', 'x-goog-api-key: ' . $key], json_encode($payload));
}

/**
 * The text of the first candidate, or null.
 *
 * @param  array|null $json
 *
 * @return string|null
 */
function mks_st_ai_text($json)
{
    return is_array($json) && isset($json['candidates'][0]['content']['parts'][0]['text']) ? (string) $json['candidates'][0]['content']['parts'][0]['text'] : null;
}

/**
 * The JSON shape every analysis must have.
 *
 * @return array
 */
function mks_st_ai_schema()
{
    $strings = ['type' => 'ARRAY', 'items' => ['type' => 'STRING']];

    return [
        'type'       => 'OBJECT',
        'properties' => [
            'language'    => ['type' => 'STRING'],
            'transcript'  => ['type' => 'STRING'],
            'summary'     => ['type' => 'STRING'],
            'sentiment'   => ['type' => 'STRING', 'enum' => ['positive', 'neutral', 'negative']],
            'temperature' => ['type' => 'STRING', 'enum' => ['hot', 'warm', 'cold']],
            'objections'  => $strings,
            'next_steps'  => $strings,
            'rubric'      => ['type' => 'ARRAY', 'items' => ['type' => 'OBJECT', 'properties' => [
                'criterion' => ['type' => 'STRING'], 'score' => ['type' => 'INTEGER'], 'note' => ['type' => 'STRING'],
            ], 'required' => ['criterion', 'score']]],
            'flags'       => ['type' => 'ARRAY', 'items' => ['type' => 'OBJECT', 'properties' => [
                'type' => ['type' => 'STRING', 'enum' => ['competitor', 'discount', 'abuse', 'keyword']], 'quote' => ['type' => 'STRING'], 'note' => ['type' => 'STRING'],
            ], 'required' => ['type']]],
            'suggestion'  => ['type' => 'OBJECT', 'properties' => [
                'outcome' => ['type' => 'STRING'], 'note' => ['type' => 'STRING'], 'follow_up_days' => ['type' => 'INTEGER'],
            ]],
        ],
        'required'   => ['language', 'transcript', 'summary', 'sentiment', 'temperature', 'objections', 'next_steps', 'rubric', 'flags', 'suggestion'],
    ];
}

/**
 * The instructions for one call: only this call's facts and the module's
 * own settings.
 *
 * @param  array       $event
 * @param  string|null $rep   the rep's name; looked up when not given
 *
 * @return string
 */
function mks_st_ai_instructions(array $event, $rep = null)
{
    $lines    = function ($key) {
        return array_values(array_filter(array_map('trim', preg_split('/[\r\n]+/', (string) mks_st_setting($key, '')))));
    };
    $outcomes = [];

    foreach (mks_st_outcomes() as $key => $outcome) {
        $outcomes[] = $key . ' (' . $outcome['label'] . ')';
    }

    $rubric      = $lines('ai_rubric') ?: ['Handled the call professionally'];
    $competitors = $lines('ai_competitors');
    $keywords    = $lines('ai_keywords');

    return 'You analyse one recorded sales phone call for ' . get_option('companyname') . '. The company\'s sales rep on the call is '
        . ($rep !== null ? $rep : mks_st_staff_name($event['staff_id'])) . '. The call was ' . ($event['direction'] === 'incoming' ? 'made by the customer to the rep' : 'made by the rep to the customer')
        . ' and lasted ' . mks_st_duration_label($event['duration']) . '. People may speak Hindi, Punjabi, English or a mix of them.' . "\n\n"
        . "Answer with JSON matching the schema:\n"
        . "- language: the main language or languages spoken.\n"
        . "- transcript: the whole conversation as lines starting \"Rep:\" or \"Customer:\", in the language spoken (Latin script is fine for Hindi and Punjabi).\n"
        . "- summary: at most three sentences, in English.\n"
        . "- sentiment: the customer's overall sentiment.\n"
        . "- temperature: how likely the customer is to buy: hot, warm or cold.\n"
        . "- objections: each customer objection, short, in English.\n"
        . "- next_steps: next steps agreed, or the sensible next steps, in English.\n"
        . '- rubric: score each of these criteria 0 (not done), 1 (partly) or 2 (done well), with a short English note: ' . implode('; ', $rubric) . ".\n"
        . '- flags: any competitor mentioned' . ($competitors ? ' (watch for: ' . implode(', ', $competitors) . ')' : '')
        . ', any discount or price promise made by the rep, any abusive or rude language from anyone'
        . ($keywords ? ', and any of these words or phrases: ' . implode(', ', $keywords) : '') . ". Quote at most twelve words. Empty if none.\n"
        . '- suggestion: the outcome key that fits best from ' . implode(', ', $outcomes)
        . ', or an empty string if none fits; a one-sentence note; and follow_up_days, 0 when no follow-up is needed.';
}

/**
 * The audio type Gemini accepts for a recording, or null.
 *
 * @param  array $event
 *
 * @return string|null
 */
function mks_st_ai_audio_type(array $event)
{
    $types = ['wav' => 'audio/wav', 'mp3' => 'audio/mp3', 'm4a' => 'audio/mp4', 'mp4' => 'audio/mp4', 'aac' => 'audio/aac',
        'ogg' => 'audio/ogg', 'oga' => 'audio/ogg', 'opus' => 'audio/ogg', 'flac' => 'audio/flac'];
    $ext   = !empty($event['recording_file']) ? strtolower(pathinfo($event['recording_file'], PATHINFO_EXTENSION))
        : (string) array_search($event['recording_mime'], mks_st_recording_formats(), true);

    return isset($types[$ext]) ? $types[$ext] : null;
}

/**
 * A recording's bytes, from this server or from Drive.
 *
 * @param  array $event
 *
 * @return string|false
 */
function mks_st_recording_bytes(array $event)
{
    if (!empty($event['recording_file'])) {
        $path = mks_st_recording_path($event['recording_file']);

        return $path !== false ? file_get_contents($path) : false;
    }

    if (!empty($event['drive_file_id'])) {
        $access = mks_st_drive_access_token();

        if ($access['token'] === '' || !function_exists('curl_init')) {
            return false;
        }

        $curl = curl_init(mks_st_google_url('apis') . '/drive/v3/files/' . rawurlencode($event['drive_file_id']) . '?alt=media');
        curl_setopt_array($curl, [CURLOPT_HTTPHEADER => ['Authorization: Bearer ' . $access['token']], CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CONNECTTIMEOUT => 10, CURLOPT_TIMEOUT => 300]);
        $bytes  = curl_exec($curl);
        $status = (int) curl_getinfo($curl, CURLINFO_HTTP_CODE);
        curl_close($curl);

        return $status === 200 ? $bytes : false;
    }

    return false;
}

/* =========================================================================
 * ANALYSIS
 * ====================================================================== */

/**
 * Analyse one call and store what was learned.
 *
 * @param  array $event
 *
 * @return array ok, error (code)
 */
function mks_st_ai_analyse(array $event)
{
    $CI    = &get_instance();
    $table = mks_st_events_table();
    $fail  = function ($status, $note) use ($CI, $table, $event) {
        $CI->db->where('id', (int) $event['id'])->update($table, ['ai_status' => $status, 'ai_at' => date('Y-m-d H:i:s'), 'ai_note' => mb_substr($note, 0, 250, 'UTF-8')]);

        return ['ok' => false, 'error' => $note];
    };

    if (!mks_st_enabled('ai_enabled') || mks_st_ai_key() === null) {
        return ['ok' => false, 'error' => 'not_ready'];
    }

    if ($event['recording_status'] !== 'stored' || !in_array($event['kind'], ['call'], true)) {
        return $fail('skipped', 'no_recording');
    }

    if ((int) $event['duration'] > (int) mks_st_setting('ai_max_minutes', 20) * 60) {
        return $fail('skipped', 'too_long');
    }

    $type = mks_st_ai_audio_type($event);

    if ($type === null) {
        return $fail('skipped', 'format_unsupported');
    }

    if (mks_st_ai_spent() + mks_st_ai_estimate($event['duration']) > (float) mks_st_setting('ai_budget', 0)) {
        return $fail('capped', 'monthly_cap');
    }

    $bytes = mks_st_recording_bytes($event);

    if ($bytes === false || $bytes === '') {
        return $fail('failed', 'recording_unavailable');
    }

    if (strlen($bytes) > MKS_ST_AI_MAX_BYTES) {
        return $fail('skipped', 'too_large');
    }

    $reply = mks_st_ai_request([
        'systemInstruction' => ['parts' => [['text' => mks_st_ai_instructions($event)]]],
        'contents'          => [['role' => 'user', 'parts' => [
            ['inline_data' => ['mime_type' => $type, 'data' => base64_encode($bytes)]],
            ['text' => 'Analyse this call.'],
        ]]],
        'generationConfig'  => ['temperature' => 0.2, 'responseMimeType' => 'application/json', 'responseSchema' => mks_st_ai_schema()],
    ]);

    unset($bytes);

    $usage = is_array($reply['json']) && isset($reply['json']['usageMetadata']) ? mks_st_ai_cost($reply['json']['usageMetadata']) : ['cost' => 0, 'in' => 0, 'out' => 0];

    if ($usage['cost'] > 0) {
        mks_st_ai_add_spend($usage['cost']);
    }

    $text = mks_st_ai_text($reply['json']);
    $data = $text !== null ? json_decode($text, true) : null;

    if ($reply['status'] !== 200 || !is_array($data) || !isset($data['summary'], $data['rubric'])) {
        return $fail('failed', $reply['status'] !== 200 ? mks_st_google_error($reply) : 'unreadable_answer');
    }

    $analysis = mks_st_ai_normalise($data);

    $CI->db->replace(mks_st_ai_table(), [
        'event_id'   => (int) $event['id'],
        'model'      => (string) mks_st_setting('gemini_model', ''),
        'language'   => mb_substr((string) $data['language'], 0, 40, 'UTF-8'),
        'transcript' => mb_substr((string) $data['transcript'], 0, 200000, 'UTF-8'),
        'analysis'   => json_encode($analysis),
        'tokens_in'  => $usage['in'],
        'tokens_out' => $usage['out'],
        'cost'       => $usage['cost'],
        'created_at' => date('Y-m-d H:i:s'),
    ]);

    $flags = array_values(array_unique(array_column($analysis['flags'], 'type')));

    $CI->db->where('id', (int) $event['id'])->update($table, [
        'ai_status'      => 'done',
        'ai_at'          => date('Y-m-d H:i:s'),
        'ai_score'       => $analysis['score'],
        'ai_sentiment'   => $analysis['sentiment'],
        'ai_temperature' => $analysis['temperature'],
        'ai_flags'       => $flags ? implode(',', $flags) : null,
        'ai_cost'        => $usage['cost'],
        'ai_note'        => null,
    ]);

    if ($flags && mks_st_enabled('ai_alerts')) {
        mks_st_notify(mks_st_recipients((int) $event['staff_id'], (string) mks_st_setting('alert_to', 'managers')), 'mks_st_note_ai_flag',
            [mks_st_staff_name($event['staff_id']), mks_st_format_number($event['number'] ?: $event['number_raw']), implode(', ', $flags), '#' . (int) $event['id']],
            MKS_SALES_TRACK_MODULE_NAME . '/calls', mks_st_enabled('alert_email'));
    }

    return ['ok' => true, 'error' => ''];
}

/**
 * Clip and check what the model returned, and work out the score from the
 * rubric marks.
 *
 * @param  array $data
 *
 * @return array
 */
function mks_st_ai_normalise(array $data)
{
    $short = function ($value, $max) {
        return mb_substr(trim(strip_tags((string) $value)), 0, $max, 'UTF-8');
    };
    $list  = function ($items, $max) use ($short) {
        return array_slice(array_values(array_filter(array_map(function ($item) use ($short) {
            return is_scalar($item) ? $short($item, 200) : '';
        }, is_array($items) ? $items : []))), 0, $max);
    };

    $rubric = [];

    foreach (is_array($data['rubric']) ? array_slice($data['rubric'], 0, 12) : [] as $row) {
        if (is_array($row) && isset($row['criterion'])) {
            $rubric[] = ['criterion' => $short($row['criterion'], 120), 'score' => max(0, min(2, (int) (isset($row['score']) ? $row['score'] : 0))),
                'note' => $short(isset($row['note']) ? $row['note'] : '', 200)];
        }
    }

    $flags = [];

    foreach (is_array($data['flags']) ? array_slice($data['flags'], 0, 10) : [] as $row) {
        if (is_array($row) && isset($row['type']) && in_array($row['type'], ['competitor', 'discount', 'abuse', 'keyword'], true)) {
            $flags[] = ['type' => $row['type'], 'quote' => $short(isset($row['quote']) ? $row['quote'] : '', 160), 'note' => $short(isset($row['note']) ? $row['note'] : '', 200)];
        }
    }

    $suggestion = isset($data['suggestion']) && is_array($data['suggestion']) ? $data['suggestion'] : [];
    $outcome    = isset($suggestion['outcome']) && isset(mks_st_outcomes()[(string) $suggestion['outcome']]) ? (string) $suggestion['outcome'] : '';
    $marks      = array_sum(array_column($rubric, 'score'));

    return [
        'summary'     => $short($data['summary'], 1200),
        'sentiment'   => in_array($data['sentiment'], ['positive', 'neutral', 'negative'], true) ? $data['sentiment'] : 'neutral',
        'temperature' => in_array($data['temperature'], ['hot', 'warm', 'cold'], true) ? $data['temperature'] : 'warm',
        'objections'  => $list($data['objections'], 10),
        'next_steps'  => $list($data['next_steps'], 10),
        'rubric'      => $rubric,
        'score'       => $rubric ? (int) round($marks * 100 / (2 * count($rubric))) : 0,
        'flags'       => $flags,
        'suggestion'  => ['outcome' => $outcome, 'note' => $short(isset($suggestion['note']) ? $suggestion['note'] : '', 300),
            'follow_up_days' => max(0, min(60, (int) (isset($suggestion['follow_up_days']) ? $suggestion['follow_up_days'] : 0)))],
    ];
}

/**
 * The stored insights for one call, or null.
 *
 * @param  int $eventId
 *
 * @return array|null transcript, language, analysis, cost, model
 */
function mks_st_ai_get($eventId)
{
    $CI  = &get_instance();
    $row = $CI->db->where('event_id', (int) $eventId)->get(mks_st_ai_table())->row_array();

    if (!$row) {
        return null;
    }

    $row['analysis'] = mks_st_decode($row['analysis']);

    return $row;
}

/**
 * May the viewer read a call's insights? Reps see their own when Settings
 * allow it.
 *
 * @param  array $event
 *
 * @return bool
 */
function mks_st_ai_visible(array $event)
{
    return mks_st_event_visible($event) && (!mks_st_scope_is_own() || mks_st_enabled('ai_rep_view'));
}

/**
 * May the viewer send a call to Gemini? Managers and team leads, for calls
 * they can see.
 *
 * @param  array $event
 *
 * @return bool
 */
function mks_st_ai_can_run(array $event)
{
    return mks_st_enabled('ai_enabled') && mks_st_event_visible($event) && !mks_st_scope_is_own();
}

/* =========================================================================
 * THE AUTOMATIC RUN, THE KEY TEST, COACHING
 * ====================================================================== */

/**
 * From the cron run: analyse a few new recordings by the rule in Settings,
 * stopping well inside a web cron's time limit.
 *
 * @return int analysed
 */
function mks_st_ai_run()
{
    $mode = (string) mks_st_setting('ai_auto', 'crm');

    if ($mode === 'manual' || !mks_st_ai_ready()) {
        return 0;
    }

    $CI    = &get_instance();
    $start = time();
    $done  = 0;

    $queue = $CI->db->query('SELECT * FROM ' . mks_st_events_table() . " WHERE ai_status IS NULL AND kind = 'call' AND recording_status = 'stored'"
        . " AND source <> 'demo' AND duration >= " . (int) mks_st_setting('ai_min_seconds', 60) . ' AND duration <= ' . (int) mks_st_setting('ai_max_minutes', 20) * 60
        . ($mode === 'crm' ? ' AND rel_type IS NOT NULL' : '') . ' ORDER BY occurred_at DESC LIMIT 3')->result_array();

    foreach ($queue as $event) {
        if (time() - $start > 40 || !mks_st_ai_ready()) {
            break;
        }

        if (mks_st_ai_analyse($event)['ok']) {
            $done++;
        }
    }

    return $done;
}

/**
 * The models this key may call generateContent on, so an administrator picks
 * one that exists: Gemini model names are retired over time, and a retired
 * one answers with a 404 that looks like a fault in the module.
 *
 * @return array|string [name, label], or an error
 */
function mks_st_ai_models()
{
    $key = mks_st_ai_key();

    if ($key === null) {
        return 'no_key';
    }

    $reply = mks_st_google_request('GET', mks_st_google_url('gemini') . '/v1beta/models?pageSize=200', ['x-goog-api-key: ' . $key]);

    if ($reply['status'] !== 200 || !isset($reply['json']['models']) || !is_array($reply['json']['models'])) {
        return mks_st_google_error($reply);
    }

    $out = [];

    foreach ($reply['json']['models'] as $model) {
        $methods = isset($model['supportedGenerationMethods']) ? (array) $model['supportedGenerationMethods'] : [];
        $name    = isset($model['name']) ? preg_replace('#^models/#', '', (string) $model['name']) : '';

        if ($name !== '' && in_array('generateContent', $methods, true) && preg_match('/^gemini-/', $name)) {
            $out[] = ['name' => $name, 'label' => isset($model['displayName']) ? (string) $model['displayName'] : $name];
        }
    }

    return $out;
}

/**
 * Check the key and model with a tiny request.
 *
 * @return true|string
 */
function mks_st_ai_test()
{
    $reply = mks_st_ai_request(['contents' => [['role' => 'user', 'parts' => [['text' => 'Reply with the single word OK.']]]], 'generationConfig' => ['temperature' => 0]]);

    if (is_array($reply['json']) && isset($reply['json']['usageMetadata'])) {
        mks_st_ai_add_spend(mks_st_ai_cost($reply['json']['usageMetadata'])['cost']);
    }

    return $reply['status'] === 200 && mks_st_ai_text($reply['json']) !== null ? true : mks_st_google_error($reply);
}

/**
 * Weekly coaching notes for each rep with enough analysed calls, written by
 * Gemini from the week's figures and sent to their team leads (or managers).
 *
 * @param  array $range from, to
 *
 * @return int notes sent
 */
function mks_st_ai_coaching(array $range)
{
    if (!mks_st_enabled('ai_coaching') || !mks_st_ai_ready()) {
        return 0;
    }

    $CI   = &get_instance();
    $rows = $CI->db->query('SELECT e.staff_id, e.ai_score, e.ai_temperature, a.analysis FROM ' . mks_st_events_table() . ' e JOIN ' . mks_st_ai_table() . ' a ON a.event_id = e.id'
        . " WHERE e.ai_status = 'done' AND e.occurred_at >= '" . $range['from'] . " 00:00:00' AND e.occurred_at <= '" . $range['to'] . " 23:59:59'")->result_array();

    $people = [];

    foreach ($rows as $row) {
        $people[(int) $row['staff_id']][] = $row;
    }

    $sent = 0;

    foreach ($people as $staffId => $calls) {
        if (count($calls) < 3 || !mks_st_ai_ready()) {
            continue;
        }

        $criteria   = [];
        $objections = [];

        foreach ($calls as $call) {
            $analysis = mks_st_decode($call['analysis']);

            foreach (isset($analysis['rubric']) ? $analysis['rubric'] : [] as $mark) {
                $criteria[$mark['criterion']][] = (int) $mark['score'];
            }

            foreach (isset($analysis['objections']) ? $analysis['objections'] : [] as $objection) {
                $key              = strtolower($objection);
                $objections[$key] = (isset($objections[$key]) ? $objections[$key] : 0) + 1;
            }
        }

        arsort($objections);

        $facts = 'Calls analysed: ' . count($calls) . '. Average score: ' . (int) round(array_sum(array_column($calls, 'ai_score')) / count($calls)) . "/100.\n"
            . 'Hot, warm, cold: ' . implode(', ', array_map(function ($t) use ($calls) {
                return count(array_filter($calls, function ($c) use ($t) {
                    return $c['ai_temperature'] === $t;
                }));
            }, ['hot', 'warm', 'cold'])) . ".\nRubric averages (0 to 2):\n";

        foreach ($criteria as $criterion => $marks) {
            $facts .= '- ' . $criterion . ': ' . round(array_sum($marks) / count($marks), 1) . "\n";
        }

        $facts .= 'Most common objections: ' . implode('; ', array_slice(array_keys($objections), 0, 5)) . '.';

        $reply = mks_st_ai_request([
            'systemInstruction' => ['parts' => [['text' => 'You are a sales coach. Write four to six short, specific coaching points in plain English for a team lead about one rep, from the figures given. No headings, no greeting, one point per line starting with "- ".']]],
            'contents'          => [['role' => 'user', 'parts' => [['text' => 'Rep: ' . mks_st_staff_name($staffId) . "\n" . $facts]]]],
            'generationConfig'  => ['temperature' => 0.4],
        ]);

        if (is_array($reply['json']) && isset($reply['json']['usageMetadata'])) {
            mks_st_ai_add_spend(mks_st_ai_cost($reply['json']['usageMetadata'])['cost']);
        }

        $notes = mks_st_ai_text($reply['json']);

        if ($reply['status'] !== 200 || $notes === null) {
            continue;
        }

        $subject = _l('mks_st_mail_coaching', [mks_st_staff_name($staffId), _d($range['from']) . ' - ' . _d($range['to'])]);
        $html    = '<div style="font-family:Arial,Helvetica,sans-serif;color:#0f172a;max-width:680px"><h2 style="font-size:18px">' . e($subject) . '</h2>'
            . '<p style="color:#64748b;font-size:13px">' . nl2br(e($facts)) . '</p><div style="font-size:14px;line-height:1.6">' . nl2br(e(trim($notes))) . '</div></div>';

        $CI->load->model('emails_model');

        foreach (mks_st_recipients($staffId, 'team_leads') as $leadId) {
            $lead = $CI->db->select('email')->where('staffid', (int) $leadId)->where('active', 1)->get(db_prefix() . 'staff')->row();

            if ($lead && $lead->email !== '' && $CI->emails_model->send_simple_email($lead->email, $subject, $html)) {
                $sent++;
            }
        }
    }

    return $sent;
}
