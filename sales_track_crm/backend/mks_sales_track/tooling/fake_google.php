<?php

/**
 * MKS Sales Track - a stand-in for Google, for testing Drive and push end to
 * end without reaching Google.
 *
 *   php -S 127.0.0.1:8090 tooling/fake_google.php
 *
 * and, in the test CRM's application/config/app-config.php only:
 *
 *   define('MKS_ST_GOOGLE_BASE', 'http://127.0.0.1:8090');
 *
 * It answers the calls Sales Track makes: OAuth token, refresh and revoke,
 * userinfo, Drive folder search and creation, resumable upload, file download
 * with ranges, and FCM send. State lives in the system temp folder; anything
 * else answers 404. Never deploy it.
 */

if (PHP_SAPI !== 'cli-server') {
    http_response_code(404);
    exit;
}

$dir   = sys_get_temp_dir() . '/mks_st_fake_google';
$state = $dir . '/state.json';

if (!is_dir($dir)) {
    mkdir($dir, 0700, true);
}

$db = is_file($state) ? json_decode(file_get_contents($state), true) : null;
$db = is_array($db) ? $db : ['files' => [], 'sessions' => [], 'messages' => [], 'tokens' => 0];

$method = $_SERVER['REQUEST_METHOD'];
$path   = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$auth   = isset($_SERVER['HTTP_AUTHORIZATION']) ? $_SERVER['HTTP_AUTHORIZATION'] : '';
$base   = 'http://' . $_SERVER['HTTP_HOST'];

$reply = function ($status, $data, array $headers = []) use (&$db, $state) {
    file_put_contents($state, json_encode($db));
    header('Content-Type: application/json');

    // Headers first: PHP turns any response carrying a Location header into
    // a 302 unless the status is set afterwards. Google answers 200.
    foreach ($headers as $header) {
        header($header);
    }

    http_response_code($status);

    echo json_encode($data);
    exit;
};

$authorised = function () use ($auth) {
    return strpos($auth, 'Bearer fake-access-') === 0;
};

if ($method === 'POST' && $path === '/token') {
    $db['tokens']++;
    $grant = isset($_POST['grant_type']) ? $_POST['grant_type'] : '';

    if ($grant === 'authorization_code') {
        if (($_POST['code'] ?? '') !== 'good-code') {
            $reply(400, ['error' => 'invalid_grant', 'error_description' => 'Bad code']);
        }

        $reply(200, ['access_token' => 'fake-access-' . $db['tokens'], 'refresh_token' => 'fake-refresh', 'expires_in' => 3600]);
    }

    if ($grant === 'refresh_token' || $grant === 'urn:ietf:params:oauth:grant-type:jwt-bearer') {
        $reply(200, ['access_token' => 'fake-access-' . $db['tokens'], 'expires_in' => 3600]);
    }

    $reply(400, ['error' => 'unsupported_grant_type']);
}

if ($method === 'POST' && $path === '/revoke') {
    $reply(200, []);
}

if ($method === 'GET' && $path === '/v1beta/models') {
    if (($_SERVER['HTTP_X_GOOG_API_KEY'] ?? '') !== 'good-gemini-key') {
        $reply(400, ['error' => ['code' => 400, 'message' => 'API key not valid. Please pass a valid API key.', 'status' => 'INVALID_ARGUMENT']]);
    }

    $reply(200, ['models' => [
        ['name' => 'models/gemini-3.1-flash-lite', 'displayName' => 'Gemini 3.1 Flash-Lite', 'supportedGenerationMethods' => ['generateContent', 'countTokens']],
        ['name' => 'models/gemini-2.5-flash', 'displayName' => 'Gemini 2.5 Flash', 'supportedGenerationMethods' => ['generateContent']],
        ['name' => 'models/text-embedding-004', 'displayName' => 'Text Embedding 004', 'supportedGenerationMethods' => ['embedContent']],
    ]]);
}

if ($method === 'POST' && preg_match('#^/v1beta/models/([\w.-]+):generateContent$#', $path, $m)) {
    if (($_SERVER['HTTP_X_GOOG_API_KEY'] ?? '') !== 'good-gemini-key') {
        $reply(400, ['error' => ['code' => 400, 'message' => 'API key not valid. Please pass a valid API key.', 'status' => 'INVALID_ARGUMENT']]);
    }

    $body  = json_decode(file_get_contents('php://input'), true);
    $parts = $body['contents'][0]['parts'] ?? [];
    $audio = isset($parts[0]['inline_data']['data']) ? strlen(base64_decode($parts[0]['inline_data']['data'])) : 0;
    $db['gemini'][] = ['model' => $m[1], 'audio_bytes' => $audio, 'schema' => isset($body['generationConfig']['responseSchema']),
        'thinking' => $body['generationConfig']['thinkingConfig'] ?? null, 'instructions' => $body['systemInstruction']['parts'][0]['text'] ?? ''];

    $answer = $audio > 0 ? json_encode([
        'language'    => 'Hinglish',
        'transcript'  => "Rep: Namaste, main Sales Track se baat kar raha hoon.\nCustomer: Haan ji, price kya hai?\nRep: Main aapko 10% discount de sakta hoon.",
        'summary'     => 'The customer asked about the price; the rep offered a discount and agreed to send a quotation.',
        'sentiment'   => 'positive',
        'temperature' => 'hot',
        'objections'  => ['Price is too high'],
        'next_steps'  => ['Send the quotation today'],
        'rubric'      => [['criterion' => 'Greeted the customer', 'score' => 2, 'note' => 'Warm greeting'], ['criterion' => 'Agreed a next step', 'score' => 1, 'note' => 'Vague']],
        'flags'       => [['type' => 'discount', 'quote' => 'main aapko 10% discount de sakta hoon', 'note' => 'Discount offered without approval']],
        'suggestion'  => ['outcome' => 'interested', 'note' => 'Wants a quotation', 'follow_up_days' => 1],
    ]) : (strpos(json_encode($parts), 'coach') !== false ? "- Ask about needs earlier.\n- Confirm a dated next step." : 'OK');

    $reply(200, ['candidates' => [['content' => ['parts' => [['text' => $answer]], 'role' => 'model']]],
        'usageMetadata' => ['promptTokenCount' => 2000 + intdiv($audio, 100), 'candidatesTokenCount' => 400,
            'promptTokensDetails' => [['modality' => 'TEXT', 'tokenCount' => 2000], ['modality' => 'AUDIO', 'tokenCount' => intdiv($audio, 100)]]]]);
}

if (!$authorised()) {
    $reply(401, ['error' => ['code' => 401, 'message' => 'Invalid credentials', 'status' => 'UNAUTHENTICATED']]);
}

if ($method === 'GET' && $path === '/oauth2/v2/userinfo') {
    $reply(200, ['email' => 'recordings@makes360.test']);
}

if ($method === 'GET' && $path === '/drive/v3/files') {
    $q     = isset($_GET['q']) ? $_GET['q'] : '';
    $found = [];

    if (preg_match("/^name = '((?:[^'\\\\]|\\\\.)*)' and mimeType = 'application\\/vnd.google-apps.folder' and '([^']+)' in parents/", $q, $m)) {
        $name = stripslashes($m[1]);

        foreach ($db['files'] as $id => $file) {
            if ($file['folder'] && $file['name'] === $name && $file['parent'] === $m[2]) {
                $found[] = ['id' => $id];
            }
        }
    }

    $reply(200, ['files' => $found]);
}

if ($method === 'POST' && $path === '/drive/v3/files') {
    $meta = json_decode(file_get_contents('php://input'), true);
    $id   = 'folder' . (count($db['files']) + 1);

    $db['files'][$id] = ['name' => $meta['name'], 'parent' => $meta['parents'][0], 'folder' => true];
    $reply(200, ['id' => $id]);
}

if ($method === 'POST' && $path === '/upload/drive/v3/files') {
    $meta    = json_decode(file_get_contents('php://input'), true);
    $session = 'up' . (count($db['sessions']) + 1);

    $db['sessions'][$session] = ['name' => $meta['name'], 'parent' => $meta['parents'][0], 'type' => $_SERVER['HTTP_X_UPLOAD_CONTENT_TYPE'] ?? ''];
    $reply(200, [], ['Location: ' . $base . '/upload/session/' . $session]);
}

if ($method === 'PUT' && preg_match('#^/upload/session/(\w+)$#', $path, $m) && isset($db['sessions'][$m[1]])) {
    $bytes = file_get_contents('php://input');
    $id    = 'file' . (count($db['files']) + 1);

    file_put_contents($dir . '/' . $id, $bytes);
    $db['files'][$id] = ['name' => $db['sessions'][$m[1]]['name'], 'parent' => $db['sessions'][$m[1]]['parent'], 'folder' => false, 'type' => $db['sessions'][$m[1]]['type']];
    $reply(200, ['id' => $id, 'size' => (string) strlen($bytes), 'md5Checksum' => md5($bytes)]);
}

if ($method === 'GET' && preg_match('#^/drive/v3/files/(\w+)$#', $path, $m) && isset($db['files'][$m[1]]) && !$db['files'][$m[1]]['folder']) {
    $bytes = file_get_contents($dir . '/' . $m[1]);
    $size  = strlen($bytes);
    $range = isset($_SERVER['HTTP_RANGE']) ? $_SERVER['HTTP_RANGE'] : '';

    file_put_contents($state, json_encode($db));

    if (preg_match('/^bytes=(\d+)-(\d*)$/', $range, $r)) {
        $start = (int) $r[1];
        $end   = $r[2] === '' ? $size - 1 : min((int) $r[2], $size - 1);

        http_response_code(206);
        header('Content-Range: bytes ' . $start . '-' . $end . '/' . $size);
        header('Content-Length: ' . ($end - $start + 1));
        echo substr($bytes, $start, $end - $start + 1);
        exit;
    }

    header('Content-Length: ' . $size);
    echo $bytes;
    exit;
}

if ($method === 'POST' && preg_match('#^/v1/projects/([\w-]+)/messages:send$#', $path, $m)) {
    $db['messages'][] = json_decode(file_get_contents('php://input'), true);
    $reply(200, ['name' => 'projects/' . $m[1] . '/messages/' . count($db['messages'])]);
}

$reply(404, ['error' => ['code' => 404, 'message' => 'Not found in the stand-in', 'status' => 'NOT_FOUND']]);
