<?php
declare(strict_types=1);

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, X-Tenant-Id');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/db.php';

$connInfo = getDatabaseConnection();
$db = $connInfo['pdo'];
$isMysql = ($connInfo['driver'] === 'mysql');

// Ensure site_pages table exists
try {
    if ($isMysql) {
        $db->exec("
            CREATE TABLE IF NOT EXISTS site_pages (
                id VARCHAR(128) PRIMARY KEY,
                page_key VARCHAR(64) NOT NULL,
                page_title VARCHAR(255) NOT NULL,
                section_key VARCHAR(64) NOT NULL,
                content_title VARCHAR(255),
                content_subtitle TEXT,
                body_text LONGTEXT,
                media_url VARCHAR(512),
                json_data LONGTEXT,
                display_order INT DEFAULT 0,
                is_active TINYINT DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX idx_page_section (page_key, section_key),
                INDEX idx_page_order (page_key, display_order)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ");
    } else {
        $db->exec("
            CREATE TABLE IF NOT EXISTS site_pages (
                id TEXT PRIMARY KEY,
                page_key TEXT NOT NULL,
                page_title TEXT NOT NULL,
                section_key TEXT NOT NULL,
                content_title TEXT,
                content_subtitle TEXT,
                body_text TEXT,
                media_url TEXT,
                json_data TEXT,
                display_order INTEGER DEFAULT 0,
                is_active INTEGER DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        ");
    }

    // Seed default content if table is empty
    $countCheck = $db->query("SELECT COUNT(*) FROM site_pages")->fetchColumn();
    if ((int)$countCheck === 0) {
        seedDefaultPageContent($db);
    }
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Database error: ' . $e->getMessage()]);
    exit();
}

$action = $_GET['action'] ?? 'get';
$pageKey = $_GET['page'] ?? '';

// Handle actions
switch ($action) {
    case 'all':
        // Return all pages and sections grouped by page_key
        $stmt = $db->query("SELECT * FROM site_pages WHERE is_active = 1 ORDER BY page_key ASC, display_order ASC");
        $rows = $stmt->fetchAll();
        $pages = [];
        foreach ($rows as $row) {
            $pk = $row['page_key'];
            if (!isset($pages[$pk])) {
                $pages[$pk] = [
                    'page_key' => $pk,
                    'page_title' => $row['page_title'],
                    'sections' => []
                ];
            }
            $pages[$pk]['sections'][$row['section_key']] = formatSectionRow($row);
        }
        echo json_encode([
            'success' => true,
            'driver' => $connInfo['driver'],
            'host' => $connInfo['host'] ?? 'localhost',
            'data' => $pages
        ]);
        break;

    case 'get':
        if (empty($pageKey)) {
            // If no page specified, return table of all available page sections
            $stmt = $db->query("SELECT * FROM site_pages ORDER BY page_key ASC, display_order ASC");
            $rows = $stmt->fetchAll();
            $data = array_map('formatSectionRow', $rows);
            echo json_encode([
                'success' => true,
                'count' => count($data),
                'driver' => $connInfo['driver'],
                'data' => $data
            ]);
            break;
        }

        // Return sections for a specific page
        $stmt = $db->prepare("SELECT * FROM site_pages WHERE page_key = :page_key AND is_active = 1 ORDER BY display_order ASC");
        $stmt->execute([':page_key' => $pageKey]);
        $rows = $stmt->fetchAll();
        $sections = [];
        $pageTitle = ucfirst($pageKey);
        foreach ($rows as $row) {
            $pageTitle = $row['page_title'];
            $sections[$row['section_key']] = formatSectionRow($row);
        }
        echo json_encode([
            'success' => true,
            'page_key' => $pageKey,
            'page_title' => $pageTitle,
            'sections' => $sections
        ]);
        break;

    case 'save':
    case 'update':
        $raw = file_get_contents('php://input');
        $payload = json_decode($raw, true) ?: $_POST;

        $id = $payload['id'] ?? ('page-sec-' . bin2hex(random_bytes(6)));
        $pageKey = $payload['page_key'] ?? 'home';
        $pageTitle = $payload['page_title'] ?? ucfirst($pageKey);
        $sectionKey = $payload['section_key'] ?? 'hero';
        $contentTitle = $payload['content_title'] ?? '';
        $contentSubtitle = $payload['content_subtitle'] ?? '';
        $bodyText = $payload['body_text'] ?? '';
        $mediaUrl = $payload['media_url'] ?? '';
        $jsonData = isset($payload['json_data']) ? (is_string($payload['json_data']) ? $payload['json_data'] : json_encode($payload['json_data'])) : null;
        $displayOrder = (int)($payload['display_order'] ?? 0);
        $isActive = isset($payload['is_active']) ? (int)$payload['is_active'] : 1;

        // Upsert section
        $checkStmt = $db->prepare("SELECT id FROM site_pages WHERE id = :id OR (page_key = :pk AND section_key = :sk)");
        $checkStmt->execute([':id' => $id, ':pk' => $pageKey, ':sk' => $sectionKey]);
        $existingId = $checkStmt->fetchColumn();

        if ($existingId) {
            $upd = $db->prepare("
                UPDATE site_pages 
                SET page_title = :page_title,
                    content_title = :content_title,
                    content_subtitle = :content_subtitle,
                    body_text = :body_text,
                    media_url = :media_url,
                    json_data = :json_data,
                    display_order = :display_order,
                    is_active = :is_active
                WHERE id = :existing_id
            ");
            $upd->execute([
                ':page_title' => $pageTitle,
                ':content_title' => $contentTitle,
                ':content_subtitle' => $contentSubtitle,
                ':body_text' => $bodyText,
                ':media_url' => $mediaUrl,
                ':json_data' => $jsonData,
                ':display_order' => $displayOrder,
                ':is_active' => $isActive,
                ':existing_id' => $existingId
            ]);
            $savedId = $existingId;
        } else {
            $ins = $db->prepare("
                INSERT INTO site_pages (
                    id, page_key, page_title, section_key, content_title, 
                    content_subtitle, body_text, media_url, json_data, display_order, is_active
                ) VALUES (
                    :id, :page_key, :page_title, :section_key, :content_title,
                    :content_subtitle, :body_text, :media_url, :json_data, :display_order, :is_active
                )
            ");
            $ins->execute([
                ':id' => $id,
                ':page_key' => $pageKey,
                ':page_title' => $pageTitle,
                ':section_key' => $sectionKey,
                ':content_title' => $contentTitle,
                ':content_subtitle' => $contentSubtitle,
                ':body_text' => $bodyText,
                ':media_url' => $mediaUrl,
                ':json_data' => $jsonData,
                ':display_order' => $displayOrder,
                ':is_active' => $isActive
            ]);
            $savedId = $id;
        }

        echo json_encode([
            'success' => true,
            'message' => 'Page content saved successfully to database table',
            'id' => $savedId
        ]);
        break;

    case 'delete':
        $id = $_GET['id'] ?? ($_POST['id'] ?? '');
        if (empty($id)) {
            echo json_encode(['success' => false, 'error' => 'Missing section ID']);
            exit();
        }
        $del = $db->prepare("DELETE FROM site_pages WHERE id = :id");
        $del->execute([':id' => $id]);
        echo json_encode(['success' => true, 'message' => 'Page section deleted from database']);
        break;

    case 'reset_defaults':
        $db->exec("DELETE FROM site_pages");
        seedDefaultPageContent($db);
        echo json_encode([
            'success' => true,
            'message' => 'Default page content table re-seeded successfully'
        ]);
        break;

    default:
        echo json_encode(['success' => false, 'error' => 'Invalid action']);
        break;
}

function formatSectionRow(array $row): array {
    $parsedJson = null;
    if (!empty($row['json_data'])) {
        $parsedJson = json_decode($row['json_data'], true);
    }
    return [
        'id' => $row['id'],
        'page_key' => $row['page_key'],
        'page_title' => $row['page_title'],
        'section_key' => $row['section_key'],
        'title' => $row['content_title'],
        'subtitle' => $row['content_subtitle'],
        'body' => $row['body_text'],
        'media_url' => $row['media_url'],
        'data' => $parsedJson,
        'order' => (int)$row['display_order'],
        'is_active' => (bool)$row['is_active'],
        'updated_at' => $row['updated_at'] ?? $row['created_at']
    ];
}

function seedDefaultPageContent(PDO $db): void {
    $sections = [
        // HOME PAGE SECTIONS
        [
            'id' => 'sec-home-hero',
            'page_key' => 'home',
            'page_title' => 'Home',
            'section_key' => 'hero',
            'content_title' => 'Automate Call Tracking & Audio Intelligence for Enterprise Sales',
            'content_subtitle' => 'RingVia360 securely captures SIM & VoIP calls, generates real-time audio transcripts & waveforms, and syncs directly into your CRM with zero battery drain.',
            'body_text' => 'Built for high-velocity Indian & global sales teams. Native Samsung Knox dual-SIM hardware partition separates personal calls from corporate CRM activity.',
            'media_url' => 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
            'json_data' => json_encode([
                'badge' => '⚡ ENTERPRISE TELEPHONY AUTOMATION 2026',
                'cta_primary' => 'Start 14-Day Free Trial',
                'cta_secondary' => 'Book Architecture Demo',
                'trust_badge' => 'Trusted by 450+ High-Growth Enterprises Across India'
            ]),
            'display_order' => 1
        ],
        [
            'id' => 'sec-home-stats',
            'page_key' => 'home',
            'page_title' => 'Home',
            'section_key' => 'stats',
            'content_title' => 'Platform Benchmark & Performance Numbers',
            'content_subtitle' => 'Real-time telemetry from enterprise production instances',
            'body_text' => 'Our carrier-grade cloud network processes hundreds of thousands of outbound calls daily with zero data loss.',
            'media_url' => '',
            'json_data' => json_encode([
                'items' => [
                    ['value' => '99.8%', 'label' => 'Automated Call Capture', 'desc' => 'Zero manual rep logging required'],
                    ['value' => '₹48.5L+', 'label' => 'Daily Deal Volume Tracked', 'desc' => 'Integrated CRM pipeline attribution'],
                    ['value' => '45%', 'label' => 'Productivity Increase', 'desc' => 'Saved 1.5 hrs/rep/day in data entry'],
                    ['value' => '100%', 'label' => 'Knox E2EE Isolation', 'desc' => 'Complete hardware privacy protection']
                ]
            ]),
            'display_order' => 2
        ],
        [
            'id' => 'sec-home-features',
            'page_key' => 'home',
            'page_title' => 'Home',
            'section_key' => 'features_highlight',
            'content_title' => 'Core Differentiators That Outperform Legacy Dialers',
            'content_subtitle' => 'Enterprise compliance, automated CRM logging, and instant WhatsApp customer follow-up.',
            'body_text' => 'Eliminate manual CRM entry and stop losing deals to forgotten follow-ups.',
            'media_url' => '',
            'json_data' => json_encode([
                'features' => [
                    [
                        'icon' => 'ShieldCheck',
                        'title' => 'Hardware Knox Dual-SIM Isolation',
                        'desc' => 'Only business SIM activity is tracked. Personal SIM calls, SMS, and data remain 100% private to the employee.'
                    ],
                    [
                        'icon' => 'Lock',
                        'title' => 'End-to-End Encrypted Call Audio',
                        'desc' => 'All call recordings and transcripts are encrypted with AES-256 before leaving the mobile device.'
                    ],
                    [
                        'icon' => 'Sparkles',
                        'title' => 'AI Sentiment & Waveform Pod',
                        'desc' => 'Immediate post-call sentiment classification (Positive / Neutral / Negative) with interactive audio scrubbing.'
                    ],
                    [
                        'icon' => 'MessageCircle',
                        'title' => 'Automated WhatsApp Dispatch',
                        'desc' => 'Instantly dispatches corporate WhatsApp message templates with meeting links upon call wrap-up.'
                    ],
                    [
                        'icon' => 'RefreshCw',
                        'title' => 'Bi-Directional CRM Sync',
                        'desc' => 'Direct real-time webhooks sync to Salesforce, HubSpot, Zoho CRM, LeadSquared, and Freshsales.'
                    ]
                ]
            ]),
            'display_order' => 3
        ],

        // FEATURES PAGE SECTIONS
        [
            'id' => 'sec-features-hero',
            'page_key' => 'features',
            'page_title' => 'Features',
            'section_key' => 'hero',
            'content_title' => 'Enterprise Telephony Engineered for Modern Sales Teams',
            'content_subtitle' => 'Deep mobile telemetry, carrier-grade audio capture, and autonomous CRM automation for seamless closing.',
            'body_text' => 'RingVia360 combines high-availability mobile companion apps with web admin supervision.',
            'media_url' => '',
            'json_data' => json_encode([
                'badge' => 'PLATFORM CAPABILITIES',
                'filter_categories' => ['All Capabilities', 'Compliance & Privacy', 'CRM Automation', 'Speech Intelligence']
            ]),
            'display_order' => 1
        ],

        // PRICING PAGE SECTIONS
        [
            'id' => 'sec-pricing-hero',
            'page_key' => 'pricing',
            'page_title' => 'Pricing',
            'section_key' => 'hero',
            'content_title' => 'Corporate Pricing Tailored for Indian & Global Scale',
            'content_subtitle' => 'Transparent INR corporate pricing with isolated tenant workspaces, unlimited storage, and 99.9% uptime SLA.',
            'body_text' => 'Every subscription includes private database isolation, Knox hardware telemetry, and dedicated support.',
            'media_url' => '',
            'json_data' => json_encode([
                'badge' => 'SIMPLE TRANSPARENT PLANS IN INR',
                'billing_period' => 'monthly',
                'plans' => [
                    [
                        'id' => 'starter',
                        'name' => 'Starter Team',
                        'price_inr' => '₹4,999',
                        'period' => '/ month',
                        'max_reps' => 'Up to 5 Reps',
                        'features' => ['Automated SIM Call Capture', 'Encrypted Audio Recording', 'RingVia360 Cloud CRM', 'Post-Call Notes & Audio Pod', 'Email Support'],
                        'popular' => false
                    ],
                    [
                        'id' => 'pro',
                        'name' => 'Growth & Scale',
                        'price_inr' => '₹14,999',
                        'period' => '/ month',
                        'max_reps' => 'Up to 25 Reps',
                        'features' => ['Everything in Starter', 'Knox Dual-SIM Separation', 'Salesforce & HubSpot Auto-Sync', 'AI Sentiment & Waveform Pod', 'Priority Phone Support'],
                        'popular' => true
                    ],
                    [
                        'id' => 'enterprise',
                        'name' => 'Enterprise Business',
                        'price_inr' => '₹45,000',
                        'period' => '/ month',
                        'max_reps' => 'Up to 100 Reps',
                        'features' => ['Everything in Growth', 'Custom CRM Field Mappings', 'Dedicated Multi-Tenant Isolation', 'Custom WhatsApp Bot Templates', '24/7 Dedicated Account Manager'],
                        'popular' => false
                    ],
                    [
                        'id' => 'custom',
                        'name' => 'Banking & Telecom',
                        'price_inr' => '₹85,000',
                        'period' => '/ month',
                        'max_reps' => 'Unlimited Reps',
                        'features' => ['Custom On-Prem / VPC Hosting', 'SOC-2 & ISO 27001 Compliance', 'Custom Knox MDM Integration', 'Unlimited Call Audio Vault', 'Tailored SLA Guarantee'],
                        'popular' => false
                    ]
                ]
            ]),
            'display_order' => 1
        ],

        // ACTIVITIES PAGE SECTIONS
        [
            'id' => 'sec-activities-hero',
            'page_key' => 'activities',
            'page_title' => 'Activities',
            'section_key' => 'hero',
            'content_title' => 'Real-Time Sales Activity & Call Stream',
            'content_subtitle' => 'Live inbound and outbound call feeds with waveform audio player, rep attribution, and CRM delivery verification.',
            'body_text' => 'Monitor rep conversations as they happen across all active field agents.',
            'media_url' => '',
            'json_data' => json_encode([
                'live_banner' => 'LIVE FEED CONNECTED • 41 ACTIVE CALLS SYNCHRONIZED TODAY',
                'quick_filters' => ['All Calls', 'Inbound', 'Outbound', 'Missed', 'High Value (>₹50k)']
            ]),
            'display_order' => 1
        ],

        // ANALYTICS PAGE SECTIONS
        [
            'id' => 'sec-analytics-hero',
            'page_key' => 'analytics',
            'page_title' => 'Analytics',
            'section_key' => 'hero',
            'content_title' => 'Telephony Performance & Pipeline Intelligence',
            'content_subtitle' => 'Transform field calling volume into quantifiable revenue outcomes and rep coaching opportunities.',
            'body_text' => 'Interactive drill-downs into call duration distributions, conversion velocity, and sentiment scores.',
            'media_url' => '',
            'json_data' => json_encode([
                'target_talk_time_min' => 180,
                'positive_sentiment_goal' => '85%',
                'active_reps_online' => 12
            ]),
            'display_order' => 1
        ],

        // CRM SYNC PAGE SECTIONS
        [
            'id' => 'sec-crm-hero',
            'page_key' => 'crm_sync',
            'page_title' => 'CRM Sync',
            'section_key' => 'hero',
            'content_title' => 'Zero-Touch Bi-Directional CRM Integrations',
            'content_subtitle' => 'Eliminate manual logging forever. Every call, note, audio recording, and sentiment tag is automatically pushed to your CRM.',
            'body_text' => 'Supports automatic contact creation, deal stage progression, and custom field synchronization.',
            'media_url' => '',
            'json_data' => json_encode([
                'supported_crms' => ['Salesforce', 'HubSpot', 'Zoho CRM', 'LeadSquared', 'Freshsales', 'Custom Webhooks'],
                'sync_frequency' => 'Real-time (sub-second webhook push)'
            ]),
            'display_order' => 1
        ],

        // DASHBOARD PAGE SECTIONS
        [
            'id' => 'sec-dashboard-hero',
            'page_key' => 'dashboard',
            'page_title' => 'Dashboard',
            'section_key' => 'hero',
            'content_title' => 'Executive Sales Intelligence',
            'content_subtitle' => 'Real-time call logs, WhatsApp outreach, and CRM pipeline progression across your sales team.',
            'body_text' => 'Monitor every rep, every call, and every deal — all in one unified command center.',
            'media_url' => '',
            'json_data' => json_encode([
                'live_badge' => 'LIVE TELEMETRY',
                'time_ranges' => ['today', 'week', 'month']
            ]),
            'display_order' => 1
        ],

        // LEADERBOARD PAGE SECTIONS
        [
            'id' => 'sec-leaderboard-hero',
            'page_key' => 'leaderboard',
            'page_title' => 'Leaderboard',
            'section_key' => 'hero',
            'content_title' => 'Sales Performance Leaderboard',
            'content_subtitle' => 'Gamified rep rankings based on calls made, deals closed, and talk-time targets achieved.',
            'body_text' => 'Drive friendly competition and celebrate top performers across your field sales team.',
            'media_url' => '',
            'json_data' => json_encode([
                'badges' => ['🏆 Top Performer', '⚡ Speed Demon', '🔥 On Fire', '💎 Deal Closer'],
                'streak_goal_days' => 14
            ]),
            'display_order' => 1
        ]
    ];

    $stmt = $db->prepare("
        INSERT INTO site_pages (
            id, page_key, page_title, section_key, content_title, 
            content_subtitle, body_text, media_url, json_data, display_order, is_active
        ) VALUES (
            :id, :page_key, :page_title, :section_key, :content_title,
            :content_subtitle, :body_text, :media_url, :json_data, :display_order, 1
        )
    ");

    foreach ($sections as $sec) {
        $stmt->execute([
            ':id' => $sec['id'],
            ':page_key' => $sec['page_key'],
            ':page_title' => $sec['page_title'],
            ':section_key' => $sec['section_key'],
            ':content_title' => $sec['content_title'],
            ':content_subtitle' => $sec['content_subtitle'],
            ':body_text' => $sec['body_text'],
            ':media_url' => $sec['media_url'],
            ':json_data' => $sec['json_data'],
            ':display_order' => $sec['display_order']
        ]);
    }
}
