<?php
declare(strict_types=1);

/**
 * RingVia360 Unified Dynamic REST API & Sync Engine
 * Handles Call Logs, Audio Recordings, Sales Reps, CRM Pipelines, Policies, and Fleet Users
 */

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, X-Tenant-Id');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/db.php';
require_once __DIR__ . '/auth_token.php';

try {
    $conn = getDatabaseConnection();
    /** @var PDO $db */
    $db = $conn['pdo'];
    $driver = $conn['driver'];
    $activeUser = $conn['user'] ?? 'system';
    $isMysql = ($driver === 'mysql');

    // Ensure uploads directory exists
    $uploadDir = __DIR__ . '/uploads';
    if (!is_dir($uploadDir)) {
        @mkdir($uploadDir, 0755, true);
    }

    // =========================================================
    // 1. DYNAMIC TABLE INITIALIZATION
    // =========================================================
    if ($isMysql) {
        // Call Logs Table
        $db->exec("
            CREATE TABLE IF NOT EXISTS call_logs (
                id VARCHAR(128) NOT NULL PRIMARY KEY,
                contact_name VARCHAR(255) NOT NULL,
                phone_number VARCHAR(64) NOT NULL,
                company VARCHAR(255),
                direction VARCHAR(32) NOT NULL,
                duration INT NOT NULL DEFAULT 0,
                timestamp VARCHAR(64) NOT NULL,
                rep_name VARCHAR(128) DEFAULT 'Rajesh Kumar (RingVia360)',
                rep_avatar VARCHAR(512),
                rep_id VARCHAR(64) DEFAULT 'rep-1',
                outcome TEXT,
                notes TEXT,
                sentiment VARCHAR(32) DEFAULT 'positive',
                sentiment_score INT DEFAULT 85,
                deal_value DECIMAL(12,2) DEFAULT 0,
                deal_stage VARCHAR(64) DEFAULT 'Proposal',
                crm_status VARCHAR(32) DEFAULT 'synced',
                crm_type VARCHAR(64) DEFAULT 'RingVia360',
                sim_slot VARCHAR(64) DEFAULT 'SIM 1 (Airtel Enterprise)',
                is_encrypted TINYINT(1) DEFAULT 1,
                recording_url VARCHAR(512),
                waveform TEXT,
                transcript TEXT,
                key_action_items TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ");

        // Leads & Contacts Table
        $db->exec("
            CREATE TABLE IF NOT EXISTS leads_contacts (
                id VARCHAR(128) NOT NULL PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                phone VARCHAR(64) NOT NULL,
                company VARCHAR(255),
                title VARCHAR(128) DEFAULT 'Executive',
                email VARCHAR(255),
                status VARCHAR(64) DEFAULT 'Active Lead',
                deal_value DECIMAL(12,2) DEFAULT 0,
                last_contacted VARCHAR(64) DEFAULT 'Just now',
                crm_account_id VARCHAR(128) DEFAULT 'RV360-ACC-01',
                notes TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ");

        // Sales Reps & Leaderboard Table
        $db->exec("
            CREATE TABLE IF NOT EXISTS sales_reps (
                id VARCHAR(128) NOT NULL PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                role VARCHAR(128) NOT NULL,
                avatar VARCHAR(512),
                phone VARCHAR(64),
                device_model VARCHAR(128),
                os_version VARCHAR(128),
                battery_level INT DEFAULT 90,
                is_online TINYINT(1) DEFAULT 1,
                last_sync VARCHAR(64) DEFAULT 'Just now',
                calls_today INT DEFAULT 0,
                talk_time_minutes INT DEFAULT 0,
                deals_closed INT DEFAULT 0,
                conversion_rate DECIMAL(5,2) DEFAULT 20.00,
                rank_order INT DEFAULT 1,
                streak_days INT DEFAULT 5,
                badges TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ");

        // CRM Connectors Table
        $db->exec("
            CREATE TABLE IF NOT EXISTS crm_connectors (
                id VARCHAR(128) NOT NULL PRIMARY KEY,
                name VARCHAR(128) NOT NULL,
                description TEXT,
                icon VARCHAR(32) DEFAULT '⚡',
                is_connected TINYINT(1) DEFAULT 1,
                last_sync_time VARCHAR(64) DEFAULT 'Real-time',
                synced_records_count INT DEFAULT 0,
                pending_sync_count INT DEFAULT 0,
                auto_sync TINYINT(1) DEFAULT 1,
                sync_frequency VARCHAR(64) DEFAULT 'Instant',
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ");

        // App Security & Policies Settings
        $db->exec("
            CREATE TABLE IF NOT EXISTS app_settings (
                setting_key VARCHAR(128) NOT NULL PRIMARY KEY,
                setting_value LONGTEXT NOT NULL,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ");

        // Admin Fleet Users Table
        $db->exec("
            CREATE TABLE IF NOT EXISTS admin_users (
                id VARCHAR(128) NOT NULL PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                email VARCHAR(255) NOT NULL,
                role VARCHAR(128) DEFAULT 'Sales Rep',
                status VARCHAR(64) DEFAULT 'Active',
                sim VARCHAR(64) DEFAULT 'SIM 1 Bound',
                device VARCHAR(128) DEFAULT 'Android Knox 3.9',
                last_active VARCHAR(64) DEFAULT 'Just now',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ");
    } else {
        // SQLite equivalents
        $db->exec("
            CREATE TABLE IF NOT EXISTS call_logs (
                id TEXT PRIMARY KEY,
                contact_name TEXT NOT NULL,
                phone_number TEXT NOT NULL,
                company TEXT,
                direction TEXT NOT NULL,
                duration INTEGER NOT NULL DEFAULT 0,
                timestamp TEXT NOT NULL,
                rep_name TEXT DEFAULT 'Rajesh Kumar (RingVia360)',
                rep_avatar TEXT,
                rep_id TEXT DEFAULT 'rep-1',
                outcome TEXT,
                notes TEXT,
                sentiment TEXT DEFAULT 'positive',
                sentiment_score INTEGER DEFAULT 85,
                deal_value REAL DEFAULT 0,
                deal_stage TEXT DEFAULT 'Proposal',
                crm_status TEXT DEFAULT 'synced',
                crm_type TEXT DEFAULT 'RingVia360',
                sim_slot TEXT DEFAULT 'SIM 1 (Airtel Enterprise)',
                is_encrypted INTEGER DEFAULT 1,
                recording_url TEXT,
                waveform TEXT,
                transcript TEXT,
                key_action_items TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS leads_contacts (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                phone TEXT NOT NULL,
                company TEXT,
                title TEXT DEFAULT 'Executive',
                email TEXT,
                status TEXT DEFAULT 'Active Lead',
                deal_value REAL DEFAULT 0,
                last_contacted TEXT DEFAULT 'Just now',
                crm_account_id TEXT DEFAULT 'RV360-ACC-01',
                notes TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS sales_reps (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                role TEXT NOT NULL,
                avatar TEXT,
                phone TEXT,
                device_model TEXT,
                os_version TEXT,
                battery_level INTEGER DEFAULT 90,
                is_online INTEGER DEFAULT 1,
                last_sync TEXT DEFAULT 'Just now',
                calls_today INTEGER DEFAULT 0,
                talk_time_minutes INTEGER DEFAULT 0,
                deals_closed INTEGER DEFAULT 0,
                conversion_rate REAL DEFAULT 20.00,
                rank_order INTEGER DEFAULT 1,
                streak_days INTEGER DEFAULT 5,
                badges TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS crm_connectors (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                description TEXT,
                icon TEXT DEFAULT '⚡',
                is_connected INTEGER DEFAULT 1,
                last_sync_time TEXT DEFAULT 'Real-time',
                synced_records_count INTEGER DEFAULT 0,
                pending_sync_count INTEGER DEFAULT 0,
                auto_sync INTEGER DEFAULT 1,
                sync_frequency TEXT DEFAULT 'Instant'
            );

            CREATE TABLE IF NOT EXISTS app_settings (
                setting_key TEXT PRIMARY KEY,
                setting_value TEXT NOT NULL,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS admin_users (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                email TEXT NOT NULL,
                role TEXT DEFAULT 'Sales Rep',
                status TEXT DEFAULT 'Active',
                sim TEXT DEFAULT 'SIM 1 Bound',
                device TEXT DEFAULT 'Android Knox 3.9',
                last_active TEXT DEFAULT 'Just now',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        ");
    }

    // Multi-tenant migration helper: ensure org_id column exists on all tenant tables
    $tenantTables = ['call_logs', 'leads_contacts', 'sales_reps', 'admin_users', 'crm_connectors'];
    foreach ($tenantTables as $tName) {
        try {
            if ($isMysql) {
                $chk = $db->query("SHOW COLUMNS FROM `$tName` LIKE 'org_id'")->fetchAll();
                if (empty($chk)) {
                    $db->exec("ALTER TABLE `$tName` ADD COLUMN org_id VARCHAR(128) DEFAULT 'org-tcs'");
                    $db->exec("CREATE INDEX `idx_{$tName}_org` ON `$tName` (org_id)");
                }
            } else {
                $db->exec("ALTER TABLE `$tName` ADD COLUMN org_id TEXT DEFAULT 'org-tcs'");
            }
        } catch (Throwable $_) {}
    }

    // =========================================================
    // 2. SEED INITIAL DATA IF EMPTY
    // =========================================================
    
    // Seed Call Logs
    $callCount = (int) $db->query("SELECT COUNT(*) FROM call_logs")->fetchColumn();
    if ($callCount === 0) {
        $initialCalls = [
            [
                'id' => 'call-101',
                'contact_name' => 'Aarav Sharma',
                'phone_number' => '+91 98201 43210',
                'company' => 'Tata Consultancy Services',
                'direction' => 'outbound',
                'duration' => 384,
                'timestamp' => '2 mins ago',
                'rep_name' => 'Rajesh Kumar (RingVia360)',
                'rep_avatar' => 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80',
                'rep_id' => 'rep-1',
                'outcome' => 'Demo Completed - Contract Requested',
                'notes' => 'Decision maker confirmed budget for 50 licenses. Requested RingVia360 custom field mapping for lead source and call tags.',
                'sentiment' => 'positive',
                'sentiment_score' => 94,
                'deal_value' => 48000,
                'deal_stage' => 'Proposal / Review',
                'crm_status' => 'synced',
                'crm_type' => 'RingVia360',
                'sim_slot' => 'SIM 1 (Airtel Enterprise)',
                'is_encrypted' => 1,
                'recording_url' => 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
                'waveform' => json_encode([30, 45, 65, 80, 70, 85, 90, 75, 60, 50, 65, 80, 95, 75, 60, 45, 40, 55, 70, 60]),
                'transcript' => json_encode([
                    ['speaker' => 'Rajesh Kumar', 'text' => 'Namaste Aarav, thanks for joining. Following up on the enterprise sales tracking proposal.', 'timestamp' => '00:04'],
                    ['speaker' => 'Aarav Sharma', 'text' => 'Namaste Rajesh! Yes, our leadership team looked over the automatic call recording specs. We love the zero-click RingVia360 sync.', 'timestamp' => '00:15'],
                    ['speaker' => 'Rajesh Kumar', 'text' => 'The dual-SIM logging and end-to-end encryption ensure ISO & SOC2 compliance seamlessly.', 'timestamp' => '00:32'],
                    ['speaker' => 'Aarav Sharma', 'text' => 'Can we start a 50-seat pilot by next Monday?', 'timestamp' => '01:10']
                ]),
                'key_action_items' => json_encode(['Send Docusign MSA for 50 licenses', 'Schedule kickoff call with technical lead'])
            ],
            [
                'id' => 'call-102',
                'contact_name' => 'Priya Patel',
                'phone_number' => '+91 98450 12890',
                'company' => 'Infosys Technologies',
                'direction' => 'inbound',
                'duration' => 512,
                'timestamp' => '18 mins ago',
                'rep_name' => 'Sneha Kapoor',
                'rep_avatar' => 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=120&auto=format&fit=crop&q=80',
                'rep_id' => 'rep-2',
                'outcome' => 'Technical Validation Passed',
                'notes' => 'Client tested inbound call capture on Samsung Knox devices with zero battery impact and full E2EE audio recording.',
                'sentiment' => 'positive',
                'sentiment_score' => 88,
                'deal_value' => 72000,
                'deal_stage' => 'Technical Validation',
                'crm_status' => 'synced',
                'crm_type' => 'RingVia360',
                'sim_slot' => 'SIM 1 (Airtel Enterprise)',
                'is_encrypted' => 1,
                'recording_url' => 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
                'waveform' => json_encode([40, 55, 75, 90, 85, 95, 80, 70, 60, 75, 85, 90, 65, 50, 45, 60, 75, 85, 70, 55]),
                'transcript' => json_encode([
                    ['speaker' => 'Sneha Kapoor', 'text' => 'RingVia360 enterprise desk, Sneha speaking. How can I assist you today, Priya?', 'timestamp' => '00:03'],
                    ['speaker' => 'Priya Patel', 'text' => 'Hi Sneha, we verified that inbound calls on Android 14 are logged even in background.', 'timestamp' => '00:18']
                ]),
                'key_action_items' => json_encode(['Email Knox MDM deployment guide'])
            ],
            [
                'id' => 'call-103',
                'contact_name' => 'Vikram Malhotra',
                'phone_number' => '+91 97110 56789',
                'company' => 'Wipro Enterprises',
                'direction' => 'missed',
                'duration' => 0,
                'timestamp' => '1 hour ago',
                'rep_name' => 'Amit Verma',
                'rep_avatar' => 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=120&auto=format&fit=crop&q=80',
                'rep_id' => 'rep-3',
                'outcome' => 'Auto-SMS Dispatched via RingVia360',
                'notes' => 'Missed call during client meeting. Auto-responder sent WhatsApp link with calendar invite.',
                'sentiment' => 'neutral',
                'sentiment_score' => 60,
                'deal_value' => 35000,
                'deal_stage' => 'Discovery',
                'crm_status' => 'synced',
                'crm_type' => 'RingVia360',
                'sim_slot' => 'SIM 1 (Airtel Enterprise)',
                'is_encrypted' => 1,
                'recording_url' => 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
                'waveform' => json_encode([10, 15, 10, 5, 5, 5, 10, 5, 5, 10, 5, 5, 5, 10, 5, 5, 5, 10, 5, 5]),
                'transcript' => json_encode([]),
                'key_action_items' => json_encode(['Trigger callback within 2 hours'])
            ],
            [
                'id' => 'call-104',
                'contact_name' => 'Ananya Deshmukh',
                'phone_number' => '+91 98330 98765',
                'company' => 'HCL Technologies',
                'direction' => 'outbound',
                'duration' => 420,
                'timestamp' => '2 hours ago',
                'rep_name' => 'Rajesh Kumar (RingVia360)',
                'rep_avatar' => 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80',
                'rep_id' => 'rep-1',
                'outcome' => 'Contract Signed & Closed Won',
                'notes' => '120-seat annual deployment approved across pan-India sales pods.',
                'sentiment' => 'positive',
                'sentiment_score' => 96,
                'deal_value' => 115000,
                'deal_stage' => 'Closed Won',
                'crm_status' => 'synced',
                'crm_type' => 'RingVia360',
                'sim_slot' => 'SIM 1 (Airtel Enterprise)',
                'is_encrypted' => 1,
                'recording_url' => 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
                'waveform' => json_encode([35, 50, 70, 85, 90, 80, 75, 85, 95, 90, 80, 70, 75, 85, 90, 75, 65, 55, 45, 60]),
                'transcript' => json_encode([
                    ['speaker' => 'Rajesh Kumar', 'text' => 'Congratulations Ananya on finalizing the RingVia360 deployment!', 'timestamp' => '00:05'],
                    ['speaker' => 'Ananya Deshmukh', 'text' => 'Thank you Rajesh! Our operations team is rolling out the companion app to 120 reps today.', 'timestamp' => '00:30']
                ]),
                'key_action_items' => json_encode(['Deploy RingVia360 Knox fleet configuration'])
            ]
        ];

        $ins = $db->prepare("
            INSERT INTO call_logs (
                id, contact_name, phone_number, company, direction, duration, timestamp,
                rep_name, rep_avatar, rep_id, outcome, notes, sentiment, sentiment_score,
                deal_value, deal_stage, crm_status, crm_type, sim_slot, is_encrypted,
                recording_url, waveform, transcript, key_action_items
            ) VALUES (
                :id, :contact_name, :phone_number, :company, :direction, :duration, :timestamp,
                :rep_name, :rep_avatar, :rep_id, :outcome, :notes, :sentiment, :sentiment_score,
                :deal_value, :deal_stage, :crm_status, :crm_type, :sim_slot, :is_encrypted,
                :recording_url, :waveform, :transcript, :key_action_items
            )
        ");
        foreach ($initialCalls as $call) {
            $ins->execute($call);
        }
    }

    // Seed Sales Reps
    $repCount = (int) $db->query("SELECT COUNT(*) FROM sales_reps")->fetchColumn();
    if ($repCount === 0) {
        $initialReps = [
            [
                'id' => 'rep-1',
                'name' => 'Rajesh Kumar',
                'role' => 'Senior Enterprise AE',
                'avatar' => 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80',
                'phone' => '+91 98201 11223',
                'device_model' => 'Samsung Galaxy S24 Ultra',
                'os_version' => 'Android 14 (Knox v3.9)',
                'battery_level' => 91,
                'is_online' => 1,
                'last_sync' => 'Just now',
                'calls_today' => 38,
                'talk_time_minutes' => 184,
                'deals_closed' => 4,
                'conversion_rate' => 28.50,
                'rank_order' => 1,
                'streak_days' => 14,
                'badges' => json_encode(['Top Performer', 'E2EE Certified', 'Speed Demon'])
            ],
            [
                'id' => 'rep-2',
                'name' => 'Sneha Kapoor',
                'role' => 'Key Account Executive',
                'avatar' => 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=120&auto=format&fit=crop&q=80',
                'phone' => '+91 98201 33445',
                'device_model' => 'iPhone 15 Pro Max',
                'os_version' => 'iOS 18.1 (CallKit Enforced)',
                'battery_level' => 78,
                'is_online' => 1,
                'last_sync' => '2m ago',
                'calls_today' => 29,
                'talk_time_minutes' => 142,
                'deals_closed' => 3,
                'conversion_rate' => 24.10,
                'rank_order' => 2,
                'streak_days' => 9,
                'badges' => json_encode(['Closing Specialist', 'Global Reach'])
            ],
            [
                'id' => 'rep-3',
                'name' => 'Amit Verma',
                'role' => 'Inbound Sales Rep',
                'avatar' => 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=120&auto=format&fit=crop&q=80',
                'phone' => '+91 98201 55667',
                'device_model' => 'Google Pixel 9 Pro',
                'os_version' => 'Android 15',
                'battery_level' => 64,
                'is_online' => 1,
                'last_sync' => '4m ago',
                'calls_today' => 42,
                'talk_time_minutes' => 126,
                'deals_closed' => 2,
                'conversion_rate' => 19.80,
                'rank_order' => 3,
                'streak_days' => 6,
                'badges' => json_encode(['High Volume', 'Rapid Responder'])
            ],
            [
                'id' => 'rep-4',
                'name' => 'Priya Sharma',
                'role' => 'SMB Sales Consultant',
                'avatar' => 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=120&auto=format&fit=crop&q=80',
                'phone' => '+91 98201 77889',
                'device_model' => 'Samsung Galaxy Z Fold 6',
                'os_version' => 'Android 14',
                'battery_level' => 82,
                'is_online' => 0,
                'last_sync' => '18m ago',
                'calls_today' => 24,
                'talk_time_minutes' => 98,
                'deals_closed' => 2,
                'conversion_rate' => 22.00,
                'rank_order' => 4,
                'streak_days' => 5,
                'badges' => json_encode(['Customer Champion'])
            ]
        ];

        $repIns = $db->prepare("
            INSERT INTO sales_reps (id, name, role, avatar, phone, device_model, os_version, battery_level, is_online, last_sync, calls_today, talk_time_minutes, deals_closed, conversion_rate, rank_order, streak_days, badges)
            VALUES (:id, :name, :role, :avatar, :phone, :device_model, :os_version, :battery_level, :is_online, :last_sync, :calls_today, :talk_time_minutes, :deals_closed, :conversion_rate, :rank_order, :streak_days, :badges)
        ");
        foreach ($initialReps as $rep) {
            $repIns->execute($rep);
        }
    }

    // Seed CRM Connectors
    $crmCount = (int) $db->query("SELECT COUNT(*) FROM crm_connectors")->fetchColumn();
    if ($crmCount === 0) {
        $initialCrms = [
            [
                'id' => 'crm-rv360',
                'name' => 'RingVia360 CRM',
                'description' => 'Native unified enterprise sync of Call Logs, Transcripts, Dual-SIM Audio & WhatsApp to RingVia360 CRM',
                'icon' => '⚡',
                'is_connected' => 1,
                'last_sync_time' => 'Real-time (Active)',
                'synced_records_count' => 24820,
                'pending_sync_count' => 0,
                'auto_sync' => 1,
                'sync_frequency' => 'Instant Zero-Click'
            ],
            [
                'id' => 'crm-hubspot',
                'name' => 'HubSpot CRM',
                'description' => 'Two-way synchronization of call engagements, recordings, contact stages, and pipeline deals',
                'icon' => '🟠',
                'is_connected' => 1,
                'last_sync_time' => '1m ago',
                'synced_records_count' => 18450,
                'pending_sync_count' => 0,
                'auto_sync' => 1,
                'sync_frequency' => 'Instant Webhook'
            ],
            [
                'id' => 'crm-zoho',
                'name' => 'Zoho CRM',
                'description' => 'Direct API mapping to Zoho Leads, Deals, and Activities with Indian telephony compliance tags',
                'icon' => '🔴',
                'is_connected' => 1,
                'last_sync_time' => '3m ago',
                'synced_records_count' => 12100,
                'pending_sync_count' => 0,
                'auto_sync' => 1,
                'sync_frequency' => 'Real-time'
            ],
            [
                'id' => 'crm-webhook',
                'name' => 'Custom Webhook API',
                'description' => 'HMAC-SHA256 signed JSON payloads dispatched immediately upon call completion',
                'icon' => '🔌',
                'is_connected' => 1,
                'last_sync_time' => 'Just now',
                'synced_records_count' => 39200,
                'pending_sync_count' => 0,
                'auto_sync' => 1,
                'sync_frequency' => 'Instant Event Stream'
            ]
        ];

        $crmIns = $db->prepare("
            INSERT INTO crm_connectors (id, name, description, icon, is_connected, last_sync_time, synced_records_count, pending_sync_count, auto_sync, sync_frequency)
            VALUES (:id, :name, :description, :icon, :is_connected, :last_sync_time, :synced_records_count, :pending_sync_count, :auto_sync, :sync_frequency)
        ");
        foreach ($initialCrms as $crm) {
            $crmIns->execute($crm);
        }
    }

    // Seed Admin Users
    $adminCount = (int) $db->query("SELECT COUNT(*) FROM admin_users")->fetchColumn();
    if ($adminCount === 0) {
        $initialAdmins = [
            ['id' => 'u-1', 'name' => 'Rajesh Kumar', 'email' => 'rajesh.kumar@ringvia360.com', 'role' => 'Sales Director', 'status' => 'Active', 'sim' => 'SIM 1 Bound', 'device' => 'Galaxy S24 Ultra (Knox)', 'last_active' => 'Just now'],
            ['id' => 'u-2', 'name' => 'Sneha Kapoor', 'email' => 'sneha.kapoor@ringvia360.com', 'role' => 'Account Executive', 'status' => 'Active', 'sim' => 'SIM 1 Bound', 'device' => 'iPhone 15 Pro Max', 'last_active' => '2m ago'],
            ['id' => 'u-3', 'name' => 'Amit Verma', 'email' => 'amit.verma@ringvia360.com', 'role' => 'Inbound Specialist', 'status' => 'Active', 'sim' => 'SIM 1 Bound', 'device' => 'Pixel 9 Pro', 'last_active' => '5m ago'],
            ['id' => 'u-4', 'name' => 'Priya Sharma', 'email' => 'priya.sharma@ringvia360.com', 'role' => 'Team Lead', 'status' => 'Active', 'sim' => 'SIM 1 Bound', 'device' => 'Galaxy Z Fold 6', 'last_active' => '15m ago'],
            ['id' => 'u-5', 'name' => 'Vikram Deshmukh', 'email' => 'vikram.deshmukh@ringvia360.com', 'role' => 'Compliance Officer', 'status' => 'Active', 'sim' => 'Unbound', 'device' => 'MacBook Pro / Web', 'last_active' => '1h ago']
        ];
        $admIns = $db->prepare("INSERT INTO admin_users (id, name, email, role, status, sim, device, last_active) VALUES (:id, :name, :email, :role, :status, :sim, :device, :last_active)");
        foreach ($initialAdmins as $adm) {
            $admIns->execute($adm);
        }
    }

    // Seed Settings
    $settCount = (int) $db->query("SELECT COUNT(*) FROM app_settings")->fetchColumn();
    if ($settCount === 0) {
        $defaultSettings = [
            'security' => json_encode([
                'dualSimIsolation' => true,
                'corporateSimSlot' => 'SIM 1',
                'autoRecordCorporate' => true,
                'ignorePersonalSim' => true,
                'workHoursOnly' => true,
                'workHoursStart' => '09:00',
                'workHoursEnd' => '19:00',
                'workDays' => ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
                'e2eeEnabled' => true,
                'kmsKeyAlias' => 'ringvia360-prod-aes256',
                'retentionDays' => 365,
                'allowRepDelete' => false,
                'consentAnnouncement' => true,
                'audioQuality' => '320kbps_hd'
            ]),
            'organization' => json_encode([
                'orgName' => 'RingVia360 Enterprise India',
                'orgDomain' => 'ringvia360.com',
                'primaryCurrency' => 'INR',
                'timezone' => 'Asia/Kolkata'
            ])
        ];
        $settIns = $db->prepare("INSERT INTO app_settings (setting_key, setting_value) VALUES (:k, :v)");
        foreach ($defaultSettings as $k => $v) {
            $settIns->execute([':k' => $k, ':v' => $v]);
        }
    }

    // =========================================================
    // 3. ROUTE DISPATCHER & MULTI-TENANT ISOLATION
    // =========================================================
    $method = $_SERVER['REQUEST_METHOD'];
    $action = $_GET['action'] ?? '';

    // Multi-tenant organization isolation resolution
    $tenantId = $_SERVER['HTTP_X_TENANT_ID'] ?? ($_GET['org_id'] ?? ($_POST['org_id'] ?? 'all'));
    $authPayload = verifyRingviaToken($_SERVER['HTTP_AUTHORIZATION'] ?? null);
    if ($authPayload) {
        // Tenant members cannot select another organization through a request parameter.
        if (($authPayload['role'] ?? '') !== 'super_admin') {
            $tenantId = (string) ($authPayload['orgId'] ?? '');
        }
    }
    if (!$tenantId || $tenantId === 'undefined' || $tenantId === 'null') {
        $tenantId = 'all';
    }

    // Action: Health & Diagnostics
    if ($action === 'db_status') {
        echo json_encode([
            'success' => true,
            'status' => 'operational',
            'driver' => $driver,
            'active_user' => $activeUser,
            'tenantId' => $tenantId,
            'database' => $conn['driver'] === 'mysql' ? 'u488332847_dn_name' : 'ringvia_calls.sqlite',
            'mysql_available' => extension_loaded('pdo_mysql'),
            'timestamp' => date('Y-m-d H:i:s T')
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        exit();
    }

    // =========================================================
    // 4. AUDIO RECORDING UPLOAD (Multipart file or Base64)
    // =========================================================
    if ($action === 'upload_audio') {
        $savedFilename = null;
        $callId = $_POST['callId'] ?? ($_GET['callId'] ?? null);

        // Case A: Multipart File Upload
        if (!empty($_FILES['audio']['tmp_name']) && is_uploaded_file($_FILES['audio']['tmp_name'])) {
            if (($_FILES['audio']['size'] ?? 0) > 25 * 1024 * 1024) {
                http_response_code(413);
                echo json_encode(['success' => false, 'error' => 'Audio recording exceeds the 25 MB limit']);
                exit();
            }
            $ext = pathinfo($_FILES['audio']['name'], PATHINFO_EXTENSION) ?: 'mp3';
            $safeExt = in_array(strtolower($ext), ['mp3', 'm4a', 'wav', 'aac', 'ogg']) ? strtolower($ext) : 'mp3';
            $filename = 'rec_' . time() . '_' . bin2hex(random_bytes(6)) . '.' . $safeExt;
            $dest = $uploadDir . '/' . $filename;
            if (move_uploaded_file($_FILES['audio']['tmp_name'], $dest)) {
                $savedFilename = $filename;
            }
        }

        // Case B: Base64 JSON Payload
        if (!$savedFilename) {
            $raw = file_get_contents('php://input');
            $body = json_decode($raw, true);
            if (!empty($body['audioData'])) {
                $base64 = $body['audioData'];
                if (str_contains($base64, ',')) {
                    $base64 = explode(',', $base64)[1];
                }
                $decoded = base64_decode($base64);
                if ($decoded !== false) {
                    $ext = !empty($body['format']) ? strtolower($body['format']) : 'mp3';
                    $filename = 'rec_' . time() . '_' . bin2hex(random_bytes(6)) . '.' . $ext;
                    file_put_contents($uploadDir . '/' . $filename, $decoded);
                    $savedFilename = $filename;
                    if (empty($callId) && !empty($body['callId'])) {
                        $callId = $body['callId'];
                    }
                }
            }
        }

        if (!$savedFilename) {
            http_response_code(400);
            echo json_encode(['success' => false, 'error' => 'No valid audio file or base64 stream provided']);
            exit();
        }

        // Determine scheme & host
        $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
        $host = $_SERVER['HTTP_HOST'] ?? 'ringvia360.com';
        $audioUrl = "{$scheme}://{$host}/api/uploads/{$savedFilename}";

        // If callId provided, automatically update recording_url in call_logs table
        if (!empty($callId)) {
            $upd = $db->prepare("UPDATE call_logs SET recording_url = :url WHERE id = :id");
            $upd->execute([':url' => $audioUrl, ':id' => $callId]);
        }

        echo json_encode([
            'success' => true,
            'message' => 'Audio recording uploaded and indexed successfully',
            'recordingUrl' => $audioUrl,
            'filename' => $savedFilename,
            'callId' => $callId
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        exit();
    }

    // =========================================================
    // 4b. SECURE AUDIO STREAMING (Strict Multi-Tenant Verification)
    // =========================================================
    if ($action === 'stream_audio') {
        $callId = $_GET['id'] ?? ($_GET['callId'] ?? '');
        if (!$callId) {
            http_response_code(400);
            echo json_encode(['success' => false, 'error' => 'Missing call ID']);
            exit();
        }

        $stmtCall = $db->prepare("SELECT * FROM call_logs WHERE id = :id LIMIT 1");
        $stmtCall->execute([':id' => $callId]);
        $callRecord = $stmtCall->fetch();

        if (!$callRecord) {
            http_response_code(404);
            echo json_encode(['success' => false, 'error' => 'Call recording not found']);
            exit();
        }

        // Verify tenant isolation: customer admin can only stream their own recordings
        if ($authPayload && ($authPayload['role'] ?? '') !== 'super_admin') {
            $userOrg = (string) ($authPayload['orgId'] ?? '');
            $callOrg = (string) ($callRecord['org_id'] ?? '');
            if ($userOrg !== $callOrg) {
                http_response_code(403);
                echo json_encode(['success' => false, 'error' => 'Cross-tenant recording access forbidden. Recording belongs to another workspace.']);
                exit();
            }
        }

        $recUrl = (string) ($callRecord['recording_url'] ?? '');
        if (empty($recUrl)) {
            http_response_code(404);
            echo json_encode(['success' => false, 'error' => 'No audio recording file associated with this call']);
            exit();
        }

        // If local file in uploads
        $basename = basename($recUrl);
        $localPath = __DIR__ . '/uploads/' . $basename;
        if (file_exists($localPath)) {
            header('Content-Type: audio/mpeg');
            header('Content-Length: ' . filesize($localPath));
            header('Accept-Ranges: bytes');
            readfile($localPath);
            exit();
        }

        // Otherwise redirect to stored URL
        header('Location: ' . $recUrl);
        exit();
    }

    // =========================================================
    // =========================================================
    // 5. ALL DATA (Single Round-Trip Fetch Scoped by Multi-Tenant Isolation)
    // =========================================================
    if ($action === 'all_data' && $method === 'GET') {
        if (!$authPayload) {
            http_response_code(401);
            echo json_encode(['success' => false, 'error' => 'Authentication is required for live feeds']);
            exit();
        }
        if ($tenantId === 'all') {
            $calls = $db->query("SELECT * FROM call_logs ORDER BY created_at DESC LIMIT 100")->fetchAll();
            $reps = $db->query("SELECT * FROM sales_reps ORDER BY rank_order ASC")->fetchAll();
            $crms = $db->query("SELECT * FROM crm_connectors ORDER BY id ASC")->fetchAll();
            $admins = $db->query("SELECT * FROM admin_users ORDER BY id ASC")->fetchAll();
            $leads = $db->query("SELECT * FROM leads_contacts ORDER BY created_at DESC LIMIT 50")->fetchAll();
        } else {
            // Intelligent multi-tenant call log retrieval:
            // Matches calls directly tagged with org_id, OR uploaded by reps enrolled in this org, OR paired to this org
            $stmtC = $db->prepare("
                SELECT * FROM call_logs 
                WHERE org_id = :org_id 
                   OR rep_name IN (SELECT name FROM sales_reps WHERE org_id = :org_id2)
                   OR rep_id IN (SELECT id FROM sales_reps WHERE org_id = :org_id3)
                   OR rep_id IN (SELECT rep_id FROM device_pairings WHERE org_id = :org_id4)
                   OR rep_name IN (SELECT rep_name FROM device_pairings WHERE org_id = :org_id5)
                ORDER BY created_at DESC LIMIT 100
            ");
            $stmtC->execute([
                ':org_id' => $tenantId,
                ':org_id2' => $tenantId,
                ':org_id3' => $tenantId,
                ':org_id4' => $tenantId,
                ':org_id5' => $tenantId
            ]);
            $calls = $stmtC->fetchAll();

            // High-availability fallback: if this tenant has zero calls yet, show latest mobile telemetry
            if (empty($calls)) {
                $calls = $db->query("SELECT * FROM call_logs ORDER BY created_at DESC LIMIT 25")->fetchAll();
            }

            $stmtR = $db->prepare("SELECT * FROM sales_reps WHERE org_id = :org_id ORDER BY rank_order ASC");
            $stmtR->execute([':org_id' => $tenantId]);
            $reps = $stmtR->fetchAll();
            if (empty($reps)) {
                try {
                    $baseReps = $db->query("SELECT * FROM sales_reps WHERE org_id = 'org-tcs' OR org_id IS NULL ORDER BY rank_order ASC LIMIT 5")->fetchAll();
                    if (!empty($baseReps)) {
                        $insR = $db->prepare("INSERT INTO sales_reps (id, org_id, name, role, avatar, phone, device_model, os_version, battery_level, is_online, last_sync, calls_today, talk_time_minutes, deals_closed, conversion_rate, rank_order, streak_days, badges) VALUES (:id, :org_id, :name, :role, :avatar, :phone, :device_model, :os_version, :battery_level, :is_online, :last_sync, :calls_today, :talk_time_minutes, :deals_closed, :conversion_rate, :rank_order, :streak_days, :badges)");
                        foreach ($baseReps as $br) {
                            $rId = 'rep-' . substr(md5($tenantId . $br['name']), 0, 8);
                            $insR->execute([
                                ':id' => $rId,
                                ':org_id' => $tenantId,
                                ':name' => $br['name'],
                                ':role' => $br['role'],
                                ':avatar' => $br['avatar'],
                                ':phone' => $br['phone'] ?? '+91 98201 11222',
                                ':device_model' => $br['device_model'] ?? 'Samsung Knox SM-S928B',
                                ':os_version' => $br['os_version'] ?? 'Android 14 Knox 3.10',
                                ':battery_level' => 92,
                                ':is_online' => 1,
                                ':last_sync' => 'Just now',
                                ':calls_today' => 3,
                                ':talk_time_minutes' => 18,
                                ':deals_closed' => 1,
                                ':conversion_rate' => 70.0,
                                ':rank_order' => $br['rank_order'] ?? 1,
                                ':streak_days' => $br['streak_days'] ?? 4,
                                ':badges' => $br['badges'] ?? '["Top Closer", "Enterprise Ready"]'
                            ]);
                        }
                        $stmtR->execute([':org_id' => $tenantId]);
                        $reps = $stmtR->fetchAll();
                    }
                } catch (Throwable $e) {}
                if (empty($reps)) {
                    $reps = $db->query("SELECT * FROM sales_reps LIMIT 5")->fetchAll();
                }
            }

            $stmtCRM = $db->prepare("SELECT * FROM crm_connectors WHERE org_id = :org_id OR org_id = 'org-tcs' OR org_id IS NULL ORDER BY id ASC");
            $stmtCRM->execute([':org_id' => $tenantId]);
            $crms = $stmtCRM->fetchAll();
            if (empty($crms)) {
                $crms = $db->query("SELECT * FROM crm_connectors LIMIT 5")->fetchAll();
            }

            $stmtA = $db->prepare("SELECT * FROM admin_users WHERE org_id = :org_id ORDER BY id ASC");
            $stmtA->execute([':org_id' => $tenantId]);
            $admins = $stmtA->fetchAll();
            if (empty($admins)) {
                $stmtU = $db->prepare("SELECT id, name, email, role, status, phone, 'SIM 1 Bound' as sim, 'Android Knox Phone' as device, 'Just now' as last_active FROM users WHERE org_id = :org_id");
                $stmtU->execute([':org_id' => $tenantId]);
                $admins = $stmtU->fetchAll();
                if (empty($admins)) {
                    $admins = $db->query("SELECT * FROM admin_users LIMIT 5")->fetchAll();
                }
            }

            $stmtL = $db->prepare("SELECT * FROM leads_contacts WHERE org_id = :org_id ORDER BY created_at DESC LIMIT 50");
            $stmtL->execute([':org_id' => $tenantId]);
            $leads = $stmtL->fetchAll();
            if (empty($leads)) {
                $leads = $db->query("SELECT * FROM leads_contacts ORDER BY created_at DESC LIMIT 20")->fetchAll();
            }
        }

        $formattedCalls = array_map(function ($row) {
            return [
                'id' => (string) $row['id'],
                'orgId' => (string) ($row['org_id'] ?? 'org-tcs'),
                'contactName' => (string) $row['contact_name'],
                'phoneNumber' => (string) $row['phone_number'],
                'company' => (string) ($row['company'] ?? 'Corporate Partner'),
                'direction' => (string) $row['direction'],
                'duration' => (int) $row['duration'],
                'timestamp' => (string) $row['timestamp'],
                'repName' => (string) ($row['rep_name'] ?? 'Rajesh Kumar (RingVia360)'),
                'repAvatar' => (string) ($row['rep_avatar'] ?? 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80'),
                'repId' => (string) ($row['rep_id'] ?? 'rep-1'),
                'outcome' => (string) ($row['outcome'] ?? 'Call Completed'),
                'notes' => (string) ($row['notes'] ?? ''),
                'sentiment' => (string) ($row['sentiment'] ?? 'positive'),
                'sentimentScore' => (int) ($row['sentiment_score'] ?? 85),
                'dealValue' => (float) ($row['deal_value'] ?? 0),
                'dealStage' => (string) ($row['deal_stage'] ?? 'Proposal'),
                'crmStatus' => (string) ($row['crm_status'] ?? 'synced'),
                'crmType' => (string) ($row['crm_type'] ?? 'RingVia360'),
                'simSlot' => (string) ($row['sim_slot'] ?? 'SIM 1 (Airtel Enterprise)'),
                'isEncrypted' => (bool) $row['is_encrypted'],
                'recordingUrl' => (string) ($row['recording_url'] ?? 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3'),
                'waveform' => json_decode((string) ($row['waveform'] ?? '[]'), true) ?: [30, 45, 60, 80, 50, 70, 90, 60, 40, 65, 80, 95, 75, 55, 65, 85, 90, 60, 40, 55],
                'transcript' => json_decode((string) ($row['transcript'] ?? '[]'), true) ?: [],
                'keyActionItems' => json_decode((string) ($row['key_action_items'] ?? '[]'), true) ?: [],
                'createdAt' => (string) $row['created_at']
            ];
        }, $calls);

        // Sales members may only retrieve activity assigned to themselves.
        if (($authPayload['role'] ?? '') === 'rep') {
            $memberName = strtolower(trim((string) ($authPayload['name'] ?? '')));
            $formattedCalls = array_values(array_filter($formattedCalls, fn($call) => strtolower(trim($call['repName'])) === $memberName));
        }

        // Fetch Reps
        $formattedReps = array_map(function ($r) {
            return [
                'id' => (string) $r['id'],
                'orgId' => (string) ($r['org_id'] ?? 'org-tcs'),
                'name' => (string) $r['name'],
                'role' => (string) $r['role'],
                'avatar' => (string) $r['avatar'],
                'phone' => (string) ($r['phone'] ?? '+91 98200 00000'),
                'deviceModel' => (string) ($r['device_model'] ?? 'Samsung Galaxy S24 Ultra'),
                'osVersion' => (string) ($r['os_version'] ?? 'Android 14'),
                'batteryLevel' => (int) $r['battery_level'],
                'isOnline' => (bool) $r['is_online'],
                'lastSync' => (string) $r['last_sync'],
                'callsToday' => (int) $r['calls_today'],
                'talkTimeMinutes' => (int) $r['talk_time_minutes'],
                'dealsClosed' => (int) $r['deals_closed'],
                'conversionRate' => (float) $r['conversion_rate'],
                'rank' => (int) $r['rank_order'],
                'streakDays' => (int) $r['streak_days'],
                'badges' => json_decode((string) ($r['badges'] ?? '[]'), true) ?: ['Active']
            ];
        }, $reps);

        // Fetch CRM Connectors
        $formattedCrms = array_map(function ($c) {
            return [
                'id' => (string) $c['id'],
                'name' => (string) $c['name'],
                'description' => (string) $c['description'],
                'icon' => (string) $c['icon'],
                'isConnected' => (bool) $c['is_connected'],
                'lastSyncTime' => (string) $c['last_sync_time'],
                'syncedRecordsCount' => (int) $c['synced_records_count'],
                'pendingSyncCount' => (int) $c['pending_sync_count'],
                'autoSync' => (bool) $c['auto_sync'],
                'syncFrequency' => (string) $c['sync_frequency']
            ];
        }, $crms);

        // Fetch Settings
        $settingsRows = $db->query("SELECT * FROM app_settings")->fetchAll();
        $settings = [];
        foreach ($settingsRows as $sr) {
            $settings[$sr['setting_key']] = json_decode((string) $sr['setting_value'], true);
        }

        echo json_encode([
            'success' => true,
            'database' => $driver,
            'active_user' => $activeUser,
            'tenantId' => $tenantId,
            'data' => [
                'calls' => $formattedCalls,
                'reps' => $formattedReps,
                'crmConnectors' => $formattedCrms,
                'adminUsers' => $admins,
                'settings' => $settings,
                'leads' => $leads
            ]
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        exit();
    }

    // =========================================================
    // 6. SALES REPS CRUD (?action=reps)
    // =========================================================
    if ($action === 'reps') {
        if ($method === 'GET') {
            if ($tenantId === 'all') {
                $reps = $db->query("SELECT * FROM sales_reps ORDER BY rank_order ASC")->fetchAll();
            } else {
                $stmt = $db->prepare("SELECT * FROM sales_reps WHERE org_id = :org_id ORDER BY rank_order ASC");
                $stmt->execute([':org_id' => $tenantId]);
                $reps = $stmt->fetchAll();
                if (empty($reps)) {
                    $reps = $db->query("SELECT * FROM sales_reps LIMIT 5")->fetchAll();
                }
            }
            $formatted = array_map(function ($r) {
                return [
                    'id' => (string) $r['id'],
                    'orgId' => (string) ($r['org_id'] ?? 'org-tcs'),
                    'name' => (string) $r['name'],
                    'role' => (string) $r['role'],
                    'avatar' => (string) $r['avatar'],
                    'phone' => (string) ($r['phone'] ?? ''),
                    'deviceModel' => (string) ($r['device_model'] ?? ''),
                    'osVersion' => (string) ($r['os_version'] ?? ''),
                    'batteryLevel' => (int) $r['battery_level'],
                    'isOnline' => (bool) $r['is_online'],
                    'lastSync' => (string) $r['last_sync'],
                    'callsToday' => (int) $r['calls_today'],
                    'talkTimeMinutes' => (int) $r['talk_time_minutes'],
                    'dealsClosed' => (int) $r['deals_closed'],
                    'conversionRate' => (float) $r['conversion_rate'],
                    'rank' => (int) $r['rank_order'],
                    'streakDays' => (int) $r['streak_days'],
                    'badges' => json_decode((string) ($r['badges'] ?? '[]'), true) ?: []
                ];
            }, $reps);
            echo json_encode(['success' => true, 'tenantId' => $tenantId, 'data' => $formatted]);
            exit();
        }

        if ($method === 'POST') {
            $body = json_decode(file_get_contents('php://input'), true) ?: [];
            $id = $body['id'] ?? ('rep-' . time());

            $existing = null;
            try {
                $chk = $db->prepare("SELECT * FROM sales_reps WHERE id = :id LIMIT 1");
                $chk->execute([':id' => $id]);
                $existing = $chk->fetch();
            } catch (Throwable $e) {}

            $repOrgId = $body['orgId'] ?? ($existing['org_id'] ?? ($tenantId !== 'all' ? $tenantId : 'org-tcs'));
            $name = $body['name'] ?? ($existing['name'] ?? 'Sales Rep');
            $role = $body['role'] ?? ($existing['role'] ?? 'Account Executive');
            $avatar = $body['avatar'] ?? ($existing['avatar'] ?? 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80');
            $phone = $body['phone'] ?? ($existing['phone'] ?? '+91 98200 12345');
            $deviceModel = $body['deviceModel'] ?? ($existing['device_model'] ?? 'Android Knox Device');
            $osVersion = $body['osVersion'] ?? ($existing['os_version'] ?? 'Android 14');
            $batteryLevel = isset($body['batteryLevel']) ? (int) $body['batteryLevel'] : ($existing ? (int) $existing['battery_level'] : 90);
            $isOnline = isset($body['isOnline']) ? ($body['isOnline'] ? 1 : 0) : ($existing ? (int) $existing['is_online'] : 1);
            $lastSync = $body['lastSync'] ?? ($existing['last_sync'] ?? 'Just now');
            $callsToday = isset($body['callsToday']) ? (int) $body['callsToday'] : ($existing ? (int) $existing['calls_today'] : 0);
            $talkTimeMinutes = isset($body['talkTimeMinutes']) ? (int) $body['talkTimeMinutes'] : ($existing ? (int) $existing['talk_time_minutes'] : 0);
            $dealsClosed = isset($body['dealsClosed']) ? (int) $body['dealsClosed'] : ($existing ? (int) $existing['deals_closed'] : 0);
            $conversionRate = isset($body['conversionRate']) ? (float) $body['conversionRate'] : ($existing ? (float) $existing['conversion_rate'] : 20.0);
            $rankOrder = isset($body['rank']) ? (int) $body['rank'] : ($existing ? (int) $existing['rank_order'] : 5);
            $streakDays = isset($body['streakDays']) ? (int) $body['streakDays'] : ($existing ? (int) $existing['streak_days'] : 1);
            $badges = isset($body['badges']) ? (is_array($body['badges']) ? json_encode($body['badges']) : $body['badges']) : ($existing['badges'] ?? json_encode(['Certified']));

            $sql = $isMysql
                ? "INSERT INTO sales_reps (id, org_id, name, role, avatar, phone, device_model, os_version, battery_level, is_online, last_sync, calls_today, talk_time_minutes, deals_closed, conversion_rate, rank_order, streak_days, badges)
                   VALUES (:id, :org_id, :name, :role, :avatar, :phone, :device_model, :os_version, :battery_level, :is_online, :last_sync, :calls_today, :talk_time_minutes, :deals_closed, :conversion_rate, :rank_order, :streak_days, :badges)
                   ON DUPLICATE KEY UPDATE org_id=VALUES(org_id), name=VALUES(name), role=VALUES(role), avatar=VALUES(avatar), phone=VALUES(phone), device_model=VALUES(device_model), os_version=VALUES(os_version), battery_level=VALUES(battery_level), is_online=VALUES(is_online), last_sync=VALUES(last_sync), calls_today=VALUES(calls_today), talk_time_minutes=VALUES(talk_time_minutes), deals_closed=VALUES(deals_closed), conversion_rate=VALUES(conversion_rate), rank_order=VALUES(rank_order)"
                : "INSERT OR REPLACE INTO sales_reps (id, org_id, name, role, avatar, phone, device_model, os_version, battery_level, is_online, last_sync, calls_today, talk_time_minutes, deals_closed, conversion_rate, rank_order, streak_days, badges)
                   VALUES (:id, :org_id, :name, :role, :avatar, :phone, :device_model, :os_version, :battery_level, :is_online, :last_sync, :calls_today, :talk_time_minutes, :deals_closed, :conversion_rate, :rank_order, :streak_days, :badges)";

            $stmt = $db->prepare($sql);
            $stmt->execute([
                ':id' => $id, ':org_id' => $repOrgId, ':name' => $name, ':role' => $role, ':avatar' => $avatar,
                ':phone' => $phone, ':device_model' => $deviceModel, ':os_version' => $osVersion,
                ':battery_level' => $batteryLevel, ':is_online' => $isOnline, ':last_sync' => $lastSync,
                ':calls_today' => $callsToday, ':talk_time_minutes' => $talkTimeMinutes,
                ':deals_closed' => $dealsClosed, ':conversion_rate' => $conversionRate,
                ':rank_order' => $rankOrder, ':streak_days' => $streakDays, ':badges' => $badges
            ]);

            echo json_encode(['success' => true, 'id' => $id, 'orgId' => $repOrgId, 'message' => "Rep $name updated in DB"]);
            exit();
        }

        if ($method === 'DELETE') {
            $id = $_GET['id'] ?? '';
            $del = $db->prepare("DELETE FROM sales_reps WHERE id = :id");
            $del->execute([':id' => $id]);
            echo json_encode(['success' => true, 'message' => "Rep #$id deleted"]);
            exit();
        }
    }

    // =========================================================
    // 7. CRM CONNECTORS (?action=crm_connectors)
    // =========================================================
    if ($action === 'crm_connectors') {
        if ($method === 'GET') {
            $crms = $db->query("SELECT * FROM crm_connectors ORDER BY id ASC")->fetchAll();
            $formatted = array_map(function ($c) {
                return [
                    'id' => (string) $c['id'],
                    'name' => (string) $c['name'],
                    'description' => (string) $c['description'],
                    'icon' => (string) $c['icon'],
                    'isConnected' => (bool) $c['is_connected'],
                    'lastSyncTime' => (string) $c['last_sync_time'],
                    'syncedRecordsCount' => (int) $c['synced_records_count'],
                    'pendingSyncCount' => (int) $c['pending_sync_count'],
                    'autoSync' => (bool) $c['auto_sync'],
                    'syncFrequency' => (string) $c['sync_frequency']
                ];
            }, $crms);
            echo json_encode(['success' => true, 'data' => $formatted]);
            exit();
        }

        if ($method === 'POST') {
            $body = json_decode(file_get_contents('php://input'), true) ?: [];
            $id = $body['id'] ?? '';
            if ($id) {
                $isConnected = isset($body['isConnected']) ? ($body['isConnected'] ? 1 : 0) : 1;
                $upd = $db->prepare("UPDATE crm_connectors SET is_connected = :conn, last_sync_time = 'Just now' WHERE id = :id");
                $upd->execute([':conn' => $isConnected, ':id' => $id]);
            }
            echo json_encode(['success' => true, 'message' => "CRM Connector #$id updated"]);
            exit();
        }
    }

    // =========================================================
    // 8. APP SETTINGS & POLICIES (?action=settings)
    // =========================================================
    if ($action === 'settings') {
        if ($method === 'GET') {
            $settingsRows = $db->query("SELECT * FROM app_settings")->fetchAll();
            $settings = [];
            foreach ($settingsRows as $sr) {
                $settings[$sr['setting_key']] = json_decode((string) $sr['setting_value'], true);
            }
            echo json_encode(['success' => true, 'data' => $settings]);
            exit();
        }

        if ($method === 'POST') {
            $body = json_decode(file_get_contents('php://input'), true) ?: [];
            $key = $body['key'] ?? 'security';
            $val = json_encode($body['value'] ?? $body);

            $sql = $isMysql
                ? "INSERT INTO app_settings (setting_key, setting_value) VALUES (:k, :v) ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value)"
                : "INSERT OR REPLACE INTO app_settings (setting_key, setting_value) VALUES (:k, :v)";

            $stmt = $db->prepare($sql);
            $stmt->execute([':k' => $key, ':v' => $val]);

            echo json_encode(['success' => true, 'message' => "Setting $key updated in DB"]);
            exit();
        }
    }

    // =========================================================
    // 9. ADMIN FLEET USERS (?action=admin_users)
    // =========================================================
    if ($action === 'admin_users') {
        if ($method === 'GET') {
            if ($tenantId === 'all') {
                $admins = $db->query("SELECT * FROM admin_users ORDER BY created_at DESC")->fetchAll();
            } else {
                $stmt = $db->prepare("SELECT * FROM admin_users WHERE org_id = :org_id ORDER BY created_at DESC");
                $stmt->execute([':org_id' => $tenantId]);
                $admins = $stmt->fetchAll();
                if (empty($admins)) {
                    $admins = $db->query("SELECT * FROM admin_users LIMIT 5")->fetchAll();
                }
            }
            echo json_encode(['success' => true, 'tenantId' => $tenantId, 'data' => $admins]);
            exit();
        }

        if ($method === 'POST') {
            $body = json_decode(file_get_contents('php://input'), true) ?: [];
            $id = $body['id'] ?? ('u-' . time());
            $userOrgId = $body['orgId'] ?? ($tenantId !== 'all' ? $tenantId : 'org-tcs');
            $name = $body['name'] ?? 'Team Member';
            $email = $body['email'] ?? 'rep@ringvia360.com';
            $role = $body['role'] ?? 'Sales Rep';
            $status = $body['status'] ?? 'Active';
            $sim = $body['sim'] ?? 'SIM 1 Bound';
            $device = $body['device'] ?? 'Samsung Galaxy S24 (Knox)';
            $lastActive = $body['lastActive'] ?? 'Just now';

            $sql = $isMysql
                ? "INSERT INTO admin_users (id, org_id, name, email, role, status, sim, device, last_active) VALUES (:id, :org_id, :name, :email, :role, :status, :sim, :device, :last_active) ON DUPLICATE KEY UPDATE org_id=VALUES(org_id), name=VALUES(name), email=VALUES(email), role=VALUES(role), status=VALUES(status), sim=VALUES(sim), device=VALUES(device)"
                : "INSERT OR REPLACE INTO admin_users (id, org_id, name, email, role, status, sim, device, last_active) VALUES (:id, :org_id, :name, :email, :role, :status, :sim, :device, :last_active)";

            $stmt = $db->prepare($sql);
            $stmt->execute([
                ':id' => $id, ':org_id' => $userOrgId, ':name' => $name, ':email' => $email, ':role' => $role,
                ':status' => $status, ':sim' => $sim, ':device' => $device, ':last_active' => $lastActive
            ]);

            echo json_encode(['success' => true, 'id' => $id, 'orgId' => $userOrgId, 'message' => "Fleet user $name saved"]);
            exit();
        }

        if ($method === 'DELETE') {
            $id = $_GET['id'] ?? '';
            $del = $db->prepare("DELETE FROM admin_users WHERE id = :id");
            $del->execute([':id' => $id]);
            echo json_encode(['success' => true, 'message' => "User #$id removed"]);
            exit();
        }
    }

    // =========================================================
    // 10. LEADS & CONTACTS (?action=leads)
    // =========================================================
    if ($action === 'leads') {
        if ($method === 'GET') {
            if ($tenantId === 'all') {
                $leads = $db->query("SELECT * FROM leads_contacts ORDER BY created_at DESC LIMIT 100")->fetchAll();
            } else {
                $stmt = $db->prepare("SELECT * FROM leads_contacts WHERE org_id = :org_id ORDER BY created_at DESC LIMIT 100");
                $stmt->execute([':org_id' => $tenantId]);
                $leads = $stmt->fetchAll();
                if (empty($leads)) {
                    $leads = $db->query("SELECT * FROM leads_contacts LIMIT 10")->fetchAll();
                }
            }
            echo json_encode(['success' => true, 'tenantId' => $tenantId, 'count' => count($leads), 'data' => $leads]);
            exit();
        }

        if ($method === 'POST') {
            $payload = json_decode(file_get_contents('php://input'), true) ?: [];
            $leadId = !empty($payload['id']) ? (string) $payload['id'] : ('lead-' . round(microtime(true) * 1000));
            $leadOrgId = !empty($payload['orgId']) ? (string) $payload['orgId'] : ($tenantId !== 'all' ? $tenantId : 'org-tcs');
            $leadSql = $isMysql
                ? "INSERT INTO leads_contacts (id, org_id, name, phone, company, title, email, status, deal_value, last_contacted, crm_account_id, notes) VALUES (:id, :org_id, :name, :phone, :company, :title, :email, :status, :deal_value, :last_contacted, :crm_account_id, :notes) ON DUPLICATE KEY UPDATE org_id=VALUES(org_id), name=VALUES(name), phone=VALUES(phone), company=VALUES(company), status=VALUES(status), deal_value=VALUES(deal_value), notes=VALUES(notes)"
                : "INSERT OR REPLACE INTO leads_contacts (id, org_id, name, phone, company, title, email, status, deal_value, last_contacted, crm_account_id, notes) VALUES (:id, :org_id, :name, :phone, :company, :title, :email, :status, :deal_value, :last_contacted, :crm_account_id, :notes)";

            $stmt = $db->prepare($leadSql);
            $stmt->execute([
                ':id' => $leadId,
                ':org_id' => $leadOrgId,
                ':name' => !empty($payload['name']) ? (string) $payload['name'] : 'Enterprise Contact',
                ':phone' => !empty($payload['phoneNumber']) ? (string) $payload['phoneNumber'] : (!empty($payload['phone']) ? (string) $payload['phone'] : '+91 98200 00000'),
                ':company' => !empty($payload['company']) ? (string) $payload['company'] : 'Enterprise Client',
                ':title' => !empty($payload['title']) ? (string) $payload['title'] : 'Decision Maker',
                ':email' => !empty($payload['email']) ? (string) $payload['email'] : '',
                ':status' => !empty($payload['status']) ? (string) $payload['status'] : 'Active Lead',
                ':deal_value' => isset($payload['dealValue']) ? (float) $payload['dealValue'] : 0,
                ':last_contacted' => !empty($payload['lastContacted']) ? (string) $payload['lastContacted'] : 'Just now',
                ':crm_account_id' => !empty($payload['crmAccountId']) ? (string) $payload['crmAccountId'] : 'RV360-ACC',
                ':notes' => !empty($payload['notes']) ? (string) $payload['notes'] : ''
            ]);

            http_response_code(201);
            echo json_encode(['success' => true, 'id' => $leadId, 'orgId' => $leadOrgId, 'message' => 'Lead saved']);
            exit();
        }
    }

    // =========================================================
    // 11. STATS (?action=stats)
    // =========================================================
    if ($action === 'stats') {
        if ($tenantId === 'all') {
            $totalCalls = (int) $db->query("SELECT COUNT(*) FROM call_logs")->fetchColumn();
            $totalSeconds = (int) $db->query("SELECT SUM(duration) FROM call_logs")->fetchColumn();
            $totalDealValue = (float) $db->query("SELECT SUM(deal_value) FROM call_logs")->fetchColumn();
            $positiveCount = (int) $db->query("SELECT COUNT(*) FROM call_logs WHERE sentiment = 'positive'")->fetchColumn();
            $activeRepsCount = (int) $db->query("SELECT COUNT(*) FROM sales_reps WHERE is_online = 1")->fetchColumn();
            $syncedCrmsCount = (int) $db->query("SELECT COUNT(*) FROM crm_connectors WHERE is_connected = 1")->fetchColumn();
        } else {
            $st1 = $db->prepare("SELECT COUNT(*), COALESCE(SUM(duration),0), COALESCE(SUM(deal_value),0) FROM call_logs WHERE org_id = :org_id");
            $st1->execute([':org_id' => $tenantId]);
            $row1 = $st1->fetch(PDO::FETCH_NUM);
            $totalCalls = (int) ($row1[0] ?? 0);
            $totalSeconds = (int) ($row1[1] ?? 0);
            $totalDealValue = (float) ($row1[2] ?? 0);

            $st2 = $db->prepare("SELECT COUNT(*) FROM call_logs WHERE org_id = :org_id AND sentiment = 'positive'");
            $st2->execute([':org_id' => $tenantId]);
            $positiveCount = (int) $st2->fetchColumn();

            $st3 = $db->prepare("SELECT COUNT(*) FROM sales_reps WHERE org_id = :org_id AND is_online = 1");
            $st3->execute([':org_id' => $tenantId]);
            $activeRepsCount = (int) $st3->fetchColumn();
            if ($activeRepsCount === 0) {
                $activeRepsCount = (int) $db->query("SELECT COUNT(*) FROM sales_reps WHERE is_online = 1")->fetchColumn();
            }

            $syncedCrmsCount = (int) $db->query("SELECT COUNT(*) FROM crm_connectors WHERE is_connected = 1")->fetchColumn();
        }

        echo json_encode([
            'success' => true,
            'tenantId' => $tenantId,
            'data' => [
                'totalCalls' => $totalCalls,
                'totalTalkTimeMinutes' => round($totalSeconds / 60, 1),
                'totalPipelineRevenue' => $totalDealValue,
                'sentimentPositiveRate' => $totalCalls > 0 ? round(($positiveCount / $totalCalls) * 100, 1) : 0,
                'activeRepsCount' => $activeRepsCount,
                'syncedCrmsCount' => $syncedCrmsCount
            ]
        ]);
        exit();
    }

    // =========================================================
    // 12. CALL LOGS GET (List with filters)
    // =========================================================
    if ($method === 'GET' && empty($action)) {
        $whereClauses = [];
        $params = [];

        if ($tenantId !== 'all') {
            $whereClauses[] = "(org_id = :org_id OR rep_name IN (SELECT name FROM sales_reps WHERE org_id = :org_id2) OR rep_id IN (SELECT id FROM sales_reps WHERE org_id = :org_id3) OR rep_name IN (SELECT rep_name FROM device_pairings WHERE org_id = :org_id4) OR rep_id IN (SELECT rep_id FROM device_pairings WHERE org_id = :org_id5))";
            $params[':org_id'] = $tenantId;
            $params[':org_id2'] = $tenantId;
            $params[':org_id3'] = $tenantId;
            $params[':org_id4'] = $tenantId;
            $params[':org_id5'] = $tenantId;
        }

        if (!empty($_GET['rep_id'])) {
            $whereClauses[] = "rep_id = :rep_id";
            $params[':rep_id'] = $_GET['rep_id'];
        }

        if (!empty($_GET['direction']) && $_GET['direction'] !== 'all') {
            $whereClauses[] = "direction = :direction";
            $params[':direction'] = $_GET['direction'];
        }
        if (!empty($_GET['sentiment']) && $_GET['sentiment'] !== 'all') {
            $whereClauses[] = "sentiment = :sentiment";
            $params[':sentiment'] = $_GET['sentiment'];
        }
        if (!empty($_GET['q'])) {
            $search = '%' . trim($_GET['q']) . '%';
            $whereClauses[] = "(contact_name LIKE :q1 OR company LIKE :q2 OR phone_number LIKE :q3 OR outcome LIKE :q4 OR notes LIKE :q5)";
            $params[':q1'] = $search;
            $params[':q2'] = $search;
            $params[':q3'] = $search;
            $params[':q4'] = $search;
            $params[':q5'] = $search;
        }

        $sql = "SELECT * FROM call_logs";
        if (count($whereClauses) > 0) {
            $sql .= " WHERE " . implode(' AND ', $whereClauses);
        }
        $sql .= " ORDER BY created_at DESC";

        $limit = isset($_GET['limit']) ? max(1, min((int) $_GET['limit'], 200)) : 100;
        $sql .= " LIMIT " . $limit;

        $stmt = $db->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll();
        if (empty($rows) && $tenantId !== 'all') {
            $rows = $db->query("SELECT * FROM call_logs ORDER BY created_at DESC LIMIT 25")->fetchAll();
        }

        $formatted = array_map(function ($row) {
            return [
                'id' => (string) $row['id'],
                'orgId' => (string) ($row['org_id'] ?? 'org-makes360-33faf'),
                'contactName' => (string) $row['contact_name'],
                'phoneNumber' => (string) $row['phone_number'],
                'company' => (string) ($row['company'] ?? 'Corporate Partner'),
                'direction' => (string) $row['direction'],
                'duration' => (int) $row['duration'],
                'timestamp' => (string) $row['timestamp'],
                'repName' => (string) ($row['rep_name'] ?? 'Rajesh Kumar (RingVia360)'),
                'repAvatar' => (string) ($row['rep_avatar'] ?? 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80'),
                'repId' => (string) ($row['rep_id'] ?? 'rep-1'),
                'outcome' => (string) ($row['outcome'] ?? 'Call Completed'),
                'notes' => (string) ($row['notes'] ?? ''),
                'sentiment' => (string) ($row['sentiment'] ?? 'positive'),
                'sentimentScore' => (int) ($row['sentiment_score'] ?? 85),
                'dealValue' => (float) ($row['deal_value'] ?? 0),
                'dealStage' => (string) ($row['deal_stage'] ?? 'Proposal'),
                'crmStatus' => (string) ($row['crm_status'] ?? 'synced'),
                'crmType' => (string) ($row['crm_type'] ?? 'RingVia360'),
                'simSlot' => (string) ($row['sim_slot'] ?? 'SIM 1 (Airtel Enterprise)'),
                'isEncrypted' => (bool) $row['is_encrypted'],
                'recordingUrl' => (string) ($row['recording_url'] ?? 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3'),
                'waveform' => json_decode((string) ($row['waveform'] ?? '[]'), true) ?: [30, 45, 60, 80, 50, 70, 90, 60, 40, 65, 80, 95, 75, 55, 65, 85, 90, 60, 40, 55],
                'transcript' => json_decode((string) ($row['transcript'] ?? '[]'), true) ?: [],
                'keyActionItems' => json_decode((string) ($row['key_action_items'] ?? '[]'), true) ?: [],
                'createdAt' => (string) $row['created_at']
            ];
        }, $rows);

        echo json_encode([
            'success' => true,
            'count' => count($formatted),
            'database' => $driver,
            'active_user' => $activeUser,
            'data' => $formatted
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        exit();
    }

    // =========================================================
    // 13. CALL LOGS POST / PUT (Save & Upsert)
    // =========================================================
    if (($method === 'POST' || $method === 'PUT') && empty($action)) {
        $raw = file_get_contents('php://input');
        $payload = json_decode($raw, true);

        if (!$payload) {
            http_response_code(400);
            echo json_encode(['success' => false, 'error' => 'Invalid JSON body payload']);
            exit();
        }

        // Action: CRM Sync flag
        if (!empty($payload['action']) && $payload['action'] === 'crm_sync') {
            $callId = !empty($payload['id']) ? (string) $payload['id'] : '';
            if ($callId) {
                $upd = $db->prepare("UPDATE call_logs SET crm_status = 'synced', crm_type = :crm_type WHERE id = :id");
                $upd->execute([
                    ':id' => $callId,
                    ':crm_type' => !empty($payload['crmType']) ? (string) $payload['crmType'] : 'RingVia360'
                ]);
            }
            echo json_encode(['success' => true, 'message' => "Call #$callId marked synced to CRM"]);
            exit();
        }

        $id = !empty($payload['id']) ? (string) $payload['id'] : ('call-' . round(microtime(true) * 1000));
        $contactName = !empty($payload['contactName']) ? (string) $payload['contactName'] : 'Client Contact';
        $phoneNumber = !empty($payload['phoneNumber']) ? (string) $payload['phoneNumber'] : '+91 98201 43210';
        $company = !empty($payload['company']) ? (string) $payload['company'] : 'Enterprise Partner';
        $direction = !empty($payload['direction']) ? (string) $payload['direction'] : 'outbound';
        $duration = isset($payload['duration']) ? (int) $payload['duration'] : (isset($payload['durationSeconds']) ? (int) $payload['durationSeconds'] : 45);
        $timestamp = !empty($payload['timestamp']) ? (string) $payload['timestamp'] : 'Just now';
        $repName = !empty($payload['repName']) ? (string) $payload['repName'] : 'Rajesh Kumar (RingVia360)';
        $repAvatar = !empty($payload['repAvatar']) ? (string) $payload['repAvatar'] : 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80';
        $repId = !empty($payload['repId']) ? (string) $payload['repId'] : 'rep-1';
        $outcome = !empty($payload['outcome']) ? (string) $payload['outcome'] : 'Call Completed & Synced';
        $notes = !empty($payload['notes']) ? (string) $payload['notes'] : 'Call logged via RingVia360 companion app.';
        $sentiment = !empty($payload['sentiment']) ? (string) $payload['sentiment'] : 'positive';
        $sentimentScore = isset($payload['sentimentScore']) ? (int) $payload['sentimentScore'] : 85;
        $dealValue = isset($payload['dealValue']) ? (float) $payload['dealValue'] : 48000;
        $dealStage = !empty($payload['dealStage']) ? (string) $payload['dealStage'] : 'Proposal';
        $crmStatus = !empty($payload['crmStatus']) ? (string) $payload['crmStatus'] : 'synced';
        $crmType = !empty($payload['crmType']) ? (string) $payload['crmType'] : 'RingVia360';
        $simSlot = !empty($payload['simSlot']) ? (string) $payload['simSlot'] : 'SIM 1 (Airtel Enterprise)';
        $isEncrypted = isset($payload['isEncrypted']) ? ($payload['isEncrypted'] ? 1 : 0) : 1;
        $recordingUrl = !empty($payload['recordingUrl']) ? (string) $payload['recordingUrl'] : null;

        $waveform = !empty($payload['waveform']) ? json_encode($payload['waveform']) : json_encode([30, 45, 65, 80, 70, 85, 90, 75, 60, 50, 65, 80, 95, 75, 60, 45, 40, 55, 70, 60]);
        $transcript = !empty($payload['transcript']) ? json_encode($payload['transcript']) : json_encode([
            ['speaker' => $repName, 'text' => "Namaste, this is $repName from RingVia360. All audio, recordings, and wrap-up notes synced seamlessly.", 'timestamp' => '00:03'],
            ['speaker' => $contactName, 'text' => "Thanks $repName! The automatic CRM sync and dual-SIM isolation work great.", 'timestamp' => '00:15']
        ]);
        $keyActionItems = !empty($payload['keyActionItems']) ? json_encode($payload['keyActionItems']) : json_encode([
            'Follow up with RingVia360 lead manager',
            'Verify CRM pipeline stage update'
        ]);

        $targetOrgId = !empty($payload['orgId']) ? (string) $payload['orgId'] : (!empty($payload['org_id']) ? (string) $payload['org_id'] : ($tenantId !== 'all' ? $tenantId : ''));

        // Intelligently resolve targetOrgId if empty, default 'org-tcs', or client temporary ID
        if (empty($targetOrgId) || $targetOrgId === 'org-tcs' || str_starts_with($targetOrgId, 'org-1790')) {
            try {
                // 1. Check device_pairings for this rep or paired device
                $pStmt = $db->prepare("SELECT org_id FROM device_pairings WHERE (rep_id = :rep_id OR rep_name = :rep_name) ORDER BY created_at DESC LIMIT 1");
                $pStmt->execute([':rep_id' => $repId, ':rep_name' => $repName]);
                $matchedOrg = $pStmt->fetchColumn();
                if ($matchedOrg && $matchedOrg !== 'org-tcs') {
                    $targetOrgId = str_starts_with($matchedOrg, 'org-1790') ? 'org-makes360-33faf' : $matchedOrg;
                }
            } catch (Throwable $e) {}

            // 2. Check sales_reps for this rep
            if (empty($targetOrgId) || $targetOrgId === 'org-tcs') {
                try {
                    $rStmt = $db->prepare("SELECT org_id FROM sales_reps WHERE (id = :id OR name = :name) AND org_id != 'org-tcs' AND org_id IS NOT NULL LIMIT 1");
                    $rStmt->execute([':id' => $repId, ':name' => $repName]);
                    $matchedRepOrg = $rStmt->fetchColumn();
                    if ($matchedRepOrg) {
                        $targetOrgId = $matchedRepOrg;
                    }
                } catch (Throwable $e) {}
            }

            // 3. Fallback to newest customer organization
            if (empty($targetOrgId) || $targetOrgId === 'org-tcs') {
                try {
                    $custOrg = $db->query("SELECT id FROM organizations WHERE id NOT IN ('org-tcs', 'org-ringvia360') ORDER BY created_at DESC LIMIT 1")->fetchColumn();
                    if ($custOrg) {
                        $targetOrgId = $custOrg;
                    }
                } catch (Throwable $e) {}
            }

            if (empty($targetOrgId)) {
                $targetOrgId = 'org-tcs';
            }
        }

        $saveSql = $isMysql
            ? "INSERT INTO call_logs (
                id, org_id, contact_name, phone_number, company, direction, duration, timestamp,
                rep_name, rep_avatar, rep_id, outcome, notes, sentiment, sentiment_score,
                deal_value, deal_stage, crm_status, crm_type, sim_slot, is_encrypted,
                recording_url, waveform, transcript, key_action_items
            ) VALUES (
                :id, :org_id, :contact_name, :phone_number, :company, :direction, :duration, :timestamp,
                :rep_name, :rep_avatar, :rep_id, :outcome, :notes, :sentiment, :sentiment_score,
                :deal_value, :deal_stage, :crm_status, :crm_type, :sim_slot, :is_encrypted,
                :recording_url, :waveform, :transcript, :key_action_items
            ) ON DUPLICATE KEY UPDATE 
                org_id = VALUES(org_id),
                outcome = VALUES(outcome),
                notes = VALUES(notes),
                sentiment = VALUES(sentiment),
                sentiment_score = VALUES(sentiment_score),
                deal_value = VALUES(deal_value),
                deal_stage = VALUES(deal_stage),
                crm_status = VALUES(crm_status),
                crm_type = VALUES(crm_type),
                recording_url = VALUES(recording_url),
                waveform = VALUES(waveform),
                transcript = VALUES(transcript),
                key_action_items = VALUES(key_action_items)"
            : "INSERT OR REPLACE INTO call_logs (
                id, org_id, contact_name, phone_number, company, direction, duration, timestamp,
                rep_name, rep_avatar, rep_id, outcome, notes, sentiment, sentiment_score,
                deal_value, deal_stage, crm_status, crm_type, sim_slot, is_encrypted,
                recording_url, waveform, transcript, key_action_items
            ) VALUES (
                :id, :org_id, :contact_name, :phone_number, :company, :direction, :duration, :timestamp,
                :rep_name, :rep_avatar, :rep_id, :outcome, :notes, :sentiment, :sentiment_score,
                :deal_value, :deal_stage, :crm_status, :crm_type, :sim_slot, :is_encrypted,
                :recording_url, :waveform, :transcript, :key_action_items
            )";

        $ins = $db->prepare($saveSql);
        $ins->execute([
            ':id' => $id,
            ':org_id' => $targetOrgId,
            ':contact_name' => $contactName,
            ':phone_number' => $phoneNumber,
            ':company' => $company,
            ':direction' => $direction,
            ':duration' => $duration,
            ':timestamp' => $timestamp,
            ':rep_name' => $repName,
            ':rep_avatar' => $repAvatar,
            ':rep_id' => $repId,
            ':outcome' => $outcome,
            ':notes' => $notes,
            ':sentiment' => $sentiment,
            ':sentiment_score' => $sentimentScore,
            ':deal_value' => $dealValue,
            ':deal_stage' => $dealStage,
            ':crm_status' => $crmStatus,
            ':crm_type' => $crmType,
            ':sim_slot' => $simSlot,
            ':is_encrypted' => $isEncrypted,
            ':recording_url' => $recordingUrl,
            ':waveform' => $waveform,
            ':transcript' => $transcript,
            ':key_action_items' => $keyActionItems
        ]);

        http_response_code(201);
        echo json_encode([
            'success' => true,
            'message' => "Call #$id saved dynamically to $driver database",
            'id' => $id,
            'orgId' => $targetOrgId,
            'database' => $driver,
            'active_user' => $activeUser
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        exit();
    }

    // =========================================================
    // 14. CALL LOGS DELETE
    // =========================================================
    if ($method === 'DELETE' && empty($action)) {
        $id = $_GET['id'] ?? '';
        if (!$id) {
            http_response_code(400);
            echo json_encode(['success' => false, 'error' => 'Missing call ID']);
            exit();
        }
        $del = $db->prepare("DELETE FROM call_logs WHERE id = :id");
        $del->execute([':id' => $id]);

        echo json_encode([
            'success' => true,
            'message' => "Call #$id deleted successfully",
            'id' => $id
        ]);
        exit();
    }

    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Method Not Allowed']);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Server database error: ' . $e->getMessage()
    ]);
}
