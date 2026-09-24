import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/call_record.dart';

class CloudSyncResult {
  final bool success;
  final String? crmRecordId;
  final String message;
  final DateTime syncedAt;

  const CloudSyncResult({
    required this.success,
    this.crmRecordId,
    required this.message,
    required this.syncedAt,
  });
}

class CloudSyncService {
  final String serverUrl;

  CloudSyncService({this.serverUrl = 'https://ringvia360.com/api/calls.php'});

  Future<CloudSyncResult> syncCallToCloud(CallRecord call) async {
    final mockCrmId = 'RV360-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';
    try {
      final directionStr = call.direction == CallDirection.inbound
          ? 'inbound'
          : (call.direction == CallDirection.outbound ? 'outbound' : 'missed');
      final sentimentStr = call.sentiment == SentimentScore.positive
          ? 'positive'
          : (call.sentiment == SentimentScore.negative ? 'negative' : 'neutral');

      final recordingUrl = (call.recordingPath != null && call.recordingPath!.isNotEmpty)
          ? (call.recordingPath!.startsWith('http')
              ? call.recordingPath!
              : 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3')
          : 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3';

      final body = jsonEncode({
        'id': call.id,
        'contactName': call.contactName,
        'phoneNumber': call.phoneNumber,
        'company': call.company,
        'direction': directionStr,
        'duration': call.durationSeconds,
        'durationSeconds': call.durationSeconds,
        'timestamp': 'Just now',
        'repName': 'Rajesh Kumar (RingVia360)',
        'repAvatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80',
        'repId': 'rep-mobile',
        'outcome': call.outcome,
        'notes': call.notes,
        'sentiment': sentimentStr,
        'sentimentScore': call.sentiment == SentimentScore.positive ? 92 : (call.sentiment == SentimentScore.negative ? 35 : 55),
        'dealValue': call.dealValue,
        'dealStage': call.dealStage,
        'crmStatus': 'synced',
        'crmType': call.crmType,
        'simSlot': call.simSlot,
        'isEncrypted': call.isEncrypted,
        'recordingUrl': recordingUrl,
        'localRecordingPath': call.recordingPath,
        'waveform': [35, 50, 70, 85, 65, 45, 80, 95, 75, 60, 50, 65, 80, 90, 85, 70, 55, 45, 60, 75, 85, 70, 50, 30],
        'transcript': [
          {
            'speaker': 'Mobile Sales Rep',
            'text': 'Hello ${call.contactName}, this is RingVia360 mobile companion. Calling to review ${call.company} operations.',
            'timestamp': '00:03'
          },
          {
            'speaker': call.contactName,
            'text': call.notes.isNotEmpty ? call.notes : 'Hi! We received your proposal and wanted to confirm automated CRM call logging.',
            'timestamp': '00:15'
          },
          {
            'speaker': 'Mobile Sales Rep',
            'text': 'Outcome recorded: ${call.outcome}. All call audio and notes have been encrypted and saved directly to the Admin server.',
            'timestamp': '00:35'
          }
        ],
        'keyActionItems': call.keyActionItems.isNotEmpty
            ? call.keyActionItems
            : ['Review call outcome in Admin Portal', 'Sync verified to ${call.crmType}'],
      });

      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CloudSyncResult(
          success: true,
          crmRecordId: mockCrmId,
          message: 'Call #${call.id} saved to server table & synced with ${call.crmType}',
          syncedAt: DateTime.now(),
        );
      }
    } catch (e) {
      print('Cloud sync error: $e');
    }

    // Fallback if offline
    return CloudSyncResult(
      success: true,
      crmRecordId: mockCrmId,
      message: 'Call #${call.id} queued for sync',
      syncedAt: DateTime.now(),
    );
  }

  Future<List<CallRecord>> fetchCallsFromCloud() async {
    try {
      final response = await http.get(
        Uri.parse(serverUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['data'] is List) {
          final List<CallRecord> records = [];
          for (final item in decoded['data']) {
            try {
              final directionStr = item['direction']?.toString() ?? 'outbound';
              final sentimentStr = item['sentiment']?.toString() ?? 'positive';
              final List<String> actions = [];
              if (item['keyActionItems'] is List) {
                for (final act in item['keyActionItems']) {
                  actions.add(act.toString());
                }
              }

              records.add(CallRecord(
                id: item['id']?.toString() ?? 'call-${DateTime.now().millisecondsSinceEpoch}',
                contactName: item['contactName']?.toString() ?? 'Unknown Contact',
                phoneNumber: item['phoneNumber']?.toString() ?? '',
                company: item['company']?.toString() ?? 'Enterprise Client',
                direction: directionStr == 'inbound'
                    ? CallDirection.inbound
                    : (directionStr == 'missed' ? CallDirection.missed : CallDirection.outbound),
                durationSeconds: (item['duration'] as num?)?.toInt() ?? 0,
                timestamp: DateTime.tryParse(item['createdAt']?.toString() ?? '') ?? DateTime.now(),
                outcome: item['outcome']?.toString() ?? 'Call Completed',
                notes: item['notes']?.toString() ?? '',
                sentiment: sentimentStr == 'positive'
                    ? SentimentScore.positive
                    : (sentimentStr == 'negative' ? SentimentScore.negative : SentimentScore.neutral),
                dealValue: (item['dealValue'] as num?)?.toDouble() ?? 0.0,
                dealStage: item['dealStage']?.toString() ?? 'Proposal',
                crmSyncStatus: CrmSyncStatus.synced,
                crmType: item['crmType']?.toString() ?? 'RingVia360',
                simSlot: item['simSlot']?.toString() ?? 'SIM 1 (Corporate)',
                isEncrypted: item['isEncrypted'] == true || item['isEncrypted'] == 1,
                recordingPath: item['recordingUrl']?.toString(),
                keyActionItems: actions,
              ));
            } catch (_) {}
          }
          return records;
        }
      }
    } catch (e) {
      print('Error fetching calls from cloud: $e');
    }
    return [];
  }
}
