<?php
declare(strict_types=1);

/**
 * RingVia360 — Self-Contained Database Initializer
 * Visit: https://ringvia360.com/api/setup_db.php
 * 
 * This script:
 *  1. Connects to MySQL (Hostinger: u488332847_dn_name)
 *  2. Creates ALL 11 required tables (DROP-safe: CREATE TABLE IF NOT EXISTS)
 *  3. Seeds default content for site_pages, organizations, users, call_logs, 
 *     sales_reps, leads_contacts, crm_connectors, admin_users, whatsapp_logs
 *  4. Returns a full status HTML page with row counts
 *
 * Run this once on deployment. Safe to re-run (uses INSERT IGNORE / checks count).
 */

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Content-Type: text/html; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit(); }

// ─────────────────────────────────────────────
// 1. DATABASE CONNECTION
// ─────────────────────────────────────────────
$mysqlDb   = 'u488332847_dn_name';
$mysqlUser = 'u488332847_ringvia360';
$mysqlPass = 'K6b?qnk2L/';
$hosts     = ['localhost', 'auth-db1260.hstgr.io', '127.0.0.1'];

$db      = null;
$driver  = 'none';
$activeHost = 'none';
$connErrors = [];

foreach ($hosts as $h) {
    try {
        $pdo = new PDO(
            "mysql:host={$h};dbname={$mysqlDb};charset=utf8mb4",
            $mysqlUser,
            $mysqlPass,
            [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_TIMEOUT            => 5,
            ]
        );
        $db = $pdo;
        $driver = 'MySQL';
        $activeHost = $h;
        break;
    } catch (Throwable $e) {
        $connErrors[$h] = $e->getMessage();
    }
}

if (!$db) {
    die('<h1 style="color:red;font-family:monospace">❌ Could not connect to MySQL.<br>Errors: ' . htmlspecialchars(json_encode($connErrors)) . '</h1>');
}

$log    = [];
$errors = [];

function exec_sql(PDO $db, string $sql, string $label, array &$log, array &$errors): void {
    try {
        $db->exec($sql);
        $log[] = "✅ $label";
    } catch (Throwable $e) {
        $errors[] = "❌ $label: " . $e->getMessage();
    }
}

function row_count(PDO $db, string $table): string {
    try {
        return (string) $db->query("SELECT COUNT(*) FROM `$table`")->fetchColumn();
    } catch (Throwable $e) {
        return 'N/A';
    }
}

function insert_ignore(PDO $db, string $table, array $data, array &$log, array &$errors): void {
    $cols = implode(', ', array_map(fn($c) => "`$c`", array_keys($data)));
    $placeholders = implode(', ', array_map(fn($c) => ":$c", array_keys($data)));
    try {
        $stmt = $db->prepare("INSERT IGNORE INTO `$table` ($cols) VALUES ($placeholders)");
        $stmt->execute($data);
        $log[] = "  ↳ Inserted into $table: " . ($data['id'] ?? $data['name'] ?? '?');
    } catch (Throwable $e) {
        $errors[] = "  ↳ Insert $table failed: " . $e->getMessage();
    }
}

// ─────────────────────────────────────────────
// 2. CREATE ALL TABLES
// ─────────────────────────────────────────────

// TABLE 1: organizations
exec_sql($db, "
    CREATE TABLE IF NOT EXISTS `organizations` (
        `id`               VARCHAR(128)   NOT NULL PRIMARY KEY,
        `name`             VARCHAR(255)   NOT NULL,
        `subdomain`        VARCHAR(128)   DEFAULT NULL,
        `plan`             VARCHAR(64)    NOT NULL DEFAULT 'pro',
        `monthly_fee_inr`  INT            NOT NULL DEFAULT 14999,
        `status`           VARCHAR(32)    NOT NULL DEFAULT 'active',
        `max_reps`         INT            NOT NULL DEFAULT 25,
        `crm_provider`     VARCHAR(64)    DEFAULT 'RingVia360',
        `contact_email`    VARCHAR(255)   DEFAULT NULL,
        `contact_phone`    VARCHAR(64)    DEFAULT NULL,
        `created_at`       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at`       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
", 'TABLE: organizations', $log, $errors);

// TABLE 2: users
exec_sql($db, "
    CREATE TABLE IF NOT EXISTS `users` (
        `id`            VARCHAR(128)   NOT NULL PRIMARY KEY,
        `org_id`        VARCHAR(128)   NOT NULL DEFAULT 'org-ringvia360',
        `name`          VARCHAR(255)   NOT NULL,
        `email`         VARCHAR(255)   NOT NULL,
        `password_hash` VARCHAR(255)   NOT NULL,
        `role`          VARCHAR(32)    NOT NULL DEFAULT 'tenant_admin',
        `avatar`        VARCHAR(512)   DEFAULT NULL,
        `phone`         VARCHAR(64)    DEFAULT NULL,
        `status`        VARCHAR(32)    NOT NULL DEFAULT 'active',
        `created_at`    TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at`    TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY `uq_users_email` (`email`),
        INDEX `idx_users_org` (`org_id`),
        INDEX `idx_users_role` (`role`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
", 'TABLE: users', $log, $errors);

// TABLE 3: sales_reps
exec_sql($db, "
    CREATE TABLE IF NOT EXISTS `sales_reps` (
        `id`                     VARCHAR(128)   NOT NULL PRIMARY KEY,
        `org_id`                 VARCHAR(128)   NOT NULL DEFAULT 'org-ringvia360',
        `name`                   VARCHAR(255)   NOT NULL,
        `role`                   VARCHAR(128)   DEFAULT 'Sales Representative',
        `email`                  VARCHAR(255)   DEFAULT NULL,
        `phone`                  VARCHAR(64)    DEFAULT NULL,
        `avatar`                 VARCHAR(512)   DEFAULT NULL,
        `device_model`           VARCHAR(128)   DEFAULT NULL,
        `os_version`             VARCHAR(64)    DEFAULT NULL,
        `battery_level`          INT            DEFAULT 80,
        `is_online`              TINYINT        NOT NULL DEFAULT 1,
        `last_sync`              VARCHAR(64)    DEFAULT 'Never',
        `calls_today`            INT            NOT NULL DEFAULT 0,
        `talk_time_minutes`      INT            NOT NULL DEFAULT 0,
        `deals_closed`           INT            NOT NULL DEFAULT 0,
        `conversion_rate`        DECIMAL(5,2)   NOT NULL DEFAULT 0.00,
        `rank`                   INT            DEFAULT 1,
        `streak_days`            INT            DEFAULT 0,
        `badges`                 TEXT           DEFAULT NULL COMMENT 'JSON array of badge strings',
        `status`                 VARCHAR(32)    NOT NULL DEFAULT 'active',
        `created_at`             TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at`             TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX `idx_reps_org` (`org_id`),
        INDEX `idx_reps_status` (`status`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
", 'TABLE: sales_reps', $log, $errors);

// TABLE 4: leads_contacts
exec_sql($db, "
    CREATE TABLE IF NOT EXISTS `leads_contacts` (
        `id`               VARCHAR(128)   NOT NULL PRIMARY KEY,
        `org_id`           VARCHAR(128)   NOT NULL DEFAULT 'org-ringvia360',
        `name`             VARCHAR(255)   NOT NULL,
        `phone_number`     VARCHAR(64)    NOT NULL,
        `company`          VARCHAR(255)   DEFAULT NULL,
        `title`            VARCHAR(128)   DEFAULT NULL,
        `email`            VARCHAR(255)   DEFAULT NULL,
        `open_deal_value`  DECIMAL(12,2)  NOT NULL DEFAULT 0.00,
        `last_contacted`   VARCHAR(64)    DEFAULT NULL,
        `crm_account_id`   VARCHAR(128)   DEFAULT NULL,
        `notes`            TEXT           DEFAULT NULL,
        `tags`             TEXT           DEFAULT NULL COMMENT 'JSON array',
        `created_at`       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at`       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX `idx_leads_org` (`org_id`),
        INDEX `idx_leads_phone` (`phone_number`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
", 'TABLE: leads_contacts', $log, $errors);

// TABLE 5: call_logs
exec_sql($db, "
    CREATE TABLE IF NOT EXISTS `call_logs` (
        `id`               VARCHAR(128)   NOT NULL PRIMARY KEY,
        `org_id`           VARCHAR(128)   NOT NULL DEFAULT 'org-ringvia360',
        `contact_name`     VARCHAR(255)   NOT NULL,
        `phone_number`     VARCHAR(64)    NOT NULL,
        `company`          VARCHAR(255)   DEFAULT NULL,
        `direction`        VARCHAR(32)    NOT NULL DEFAULT 'outbound',
        `duration`         INT            NOT NULL DEFAULT 0,
        `timestamp`        VARCHAR(64)    NOT NULL DEFAULT '',
        `rep_name`         VARCHAR(255)   DEFAULT NULL,
        `rep_avatar`       VARCHAR(512)   DEFAULT NULL,
        `rep_id`           VARCHAR(128)   DEFAULT 'rep-mobile',
        `outcome`          VARCHAR(255)   DEFAULT NULL,
        `notes`            TEXT           DEFAULT NULL,
        `sentiment`        VARCHAR(32)    NOT NULL DEFAULT 'positive',
        `sentiment_score`  INT            NOT NULL DEFAULT 85,
        `deal_value`       DECIMAL(12,2)  NOT NULL DEFAULT 0.00,
        `deal_stage`       VARCHAR(128)   DEFAULT 'Proposal',
        `crm_status`       VARCHAR(64)    NOT NULL DEFAULT 'synced',
        `crm_type`         VARCHAR(64)    NOT NULL DEFAULT 'RingVia360',
        `crm_record_id`    VARCHAR(128)   DEFAULT NULL,
        `sim_slot`         VARCHAR(64)    DEFAULT 'SIM 1 (Corporate)',
        `is_encrypted`     TINYINT        NOT NULL DEFAULT 1,
        `recording_url`    VARCHAR(512)   DEFAULT NULL,
        `waveform`         TEXT           DEFAULT NULL COMMENT 'JSON array of waveform bars',
        `transcript`       LONGTEXT       DEFAULT NULL COMMENT 'JSON array of transcript items',
        `key_action_items` TEXT           DEFAULT NULL COMMENT 'JSON array of action strings',
        `tags`             TEXT           DEFAULT NULL COMMENT 'JSON array of tag strings',
        `created_at`       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at`       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX `idx_calls_org` (`org_id`),
        INDEX `idx_calls_direction` (`direction`),
        INDEX `idx_calls_sentiment` (`sentiment`),
        INDEX `idx_calls_created` (`created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
", 'TABLE: call_logs', $log, $errors);

// TABLE 6: whatsapp_logs
exec_sql($db, "
    CREATE TABLE IF NOT EXISTS `whatsapp_logs` (
        `id`             VARCHAR(128)   NOT NULL PRIMARY KEY,
        `org_id`         VARCHAR(128)   NOT NULL DEFAULT 'org-ringvia360',
        `contact_name`   VARCHAR(255)   NOT NULL,
        `phone_number`   VARCHAR(64)    NOT NULL,
        `company`        VARCHAR(255)   DEFAULT NULL,
        `message_count`  INT            NOT NULL DEFAULT 1,
        `last_message`   TEXT           DEFAULT NULL,
        `timestamp`      VARCHAR(64)    DEFAULT NULL,
        `rep_name`       VARCHAR(255)   DEFAULT NULL,
        `rep_avatar`     VARCHAR(512)   DEFAULT NULL,
        `sentiment`      VARCHAR(32)    NOT NULL DEFAULT 'positive',
        `crm_status`     VARCHAR(64)    NOT NULL DEFAULT 'synced',
        `crm_type`       VARCHAR(64)    NOT NULL DEFAULT 'RingVia360',
        `media_count`    INT            NOT NULL DEFAULT 0,
        `is_business_api` TINYINT       NOT NULL DEFAULT 1,
        `created_at`     TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX `idx_wa_org` (`org_id`),
        INDEX `idx_wa_phone` (`phone_number`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
", 'TABLE: whatsapp_logs', $log, $errors);

// TABLE 7: admin_users
exec_sql($db, "
    CREATE TABLE IF NOT EXISTS `admin_users` (
        `id`          VARCHAR(128)   NOT NULL PRIMARY KEY,
        `org_id`      VARCHAR(128)   NOT NULL DEFAULT 'org-ringvia360',
        `name`        VARCHAR(255)   NOT NULL,
        `email`       VARCHAR(255)   NOT NULL,
        `role`        VARCHAR(128)   NOT NULL DEFAULT 'Sales Rep',
        `status`      VARCHAR(32)    NOT NULL DEFAULT 'Active',
        `sim`         VARCHAR(64)    DEFAULT 'SIM 1 Bound',
        `device`      VARCHAR(128)   DEFAULT NULL,
        `last_active` VARCHAR(64)    DEFAULT 'Never',
        `created_at`  TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX `idx_admin_org` (`org_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
", 'TABLE: admin_users', $log, $errors);

// TABLE 8: crm_connectors
exec_sql($db, "
    CREATE TABLE IF NOT EXISTS `crm_connectors` (
        `id`                  VARCHAR(128)   NOT NULL PRIMARY KEY,
        `org_id`              VARCHAR(128)   NOT NULL DEFAULT 'org-ringvia360',
        `name`                VARCHAR(128)   NOT NULL,
        `description`         TEXT           DEFAULT NULL,
        `icon`                VARCHAR(16)    DEFAULT '🔗',
        `is_connected`        TINYINT        NOT NULL DEFAULT 0,
        `last_sync_time`      VARCHAR(64)    DEFAULT 'Never',
        `synced_records_count` INT           NOT NULL DEFAULT 0,
        `pending_sync_count`  INT            NOT NULL DEFAULT 0,
        `auto_sync`           TINYINT        NOT NULL DEFAULT 0,
        `api_endpoint`        VARCHAR(512)   DEFAULT NULL,
        `api_key`             VARCHAR(512)   DEFAULT NULL,
        `health`              VARCHAR(32)    NOT NULL DEFAULT 'disconnected',
        `created_at`          TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at`          TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX `idx_crm_org` (`org_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
", 'TABLE: crm_connectors', $log, $errors);

// TABLE 9: audit_logs
exec_sql($db, "
    CREATE TABLE IF NOT EXISTS `audit_logs` (
        `id`          VARCHAR(128)   NOT NULL PRIMARY KEY,
        `org_id`      VARCHAR(128)   DEFAULT NULL,
        `user_email`  VARCHAR(255)   DEFAULT NULL,
        `action`      VARCHAR(255)   NOT NULL,
        `details`     TEXT           DEFAULT NULL,
        `ip_address`  VARCHAR(64)    DEFAULT NULL,
        `severity`    VARCHAR(32)    NOT NULL DEFAULT 'info',
        `signature`   VARCHAR(128)   DEFAULT NULL,
        `created_at`  TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX `idx_audit_org` (`org_id`),
        INDEX `idx_audit_created` (`created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
", 'TABLE: audit_logs', $log, $errors);

// TABLE 10: security_settings
exec_sql($db, "
    CREATE TABLE IF NOT EXISTS `security_settings` (
        `id`                          VARCHAR(128)   NOT NULL PRIMARY KEY DEFAULT 'default',
        `org_id`                      VARCHAR(128)   NOT NULL DEFAULT 'org-ringvia360',
        `e2ee_enabled`                TINYINT        NOT NULL DEFAULT 1,
        `kms_key_alias`               VARCHAR(255)   DEFAULT 'alias/ringvia360-enterprise-vault-v2',
        `call_recording_consent`      VARCHAR(64)    DEFAULT 'two-party-beep',
        `auto_redact_pii`             TINYINT        NOT NULL DEFAULT 1,
        `data_retention_days`         INT            NOT NULL DEFAULT 90,
        `whitelisted_ips`             TEXT           DEFAULT NULL COMMENT 'JSON array',
        `device_attestation_enforced` TINYINT        NOT NULL DEFAULT 1,
        `updated_at`                  TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX `idx_sec_org` (`org_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
", 'TABLE: security_settings', $log, $errors);

// TABLE 11: site_pages (CMS content)
exec_sql($db, "
    CREATE TABLE IF NOT EXISTS `site_pages` (
        `id`               VARCHAR(128)   NOT NULL PRIMARY KEY,
        `page_key`         VARCHAR(64)    NOT NULL,
        `page_title`       VARCHAR(255)   NOT NULL,
        `section_key`      VARCHAR(64)    NOT NULL,
        `content_title`    VARCHAR(512)   DEFAULT NULL,
        `content_subtitle` TEXT           DEFAULT NULL,
        `body_text`        LONGTEXT       DEFAULT NULL,
        `media_url`        VARCHAR(512)   DEFAULT NULL,
        `json_data`        LONGTEXT       DEFAULT NULL COMMENT 'Structured JSON: pricing plans, feature lists, stats etc.',
        `display_order`    INT            NOT NULL DEFAULT 0,
        `is_active`        TINYINT        NOT NULL DEFAULT 1,
        `created_at`       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at`       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX `idx_sp_page_section` (`page_key`, `section_key`),
        INDEX `idx_sp_page_order`   (`page_key`, `display_order`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
", 'TABLE: site_pages', $log, $errors);

$log[] = '';
$log[] = '─── All tables created ───';
$log[] = '';

// ─────────────────────────────────────────────
// 3. SEED DATA — Only if tables are empty
// ─────────────────────────────────────────────

// ── ORGANIZATIONS ──
if ((int) $db->query("SELECT COUNT(*) FROM `organizations`")->fetchColumn() === 0) {
    $orgs = [
        ['id' => 'org-ringvia360', 'name' => 'RingVia360 (Platform)', 'subdomain' => 'platform', 'plan' => 'enterprise', 'monthly_fee_inr' => 0, 'status' => 'active', 'max_reps' => 9999, 'crm_provider' => 'RingVia360'],
        ['id' => 'org-tcs',        'name' => 'Tata Consultancy Services', 'subdomain' => 'tcs', 'plan' => 'enterprise', 'monthly_fee_inr' => 45000, 'status' => 'active', 'max_reps' => 100, 'crm_provider' => 'RingVia360'],
        ['id' => 'org-infosys',    'name' => 'Infosys Technologies', 'subdomain' => 'infosys', 'plan' => 'pro', 'monthly_fee_inr' => 14999, 'status' => 'active', 'max_reps' => 25, 'crm_provider' => 'HubSpot'],
        ['id' => 'org-hdfc',       'name' => 'HDFC Bank Enterprise', 'subdomain' => 'hdfc', 'plan' => 'banking', 'monthly_fee_inr' => 85000, 'status' => 'active', 'max_reps' => 500, 'crm_provider' => 'Salesforce'],
        ['id' => 'org-wipro',      'name' => 'Wipro Enterprises', 'subdomain' => 'wipro', 'plan' => 'pro', 'monthly_fee_inr' => 14999, 'status' => 'suspended', 'max_reps' => 25, 'crm_provider' => 'Zoho CRM'],
    ];
    foreach ($orgs as $o) {
        insert_ignore($db, 'organizations', $o, $log, $errors);
    }
}

// ── USERS ──
if ((int) $db->query("SELECT COUNT(*) FROM `users`")->fetchColumn() === 0) {
    $users = [
        ['id' => 'user-super-01', 'org_id' => 'org-ringvia360', 'name' => 'Rajesh Sharma', 'email' => 'superadmin@ringvia360.com', 'password_hash' => password_hash('RingVia@2026!', PASSWORD_BCRYPT), 'role' => 'super_admin', 'phone' => '+91 98200 99999', 'status' => 'active'],
        ['id' => 'user-admin-01', 'org_id' => 'org-tcs',        'name' => 'Rajesh Kumar',  'email' => 'admin@tcs.ringvia360.com',    'password_hash' => password_hash('Admin@123!',    PASSWORD_BCRYPT), 'role' => 'tenant_admin', 'phone' => '+91 98201 11223', 'status' => 'active'],
        ['id' => 'user-rep-01',   'org_id' => 'org-tcs',        'name' => 'Sneha Kapoor',  'email' => 'sneha.kapoor@tcs.com',       'password_hash' => password_hash('Rep@123!',      PASSWORD_BCRYPT), 'role' => 'rep',          'phone' => '+91 98201 33445', 'status' => 'active'],
        ['id' => 'user-admin-02', 'org_id' => 'org-infosys',    'name' => 'Priya Patel',   'email' => 'admin@infosys.ringvia360.com','password_hash' => password_hash('Admin@123!',    PASSWORD_BCRYPT), 'role' => 'tenant_admin', 'phone' => '+91 98450 12890', 'status' => 'active'],
        ['id' => 'user-admin-03', 'org_id' => 'org-hdfc',       'name' => 'Vikram Malhotra','email'=> 'admin@hdfc.ringvia360.com',   'password_hash' => password_hash('Admin@123!',    PASSWORD_BCRYPT), 'role' => 'tenant_admin', 'phone' => '+91 97110 56789', 'status' => 'active'],
    ];
    foreach ($users as $u) {
        insert_ignore($db, 'users', $u, $log, $errors);
    }
}

// ── SALES REPS ──
if ((int) $db->query("SELECT COUNT(*) FROM `sales_reps`")->fetchColumn() === 0) {
    $reps = [
        ['id' => 'rep-1', 'org_id' => 'org-tcs', 'name' => 'Rajesh Kumar',  'role' => 'Senior Enterprise AE',  'email' => 'rajesh.kumar@ringvia360.com',  'phone' => '+91 98201 11223', 'device_model' => 'Samsung Galaxy S24 Ultra', 'os_version' => 'Android 14 (Knox v3.9)', 'battery_level' => 91, 'is_online' => 1, 'last_sync' => 'Just now', 'calls_today' => 38, 'talk_time_minutes' => 184, 'deals_closed' => 4, 'conversion_rate' => 28.5, 'rank' => 1, 'streak_days' => 14, 'badges' => json_encode(['Top Performer', 'E2EE Certified', 'Speed Demon']), 'status' => 'active'],
        ['id' => 'rep-2', 'org_id' => 'org-tcs', 'name' => 'Sneha Kapoor',  'role' => 'Key Account Executive', 'email' => 'sneha.kapoor@ringvia360.com',  'phone' => '+91 98201 33445', 'device_model' => 'iPhone 15 Pro Max',       'os_version' => 'iOS 18.1 (CallKit)',     'battery_level' => 78, 'is_online' => 1, 'last_sync' => '2m ago',  'calls_today' => 29, 'talk_time_minutes' => 142, 'deals_closed' => 3, 'conversion_rate' => 24.1, 'rank' => 2, 'streak_days' => 9,  'badges' => json_encode(['Closing Specialist', 'Global Reach']), 'status' => 'active'],
        ['id' => 'rep-3', 'org_id' => 'org-tcs', 'name' => 'Amit Verma',    'role' => 'Inbound Sales Rep',     'email' => 'amit.verma@ringvia360.com',    'phone' => '+91 98201 55667', 'device_model' => 'Google Pixel 9 Pro',      'os_version' => 'Android 15',             'battery_level' => 64, 'is_online' => 1, 'last_sync' => '4m ago',  'calls_today' => 42, 'talk_time_minutes' => 126, 'deals_closed' => 2, 'conversion_rate' => 19.8, 'rank' => 3, 'streak_days' => 6,  'badges' => json_encode(['High Volume', 'Rapid Responder']),    'status' => 'active'],
        ['id' => 'rep-4', 'org_id' => 'org-tcs', 'name' => 'Priya Sharma',  'role' => 'SMB Sales Consultant',  'email' => 'priya.sharma@ringvia360.com',  'phone' => '+91 98201 77889', 'device_model' => 'Samsung Galaxy Z Fold 6', 'os_version' => 'Android 14',             'battery_level' => 82, 'is_online' => 0, 'last_sync' => '18m ago', 'calls_today' => 24, 'talk_time_minutes' => 98,  'deals_closed' => 2, 'conversion_rate' => 22.0, 'rank' => 4, 'streak_days' => 5,  'badges' => json_encode(['Customer Champion']),                 'status' => 'active'],
    ];
    foreach ($reps as $r) {
        insert_ignore($db, 'sales_reps', $r, $log, $errors);
    }
}

// ── LEADS / CONTACTS ──
if ((int) $db->query("SELECT COUNT(*) FROM `leads_contacts`")->fetchColumn() === 0) {
    $leads = [
        ['id' => 'lead-1', 'org_id' => 'org-tcs', 'name' => 'Aarav Sharma',    'phone_number' => '+91 98201 43210', 'company' => 'Tata Consultancy Services', 'title' => 'VP Engineering',       'open_deal_value' => 48000, 'last_contacted' => '2 mins ago'],
        ['id' => 'lead-2', 'org_id' => 'org-tcs', 'name' => 'Priya Patel',     'phone_number' => '+91 98450 12890', 'company' => 'Infosys Technologies',      'title' => 'Head of Procurement',  'open_deal_value' => 72000, 'last_contacted' => '18 mins ago'],
        ['id' => 'lead-3', 'org_id' => 'org-tcs', 'name' => 'Vikram Malhotra', 'phone_number' => '+91 97110 56789', 'company' => 'Wipro Enterprises',         'title' => 'CTO',                  'open_deal_value' => 0,     'last_contacted' => '42 mins ago'],
        ['id' => 'lead-4', 'org_id' => 'org-tcs', 'name' => 'Ananya Iyer',     'phone_number' => '+91 99001 77654', 'company' => 'HDFC Bank Corporate',       'title' => 'IT Director',          'open_deal_value' => 24000, 'last_contacted' => '1 hour ago'],
        ['id' => 'lead-5', 'org_id' => 'org-tcs', 'name' => 'Rohan Mehta',     'phone_number' => '+91 98190 23456', 'company' => 'Razorpay Software',         'title' => 'Head of Sales Ops',   'open_deal_value' => 18000, 'last_contacted' => '2 hours ago'],
    ];
    foreach ($leads as $l) {
        insert_ignore($db, 'leads_contacts', $l, $log, $errors);
    }
}

// ── CALL LOGS ──
if ((int) $db->query("SELECT COUNT(*) FROM `call_logs`")->fetchColumn() === 0) {
    $calls = [
        [
            'id' => 'call-101', 'org_id' => 'org-tcs',
            'contact_name' => 'Aarav Sharma', 'phone_number' => '+91 98201 43210', 'company' => 'Tata Consultancy Services',
            'direction' => 'outbound', 'duration' => 384, 'timestamp' => '2 mins ago',
            'rep_name' => 'Rajesh Kumar', 'rep_id' => 'rep-1',
            'rep_avatar' => 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80',
            'outcome' => 'Demo Completed - Contract Requested',
            'notes' => 'Decision maker confirmed budget for 50 licenses. Requested RingVia360 custom field mapping for lead source and call tags.',
            'sentiment' => 'positive', 'sentiment_score' => 94,
            'deal_value' => 48000, 'deal_stage' => 'Proposal / Review',
            'crm_status' => 'synced', 'crm_type' => 'RingVia360', 'crm_record_id' => 'rv360-rec-001',
            'is_encrypted' => 1, 'sim_slot' => 'SIM 1 (Corporate)',
            'recording_url' => 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
            'waveform' => json_encode([20,45,60,80,50,65,90,40,75,85,95,70,55,65,85,100,70,60,40,55,75,90,60,30]),
            'transcript' => json_encode([
                ['speaker' => 'Rajesh Kumar',  'text' => 'Namaste Aarav, thanks for jumping on. Following up on the enterprise sales tracking proposal.',        'timestamp' => '00:04'],
                ['speaker' => 'Aarav Sharma',  'text' => 'Namaste Rajesh! Yes, our leadership team loved the zero-click RingVia360 CRM sync.',                   'timestamp' => '00:15'],
                ['speaker' => 'Rajesh Kumar',  'text' => 'The dual-SIM logging ensures you comply with ISO & SOC2 audits without reps lifting a finger.',         'timestamp' => '00:32'],
                ['speaker' => 'Aarav Sharma',  'text' => 'That addresses our major blocker. Can we start a 50-seat pilot by next Monday?',                        'timestamp' => '01:10'],
                ['speaker' => 'Rajesh Kumar',  'text' => 'Absolutely! I will configure your RingVia360 portal mapping right after this call.',                    'timestamp' => '01:25'],
            ]),
            'key_action_items' => json_encode(['Send Docusign MSA for 50 licenses', 'Invite Aarav to RingVia360 Admin Portal sandbox', 'Schedule kickoff call with technical lead']),
            'tags' => json_encode(['Hot Lead', 'Enterprise', 'RingVia360 Sync', 'E2EE Ready']),
        ],
        [
            'id' => 'call-102', 'org_id' => 'org-tcs',
            'contact_name' => 'Priya Patel', 'phone_number' => '+91 98450 12890', 'company' => 'Infosys Technologies',
            'direction' => 'inbound', 'duration' => 512, 'timestamp' => '18 mins ago',
            'rep_name' => 'Sneha Kapoor', 'rep_id' => 'rep-2',
            'rep_avatar' => 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=120&auto=format&fit=crop&q=80',
            'outcome' => 'Technical Validation Passed',
            'notes' => 'Client tested inbound call capture on Samsung Knox devices. Confirmed zero delay sync to RingVia360.',
            'sentiment' => 'positive', 'sentiment_score' => 88,
            'deal_value' => 72000, 'deal_stage' => 'Technical Validation',
            'crm_status' => 'synced', 'crm_type' => 'RingVia360', 'crm_record_id' => 'rv360-rec-002',
            'is_encrypted' => 1, 'sim_slot' => 'SIM 1 (Corporate)',
            'recording_url' => 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
            'waveform' => json_encode([30,40,50,70,80,85,60,45,70,95,80,60,75,90,85,70,60,50,40,65,80,70,50,35]),
            'transcript' => json_encode([
                ['speaker' => 'Sneha Kapoor', 'text' => 'RingVia360 enterprise desk, Sneha speaking. How can I assist you today, Priya?', 'timestamp' => '00:03'],
                ['speaker' => 'Priya Patel',  'text' => 'Hi Sneha, we need to verify if inbound calls on Android 14 are logged when app is in background.', 'timestamp' => '00:18'],
                ['speaker' => 'Sneha Kapoor', 'text' => 'Yes, our background telephony service uses native OS CallScreening with zero battery drain.', 'timestamp' => '00:40'],
            ]),
            'key_action_items' => json_encode(['Email Android MDM deployment guide', 'Verify webhook delivery endpoints']),
            'tags' => json_encode(['Inbound Inquiry', 'RingVia360', 'Android 14', 'High Intent']),
        ],
        [
            'id' => 'call-103', 'org_id' => 'org-tcs',
            'contact_name' => 'Vikram Malhotra', 'phone_number' => '+91 97110 56789', 'company' => 'Wipro Enterprises',
            'direction' => 'missed', 'duration' => 0, 'timestamp' => '42 mins ago',
            'rep_name' => 'Rajesh Kumar', 'rep_id' => 'rep-1',
            'rep_avatar' => 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80',
            'outcome' => 'Missed Call - Auto Follow-up WhatsApp Sent',
            'notes' => 'Incoming call was missed during meeting. Auto-responder dispatched instant WhatsApp template with meeting link.',
            'sentiment' => 'neutral', 'sentiment_score' => 50,
            'deal_value' => 0, 'deal_stage' => 'Prospect',
            'crm_status' => 'synced', 'crm_type' => 'RingVia360', 'crm_record_id' => 'rv360-rec-003',
            'is_encrypted' => 1, 'sim_slot' => 'SIM 1 (Corporate)',
            'recording_url' => null, 'waveform' => null, 'transcript' => null,
            'key_action_items' => json_encode(['Check if client booked calendar slot by 4 PM']),
            'tags' => json_encode(['Missed Call', 'Automated Bot Triggered']),
        ],
        [
            'id' => 'call-104', 'org_id' => 'org-tcs',
            'contact_name' => 'Ananya Iyer', 'phone_number' => '+91 99001 77654', 'company' => 'HDFC Bank Corporate',
            'direction' => 'outbound', 'duration' => 215, 'timestamp' => '1 hour ago',
            'rep_name' => 'Rajesh Kumar', 'rep_id' => 'rep-1',
            'rep_avatar' => 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80',
            'outcome' => 'Follow-up Scheduled',
            'notes' => 'Spoke with Ananya. Reviewed banking compliance and Knox E2EE dual-SIM isolation.',
            'sentiment' => 'neutral', 'sentiment_score' => 65,
            'deal_value' => 24000, 'deal_stage' => 'Discovery',
            'crm_status' => 'synced', 'crm_type' => 'RingVia360', 'crm_record_id' => 'rv360-rec-004',
            'is_encrypted' => 1, 'sim_slot' => 'SIM 1 (Corporate)',
            'recording_url' => 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
            'waveform' => json_encode([25,35,45,60,50,70,75,65,80,60,50,45,60,75,65,55,45,50,60,55,40,30,25,20]),
            'transcript' => null,
            'key_action_items' => json_encode(['Send RingVia360 security battlecard']),
            'tags' => json_encode(['Enterprise Banking', 'RingVia360 CRM']),
        ],
        [
            'id' => 'call-105', 'org_id' => 'org-tcs',
            'contact_name' => 'Rohan Mehta', 'phone_number' => '+91 98190 23456', 'company' => 'Razorpay Software',
            'direction' => 'outbound', 'duration' => 140, 'timestamp' => '2 hours ago',
            'rep_name' => 'Amit Verma', 'rep_id' => 'rep-3',
            'rep_avatar' => 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=120&auto=format&fit=crop&q=80',
            'outcome' => 'Commercial Agreement Sent',
            'notes' => 'Confirmed 25 licenses for payment sales squad. Pre-configured RingVia360 webhooks.',
            'sentiment' => 'positive', 'sentiment_score' => 82,
            'deal_value' => 18000, 'deal_stage' => 'Negotiation',
            'crm_status' => 'synced', 'crm_type' => 'RingVia360', 'crm_record_id' => null,
            'is_encrypted' => 1, 'sim_slot' => 'SIM 1 (Corporate)',
            'recording_url' => null, 'waveform' => null, 'transcript' => null,
            'key_action_items' => json_encode(['Verify Razorpay webhook authorization keys']),
            'tags' => json_encode(['Fast Close', 'Fintech']),
        ],
    ];
    foreach ($calls as $c) {
        insert_ignore($db, 'call_logs', $c, $log, $errors);
    }
}

// ── WHATSAPP LOGS ──
if ((int) $db->query("SELECT COUNT(*) FROM `whatsapp_logs`")->fetchColumn() === 0) {
    $wa = [
        ['id' => 'wa-1', 'org_id' => 'org-tcs', 'contact_name' => 'Aarav Sharma',    'phone_number' => '+91 98201 43210', 'company' => 'Tata Consultancy Services', 'message_count' => 14, 'last_message' => 'Received the RingVia360 enterprise license details! Our team is very happy.',   'timestamp' => '5 mins ago',  'rep_name' => 'Rajesh Kumar', 'sentiment' => 'positive', 'crm_status' => 'synced', 'crm_type' => 'RingVia360', 'media_count' => 3,  'is_business_api' => 1],
        ['id' => 'wa-2', 'org_id' => 'org-tcs', 'contact_name' => 'Priya Patel',     'phone_number' => '+91 98111 22334', 'company' => 'Infosys Technologies',      'message_count' => 8,  'last_message' => 'Please send over the NDA and E2EE cloud call recording compliance report.', 'timestamp' => '28 mins ago', 'rep_name' => 'Sneha Kapoor', 'sentiment' => 'neutral',  'crm_status' => 'synced', 'crm_type' => 'RingVia360', 'media_count' => 1,  'is_business_api' => 1],
        ['id' => 'wa-3', 'org_id' => 'org-tcs', 'contact_name' => 'Vikram Malhotra', 'phone_number' => '+91 99887 76655', 'company' => 'HDFC Bank Enterprise',       'message_count' => 22, 'last_message' => 'Confirmed payment receipt for the 150-seat annual RingVia360 plan. Thank you!', 'timestamp' => '1 hour ago',  'rep_name' => 'Rajesh Kumar', 'sentiment' => 'positive', 'crm_status' => 'synced', 'crm_type' => 'RingVia360', 'media_count' => 4, 'is_business_api' => 1],
    ];
    foreach ($wa as $w) {
        insert_ignore($db, 'whatsapp_logs', $w, $log, $errors);
    }
}

// ── ADMIN USERS ──
if ((int) $db->query("SELECT COUNT(*) FROM `admin_users`")->fetchColumn() === 0) {
    $admins = [
        ['id' => 'u-1', 'org_id' => 'org-tcs', 'name' => 'Rajesh Kumar',    'email' => 'rajesh.kumar@ringvia360.com',   'role' => 'Sales Director',       'status' => 'Active', 'sim' => 'SIM 1 Bound', 'device' => 'Galaxy S24 Ultra (Knox)', 'last_active' => 'Just now'],
        ['id' => 'u-2', 'org_id' => 'org-tcs', 'name' => 'Sneha Kapoor',    'email' => 'sneha.kapoor@ringvia360.com',   'role' => 'Account Executive',    'status' => 'Active', 'sim' => 'SIM 1 Bound', 'device' => 'iPhone 15 Pro Max',       'last_active' => '2m ago'],
        ['id' => 'u-3', 'org_id' => 'org-tcs', 'name' => 'Amit Verma',      'email' => 'amit.verma@ringvia360.com',     'role' => 'Inbound Specialist',   'status' => 'Active', 'sim' => 'SIM 1 Bound', 'device' => 'Pixel 9 Pro',             'last_active' => '5m ago'],
        ['id' => 'u-4', 'org_id' => 'org-tcs', 'name' => 'Priya Sharma',    'email' => 'priya.sharma@ringvia360.com',   'role' => 'Team Lead',            'status' => 'Active', 'sim' => 'SIM 1 Bound', 'device' => 'Galaxy Z Fold 6',         'last_active' => '15m ago'],
        ['id' => 'u-5', 'org_id' => 'org-tcs', 'name' => 'Vikram Deshmukh', 'email' => 'vikram.deshmukh@ringvia360.com','role' => 'Compliance Officer',   'status' => 'Active', 'sim' => 'Unbound',     'device' => 'MacBook Pro / Web',       'last_active' => '1h ago'],
    ];
    foreach ($admins as $a) {
        insert_ignore($db, 'admin_users', $a, $log, $errors);
    }
}

// ── CRM CONNECTORS ──
if ((int) $db->query("SELECT COUNT(*) FROM `crm_connectors`")->fetchColumn() === 0) {
    $crms = [
        ['id' => 'crm-rv360',    'org_id' => 'org-tcs', 'name' => 'RingVia360',  'description' => 'Native unified enterprise sync of Call Logs, Transcripts, Dual-SIM Audio & WhatsApp', 'icon' => '⚡', 'is_connected' => 1, 'last_sync_time' => 'Real-time (Active)', 'synced_records_count' => 24820, 'pending_sync_count' => 0, 'auto_sync' => 1, 'api_endpoint' => 'https://ringvia360.com/api/calls.php', 'health' => 'healthy'],
        ['id' => 'crm-hubspot',  'org_id' => 'org-tcs', 'name' => 'HubSpot',     'description' => 'Automatic contact matching, deal tracking and call recording audio attachment',          'icon' => '🟠', 'is_connected' => 1, 'last_sync_time' => '1m ago',            'synced_records_count' => 9430,  'pending_sync_count' => 0, 'auto_sync' => 1, 'api_endpoint' => 'https://api.hubapi.com/crm/v3/objects/calls',     'health' => 'healthy'],
        ['id' => 'crm-zoho',     'org_id' => 'org-tcs', 'name' => 'Zoho CRM',    'description' => 'Seamless telephony integration module with instant call popup',                          'icon' => '🔴', 'is_connected' => 1, 'last_sync_time' => '5m ago',            'synced_records_count' => 4210,  'pending_sync_count' => 0, 'auto_sync' => 1, 'api_endpoint' => 'https://www.zohoapis.com/crm/v2/Calls',          'health' => 'healthy'],
        ['id' => 'crm-pipe',     'org_id' => 'org-tcs', 'name' => 'Pipedrive',   'description' => 'Sync activities to deals with automated pipeline stage progression',                    'icon' => '🟢', 'is_connected' => 0, 'last_sync_time' => 'Never',             'synced_records_count' => 0,     'pending_sync_count' => 0, 'auto_sync' => 0, 'api_endpoint' => null,                                              'health' => 'disconnected'],
        ['id' => 'crm-webhook',  'org_id' => 'org-tcs', 'name' => 'Webhook API', 'description' => 'Zero-latency JSON stream of call and WhatsApp events to your data warehouse',           'icon' => '🚀', 'is_connected' => 1, 'last_sync_time' => 'Just now',          'synced_records_count' => 28490, 'pending_sync_count' => 0, 'auto_sync' => 1, 'api_endpoint' => 'https://ringvia360.com/api/calls.php',           'health' => 'healthy'],
    ];
    foreach ($crms as $c) {
        insert_ignore($db, 'crm_connectors', $c, $log, $errors);
    }
}

// ── AUDIT LOGS ──
if ((int) $db->query("SELECT COUNT(*) FROM `audit_logs`")->fetchColumn() === 0) {
    $audits = [
        ['id' => 'audit-1', 'org_id' => 'org-tcs', 'user_email' => 'rajesh.kumar@ringvia360.com',  'action' => 'Call Recording Encrypted & Uploaded',   'details' => 'Call #call-101 encrypted via KMS Key with AES-256-GCM and saved to RingVia360 server',        'ip_address' => '103.21.244.12', 'severity' => 'info', 'signature' => 'SHA256:8f4c2e1b...9a43'],
        ['id' => 'audit-2', 'org_id' => 'org-tcs', 'user_email' => 'system-agent',                  'action' => 'RingVia360 Bi-directional Sync',         'details' => 'Synced Call #call-101 to RingVia360 CRM Opportunity RV360-101 in 112ms',                    'ip_address' => '10.0.4.12',     'severity' => 'info', 'signature' => 'SHA256:3d1e7c9f...5521'],
        ['id' => 'audit-3', 'org_id' => 'org-tcs', 'user_email' => 'compliance@ringvia360.com',     'action' => 'DPDP Act Compliance Retention Check',    'details' => 'Automated 90-day retention verification completed. All voice data encrypted at rest.',        'ip_address' => '103.21.244.89', 'severity' => 'info', 'signature' => 'SHA256:1a2b3c4d...e5f6'],
        ['id' => 'audit-4', 'org_id' => 'org-tcs', 'user_email' => 'sneha.kapoor@ringvia360.com',   'action' => 'Device Attestation Verified',            'details' => 'iOS Hardware Secure Enclave token validated for iPhone 15 Pro Max',                           'ip_address' => '103.21.244.90', 'severity' => 'info', 'signature' => 'SHA256:90ab89ef...1234'],
    ];
    foreach ($audits as $a) {
        insert_ignore($db, 'audit_logs', $a, $log, $errors);
    }
}

// ── SECURITY SETTINGS ──
if ((int) $db->query("SELECT COUNT(*) FROM `security_settings`")->fetchColumn() === 0) {
    insert_ignore($db, 'security_settings', [
        'id'                          => 'default',
        'org_id'                      => 'org-tcs',
        'e2ee_enabled'                => 1,
        'kms_key_alias'               => 'alias/ringvia360-enterprise-vault-v2',
        'call_recording_consent'      => 'two-party-beep',
        'auto_redact_pii'             => 1,
        'data_retention_days'         => 90,
        'whitelisted_ips'             => json_encode(['198.51.100.0/24', '192.0.2.0/24']),
        'device_attestation_enforced' => 1,
    ], $log, $errors);
}

// ── SITE PAGES (CMS CONTENT) ──
if ((int) $db->query("SELECT COUNT(*) FROM `site_pages`")->fetchColumn() === 0) {
    $pages = [
        // HOME
        ['id'=>'sec-home-hero',     'page_key'=>'home',       'page_title'=>'Home',       'section_key'=>'hero',              'content_title'=>'Automate Call Tracking & Audio Intelligence for Enterprise Sales', 'content_subtitle'=>'RingVia360 securely captures SIM & VoIP calls, generates real-time audio transcripts & waveforms, and syncs directly into your CRM with zero battery drain.', 'body_text'=>'Built for high-velocity Indian & global sales teams. Native Samsung Knox dual-SIM hardware partition separates personal calls from corporate CRM activity.', 'media_url'=>'', 'json_data'=>json_encode(['badge'=>'⚡ ENTERPRISE TELEPHONY AUTOMATION 2026','cta_primary'=>'Open Executive Dashboard','cta_secondary'=>'Launch Mobile Dialer Simulator','trust_badge'=>'Trusted by 450+ High-Growth Enterprises Across India']), 'display_order'=>1],
        ['id'=>'sec-home-stats',    'page_key'=>'home',       'page_title'=>'Home',       'section_key'=>'stats',             'content_title'=>'Platform Benchmark & Performance Numbers', 'content_subtitle'=>'Real-time telemetry from enterprise production instances', 'body_text'=>'Our carrier-grade cloud network processes hundreds of thousands of outbound calls daily.', 'media_url'=>'', 'json_data'=>json_encode(['items'=>[['value'=>'99.8%','label'=>'Automated Call Capture','desc'=>'Zero manual rep logging required'],['value'=>'₹48.5L+','label'=>'Daily Deal Volume Tracked','desc'=>'Integrated CRM pipeline attribution'],['value'=>'45%','label'=>'Productivity Increase','desc'=>'Saved 1.5 hrs/rep/day in data entry'],['value'=>'100%','label'=>'Knox E2EE Isolation','desc'=>'Complete hardware privacy protection']]]), 'display_order'=>2],
        ['id'=>'sec-home-features', 'page_key'=>'home',       'page_title'=>'Home',       'section_key'=>'features_highlight','content_title'=>'Core Differentiators That Outperform Legacy Dialers', 'content_subtitle'=>'Enterprise compliance, automated CRM logging, and instant WhatsApp customer follow-up.', 'body_text'=>'Eliminate manual CRM entry and stop losing deals to forgotten follow-ups.', 'media_url'=>'', 'json_data'=>json_encode(['features'=>[['icon'=>'ShieldCheck','title'=>'Hardware Knox Dual-SIM Isolation','desc'=>'Only business SIM activity is tracked. Personal SIM calls, SMS, and data remain 100% private to the employee.'],['icon'=>'Lock','title'=>'End-to-End Encrypted Call Audio','desc'=>'All call recordings and transcripts are encrypted with AES-256 before leaving the mobile device.'],['icon'=>'Sparkles','title'=>'AI Sentiment & Waveform Pod','desc'=>'Immediate post-call sentiment classification (Positive / Neutral / Negative) with interactive audio scrubbing.'],['icon'=>'MessageCircle','title'=>'Automated WhatsApp Dispatch','desc'=>'Instantly dispatches corporate WhatsApp message templates with meeting links upon call wrap-up.'],['icon'=>'RefreshCw','title'=>'Bi-Directional CRM Sync','desc'=>'Direct real-time webhooks sync to HubSpot, Zoho CRM, LeadSquared, and Freshsales.']]]), 'display_order'=>3],
        ['id'=>'sec-home-compare',  'page_key'=>'home',       'page_title'=>'Home',       'section_key'=>'comparison',        'content_title'=>'Why Enterprise Teams Choose RingVia360', 'content_subtitle'=>'A head-to-head comparison with legacy sales dialers.', 'body_text'=>'', 'media_url'=>'', 'json_data'=>json_encode(['rows'=>[['feature'=>'Automatic Call & WhatsApp Logging','legacy'=>'Basic mobile logger','rv'=>'Zero-latency native background event engine'],['feature'=>'Speech-to-Text Transcription','legacy'=>'Third-party add-on','rv'=>'Native Whisper AI diarization included'],['feature'=>'AI Sentiment & Deal Health Scoring','legacy'=>'Not available','rv'=>'Automated deal risk & sentiment detection'],['feature'=>'Dual-SIM Personal Privacy Isolation','legacy'=>'Partial Android only','rv'=>'Hardware-enforced SIM policy (iOS & Android)'],['feature'=>'End-to-End Encryption (E2EE)','legacy'=>'Server-side standard','rv'=>'Client-side AES-256-GCM + Cloud KMS vault'],['feature'=>'Two-Party Consent Enforcement','legacy'=>'Manual rep note','rv'=>'Automatic audio beep & consent compliance'],['feature'=>'CRM Custom Field Mapping','legacy'=>'Fixed templates','rv'=>'Bi-directional visual schema mapper'],['feature'=>'Interactive Rep Mobile Simulator','legacy'=>'None','rv'=>'Embedded in-browser test phone simulator']]]), 'display_order'=>4],

        // FEATURES
        ['id'=>'sec-features-hero', 'page_key'=>'features',   'page_title'=>'Features',   'section_key'=>'hero',              'content_title'=>'Enterprise Telephony Engineered for Modern Sales Teams', 'content_subtitle'=>'Deep mobile telemetry, carrier-grade audio capture, and autonomous CRM automation for seamless closing.', 'body_text'=>'RingVia360 combines high-availability mobile companion apps with web admin supervision.', 'media_url'=>'', 'json_data'=>json_encode(['badge'=>'PLATFORM CAPABILITIES','filter_categories'=>['All Capabilities','Compliance & Privacy','CRM Automation','Speech Intelligence']]), 'display_order'=>1],
        ['id'=>'sec-features-list', 'page_key'=>'features',   'page_title'=>'Features',   'section_key'=>'feature_list',      'content_title'=>'Full Feature Set', 'content_subtitle'=>'Everything included in every plan', 'body_text'=>'', 'media_url'=>'', 'json_data'=>json_encode(['features'=>[['icon'=>'Smartphone','title'=>'Native Background Telephony SDK','desc'=>'Runs seamlessly on Android Knox and iOS CallKit. Detects inbound, outbound, and missed calls with zero battery drain and complete dual-SIM privacy separation.','category'=>'Compliance & Privacy'],['icon'=>'Zap','title'=>'WhatsApp Business Intelligence','desc'=>'Track text message volume, attachments, response times, and client sentiment without disrupting the rep chat experience.','category'=>'CRM Automation'],['icon'=>'Sparkles','title'=>'AI Transcripts & Deal Sentiment','desc'=>'Powered by Whisper & Gemini AI: turns recordings into instant transcripts, extracts action items, detects buyer hesitation.','category'=>'Speech Intelligence'],['icon'=>'Share2','title'=>'Universal CRM Sync Pipeline','desc'=>'Plug-and-play connectors for RingVia360 CRM, HubSpot, Zoho, and real-time Webhooks with guaranteed delivery.','category'=>'CRM Automation'],['icon'=>'Lock','title'=>'Bank-Grade E2EE & Compliance','desc'=>'End-to-end encrypted audio storage, Cloud KMS master keys, two-party consent beep automation, and GDPR right-to-erasure.','category'=>'Compliance & Privacy'],['icon'=>'Award','title'=>'Gamified Rep Leaderboard','desc'=>'Inspire healthy competition with activity streak counters, conversion velocity trophies, and live device telemetry.','category'=>'CRM Automation']]]), 'display_order'=>2],

        // PRICING
        ['id'=>'sec-pricing-hero',  'page_key'=>'pricing',    'page_title'=>'Pricing',    'section_key'=>'hero',              'content_title'=>'Corporate Pricing Tailored for Indian & Global Scale', 'content_subtitle'=>'Transparent INR corporate pricing with isolated tenant workspaces, unlimited storage, and 99.9% uptime SLA.', 'body_text'=>'Every subscription includes private database isolation, Knox hardware telemetry, and dedicated support.', 'media_url'=>'', 'json_data'=>json_encode(['badge'=>'SIMPLE TRANSPARENT PLANS IN INR','billing_period'=>'monthly','plans'=>[['id'=>'starter','name'=>'Starter Team','price_inr'=>'₹4,999','period'=>'/ month','max_reps'=>'Up to 5 Reps','features'=>['Automated SIM Call Capture','Encrypted Audio Recording','RingVia360 Cloud CRM','Post-Call Notes & Audio Pod','Email Support'],'popular'=>false],['id'=>'pro','name'=>'Growth & Scale','price_inr'=>'₹14,999','period'=>'/ month','max_reps'=>'Up to 25 Reps','features'=>['Everything in Starter','Knox Dual-SIM Separation','HubSpot & Zoho Auto-Sync','AI Sentiment & Waveform Pod','Priority Phone Support'],'popular'=>true],['id'=>'enterprise','name'=>'Enterprise Business','price_inr'=>'₹45,000','period'=>'/ month','max_reps'=>'Up to 100 Reps','features'=>['Everything in Growth','Custom CRM Field Mappings','Dedicated Multi-Tenant Isolation','Custom WhatsApp Bot Templates','24/7 Dedicated Account Manager'],'popular'=>false],['id'=>'banking','name'=>'Banking & Telecom','price_inr'=>'₹85,000','period'=>'/ month','max_reps'=>'Unlimited Reps','features'=>['Custom On-Prem / VPC Hosting','SOC-2 & ISO 27001 Compliance','Custom Knox MDM Integration','Unlimited Call Audio Vault','Tailored SLA Guarantee'],'popular'=>false]]]), 'display_order'=>1],

        // ACTIVITIES
        ['id'=>'sec-activities-hero','page_key'=>'activities','page_title'=>'Activities', 'section_key'=>'hero',              'content_title'=>'Real-Time Sales Activity & Call Stream', 'content_subtitle'=>'Live inbound and outbound call feeds with waveform audio player, rep attribution, and CRM delivery verification.', 'body_text'=>'Monitor rep conversations as they happen across all active field agents.', 'media_url'=>'', 'json_data'=>json_encode(['live_banner'=>'LIVE FEED CONNECTED • 41 ACTIVE CALLS SYNCHRONIZED TODAY','quick_filters'=>['All Calls','Inbound','Outbound','Missed','High Value (>₹50k)']]), 'display_order'=>1],

        // ANALYTICS
        ['id'=>'sec-analytics-hero','page_key'=>'analytics',  'page_title'=>'Analytics',  'section_key'=>'hero',              'content_title'=>'Telephony Performance & Pipeline Intelligence', 'content_subtitle'=>'Transform field calling volume into quantifiable revenue outcomes and rep coaching opportunities.', 'body_text'=>'Interactive drill-downs into call duration distributions, conversion velocity, and sentiment scores.', 'media_url'=>'', 'json_data'=>json_encode(['target_talk_time_min'=>180,'positive_sentiment_goal'=>'85%','active_reps_online'=>12]), 'display_order'=>1],

        // CRM SYNC
        ['id'=>'sec-crm-hero',      'page_key'=>'crm_sync',   'page_title'=>'CRM Sync',   'section_key'=>'hero',              'content_title'=>'Zero-Touch Bi-Directional CRM Integrations', 'content_subtitle'=>'Eliminate manual logging forever. Every call, note, audio recording, and sentiment tag is automatically pushed to your CRM.', 'body_text'=>'Supports automatic contact creation, deal stage progression, and custom field synchronization.', 'media_url'=>'', 'json_data'=>json_encode(['supported_crms'=>['Salesforce','HubSpot','Zoho CRM','LeadSquared','Freshsales','Custom Webhooks'],'sync_frequency'=>'Real-time (sub-second webhook push)']), 'display_order'=>1],

        // DASHBOARD
        ['id'=>'sec-dashboard-hero','page_key'=>'dashboard',  'page_title'=>'Dashboard',  'section_key'=>'hero',              'content_title'=>'Executive Sales Intelligence', 'content_subtitle'=>'Real-time call logs, WhatsApp outreach, and CRM pipeline progression across your sales team.', 'body_text'=>'Monitor every rep, every call, and every deal — all in one unified command center.', 'media_url'=>'', 'json_data'=>json_encode(['live_badge'=>'LIVE TELEMETRY','time_ranges'=>['today','week','month']]), 'display_order'=>1],

        // LEADERBOARD
        ['id'=>'sec-leaderboard-hero','page_key'=>'leaderboard','page_title'=>'Leaderboard','section_key'=>'hero',            'content_title'=>'Sales Performance Leaderboard', 'content_subtitle'=>'Gamified rep rankings based on calls made, deals closed, and talk-time targets achieved.', 'body_text'=>'Drive friendly competition and celebrate top performers across your field sales team.', 'media_url'=>'', 'json_data'=>json_encode(['badges'=>['🏆 Top Performer','⚡ Speed Demon','🔥 On Fire','💎 Deal Closer'],'streak_goal_days'=>14]), 'display_order'=>1],

        // LOGIN / AUTH
        ['id'=>'sec-login-hero',    'page_key'=>'login',      'page_title'=>'Login',      'section_key'=>'hero',              'content_title'=>'Welcome Back to RingVia360', 'content_subtitle'=>'Enterprise Call Intelligence & Automated CRM Sync Platform', 'body_text'=>'Secure multi-tenant login. Your data is isolated and encrypted.', 'media_url'=>'', 'json_data'=>json_encode(['demo_admin_email'=>'admin@tcs.ringvia360.com','demo_admin_pass'=>'Admin@123!','demo_super_email'=>'superadmin@ringvia360.com','demo_super_pass'=>'RingVia@2026!']), 'display_order'=>1],

        // SECURITY
        ['id'=>'sec-security-hero', 'page_key'=>'security',   'page_title'=>'Security',   'section_key'=>'hero',              'content_title'=>'Enterprise-Grade Security & Compliance', 'content_subtitle'=>'AES-256-GCM encryption at rest, DPDP Act compliance, and Samsung Knox hardware attestation.', 'body_text'=>'Every call recording is encrypted client-side before upload. Zero plaintext audio ever leaves the device.', 'media_url'=>'', 'json_data'=>json_encode(['certifications'=>['ISO 27001','SOC-2 Type II','DPDP Act (India)','GDPR']]), 'display_order'=>1],
    ];

    $stmt = $db->prepare("
        INSERT IGNORE INTO `site_pages`
            (id, page_key, page_title, section_key, content_title, content_subtitle, body_text, media_url, json_data, display_order, is_active)
        VALUES
            (:id, :page_key, :page_title, :section_key, :content_title, :content_subtitle, :body_text, :media_url, :json_data, :display_order, 1)
    ");
    foreach ($pages as $p) {
        try {
            $stmt->execute([
                ':id'               => $p['id'],
                ':page_key'         => $p['page_key'],
                ':page_title'       => $p['page_title'],
                ':section_key'      => $p['section_key'],
                ':content_title'    => $p['content_title'],
                ':content_subtitle' => $p['content_subtitle'],
                ':body_text'        => $p['body_text'],
                ':media_url'        => $p['media_url'],
                ':json_data'        => $p['json_data'],
                ':display_order'    => $p['display_order'],
            ]);
            $log[] = "  ↳ site_pages: {$p['page_key']} / {$p['section_key']}";
        } catch (Throwable $e) {
            $errors[] = "  ↳ site_pages {$p['id']}: " . $e->getMessage();
        }
    }
}

$log[] = '';
$log[] = '─── All seed data inserted ───';

// ─────────────────────────────────────────────
// 4. COLLECT TABLE COUNTS FOR STATUS DISPLAY
// ─────────────────────────────────────────────
$tables = ['organizations','users','sales_reps','leads_contacts','call_logs','whatsapp_logs','admin_users','crm_connectors','audit_logs','security_settings','site_pages'];
$counts = [];
foreach ($tables as $t) {
    $counts[$t] = row_count($db, $t);
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>RingVia360 — DB Setup Status</title>
    <style>
        *{box-sizing:border-box;margin:0;padding:0}
        body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:#080d16;color:#e2e8f0;padding:2rem 1rem;min-height:100vh}
        .wrap{max-width:860px;margin:0 auto}
        .card{background:#0f1623;border:1px solid #1e2d45;border-radius:16px;padding:2rem;margin-bottom:1.5rem}
        h1{font-size:1.8rem;font-weight:800;color:#38bdf8;margin-bottom:.5rem}
        h2{font-size:1.1rem;font-weight:700;color:#94a3b8;margin-bottom:1rem;text-transform:uppercase;letter-spacing:.05em}
        .badge{display:inline-block;padding:3px 10px;border-radius:999px;font-size:.72rem;font-weight:700;background:#0c4a6e;color:#38bdf8;margin-left:8px;vertical-align:middle}
        .badge.mysql{background:#064e3b;color:#34d399}
        .badge.err{background:#7f1d1d;color:#f87171}
        .meta{font-size:.82rem;color:#64748b;margin-bottom:1.5rem}
        .meta strong{color:#94a3b8}
        table{width:100%;border-collapse:collapse}
        th,td{text-align:left;padding:10px 14px;border-bottom:1px solid #1e2d45;font-size:.84rem}
        th{color:#64748b;font-weight:600;text-transform:uppercase;letter-spacing:.04em;background:#0a1120}
        td code{font-family:ui-monospace,monospace;color:#38bdf8;font-size:.8rem}
        td.ok{color:#34d399;font-weight:600}
        td.cnt{font-family:ui-monospace,monospace;color:#a78bfa}
        .log-box{background:#070b12;border:1px solid #1e2d45;border-radius:10px;padding:1rem;max-height:320px;overflow-y:auto;font-size:.75rem;line-height:1.7;font-family:ui-monospace,monospace}
        .log-box .ok{color:#34d399}.log-box .er{color:#f87171}.log-box .dim{color:#475569}
        .links{display:flex;gap:1rem;flex-wrap:wrap;margin-top:1rem}
        .links a{display:inline-block;padding:.5rem 1.1rem;border-radius:8px;background:#1e3a5f;color:#38bdf8;text-decoration:none;font-size:.84rem;font-weight:600;transition:background .15s}
        .links a:hover{background:#1d4ed8;color:#fff}
        .err-box{background:#1c0f0f;border:1px solid #7f1d1d;border-radius:10px;padding:1rem;font-size:.78rem;color:#f87171;font-family:ui-monospace,monospace;margin-top:1rem}
        .hero-row{display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:1rem;margin-bottom:1rem}
    </style>
</head>
<body>
<div class="wrap">
    <div class="card">
        <div class="hero-row">
            <div>
                <h1>⚡ RingVia360 Database Setup</h1>
                <div class="meta">
                    <strong>Host:</strong> <?= htmlspecialchars($activeHost) ?> &nbsp;|&nbsp;
                    <strong>DB:</strong> <?= htmlspecialchars($mysqlDb) ?> &nbsp;|&nbsp;
                    <strong>User:</strong> <?= htmlspecialchars($mysqlUser) ?>
                    <span class="badge mysql"><?= $driver ?></span>
                </div>
            </div>
            <div style="font-size:1.2rem;font-weight:800;color:<?= empty($errors) ? '#34d399' : '#f87171' ?>">
                <?= empty($errors) ? '✓ All Done' : '⚠ Errors' ?>
            </div>
        </div>

        <h2>Tables & Row Counts</h2>
        <table>
            <thead><tr><th>Table</th><th>Rows</th><th>Status</th></tr></thead>
            <tbody>
                <?php foreach ($counts as $t => $c): ?>
                <tr>
                    <td><code><?= htmlspecialchars($t) ?></code></td>
                    <td class="cnt"><?= htmlspecialchars($c) ?> rows</td>
                    <td class="ok">✓ Ready</td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>

        <div class="links">
            <a href="https://ringvia360.com/">← Home</a>
            <a href="https://ringvia360.com/login">Login Page</a>
            <a href="https://ringvia360.com/admin">Admin Portal</a>
            <a href="/api/pages.php?action=all">View Pages API JSON</a>
            <a href="/api/calls.php?action=list">View Calls API JSON</a>
            <a href="?format=json&v=<?= time() ?>">JSON Report</a>
        </div>
    </div>

    <div class="card">
        <h2>Setup Log</h2>
        <div class="log-box">
            <?php foreach ($log as $line): ?>
                <?php if (str_starts_with($line, '✅')): ?>
                    <div class="ok"><?= htmlspecialchars($line) ?></div>
                <?php elseif (str_starts_with($line, '  ↳')): ?>
                    <div class="dim"><?= htmlspecialchars($line) ?></div>
                <?php elseif (str_starts_with($line, '───')): ?>
                    <div style="color:#475569;margin:.25rem 0">────────────────────────</div>
                <?php else: ?>
                    <div class="dim"><?= htmlspecialchars($line) ?></div>
                <?php endif; ?>
            <?php endforeach; ?>
        </div>

        <?php if (!empty($errors)): ?>
        <div class="err-box">
            <strong>⚠ Errors:</strong><br>
            <?php foreach ($errors as $e): ?>
                <?= htmlspecialchars($e) ?><br>
            <?php endforeach; ?>
        </div>
        <?php endif; ?>
    </div>

    <div class="card">
        <h2>Demo Login Credentials</h2>
        <table>
            <thead><tr><th>Role</th><th>Email</th><th>Password</th></tr></thead>
            <tbody>
                <tr><td>Super Admin</td><td><code>superadmin@ringvia360.com</code></td><td><code>RingVia@2026!</code></td></tr>
                <tr><td>Tenant Admin (TCS)</td><td><code>admin@tcs.ringvia360.com</code></td><td><code>Admin@123!</code></td></tr>
                <tr><td>Sales Rep</td><td><code>sneha.kapoor@tcs.com</code></td><td><code>Rep@123!</code></td></tr>
                <tr><td>Tenant Admin (Infosys)</td><td><code>admin@infosys.ringvia360.com</code></td><td><code>Admin@123!</code></td></tr>
            </tbody>
        </table>
    </div>
</div>
</body>
</html>
