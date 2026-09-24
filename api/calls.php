<?php
declare(strict_types=1);

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/db.php';

try {
    $conn = getDatabaseConnection();
    /** @var PDO $db */
    $db = $conn['pdo'];
    $driver = $conn['driver'];
    $isMysql = ($driver === 'mysql');

    // 1. Create Tables
    if ($isMysql) {
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
    } else {
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
        ");

        $db->exec("
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
        ");
    }

    // 2. Seed Call Logs if Table is Empty
    $countStmt = $db->query("SELECT COUNT(*) AS total FROM call_logs");
    $total = (int) $countStmt->fetchColumn();

    if ($total === 0) {
        $initialData = [
            [
                'id' => 'call-101',
                'contact_name' => 'Aarav Sharma',
                'phone_number' => '+91 98201 43210',
                'company' => 'Tata Consultancy Services',
                'direction' => 'outbound',
                'duration' => 384,
                'timestamp' => '8m ago',
                'rep_name' => 'Rajesh Kumar (RingVia360)',
                'rep_avatar' => 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80',
                'rep_id' => 'rep-1',
                'outcome' => 'Demo Completed - Contract Requested',
                'notes' => 'Decision maker confirmed budget for 50 licenses. Requested RingVia360 custom field mapping.',
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
                    ['speaker' => 'Rajesh Kumar', 'text' => 'Namaste Aarav, thanks for joining. Did you test our SIM isolation and live audio podcast sync?', 'timestamp' => '00:03'],
                    ['speaker' => 'Aarav Sharma', 'text' => 'Yes Rajesh, our team tested the Knox dual-SIM isolation on 10 devices. Corporate calls were logged flawlessly into RingVia360.', 'timestamp' => '00:45'],
                    ['speaker' => 'Rajesh Kumar', 'text' => 'Fantastic! We can have your custom RingVia360 fields and live feed reporting active by Monday.', 'timestamp' => '02:10'],
                    ['speaker' => 'Aarav Sharma', 'text' => 'Perfect. Please send over the enterprise agreement for 50 seats.', 'timestamp' => '05:30']
                ]),
                'key_action_items' => json_encode([
                    'Send Docusign MSA for 50 licenses',
                    'Schedule kickoff call with IT Director'
                ])
            ],
            [
                'id' => 'call-102',
                'contact_name' => 'Priya Patel',
                'phone_number' => '+91 98450 12890',
                'company' => 'Infosys Technologies',
                'direction' => 'inbound',
                'duration' => 512,
                'timestamp' => '35m ago',
                'rep_name' => 'Rajesh Kumar (RingVia360)',
                'rep_avatar' => 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80',
                'rep_id' => 'rep-1',
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
                    ['speaker' => 'Priya Patel', 'text' => 'Hello Rajesh, we just completed the 24-hour battery consumption benchmark on our sales team.', 'timestamp' => '00:08'],
                    ['speaker' => 'Rajesh Kumar', 'text' => 'Great to hear, Priya! How did RingVia360 perform against Salestrail?', 'timestamp' => '00:25'],
                    ['speaker' => 'Priya Patel', 'text' => 'Zero noticeable battery drain even with full E2EE call recording enabled.', 'timestamp' => '01:15']
                ]),
                'key_action_items' => json_encode([
                    'Email Knox MDM deployment guide'
                ])
            ],
            [
                'id' => 'call-103',
                'contact_name' => 'Vikram Malhotra',
                'phone_number' => '+91 97110 56789',
                'company' => 'Wipro Enterprises',
                'direction' => 'missed',
                'duration' => 0,
                'timestamp' => '1h ago',
                'rep_name' => 'Rajesh Kumar (RingVia360)',
                'rep_avatar' => 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80',
                'rep_id' => 'rep-1',
                'outcome' => 'Missed Call - Auto Follow-up Dispatched',
                'notes' => 'Auto-responder dispatched instant WhatsApp template with meeting link.',
                'sentiment' => 'neutral',
                'sentiment_score' => 50,
                'deal_value' => 15000,
                'deal_stage' => 'Discovery',
                'crm_status' => 'synced',
                'crm_type' => 'RingVia360',
                'sim_slot' => 'SIM 1 (Airtel Enterprise)',
                'is_encrypted' => 1,
                'recording_url' => 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
                'waveform' => json_encode([10, 10, 10, 10, 10, 10, 10, 10, 10, 10]),
                'transcript' => json_encode([]),
                'key_action_items' => json_encode([
                    'Check if client booked calendar slot'
                ])
            ]
        ];

        $insSql = $isMysql
            ? "INSERT INTO call_logs (
                id, contact_name, phone_number, company, direction, duration, timestamp,
                rep_name, rep_avatar, rep_id, outcome, notes, sentiment, sentiment_score,
                deal_value, deal_stage, crm_status, crm_type, sim_slot, is_encrypted,
                recording_url, waveform, transcript, key_action_items
            ) VALUES (
                :id, :contact_name, :phone_number, :company, :direction, :duration, :timestamp,
                :rep_name, :rep_avatar, :rep_id, :outcome, :notes, :sentiment, :sentiment_score,
                :deal_value, :deal_stage, :crm_status, :crm_type, :sim_slot, :is_encrypted,
                :recording_url, :waveform, :transcript, :key_action_items
            ) ON DUPLICATE KEY UPDATE outcome = VALUES(outcome), notes = VALUES(notes)"
            : "INSERT OR REPLACE INTO call_logs (
                id, contact_name, phone_number, company, direction, duration, timestamp,
                rep_name, rep_avatar, rep_id, outcome, notes, sentiment, sentiment_score,
                deal_value, deal_stage, crm_status, crm_type, sim_slot, is_encrypted,
                recording_url, waveform, transcript, key_action_items
            ) VALUES (
                :id, :contact_name, :phone_number, :company, :direction, :duration, :timestamp,
                :rep_name, :rep_avatar, :rep_id, :outcome, :notes, :sentiment, :sentiment_score,
                :deal_value, :deal_stage, :crm_status, :crm_type, :sim_slot, :is_encrypted,
                :recording_url, :waveform, :transcript, :key_action_items
            )";

        $insStmt = $db->prepare($insSql);
        foreach ($initialData as $row) {
            $insStmt->execute($row);
        }
    }

    // 3. Seed Leads if Empty
    $leadsCountStmt = $db->query("SELECT COUNT(*) AS total FROM leads_contacts");
    if ((int) $leadsCountStmt->fetchColumn() === 0) {
        $initialLeads = [
            ['id' => 'lead-1', 'name' => 'Aarav Sharma', 'phone' => '+91 98201 43210', 'company' => 'Tata Consultancy Services', 'title' => 'VP of IT Operations', 'email' => 'aarav.sharma@tcs.example.com', 'status' => 'Enterprise Pilot', 'deal_value' => 48000, 'last_contacted' => '8m ago', 'crm_account_id' => 'RV360-ACC-101', 'notes' => '50-seat pilot agreed for RingVia360 mobile dialer.'],
            ['id' => 'lead-2', 'name' => 'Priya Patel', 'phone' => '+91 98450 12890', 'company' => 'Infosys Technologies', 'title' => 'Director of Sales Operations', 'email' => 'priya.patel@infosys.example.com', 'status' => 'Technical Validation', 'deal_value' => 72000, 'last_contacted' => '35m ago', 'crm_account_id' => 'RV360-ACC-102', 'notes' => 'Knox MDM and dual-SIM compliance verified.'],
            ['id' => 'lead-3', 'name' => 'Vikram Malhotra', 'phone' => '+91 97110 56789', 'company' => 'Wipro Enterprises', 'title' => 'Chief Revenue Officer', 'email' => 'vikram.m@wipro.example.com', 'status' => 'Proposal Sent', 'deal_value' => 25000, 'last_contacted' => '1h ago', 'crm_account_id' => 'RV360-ACC-103', 'notes' => 'Follow up on automated WhatsApp logging demo.']
        ];
        $leadSql = $isMysql
            ? "INSERT INTO leads_contacts (id, name, phone, company, title, email, status, deal_value, last_contacted, crm_account_id, notes) VALUES (:id, :name, :phone, :company, :title, :email, :status, :deal_value, :last_contacted, :crm_account_id, :notes) ON DUPLICATE KEY UPDATE name=VALUES(name)"
            : "INSERT OR REPLACE INTO leads_contacts (id, name, phone, company, title, email, status, deal_value, last_contacted, crm_account_id, notes) VALUES (:id, :name, :phone, :company, :title, :email, :status, :deal_value, :last_contacted, :crm_account_id, :notes)";
        $leadStmt = $db->prepare($leadSql);
        foreach ($initialLeads as $lead) {
            $leadStmt->execute($lead);
        }
    }

    $method = $_SERVER['REQUEST_METHOD'];
    $action = $_GET['action'] ?? '';

    // =========================================================
    // GET REQUESTS
    // =========================================================
    if ($method === 'GET') {
        // Health / DB Status Check
        if ($action === 'db_status') {
            echo json_encode([
                'success' => true,
                'driver' => $driver,
                'database' => $isMysql ? 'u488332847_dn_name (MySQL)' : 'ringvia_calls.sqlite (SQLite)',
                'mysql_error' => $conn['mysql_error'] ?? null,
                'timestamp' => date('Y-m-d H:i:s')
            ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
            exit();
        }

        // Live Leads & Contacts
        if ($action === 'leads') {
            $query = "SELECT * FROM leads_contacts ORDER BY created_at DESC";
            $leads = $db->query($query)->fetchAll();
            $formattedLeads = array_map(function ($l) {
                return [
                    'id' => (string) $l['id'],
                    'name' => (string) $l['name'],
                    'phoneNumber' => (string) $l['phone'],
                    'company' => (string) ($l['company'] ?? ''),
                    'title' => (string) ($l['title'] ?? ''),
                    'email' => (string) ($l['email'] ?? ''),
                    'status' => (string) ($l['status'] ?? 'Active Lead'),
                    'openDealValue' => (float) ($l['deal_value'] ?? 0),
                    'lastContacted' => (string) ($l['last_contacted'] ?? 'Recent'),
                    'crmAccountId' => (string) ($l['crm_account_id'] ?? 'RV360-ACC-01'),
                    'notes' => (string) ($l['notes'] ?? '')
                ];
            }, $leads);

            echo json_encode([
                'success' => true,
                'count' => count($formattedLeads),
                'data' => $formattedLeads
            ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
            exit();
        }

        // Live Dashboard & Rep Stats
        if ($action === 'stats') {
            $callsCount = (int) $db->query("SELECT COUNT(*) FROM call_logs")->fetchColumn();
            $totalDuration = (int) $db->query("SELECT COALESCE(SUM(duration), 0) FROM call_logs")->fetchColumn();
            $totalDealValue = (float) $db->query("SELECT COALESCE(SUM(deal_value), 0) FROM call_logs WHERE deal_stage = 'Closed Won' OR deal_stage = 'Proposal'")->fetchColumn();
            $syncedCount = (int) $db->query("SELECT COUNT(*) FROM call_logs WHERE crm_status = 'synced'")->fetchColumn();
            $positiveCount = (int) $db->query("SELECT COUNT(*) FROM call_logs WHERE sentiment = 'positive'")->fetchColumn();

            echo json_encode([
                'success' => true,
                'stats' => [
                    'totalCalls' => $callsCount,
                    'totalDurationMinutes' => round($totalDuration / 60, 1),
                    'totalDealValue' => $totalDealValue,
                    'syncedCrmCount' => $syncedCount,
                    'positiveSentimentPercent' => $callsCount > 0 ? round(($positiveCount / $callsCount) * 100) : 85,
                    'dbEngine' => $driver
                ]
            ], JSON_PRETTY_PRINT);
            exit();
        }

        // Fetch Call Logs (with optional search, direction, sentiment filters)
        $whereClauses = [];
        $params = [];

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

        $formatted = array_map(function ($row) {
            return [
                'id' => (string) $row['id'],
                'contactName' => (string) $row['contact_name'],
                'phoneNumber' => (string) $row['phone_number'],
                'company' => (string) ($row['company'] ?? 'Corporate Partner'),
                'direction' => (string) $row['direction'],
                'duration' => (int) $row['duration'],
                'timestamp' => (string) $row['timestamp'],
                'repName' => (string) ($row['rep_name'] ?? 'Rajesh Kumar (RingVia360)'),
                'repAvatar' => (string) ($row['rep_avatar'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80'),
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
            'data' => $formatted
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        exit();
    }

    // =========================================================
    // POST / PUT REQUESTS (Save, Update, Sync)
    // =========================================================
    if ($method === 'POST' || $method === 'PUT') {
        $raw = file_get_contents('php://input');
        $payload = json_decode($raw, true);

        if (!$payload) {
            http_response_code(400);
            echo json_encode(['success' => false, 'error' => 'Invalid JSON body payload']);
            exit();
        }

        // Action: CRM Sync
        if ($action === 'crm_sync' || (!empty($payload['action']) && $payload['action'] === 'crm_sync')) {
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

        // Action: Upsert Lead
        if ($action === 'leads' || (!empty($payload['action']) && $payload['action'] === 'leads')) {
            $leadId = !empty($payload['id']) ? (string) $payload['id'] : ('lead-' . round(microtime(true) * 1000));
            $leadSql = $isMysql
                ? "INSERT INTO leads_contacts (id, name, phone, company, title, email, status, deal_value, last_contacted, crm_account_id, notes) VALUES (:id, :name, :phone, :company, :title, :email, :status, :deal_value, :last_contacted, :crm_account_id, :notes) ON DUPLICATE KEY UPDATE name=VALUES(name), phone=VALUES(phone), company=VALUES(company), status=VALUES(status), deal_value=VALUES(deal_value), notes=VALUES(notes)"
                : "INSERT OR REPLACE INTO leads_contacts (id, name, phone, company, title, email, status, deal_value, last_contacted, crm_account_id, notes) VALUES (:id, :name, :phone, :company, :title, :email, :status, :deal_value, :last_contacted, :crm_account_id, :notes)";
            
            $stmt = $db->prepare($leadSql);
            $stmt->execute([
                ':id' => $leadId,
                ':name' => !empty($payload['name']) ? (string) $payload['name'] : 'Lead Contact',
                ':phone' => !empty($payload['phoneNumber']) ? (string) $payload['phoneNumber'] : (!empty($payload['phone']) ? (string) $payload['phone'] : '+91 98200 00000'),
                ':company' => !empty($payload['company']) ? (string) $payload['company'] : 'Enterprise',
                ':title' => !empty($payload['title']) ? (string) $payload['title'] : 'Executive',
                ':email' => !empty($payload['email']) ? (string) $payload['email'] : '',
                ':status' => !empty($payload['status']) ? (string) $payload['status'] : 'Active Lead',
                ':deal_value' => isset($payload['openDealValue']) ? (float) $payload['openDealValue'] : (isset($payload['dealValue']) ? (float) $payload['dealValue'] : 0),
                ':last_contacted' => !empty($payload['lastContacted']) ? (string) $payload['lastContacted'] : 'Just now',
                ':crm_account_id' => !empty($payload['crmAccountId']) ? (string) $payload['crmAccountId'] : 'RV360-ACC',
                ':notes' => !empty($payload['notes']) ? (string) $payload['notes'] : ''
            ]);

            http_response_code(201);
            echo json_encode(['success' => true, 'id' => $leadId, 'message' => 'Lead successfully saved']);
            exit();
        }

        // Action: Upsert Call Log
        $id = !empty($payload['id']) ? (string) $payload['id'] : ('call-' . round(microtime(true) * 1000));
        $contactName = !empty($payload['contactName']) ? (string) $payload['contactName'] : 'Client Contact';
        $phoneNumber = !empty($payload['phoneNumber']) ? (string) $payload['phoneNumber'] : '+91 98201 43210';
        $company = !empty($payload['company']) ? (string) $payload['company'] : 'Enterprise Partner';
        $direction = !empty($payload['direction']) ? (string) $payload['direction'] : 'outbound';
        $duration = isset($payload['duration']) ? (int) $payload['duration'] : (isset($payload['durationSeconds']) ? (int) $payload['durationSeconds'] : 45);
        $timestamp = !empty($payload['timestamp']) ? (string) $payload['timestamp'] : 'Just now';
        $repName = !empty($payload['repName']) ? (string) $payload['repName'] : 'Rajesh Kumar (RingVia360)';
        $repAvatar = !empty($payload['repAvatar']) ? (string) $payload['repAvatar'] : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80';
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
        $recordingUrl = !empty($payload['recordingUrl']) ? (string) $payload['recordingUrl'] : 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3';

        $waveform = !empty($payload['waveform']) ? json_encode($payload['waveform']) : json_encode([30, 45, 65, 80, 70, 85, 90, 75, 60, 50, 65, 80, 95, 75, 60, 45, 40, 55, 70, 60]);
        $transcript = !empty($payload['transcript']) ? json_encode($payload['transcript']) : json_encode([
            ['speaker' => $repName, 'text' => "Namaste, this is $repName from RingVia360. All audio, recordings, and wrap-up notes synced seamlessly.", 'timestamp' => '00:03'],
            ['speaker' => $contactName, 'text' => "Thanks $repName! The automatic CRM sync and dual-SIM isolation work great.", 'timestamp' => '00:15']
        ]);
        $keyActionItems = !empty($payload['keyActionItems']) ? json_encode($payload['keyActionItems']) : json_encode([
            'Follow up with RingVia360 lead manager',
            'Verify CRM pipeline stage update'
        ]);

        $saveSql = $isMysql
            ? "INSERT INTO call_logs (
                id, contact_name, phone_number, company, direction, duration, timestamp,
                rep_name, rep_avatar, rep_id, outcome, notes, sentiment, sentiment_score,
                deal_value, deal_stage, crm_status, crm_type, sim_slot, is_encrypted,
                recording_url, waveform, transcript, key_action_items
            ) VALUES (
                :id, :contact_name, :phone_number, :company, :direction, :duration, :timestamp,
                :rep_name, :rep_avatar, :rep_id, :outcome, :notes, :sentiment, :sentiment_score,
                :deal_value, :deal_stage, :crm_status, :crm_type, :sim_slot, :is_encrypted,
                :recording_url, :waveform, :transcript, :key_action_items
            ) ON DUPLICATE KEY UPDATE 
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
                id, contact_name, phone_number, company, direction, duration, timestamp,
                rep_name, rep_avatar, rep_id, outcome, notes, sentiment, sentiment_score,
                deal_value, deal_stage, crm_status, crm_type, sim_slot, is_encrypted,
                recording_url, waveform, transcript, key_action_items
            ) VALUES (
                :id, :contact_name, :phone_number, :company, :direction, :duration, :timestamp,
                :rep_name, :rep_avatar, :rep_id, :outcome, :notes, :sentiment, :sentiment_score,
                :deal_value, :deal_stage, :crm_status, :crm_type, :sim_slot, :is_encrypted,
                :recording_url, :waveform, :transcript, :key_action_items
            )";

        $ins = $db->prepare($saveSql);
        $ins->execute([
            ':id' => $id,
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
            'database' => $driver
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        exit();
    }

    // =========================================================
    // DELETE REQUEST (Remove Call)
    // =========================================================
    if ($method === 'DELETE') {
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
