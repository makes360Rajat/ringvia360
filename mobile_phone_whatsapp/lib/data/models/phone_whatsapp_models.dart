/// Device fleet telemetry model
class DeviceTelemetryModel {
  final String id;
  final String userName;
  final String userEmail;
  final String model;
  final String osVersion;
  final int batteryPercent;
  final bool isOnline;
  final String lastSeen;
  final String lastSync;
  final int pendingSyncCount;
  final String syncMode;
  final String appVersion;

  const DeviceTelemetryModel({
    required this.id,
    required this.userName,
    required this.userEmail,
    required this.model,
    required this.osVersion,
    required this.batteryPercent,
    required this.isOnline,
    required this.lastSeen,
    required this.lastSync,
    required this.pendingSyncCount,
    required this.syncMode,
    required this.appVersion,
  });

  factory DeviceTelemetryModel.fromJson(Map<String, dynamic> json) {
    return DeviceTelemetryModel(
      id: json['id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? json['userName']?.toString() ?? 'Mobile User',
      userEmail: json['user_email']?.toString() ?? json['userEmail']?.toString() ?? '',
      model: json['model']?.toString() ?? 'Android Device',
      osVersion: json['os_version']?.toString() ?? json['osVersion']?.toString() ?? 'Android 14',
      batteryPercent: int.tryParse(json['battery_percent']?.toString() ?? json['batteryPercent']?.toString() ?? '100') ?? 100,
      isOnline: (json['is_online'] == 1 || json['is_online'] == true || json['isOnline'] == true),
      lastSeen: json['last_seen']?.toString() ?? json['lastSeen']?.toString() ?? '',
      lastSync: json['last_sync']?.toString() ?? json['lastSync']?.toString() ?? '',
      pendingSyncCount: int.tryParse(json['pending_sync_count']?.toString() ?? json['pendingSyncCount']?.toString() ?? '0') ?? 0,
      syncMode: json['sync_mode']?.toString() ?? json['syncMode']?.toString() ?? 'automatic',
      appVersion: json['app_version']?.toString() ?? json['appVersion']?.toString() ?? 'v2.4.0',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_name': userName,
    'user_email': userEmail,
    'model': model,
    'os_version': osVersion,
    'battery_percent': batteryPercent,
    'is_online': isOnline ? 1 : 0,
    'last_seen': lastSeen,
    'last_sync': lastSync,
    'pending_sync_count': pendingSyncCount,
    'sync_mode': syncMode,
    'app_version': appVersion,
  };
}

/// Real-time pre-answer incoming ringing event model
class IncomingCallEventModel {
  final String id;
  final String deviceId;
  final String phoneNumber;
  final String contactName;
  final String simSlot;
  final String timestamp;
  final String state;

  const IncomingCallEventModel({
    required this.id,
    required this.deviceId,
    required this.phoneNumber,
    required this.contactName,
    required this.simSlot,
    required this.timestamp,
    required this.state,
  });

  factory IncomingCallEventModel.fromJson(Map<String, dynamic> json) {
    return IncomingCallEventModel(
      id: json['id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? json['deviceId']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? json['phoneNumber']?.toString() ?? '',
      contactName: json['contact_name']?.toString() ?? json['contactName']?.toString() ?? 'Unknown Caller',
      simSlot: json['sim_slot']?.toString() ?? json['simSlot']?.toString() ?? 'SIM 1 (Corporate)',
      timestamp: json['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      state: json['state']?.toString() ?? 'RINGING',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceId': deviceId,
    'phoneNumber': phoneNumber,
    'contactName': contactName,
    'simSlot': simSlot,
    'timestamp': timestamp,
    'state': state,
  };
}

/// Call Log Telemetry with Audio Recording and SHA-256 Checksum
class CallLogTelemetryModel {
  final String id;
  final String deviceId;
  final String phoneNumber;
  final String contactName;
  final String direction; // inbound, outbound, missed, rejected
  final int durationSeconds;
  final String simSlot;
  final String startedAt;
  final String endedAt;
  final String outcome;
  final String recordingStatus; // AVAILABLE, PENDING_UPLOAD, NOT_AVAILABLE
  final String? recordingUrl;
  final String? recordingSha256;
  final String syncStatus; // SYNCED, SYNC_PENDING, FAILED
  final String syncMode; // AUTOMATIC, MANUAL
  final String? notes;

  const CallLogTelemetryModel({
    required this.id,
    required this.deviceId,
    required this.phoneNumber,
    required this.contactName,
    required this.direction,
    required this.durationSeconds,
    required this.simSlot,
    required this.startedAt,
    required this.endedAt,
    required this.outcome,
    required this.recordingStatus,
    this.recordingUrl,
    this.recordingSha256,
    required this.syncStatus,
    required this.syncMode,
    this.notes,
  });

  String get timestamp => startedAt.isNotEmpty ? startedAt : endedAt;

  factory CallLogTelemetryModel.fromJson(Map<String, dynamic> json) {
    return CallLogTelemetryModel(
      id: json['id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? json['deviceId']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? json['phoneNumber']?.toString() ?? '',
      contactName: json['contact_name']?.toString() ?? json['contactName']?.toString() ?? 'Unknown Contact',
      direction: json['direction']?.toString() ?? 'inbound',
      durationSeconds: int.tryParse(json['duration_seconds']?.toString() ?? json['duration']?.toString() ?? '0') ?? 0,
      simSlot: json['sim_slot']?.toString() ?? json['simSlot']?.toString() ?? 'SIM 1 (Corporate)',
      startedAt: json['started_at']?.toString() ?? json['startedAt']?.toString() ?? json['timestamp']?.toString() ?? json['call_time']?.toString() ?? '',
      endedAt: json['ended_at']?.toString() ?? json['endedAt']?.toString() ?? '',
      outcome: json['outcome']?.toString() ?? 'Call Completed',
      recordingStatus: json['recording_status']?.toString() ?? json['recordingStatus']?.toString() ?? 'NOT_AVAILABLE',
      recordingUrl: (json['recording_url'] ?? json['recordingUrl'])?.toString().trim().isNotEmpty == true
          ? (json['recording_url'] ?? json['recordingUrl'])!.toString().trim()
          : null,
      recordingSha256: (json['recording_sha256'] ?? json['recordingSha256'])?.toString().trim().isNotEmpty == true
          ? (json['recording_sha256'] ?? json['recordingSha256'])!.toString().trim()
          : null,
      syncStatus: json['sync_status']?.toString() ?? json['syncStatus']?.toString() ?? 'SYNCED',
      syncMode: json['sync_mode']?.toString() ?? json['syncMode']?.toString() ?? 'AUTOMATIC',
      notes: json['notes']?.toString().trim().isNotEmpty == true
          ? json['notes']!.toString().trim()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceId': deviceId,
    'phoneNumber': phoneNumber,
    'contactName': contactName,
    'direction': direction,
    'duration': durationSeconds,
    'simSlot': simSlot,
    'startedAt': startedAt,
    'endedAt': endedAt,
    'outcome': outcome,
    'recordingStatus': recordingStatus,
    'recordingUrl': recordingUrl,
    'recordingSha256': recordingSha256,
    'syncStatus': syncStatus,
    'syncMode': syncMode,
    'notes': notes,
  };

  CallLogTelemetryModel copyWith({
    String? contactName,
    String? outcome,
    String? notes,
    String? syncStatus,
    String? syncMode,
    String? recordingStatus,
    String? recordingUrl,
    String? recordingSha256,
  }) {
    return CallLogTelemetryModel(
      id: id,
      deviceId: deviceId,
      phoneNumber: phoneNumber,
      contactName: contactName ?? this.contactName,
      direction: direction,
      durationSeconds: durationSeconds,
      simSlot: simSlot,
      startedAt: startedAt,
      endedAt: endedAt,
      outcome: outcome ?? this.outcome,
      recordingStatus: recordingStatus ?? this.recordingStatus,
      recordingUrl: recordingUrl ?? this.recordingUrl,
      recordingSha256: recordingSha256 ?? this.recordingSha256,
      syncStatus: syncStatus ?? this.syncStatus,
      syncMode: syncMode ?? this.syncMode,
      notes: notes ?? this.notes,
    );
  }
}

/// WhatsApp Notification Model (Permitted Android NotificationListenerService)
class WhatsAppNotificationModel {
  final String id;
  final String deviceId;
  final String packageName; // com.whatsapp or com.whatsapp.w4b
  final String sender;
  final String messagePreview;
  final String? groupName;
  final String timestamp;
  final String syncStatus;

  const WhatsAppNotificationModel({
    required this.id,
    required this.deviceId,
    required this.packageName,
    required this.sender,
    required this.messagePreview,
    this.groupName,
    required this.timestamp,
    required this.syncStatus,
  });

  factory WhatsAppNotificationModel.fromJson(Map<String, dynamic> json) {
    return WhatsAppNotificationModel(
      id: json['id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? json['deviceId']?.toString() ?? '',
      packageName: json['package_name']?.toString() ?? json['packageName']?.toString() ?? 'com.whatsapp',
      sender: json['sender']?.toString() ?? 'Sender',
      messagePreview: json['message_preview']?.toString() ?? json['messagePreview']?.toString() ?? '',
      groupName: json['group_name']?.toString() ?? json['groupName']?.toString(),
      timestamp: json['notification_timestamp']?.toString() ?? json['timestamp']?.toString() ?? '',
      syncStatus: json['sync_status']?.toString() ?? json['syncStatus']?.toString() ?? 'SYNCED',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceId': deviceId,
    'packageName': packageName,
    'sender': sender,
    'messagePreview': messagePreview,
    'groupName': groupName,
    'timestamp': timestamp,
    'syncStatus': syncStatus,
  };

  WhatsAppNotificationModel copyWith({String? syncStatus}) {
    return WhatsAppNotificationModel(
      id: id,
      deviceId: deviceId,
      packageName: packageName,
      sender: sender,
      messagePreview: messagePreview,
      groupName: groupName,
      timestamp: timestamp,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

/// Carrier SMS Log Model
class SmsLogModel {
  final String id;
  final String deviceId;
  final String direction; // inbound, outbound
  final String sender;
  final String recipient;
  final String messageBody;
  final String simSlot;
  final String timestamp;
  final String syncStatus;

  const SmsLogModel({
    required this.id,
    required this.deviceId,
    required this.direction,
    required this.sender,
    required this.recipient,
    required this.messageBody,
    required this.simSlot,
    required this.timestamp,
    required this.syncStatus,
  });

  factory SmsLogModel.fromJson(Map<String, dynamic> json) {
    return SmsLogModel(
      id: json['id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? json['deviceId']?.toString() ?? '',
      direction: json['direction']?.toString() ?? 'inbound',
      sender: json['sender']?.toString() ?? '',
      recipient: json['recipient']?.toString() ?? '',
      messageBody: json['message_body']?.toString() ?? json['messageBody']?.toString() ?? '',
      simSlot: json['sim_slot']?.toString() ?? json['simSlot']?.toString() ?? 'SIM 1 (Corporate)',
      timestamp: json['timestamp']?.toString() ?? '',
      syncStatus: json['sync_status']?.toString() ?? json['syncStatus']?.toString() ?? 'SYNCED',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceId': deviceId,
    'direction': direction,
    'sender': sender,
    'recipient': recipient,
    'messageBody': messageBody,
    'simSlot': simSlot,
    'timestamp': timestamp,
    'syncStatus': syncStatus,
  };

  SmsLogModel copyWith({String? syncStatus}) {
    return SmsLogModel(
      id: id,
      deviceId: deviceId,
      direction: direction,
      sender: sender,
      recipient: recipient,
      messageBody: messageBody,
      simSlot: simSlot,
      timestamp: timestamp,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

/// Sync Diagnostic Log
class SyncDiagnosticModel {
  final String id;
  final String deviceId;
  final String eventType;
  final int batchSize;
  final String status;
  final int durationMs;
  final String? errorMessage;
  final String timestamp;

  const SyncDiagnosticModel({
    required this.id,
    required this.deviceId,
    required this.eventType,
    required this.batchSize,
    required this.status,
    required this.durationMs,
    this.errorMessage,
    required this.timestamp,
  });

  factory SyncDiagnosticModel.fromJson(Map<String, dynamic> json) {
    return SyncDiagnosticModel(
      id: json['id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? json['deviceId']?.toString() ?? '',
      eventType: json['event_type']?.toString() ?? json['eventType']?.toString() ?? 'SYNC',
      batchSize: int.tryParse(json['batch_size']?.toString() ?? json['batchSize']?.toString() ?? '1') ?? 1,
      status: json['status']?.toString() ?? 'SUCCESS',
      durationMs: int.tryParse(json['duration_ms']?.toString() ?? json['durationMs']?.toString() ?? '0') ?? 0,
      errorMessage: json['error_message']?.toString() ?? json['errorMessage']?.toString(),
      timestamp: json['created_at']?.toString() ?? json['timestamp']?.toString() ?? '',
    );
  }
}

/// Local Device Call Recording Model
class LocalRecordingModel {
  final String filePath;
  final String fileName;
  final int fileSizeBytes;
  final int durationSeconds;
  final String lastModified;
  final String sha256Hash;
  final String matchedPhoneNumber;
  final String matchedContactName;
  final String recordedTimestamp;
  final int lastModifiedTimestamp; // Added for sorting
  final bool isSyncedToServer;
  final String? serverRecordingUrl;
  final String? matchedCallId;

  const LocalRecordingModel({
    required this.filePath,
    required this.fileName,
    required this.fileSizeBytes,
    required this.durationSeconds,
    required this.lastModified,
    required this.sha256Hash,
    required this.matchedPhoneNumber,
    this.matchedContactName = '',
    this.recordedTimestamp = '',
    this.lastModifiedTimestamp = 0,
    this.isSyncedToServer = false,
    this.serverRecordingUrl,
    this.matchedCallId,
  });

  factory LocalRecordingModel.fromJson(Map<String, dynamic> json) {
    int parsedMs = int.tryParse(json['lastModifiedTimestamp']?.toString() ?? '0') ?? 0;
    if (parsedMs == 0 && json['lastModified'] != null) {
      final dt = DateTime.tryParse(json['lastModified'].toString());
      if (dt != null) parsedMs = dt.millisecondsSinceEpoch;
    }
    if (parsedMs == 0 && json['recordedTimestamp'] != null) {
      final dt = DateTime.tryParse(json['recordedTimestamp'].toString());
      if (dt != null) parsedMs = dt.millisecondsSinceEpoch;
    }

    return LocalRecordingModel(
      filePath: json['filePath']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      fileSizeBytes: int.tryParse(json['fileSizeBytes']?.toString() ?? '0') ?? 0,
      durationSeconds: int.tryParse(json['durationSeconds']?.toString() ?? '0') ?? 0,
      lastModified: json['lastModified']?.toString() ?? '',
      sha256Hash: json['sha256Hash']?.toString() ?? '',
      matchedPhoneNumber: json['matchedPhoneNumber']?.toString() ?? '',
      matchedContactName: json['matchedContactName']?.toString() ?? '',
      recordedTimestamp: json['recordedTimestamp']?.toString() ?? '',
      lastModifiedTimestamp: parsedMs,
      isSyncedToServer: json['isSyncedToServer'] == true,
      serverRecordingUrl: json['serverRecordingUrl']?.toString(),
      matchedCallId: json['matchedCallId']?.toString(),
    );
  }

  LocalRecordingModel copyWith({
    String? filePath,
    String? fileName,
    int? fileSizeBytes,
    int? durationSeconds,
    String? lastModified,
    String? sha256Hash,
    bool? isSyncedToServer,
    String? serverRecordingUrl,
    String? matchedCallId,
    String? matchedPhoneNumber,
    String? matchedContactName,
    int? lastModifiedTimestamp,
  }) {
    return LocalRecordingModel(
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      lastModified: lastModified ?? this.lastModified,
      sha256Hash: sha256Hash ?? this.sha256Hash,
      matchedPhoneNumber: matchedPhoneNumber ?? this.matchedPhoneNumber,
      matchedContactName: matchedContactName ?? this.matchedContactName,
      recordedTimestamp: recordedTimestamp,
      lastModifiedTimestamp: lastModifiedTimestamp ?? this.lastModifiedTimestamp,
      isSyncedToServer: isSyncedToServer ?? this.isSyncedToServer,
      serverRecordingUrl: serverRecordingUrl ?? this.serverRecordingUrl,
      matchedCallId: matchedCallId ?? this.matchedCallId,
    );
  }

  Map<String, dynamic> toJson() => {
    'filePath': filePath,
    'fileName': fileName,
    'fileSizeBytes': fileSizeBytes,
    'durationSeconds': durationSeconds,
    'lastModified': lastModified,
    'lastModifiedTimestamp': lastModifiedTimestamp,
    'sha256Hash': sha256Hash,
    'matchedPhoneNumber': matchedPhoneNumber,
    'matchedContactName': matchedContactName,
    'recordedTimestamp': recordedTimestamp,
    'isSyncedToServer': isSyncedToServer,
    'serverRecordingUrl': serverRecordingUrl,
    'matchedCallId': matchedCallId,
  };
}

/// Permission Detail & Requirement Model
class PermissionInfoModel {
  final String key;
  final String title;
  final String description;
  final String whyNeeded;
  final bool isGranted;
  final bool isCritical;

  const PermissionInfoModel({
    required this.key,
    required this.title,
    required this.description,
    required this.whyNeeded,
    required this.isGranted,
    this.isCritical = true,
  });
}
