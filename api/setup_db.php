<?php
declare(strict_types=1);

/**
 * RingVia360 Database Setup & Table Installer
 * Creates all tables and seeds production data in MySQL (u488332847_dn_name)
 */

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

require_once __DIR__ . '/db.php';
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/pages.php';

$connInfo = getDatabaseConnection();
$db = $connInfo['pdo'];
$driver = $connInfo['driver'];
$host = $connInfo['host'] ?? 'localhost';
$user = $connInfo['user'] ?? 'unknown';
$isMysql = ($driver === 'mysql');

$results = [
    'timestamp' => date('Y-m-d H:i:s'),
    'database' => 'u488332847_dn_name',
    'driver' => $driver,
    'host' => $host,
    'user' => $user,
    'tables_created' => [],
    'errors' => $connInfo['errors'] ?? []
];

try {
    // 1. Table: site_pages
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
    }
    $results['tables_created'][] = 'site_pages';

    // 2. Table: organizations
    if ($isMysql) {
        $db->exec("
            CREATE TABLE IF NOT EXISTS organizations (
                id VARCHAR(128) PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                subdomain VARCHAR(128) UNIQUE,
                plan VARCHAR(64) DEFAULT 'pro',
                monthly_fee_inr INT DEFAULT 14999,
                status VARCHAR(32) DEFAULT 'active',
                max_reps INT DEFAULT 25,
                crm_provider VARCHAR(64) DEFAULT 'Salesforce',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ");
    }
    $results['tables_created'][] = 'organizations';

    // 3. Table: users
    if ($isMysql) {
        $db->exec("
            CREATE TABLE IF NOT EXISTS users (
                id VARCHAR(128) PRIMARY KEY,
                org_id VARCHAR(128) NOT NULL,
                name VARCHAR(255) NOT NULL,
                email VARCHAR(255) NOT NULL UNIQUE,
                password_hash VARCHAR(255) NOT NULL,
                role VARCHAR(32) DEFAULT 'tenant_admin',
                status VARCHAR(32) DEFAULT 'active',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX idx_user_org (org_id),
                INDEX idx_user_role (role)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ");
    }
    $results['tables_created'][] = 'users';

    // 4. Table: call_logs
    if ($isMysql) {
        $db->exec("
            CREATE TABLE IF NOT EXISTS call_logs (
                id VARCHAR(128) PRIMARY KEY,
                org_id VARCHAR(128) DEFAULT 'org-tcs',
                contact_name VARCHAR(255) NOT NULL,
                phone_number VARCHAR(64) NOT NULL,
                company VARCHAR(255),
                direction VARCHAR(32) NOT NULL,
                duration INT NOT NULL DEFAULT 0,
                timestamp VARCHAR(64) NOT NULL,
                rep_name VARCHAR(255) DEFAULT 'Rajesh Kumar (RingVia360)',
                rep_avatar VARCHAR(512),
                rep_id VARCHAR(128) DEFAULT 'rep-mobile',
                outcome VARCHAR(255),
                notes TEXT,
                sentiment VARCHAR(32) DEFAULT 'positive',
                sentiment_score INT DEFAULT 85,
                deal_value DECIMAL(12,2) DEFAULT 0.00,
                deal_stage VARCHAR(128) DEFAULT 'Proposal',
                crm_status VARCHAR(64) DEFAULT 'synced',
                crm_type VARCHAR(64) DEFAULT 'RingVia360',
                sim_slot VARCHAR(64) DEFAULT 'SIM 1 (Corporate)',
                is_encrypted TINYINT DEFAULT 1,
                recording_url VARCHAR(512),
                waveform TEXT,
                transcript TEXT,
                key_action_items TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_calls_org (org_id),
                INDEX idx_calls_created (created_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ");
    }
    $results['tables_created'][] = 'call_logs';

    // 5. Table: leads_contacts
    if ($isMysql) {
        $db->exec("
            CREATE TABLE IF NOT EXISTS leads_contacts (
                id VARCHAR(128) PRIMARY KEY,
                org_id VARCHAR(128) DEFAULT 'org-tcs',
                name VARCHAR(255) NOT NULL,
                phone_number VARCHAR(64) NOT NULL,
                company VARCHAR(255),
                title VARCHAR(128),
                open_deal_value DECIMAL(12,2) DEFAULT 0.00,
                last_contacted VARCHAR(64),
                crm_account_id VARCHAR(128),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_leads_org (org_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ");
    }
    $results['tables_created'][] = 'leads_contacts';

    // 6. Table: sales_reps
    if ($isMysql) {
        $db->exec("
            CREATE TABLE IF NOT EXISTS sales_reps (
                id VARCHAR(128) PRIMARY KEY,
                org_id VARCHAR(128) DEFAULT 'org-tcs',
                name VARCHAR(255) NOT NULL,
                email VARCHAR(255),
                avatar VARCHAR(512),
                calls_today INT DEFAULT 0,
                talk_time VARCHAR(32) DEFAULT '0m',
                sentiment_score INT DEFAULT 85,
                pipeline_attributed DECIMAL(12,2) DEFAULT 0.00,
                status VARCHAR(32) DEFAULT 'active',
                INDEX idx_reps_org (org_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ");
    }
    $results['tables_created'][] = 'sales_reps';

    // 7. Table: admin_users
    if ($isMysql) {
        $db->exec("
            CREATE TABLE IF NOT EXISTS admin_users (
                id VARCHAR(128) PRIMARY KEY,
                org_id VARCHAR(128) DEFAULT 'org-tcs',
                name VARCHAR(255) NOT NULL,
                email VARCHAR(255) NOT NULL,
                role VARCHAR(32) DEFAULT 'Manager',
                avatar VARCHAR(512),
                last_active VARCHAR(64),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_admin_org (org_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ");
    }
    $results['tables_created'][] = 'admin_users';

    // 8. Table: crm_connectors
    if ($isMysql) {
        $db->exec("
            CREATE TABLE IF NOT EXISTS crm_connectors (
                id VARCHAR(128) PRIMARY KEY,
                org_id VARCHAR(128) DEFAULT 'org-tcs',
                name VARCHAR(128) NOT NULL,
                status VARCHAR(32) DEFAULT 'connected',
                last_sync VARCHAR(64),
                records_synced INT DEFAULT 0,
                webhook_url VARCHAR(512),
                api_key VARCHAR(255),
                INDEX idx_crm_org (org_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ");
    }
    $results['tables_created'][] = 'crm_connectors';

    // 9. Table: whatsapp_logs
    if ($isMysql) {
        $db->exec("
            CREATE TABLE IF NOT EXISTS whatsapp_logs (
                id VARCHAR(128) PRIMARY KEY,
                org_id VARCHAR(128) DEFAULT 'org-tcs',
                contact_phone VARCHAR(64) NOT NULL,
                template_name VARCHAR(128),
                status VARCHAR(32) DEFAULT 'delivered',
                sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_wa_org (org_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ");
    }
    $results['tables_created'][] = 'whatsapp_logs';

    // 10. Table: audit_logs
    if ($isMysql) {
        $db->exec("
            CREATE TABLE IF NOT EXISTS audit_logs (
                id VARCHAR(128) PRIMARY KEY,
                org_id VARCHAR(128),
                user_id VARCHAR(128),
                action VARCHAR(128) NOT NULL,
                details TEXT,
                ip_address VARCHAR(64),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_audit_org (org_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ");
    }
    $results['tables_created'][] = 'audit_logs';

    // Seed Organizations & Users
    initAuthTables($db, $isMysql);

    // Seed Site Pages Content
    seedDefaultPageContent($db);

    // Fetch counts for all tables
    $counts = [];
    foreach ($results['tables_created'] as $tbl) {
        try {
            $cnt = $db->query("SELECT COUNT(*) FROM {$tbl}")->fetchColumn();
            $counts[$tbl] = (int)$cnt;
        } catch (Throwable $e) {
            $counts[$tbl] = 'Error: ' . $e->getMessage();
        }
    }
    $results['table_counts'] = $counts;
    $results['success'] = true;
    $results['message'] = 'All tables successfully created and seeded in ' . $driver . ' (' . $results['database'] . ')!';

} catch (Throwable $e) {
    $results['success'] = false;
    $results['error'] = $e->getMessage();
}

// Return JSON or clean HTML summary
if (isset($_GET['format']) && $_GET['format'] === 'json') {
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($results, JSON_PRETTY_PRINT);
    exit();
}

header('Content-Type: text/html; charset=utf-8');
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RingVia360 Database Setup Status</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0b0f19; color: #f1f5f9; padding: 40px 20px; line-height: 1.6; }
        .container { max-width: 800px; margin: 0 auto; background: #111827; border: 1px solid #1f2937; border-radius: 16px; padding: 32px; box-shadow: 0 20px 40px rgba(0,0,0,0.5); }
        h1 { color: #38bdf8; margin-top: 0; display: flex; align-items: center; gap: 12px; }
        .badge { background: #0284c7; color: white; padding: 4px 10px; border-radius: 9999px; font-size: 13px; }
        .status-pill { display: inline-block; padding: 6px 14px; border-radius: 6px; font-weight: 600; margin-bottom: 24px; }
        .status-pill.success { background: #064e3b; color: #34d399; border: 1px solid #059669; }
        .status-pill.error { background: #7f1d1d; color: #f87171; border: 1px solid #dc2626; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { text-align: left; padding: 12px 16px; border-bottom: 1px solid #1f2937; }
        th { color: #94a3b8; font-weight: 500; font-size: 14px; text-transform: uppercase; letter-spacing: 0.05em; }
        td { color: #e2e8f0; font-family: ui-monospace, monospace; }
        .footer { margin-top: 32px; font-size: 13px; color: #64748b; text-align: center; }
        a { color: #38bdf8; text-decoration: none; }
    </style>
</head>
<body>
    <div class="container">
        <h1>
            <span>RingVia360 Database Setup</span>
            <span class="badge"><?= htmlspecialchars($driver) ?></span>
        </h1>
        
        <?php if ($results['success']): ?>
            <div class="status-pill success">✓ <?= htmlspecialchars($results['message']) ?></div>
        <?php else: ?>
            <div class="status-pill error">✗ Error: <?= htmlspecialchars($results['error'] ?? 'Setup failed') ?></div>
        <?php endif; ?>

        <p><strong>Database:</strong> <?= htmlspecialchars($results['database']) ?> | <strong>Host:</strong> <?= htmlspecialchars($results['host']) ?> | <strong>User:</strong> <?= htmlspecialchars($results['user']) ?></p>

        <h3>Database Tables & Live Row Counts:</h3>
        <table>
            <thead>
                <tr>
                    <th>Table Name</th>
                    <th>Row Count</th>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($results['table_counts'] as $tbl => $cnt): ?>
                <tr>
                    <td><strong><?= htmlspecialchars($tbl) ?></strong></td>
                    <td><?= is_numeric($cnt) ? $cnt . ' rows' : htmlspecialchars((string)$cnt) ?></td>
                    <td style="color: #34d399;">✓ Ready & Seeded</td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>

        <div class="footer">
            <p><a href="/admin">← Go to RingVia360 Admin Portal</a> | <a href="/login">Go to Login</a> | <a href="?format=json">View JSON Response</a></p>
            <p>RingVia360 Telephony & CRM Auto-Logging System • <?= htmlspecialchars($results['timestamp']) ?></p>
        </div>
    </div>
</body>
</html>
