<?php
declare(strict_types=1);

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS, DELETE');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$dbDir = __DIR__ . '/data';
if (!is_dir($dbDir)) {
    mkdir($dbDir, 0755, true);
}
$dbPath = $dbDir . '/ringvia_calls.sqlite';

try {
    $db = new PDO('sqlite:' . $dbPath);
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $db->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);

    // Create Call Logs Table
    $db->exec("
        CREATE TABLE IF NOT EXISTS call_logs (
            id TEXT PRIMARY KEY,
            contact_name TEXT NOT NULL,
            phone_number TEXT NOT NULL,
            company TEXT,
            direction TEXT NOT NULL,
            duration INTEGER NOT NULL DEFAULT 0,
            timestamp TEXT NOT NULL,
            rep_name TEXT DEFAULT 'Sarah Jenkins',
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
            sim_slot TEXT DEFAULT 'SIM 1 (Corporate)',
            is_encrypted INTEGER DEFAULT 1,
            recording_url TEXT,
            waveform TEXT,
            transcript TEXT,
            key_action_items TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    ");

    // Seed initial records if empty
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
                'rep_name' => 'Rajesh Kumar',
                'rep_avatar' => 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80',
                'rep_id' => 'rep-1',
                'outcome' => 'Demo Completed - Contract Requested',
                'notes' => 'Decision maker confirmed budget for 50 licenses. Requested RingVia360 field mapping.',
                'sentiment' => 'positive',
                'sentiment_score' => 94,
                'deal_value' => 48000,
                'deal_stage' => 'Proposal / Review',
                'crm_status' => 'synced',
                'crm_type' => 'RingVia360',
                'sim_slot' => 'SIM 1 (Corporate)',
                'is_encrypted' => 1,
                'recording_url' => 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
                'waveform' => json_encode([30, 45, 65, 80, 70, 85, 90, 75, 60, 50, 65, 80, 95, 75, 60, 45, 40, 55, 70, 60]),
                'transcript' => json_encode([
                    ['speaker' => 'Rajesh Kumar', 'text' => 'Namaste Aarav, thanks for joining. Did you get a chance to test our SIM isolation?', 'timestamp' => '00:03'],
                    ['speaker' => 'Aarav Sharma', 'text' => 'Yes Rajesh, our team tested the Knox dual-SIM isolation on 10 Samsung devices. Corporate calls were logged flawlessly.', 'timestamp' => '00:45'],
                    ['speaker' => 'Rajesh Kumar', 'text' => 'Fantastic! We can have your custom RingVia360 fields and reporting live by Monday.', 'timestamp' => '02:10'],
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
                'rep_name' => 'Rajesh Kumar',
                'rep_avatar' => 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80',
                'rep_id' => 'rep-1',
                'outcome' => 'Technical Validation Passed',
                'notes' => 'Client tested inbound call capture on Samsung Knox devices with zero battery impact.',
                'sentiment' => 'positive',
                'sentiment_score' => 88,
                'deal_value' => 72000,
                'deal_stage' => 'Technical Validation',
                'crm_status' => 'synced',
                'crm_type' => 'RingVia360',
                'sim_slot' => 'SIM 1 (Corporate)',
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
                'rep_name' => 'Rajesh Kumar',
                'rep_avatar' => 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80',
                'rep_id' => 'rep-1',
                'outcome' => 'Missed Call - Auto Follow-up Dispatched',
                'notes' => 'Auto-responder dispatched instant WhatsApp template with meeting link.',
                'sentiment' => 'neutral',
                'sentiment_score' => 50,
                'deal_value' => 15000,
                'dealStage' => 'Discovery',
                'deal_stage' => 'Discovery',
                'crm_status' => 'synced',
                'crm_type' => 'RingVia360',
                'sim_slot' => 'SIM 1 (Corporate)',
                'is_encrypted' => 1,
                'recording_url' => '',
                'waveform' => json_encode([10, 10, 10, 10, 10, 10, 10, 10, 10, 10]),
                'transcript' => json_encode([]),
                'key_action_items' => json_encode([
                    'Check if client booked calendar slot'
                ])
            ]
        ];

        $insStmt = $db->prepare("
            INSERT OR REPLACE INTO call_logs (
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

        foreach ($initialData as $row) {
            $insStmt->execute($row);
        }
    }

    $method = $_SERVER['REQUEST_METHOD'];

    if ($method === 'GET') {
        $stmt = $db->query("SELECT * FROM call_logs ORDER BY created_at DESC");
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
                'repName' => (string) ($row['rep_name'] ?? 'Rajesh Kumar'),
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
                'simSlot' => (string) ($row['sim_slot'] ?? 'SIM 1 (Corporate)'),
                'isEncrypted' => (bool) $row['is_encrypted'],
                'recordingUrl' => (string) ($row['recording_url'] ?? ''),
                'waveform' => json_decode((string) ($row['waveform'] ?? '[]'), true) ?: [30, 45, 60, 80, 50, 70, 90, 60, 40, 65, 80, 95, 75, 55, 65, 85, 90, 60, 40, 55],
                'transcript' => json_decode((string) ($row['transcript'] ?? '[]'), true) ?: [],
                'keyActionItems' => json_decode((string) ($row['key_action_items'] ?? '[]'), true) ?: [],
                'createdAt' => (string) $row['created_at']
            ];
        }, $rows);

        echo json_encode([
            'success' => true,
            'count' => count($formatted),
            'data' => $formatted
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        exit();
    }

    if ($method === 'POST') {
        $raw = file_get_contents('php://input');
        $payload = json_decode($raw, true);

        if (!$payload) {
            http_response_code(400);
            echo json_encode(['success' => false, 'error' => 'Invalid JSON body payload']);
            exit();
        }

        $id = !empty($payload['id']) ? (string) $payload['id'] : ('call-' . round(microtime(true) * 1000));
        $contactName = !empty($payload['contactName']) ? (string) $payload['contactName'] : 'Aarav Sharma';
        $phoneNumber = !empty($payload['phoneNumber']) ? (string) $payload['phoneNumber'] : '+919820143210';
        $company = !empty($payload['company']) ? (string) $payload['company'] : 'Tata Consultancy Services';
        $direction = !empty($payload['direction']) ? (string) $payload['direction'] : 'outbound';
        $duration = isset($payload['duration']) ? (int) $payload['duration'] : (isset($payload['durationSeconds']) ? (int) $payload['durationSeconds'] : 45);
        $timestamp = !empty($payload['timestamp']) ? (string) $payload['timestamp'] : 'Just now';
        $repName = !empty($payload['repName']) ? (string) $payload['repName'] : 'Rajesh Kumar (RingVia360)';
        $repAvatar = !empty($payload['repAvatar']) ? (string) $payload['repAvatar'] : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80';
        $repId = !empty($payload['repId']) ? (string) $payload['repId'] : 'rep-mobile';
        $outcome = !empty($payload['outcome']) ? (string) $payload['outcome'] : 'Call Completed & Tracked';
        $notes = !empty($payload['notes']) ? (string) $payload['notes'] : 'Call logged via RingVia360 phone companion app.';
        $sentiment = !empty($payload['sentiment']) ? (string) $payload['sentiment'] : 'positive';
        $sentimentScore = isset($payload['sentimentScore']) ? (int) $payload['sentimentScore'] : ($sentiment === 'positive' ? 90 : ($sentiment === 'negative' ? 35 : 55));
        $dealValue = isset($payload['dealValue']) ? (float) $payload['dealValue'] : 48000;
        $dealStage = !empty($payload['dealStage']) ? (string) $payload['dealStage'] : 'Proposal';
        $crmStatus = !empty($payload['crmStatus']) ? (string) $payload['crmStatus'] : 'synced';
        $crmType = !empty($payload['crmType']) ? (string) $payload['crmType'] : 'RingVia360';
        $simSlot = !empty($payload['simSlot']) ? (string) $payload['simSlot'] : 'SIM 1 (Corporate)';
        $isEncrypted = isset($payload['isEncrypted']) ? ($payload['isEncrypted'] ? 1 : 0) : 1;
        $recordingUrl = !empty($payload['recordingUrl']) ? (string) $payload['recordingUrl'] : 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3';

        // Waveform
        $waveform = !empty($payload['waveform']) ? json_encode($payload['waveform']) : json_encode([30, 45, 65, 80, 70, 85, 90, 75, 60, 50, 65, 80, 95, 75, 60, 45, 40, 55, 70, 60]);
        
        // Transcript
        $transcript = !empty($payload['transcript']) ? json_encode($payload['transcript']) : json_encode([
            ['speaker' => $repName, 'text' => "Hello, this is $repName from RingVia360. Confirming our discussion on mobile sales activity tracking.", 'timestamp' => '00:03'],
            ['speaker' => $contactName, 'text' => "Thanks $repName! The call logs, recordings, and wrap-up notes synced seamlessly to our CRM.", 'timestamp' => '00:15']
        ]);

        // Key Action Items
        $keyActionItems = !empty($payload['keyActionItems']) ? json_encode($payload['keyActionItems']) : json_encode([
            'Follow up with CRM account manager',
            'Send mobile app setup instructions'
        ]);

        $ins = $db->prepare("
            INSERT OR REPLACE INTO call_logs (
                id, contact_name, phone_number, company, direction, duration, timestamp,
                rep_name, rep_avatar, rep_id, outcome, notes, sentiment, sentiment_score,
                deal_value, deal_stage, crm_status, crm_type, sim_slot, is_encrypted,
                recording_url, waveform, transcript, key_action_items, created_at
            ) VALUES (
                :id, :contact_name, :phone_number, :company, :direction, :duration, :timestamp,
                :rep_name, :rep_avatar, :rep_id, :outcome, :notes, :sentiment, :sentiment_score,
                :deal_value, :deal_stage, :crm_status, :crm_type, :sim_slot, :is_encrypted,
                :recording_url, :waveform, :transcript, :key_action_items, CURRENT_TIMESTAMP
            )
        ");

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
            'message' => "Call #$id successfully stored in server call_logs table",
            'id' => $id
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        exit();
    }

    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Method Not Allowed']);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Server database error: ' . $e->getMessage()
    ]);
}
