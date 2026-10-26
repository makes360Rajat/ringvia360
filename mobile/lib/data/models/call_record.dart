enum CallDirection { inbound, outbound, missed }
enum SentimentScore { positive, neutral, negative }
enum CrmSyncStatus { synced, pending, failed }

class CallRecord {
  final String id;
  final String contactName;
  final String phoneNumber;
  final String company;
  final CallDirection direction;
  final int durationSeconds;
  final DateTime timestamp;
  final String outcome;
  final String notes;
  final SentimentScore sentiment;
  final double dealValue;
  final String dealStage;
  final CrmSyncStatus crmSyncStatus;
  final String crmType;
  final String simSlot;
  final bool isEncrypted;
  final String? recordingPath;
  final List<String> keyActionItems;

  CallRecord({
    required this.id,
    required this.contactName,
    required this.phoneNumber,
    required this.company,
    required this.direction,
    required this.durationSeconds,
    required this.timestamp,
    required this.outcome,
    required this.notes,
    required this.sentiment,
    required this.dealValue,
    required this.dealStage,
    required this.crmSyncStatus,
    this.crmType = 'RingVia360',
    required this.simSlot,
    this.isEncrypted = true,
    this.recordingPath,
    this.keyActionItems = const [],
  });

  CallRecord copyWith({
    String? id,
    String? contactName,
    String? phoneNumber,
    String? company,
    CallDirection? direction,
    int? durationSeconds,
    DateTime? timestamp,
    String? outcome,
    String? notes,
    SentimentScore? sentiment,
    double? dealValue,
    String? dealStage,
    CrmSyncStatus? crmSyncStatus,
    String? crmType,
    String? simSlot,
    bool? isEncrypted,
    String? recordingPath,
    List<String>? keyActionItems,
  }) {
    return CallRecord(
      id: id ?? this.id,
      contactName: contactName ?? this.contactName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      company: company ?? this.company,
      direction: direction ?? this.direction,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      timestamp: timestamp ?? this.timestamp,
      outcome: outcome ?? this.outcome,
      notes: notes ?? this.notes,
      sentiment: sentiment ?? this.sentiment,
      dealValue: dealValue ?? this.dealValue,
      dealStage: dealStage ?? this.dealStage,
      crmSyncStatus: crmSyncStatus ?? this.crmSyncStatus,
      crmType: crmType ?? this.crmType,
      simSlot: simSlot ?? this.simSlot,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      recordingPath: recordingPath ?? this.recordingPath,
      keyActionItems: keyActionItems ?? this.keyActionItems,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contactName': contactName,
      'phoneNumber': phoneNumber,
      'company': company,
      'direction': direction.name,
      'durationSeconds': durationSeconds,
      'timestamp': timestamp.toIso8601String(),
      'outcome': outcome,
      'notes': notes,
      'sentiment': sentiment.name,
      'dealValue': dealValue,
      'dealStage': dealStage,
      'crmSyncStatus': crmSyncStatus.name,
      'crmType': crmType,
      'simSlot': simSlot,
      'isEncrypted': isEncrypted,
      'recordingPath': recordingPath,
      'keyActionItems': keyActionItems,
    };
  }

  factory CallRecord.fromJson(Map<String, dynamic> json) {
    return CallRecord(
      id: json['id'] as String,
      contactName: json['contactName'] as String,
      phoneNumber: json['phoneNumber'] as String,
      company: json['company'] as String,
      direction: CallDirection.values.firstWhere(
        (e) => e.name == json['direction'],
        orElse: () => CallDirection.outbound,
      ),
      durationSeconds: json['durationSeconds'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      outcome: json['outcome'] as String,
      notes: json['notes'] as String,
      sentiment: SentimentScore.values.firstWhere(
        (e) => e.name == json['sentiment'],
        orElse: () => SentimentScore.neutral,
      ),
      dealValue: (json['dealValue'] as num).toDouble(),
      dealStage: json['dealStage'] as String,
      crmSyncStatus: CrmSyncStatus.values.firstWhere(
        (e) => e.name == json['crmSyncStatus'],
        orElse: () => CrmSyncStatus.pending,
      ),
      crmType: json['crmType'] as String? ?? 'RingVia360',
      simSlot: json['simSlot'] as String? ?? 'SIM 1 (Work)',
      isEncrypted: json['isEncrypted'] as bool? ?? true,
      recordingPath: json['recordingPath'] as String?,
      keyActionItems: List<String>.from(json['keyActionItems'] as List? ?? []),
    );
  }
}
