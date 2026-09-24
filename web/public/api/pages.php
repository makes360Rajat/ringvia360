<?php
declare(strict_types=1);

/**
 * RingVia360 — Site Pages / CMS Content API
 * 
 * All website content is stored in the `site_pages` MySQL table.
 * NO content is hardcoded in the frontend or PHP arrays — it ALL comes from DB.
 *
 * Endpoints:
 *   GET  ?action=all                → All active sections grouped by page_key
 *   GET  ?action=page&page=home     → Single page sections
 *   POST {action:save, ...}         → Upsert a section
 *   POST {action:delete, id:...}    → Delete a section
 *   POST {action:reset_defaults}    → Re-seed CMS content from setup_db.php
 */

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, X-Tenant-Id');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit(); }

require_once __DIR__ . '/db.php';

$connInfo = getDatabaseConnection();
$db       = $connInfo['pdo'];
$driver   = $connInfo['driver'];

// ── Parse Request ──────────────────────────────────────────
$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? '';

$body = [];
if ($method === 'POST') {
    $raw = file_get_contents('php://input');
    $body = json_decode($raw, true) ?? [];
    if (empty($body) && !empty($_POST)) {
        $body = $_POST;
    }
    if (empty($action)) {
        $action = $body['action'] ?? '';
    }
}

// ── Helper: send JSON ──────────────────────────────────────
function respond(array $data, int $status = 200): never {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit();
}

// ── Ensure table exists (auto-create if missing) ───────────
function ensureSitePagesTable(PDO $db, string $driver): void {
    if ($driver === 'sqlite') {
        $db->exec("
            CREATE TABLE IF NOT EXISTS `site_pages` (
                `id`               TEXT PRIMARY KEY,
                `page_key`         TEXT NOT NULL,
                `page_title`       TEXT NOT NULL,
                `section_key`      TEXT NOT NULL,
                `content_title`    TEXT DEFAULT NULL,
                `content_subtitle` TEXT DEFAULT NULL,
                `body_text`        TEXT DEFAULT NULL,
                `media_url`        TEXT DEFAULT NULL,
                `json_data`        TEXT DEFAULT NULL,
                `display_order`    INTEGER NOT NULL DEFAULT 0,
                `is_active`        INTEGER NOT NULL DEFAULT 1,
                `created_at`       TEXT DEFAULT CURRENT_TIMESTAMP,
                `updated_at`       TEXT DEFAULT CURRENT_TIMESTAMP
            );
            CREATE INDEX IF NOT EXISTS `idx_sp_page_section` ON `site_pages` (`page_key`, `section_key`);
            CREATE INDEX IF NOT EXISTS `idx_sp_page_order` ON `site_pages` (`page_key`, `display_order`);
        ");
    } else {
        $db->exec("
            CREATE TABLE IF NOT EXISTS `site_pages` (
                `id`               VARCHAR(128)   NOT NULL PRIMARY KEY,
                `page_key`         VARCHAR(64)    NOT NULL,
                `page_title`       VARCHAR(255)   NOT NULL,
                `section_key`      VARCHAR(64)    NOT NULL,
                `content_title`    VARCHAR(512)   DEFAULT NULL,
                `content_subtitle` TEXT           DEFAULT NULL,
                `body_text`        LONGTEXT       DEFAULT NULL,
                `media_url`        VARCHAR(512)   DEFAULT NULL,
                `json_data`        LONGTEXT       DEFAULT NULL,
                `display_order`    INT            NOT NULL DEFAULT 0,
                `is_active`        TINYINT        NOT NULL DEFAULT 1,
                `created_at`       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `updated_at`       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX `idx_sp_page_section` (`page_key`, `section_key`),
                INDEX `idx_sp_page_order`   (`page_key`, `display_order`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ");
    }
}

try {
    ensureSitePagesTable($db, $driver);
} catch (Throwable $e) {
    respond(['success' => false, 'error' => 'Table init failed: ' . $e->getMessage()], 500);
}

// ─────────────────────────────────────────────────────────────
// GET all → grouped by page_key
// ─────────────────────────────────────────────────────────────
if ($method === 'GET' && ($action === 'all' || $action === '')) {
    try {
        $rows = $db->query("
            SELECT id, page_key, page_title, section_key,
                   content_title, content_subtitle, body_text,
                   media_url, json_data, display_order, is_active,
                   updated_at
            FROM `site_pages`
            WHERE is_active = 1
            ORDER BY page_key ASC, display_order ASC
        ")->fetchAll();

        $grouped = [];
        foreach ($rows as $r) {
            $pk = $r['page_key'];
            if (!isset($grouped[$pk])) {
                $grouped[$pk] = [
                    'page_key'   => $pk,
                    'page_title' => $r['page_title'],
                    'sections'   => [],
                ];
            }
            $grouped[$pk]['sections'][$r['section_key']] = [
                'id'               => $r['id'],
                'page_key'         => $r['page_key'],
                'page_title'       => $r['page_title'],
                'section_key'      => $r['section_key'],
                'title'            => $r['content_title'],
                'subtitle'         => $r['content_subtitle'],
                'body'             => $r['body_text'],
                'media_url'        => $r['media_url'],
                'data'             => $r['json_data'] ? json_decode($r['json_data'], true) : null,
                'order'            => (int) $r['display_order'],
                'is_active'        => (bool) $r['is_active'],
                'updated_at'       => $r['updated_at'],
            ];
        }

        respond([
            'success' => true,
            'driver'  => $driver,
            'count'   => count($rows),
            'pages'   => array_values($grouped),
        ]);
    } catch (Throwable $e) {
        respond(['success' => false, 'error' => $e->getMessage()], 500);
    }
}

// ─────────────────────────────────────────────────────────────
// GET page → single page by key
// ─────────────────────────────────────────────────────────────
if ($method === 'GET' && $action === 'page') {
    $pageKey = trim($_GET['page'] ?? '');
    if (!$pageKey) {
        respond(['success' => false, 'error' => 'Missing page param'], 400);
    }
    try {
        $stmt = $db->prepare("
            SELECT * FROM `site_pages`
            WHERE page_key = :pk AND is_active = 1
            ORDER BY display_order ASC
        ");
        $stmt->execute([':pk' => $pageKey]);
        $rows = $stmt->fetchAll();

        $sections = [];
        foreach ($rows as $r) {
            $sections[$r['section_key']] = [
                'id'          => $r['id'],
                'section_key' => $r['section_key'],
                'title'       => $r['content_title'],
                'subtitle'    => $r['content_subtitle'],
                'body'        => $r['body_text'],
                'media_url'   => $r['media_url'],
                'data'        => $r['json_data'] ? json_decode($r['json_data'], true) : null,
                'order'       => (int) $r['display_order'],
                'is_active'   => (bool) $r['is_active'],
            ];
        }

        respond([
            'success'  => true,
            'page_key' => $pageKey,
            'sections' => $sections,
        ]);
    } catch (Throwable $e) {
        respond(['success' => false, 'error' => $e->getMessage()], 500);
    }
}

// ─────────────────────────────────────────────────────────────
// POST save → upsert a section
// ─────────────────────────────────────────────────────────────
if ($method === 'POST' && $action === 'save') {
    $id         = trim($body['id'] ?? '');
    $pageKey    = trim($body['page_key'] ?? '');
    $pageTitle  = trim($body['page_title'] ?? ucfirst($pageKey));
    $sectionKey = trim($body['section_key'] ?? '');
    $title      = trim($body['title'] ?? $body['content_title'] ?? '');
    $subtitle   = trim($body['subtitle'] ?? $body['content_subtitle'] ?? '');
    $bodyText   = trim($body['body'] ?? $body['body_text'] ?? '');
    $mediaUrl   = trim($body['media_url'] ?? '');
    $jsonData   = $body['data'] ?? $body['json_data'] ?? null;
    $order      = (int) ($body['order'] ?? $body['display_order'] ?? 0);
    $isActive   = isset($body['is_active']) ? (int) $body['is_active'] : 1;

    if (!$pageKey || !$sectionKey) {
        respond(['success' => false, 'error' => 'page_key and section_key are required'], 400);
    }

    if (!$id) {
        $id = 'sec-' . $pageKey . '-' . $sectionKey . '-' . time();
    }

    $jsonStr = is_array($jsonData) ? json_encode($jsonData, JSON_UNESCAPED_UNICODE) : ($jsonData ?? null);

    try {
        $upsertSql = $driver === 'sqlite' ? "
            INSERT INTO `site_pages`
                (id, page_key, page_title, section_key, content_title, content_subtitle, body_text, media_url, json_data, display_order, is_active)
            VALUES
                (:id, :pk, :pt, :sk, :ct, :cs, :bt, :mu, :jd, :do, :ia)
            ON CONFLICT(id) DO UPDATE SET
                page_title = excluded.page_title,
                content_title = excluded.content_title,
                content_subtitle = excluded.content_subtitle,
                body_text = excluded.body_text,
                media_url = excluded.media_url,
                json_data = excluded.json_data,
                display_order = excluded.display_order,
                is_active = excluded.is_active,
                updated_at = CURRENT_TIMESTAMP
        " : "
            INSERT INTO `site_pages`
                (id, page_key, page_title, section_key, content_title, content_subtitle, body_text, media_url, json_data, display_order, is_active)
            VALUES
                (:id, :pk, :pt, :sk, :ct, :cs, :bt, :mu, :jd, :do, :ia)
            ON DUPLICATE KEY UPDATE
                page_title       = VALUES(page_title),
                content_title    = VALUES(content_title),
                content_subtitle = VALUES(content_subtitle),
                body_text        = VALUES(body_text),
                media_url        = VALUES(media_url),
                json_data        = VALUES(json_data),
                display_order    = VALUES(display_order),
                is_active        = VALUES(is_active),
                updated_at       = CURRENT_TIMESTAMP
        ";
        $stmt = $db->prepare($upsertSql);
        $stmt->execute([
            ':id' => $id,
            ':pk' => $pageKey,
            ':pt' => $pageTitle,
            ':sk' => $sectionKey,
            ':ct' => $title,
            ':cs' => $subtitle,
            ':bt' => $bodyText,
            ':mu' => $mediaUrl,
            ':jd' => $jsonStr,
            ':do' => $order,
            ':ia' => $isActive,
        ]);

        respond([
            'success'    => true,
            'id'         => $id,
            'page_key'   => $pageKey,
            'section_key'=> $sectionKey,
            'message'    => 'Section saved to database',
        ]);
    } catch (Throwable $e) {
        respond(['success' => false, 'error' => $e->getMessage()], 500);
    }
}

// ─────────────────────────────────────────────────────────────
// POST delete → delete a section by id
// ─────────────────────────────────────────────────────────────
if ($method === 'POST' && $action === 'delete') {
    $id = trim($body['id'] ?? '');
    if (!$id) {
        respond(['success' => false, 'error' => 'id required'], 400);
    }
    try {
        $stmt = $db->prepare("DELETE FROM `site_pages` WHERE id = :id");
        $stmt->execute([':id' => $id]);
        respond(['success' => true, 'deleted_id' => $id]);
    } catch (Throwable $e) {
        respond(['success' => false, 'error' => $e->getMessage()], 500);
    }
}

// ─────────────────────────────────────────────────────────────
// POST reset_defaults → repopulate the CMS seed data.
// ─────────────────────────────────────────────────────────────
if ($method === 'POST' && $action === 'reset_defaults') {
    try {
        $db->exec("DELETE FROM `site_pages`");
        // setup_db.php owns the complete, versioned seed data for every table.
        // Its seeding is conditional, so after the delete it repopulates only CMS rows.
        ob_start();
        require __DIR__ . '/setup_db.php';
        ob_end_clean();
        respond(['success' => true, 'message' => 'Default CMS content restored']);
    } catch (Throwable $e) {
        respond(['success' => false, 'error' => $e->getMessage()], 500);
    }
}

// ─────────────────────────────────────────────────────────────
// Fallback
// ─────────────────────────────────────────────────────────────
respond([
    'success'   => false,
    'error'     => 'Unknown action: ' . $action,
    'endpoints' => [
        'GET ?action=all'               => 'Fetch all pages & sections from DB',
        'GET ?action=page&page=home'    => 'Fetch single page sections from DB',
        'POST {action:save, ...}'       => 'Save/update a section in DB',
        'POST {action:delete, id:...}'  => 'Delete a section from DB',
        'POST action=reset_defaults'    => 'Wipe site_pages and re-seed from setup_db.php',
    ],
], 400);
