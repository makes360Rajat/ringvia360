import 'dart:convert';
import 'package:crypto/crypto.dart';

class CrmDevice {
  final int id;
  final String name;
  final String description;
  final String platform;
  final String status;
  final int trackSim;

  CrmDevice({
    required this.id,
    required this.name,
    required this.description,
    required this.platform,
    required this.status,
    required this.trackSim,
  });

  factory CrmDevice.fromJson(Map<String, dynamic> json) {
    return CrmDevice(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Sales Phone',
      description: json['description']?.toString() ?? '',
      platform: json['platform']?.toString() ?? 'android',
      status: json['status']?.toString() ?? 'active',
      trackSim: (json['track_sim'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'platform': platform,
    'status': status,
    'track_sim': trackSim,
  };
}

class CrmStaff {
  final int id;
  final String name;

  CrmStaff({required this.id, required this.name});

  factory CrmStaff.fromJson(Map<String, dynamic> json) {
    return CrmStaff(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Sales Representative',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class OutcomeOptionModel {
  final String key;
  final String label;
  final String tone;
  final bool followUp;
  final int leadStatus;
  final bool fixed;

  OutcomeOptionModel({
    required this.key,
    required this.label,
    required this.tone,
    required this.followUp,
    required this.leadStatus,
    required this.fixed,
  });

  factory OutcomeOptionModel.fromJson(Map<String, dynamic> json) {
    return OutcomeOptionModel(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      tone: json['tone']?.toString() ?? 'slate',
      followUp: json['follow_up'] == true,
      leadStatus: (json['lead_status'] as num?)?.toInt() ?? 0,
      fixed: json['fixed'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'tone': tone,
    'follow_up': followUp,
    'lead_status': leadStatus,
    'fixed': fixed,
  };
}

class LeadStatusModel {
  final int id;
  final String name;
  final String color;

  LeadStatusModel({required this.id, required this.name, required this.color});

  factory LeadStatusModel.fromJson(Map<String, dynamic> json) {
    return LeadStatusModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      color: json['color']?.toString() ?? '#28B8DA',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};
}

class SalesTrackConfig {
  final bool trackingCalls;
  final bool trackingRecordings;
  final bool trackingWhatsappCalls;
  final bool trackingSms;
  final bool paused;
  final String excludedSalt;
  final List<String> excludedHashes;
  final int matchDigits;
  final String countryCode;
  final int trackSim;
  final String smsText; // 'all', 'crm', 'none'
  final int syncMinutes;
  final int historyDays;
  final int batchSize;
  final bool recordingsWifiOnly;
  final int recordingsMaxMb;
  final List<String> recordingsFormats;
  final String appMinVersion;
  final bool appLockEnabled;
  final String appLockAlgorithm;
  final int appLockIterations;
  final String appLockSalt;
  final String appLockHash;
  final String outcomesAsk; // 'connected', 'connected_only', 'all'
  final bool outcomesMandatory;
  final bool outcomesNoteRequired;
  final bool outcomesCreateLead;
  final List<OutcomeOptionModel> outcomesList;
  final List<LeadStatusModel> leadStatuses;
  final String version;

  SalesTrackConfig({
    required this.trackingCalls,
    required this.trackingRecordings,
    required this.trackingWhatsappCalls,
    required this.trackingSms,
    required this.paused,
    required this.excludedSalt,
    required this.excludedHashes,
    required this.matchDigits,
    required this.countryCode,
    required this.trackSim,
    required this.smsText,
    required this.syncMinutes,
    required this.historyDays,
    required this.batchSize,
    required this.recordingsWifiOnly,
    required this.recordingsMaxMb,
    required this.recordingsFormats,
    required this.appMinVersion,
    required this.appLockEnabled,
    required this.appLockAlgorithm,
    required this.appLockIterations,
    required this.appLockSalt,
    required this.appLockHash,
    required this.outcomesAsk,
    required this.outcomesMandatory,
    required this.outcomesNoteRequired,
    required this.outcomesCreateLead,
    required this.outcomesList,
    required this.leadStatuses,
    required this.version,
  });

  factory SalesTrackConfig.defaultConfig() {
    return SalesTrackConfig(
      trackingCalls: true,
      trackingRecordings: true,
      trackingWhatsappCalls: true,
      trackingSms: true,
      paused: false,
      excludedSalt: '',
      excludedHashes: [],
      matchDigits: 10,
      countryCode: '91',
      trackSim: 0,
      smsText: 'all',
      syncMinutes: 15,
      historyDays: 7,
      batchSize: 200,
      recordingsWifiOnly: false,
      recordingsMaxMb: 25,
      recordingsFormats: ['m4a', 'mp3', 'aac', 'wav', 'amr'],
      appMinVersion: '1.0.0',
      appLockEnabled: false,
      appLockAlgorithm: 'pbkdf2-sha256',
      appLockIterations: 100000,
      appLockSalt: '',
      appLockHash: '',
      outcomesAsk: 'connected',
      outcomesMandatory: false,
      outcomesNoteRequired: false,
      outcomesCreateLead: true,
      outcomesList: [
        OutcomeOptionModel(key: 'interested', label: 'Interested', tone: 'green', followUp: true, leadStatus: 0, fixed: false),
        OutcomeOptionModel(key: 'callback', label: 'Call Back Later', tone: 'amber', followUp: true, leadStatus: 0, fixed: false),
        OutcomeOptionModel(key: 'converted', label: 'Converted', tone: 'violet', followUp: false, leadStatus: 0, fixed: true),
        OutcomeOptionModel(key: 'not_interested', label: 'Not Interested', tone: 'rose', followUp: false, leadStatus: 0, fixed: false),
      ],
      leadStatuses: [],
      version: '1.0.0',
    );
  }

  factory SalesTrackConfig.fromJson(Map<String, dynamic> json) {
    final tracking = json['tracking'] as Map<String, dynamic>? ?? {};
    final excluded = json['excluded'] as Map<String, dynamic>? ?? {};
    final rec = json['recordings'] as Map<String, dynamic>? ?? {};
    final app = json['app'] as Map<String, dynamic>? ?? {};
    final lock = json['app_lock'] as Map<String, dynamic>? ?? {};
    final outcomes = json['outcomes'] as Map<String, dynamic>? ?? {};

    final outcomesList = <OutcomeOptionModel>[];
    if (outcomes['list'] is List) {
      for (final item in outcomes['list'] as List) {
        if (item is Map<String, dynamic>) {
          outcomesList.add(OutcomeOptionModel.fromJson(item));
        }
      }
    }

    final leadStatuses = <LeadStatusModel>[];
    if (outcomes['lead_statuses'] is List) {
      for (final item in outcomes['lead_statuses'] as List) {
        if (item is Map<String, dynamic>) {
          leadStatuses.add(LeadStatusModel.fromJson(item));
        }
      }
    }

    final formats = <String>[];
    if (rec['formats'] is List) {
      for (final f in rec['formats'] as List) {
        formats.add(f.toString());
      }
    }

    final excludedList = <String>[];
    if (excluded['hashes'] is List) {
      for (final h in excluded['hashes'] as List) {
        excludedList.add(h.toString());
      }
    }

    return SalesTrackConfig(
      trackingCalls: tracking['calls'] != false,
      trackingRecordings: tracking['recordings'] != false,
      trackingWhatsappCalls: tracking['whatsapp_calls'] != false,
      trackingSms: tracking['sms'] != false,
      paused: json['paused'] == true,
      excludedSalt: excluded['salt']?.toString() ?? '',
      excludedHashes: excludedList,
      matchDigits: (json['match_digits'] as num?)?.toInt() ?? 10,
      countryCode: json['country_code']?.toString() ?? '91',
      trackSim: (json['track_sim'] as num?)?.toInt() ?? 0,
      smsText: json['sms_text']?.toString() ?? 'all',
      syncMinutes: (json['sync_minutes'] as num?)?.toInt() ?? 15,
      historyDays: (json['history_days'] as num?)?.toInt() ?? 7,
      batchSize: (json['batch_size'] as num?)?.toInt() ?? 200,
      recordingsWifiOnly: rec['wifi_only'] == true,
      recordingsMaxMb: (rec['max_mb'] as num?)?.toInt() ?? 25,
      recordingsFormats: formats.isNotEmpty ? formats : ['m4a', 'mp3', 'aac', 'wav', 'amr'],
      appMinVersion: app['min_version']?.toString() ?? '1.0.0',
      appLockEnabled: lock['enabled'] == true,
      appLockAlgorithm: lock['algorithm']?.toString() ?? 'pbkdf2-sha256',
      appLockIterations: (lock['iterations'] as num?)?.toInt() ?? 100000,
      appLockSalt: lock['salt']?.toString() ?? '',
      appLockHash: lock['hash']?.toString() ?? '',
      outcomesAsk: outcomes['ask']?.toString() ?? 'connected',
      outcomesMandatory: outcomes['mandatory'] == true,
      outcomesNoteRequired: outcomes['note_required'] == true,
      outcomesCreateLead: outcomes['create_lead'] != false,
      outcomesList: outcomesList.isNotEmpty ? outcomesList : SalesTrackConfig.defaultConfig().outcomesList,
      leadStatuses: leadStatuses,
      version: json['version']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'tracking': {
      'calls': trackingCalls,
      'recordings': trackingRecordings,
      'whatsapp_calls': trackingWhatsappCalls,
      'sms': trackingSms,
    },
    'paused': paused,
    'excluded': {
      'salt': excludedSalt,
      'hashes': excludedHashes,
    },
    'match_digits': matchDigits,
    'country_code': countryCode,
    'track_sim': trackSim,
    'sms_text': smsText,
    'sync_minutes': syncMinutes,
    'history_days': historyDays,
    'batch_size': batchSize,
    'recordings': {
      'wifi_only': recordingsWifiOnly,
      'max_mb': recordingsMaxMb,
      'formats': recordingsFormats,
    },
    'app': {
      'min_version': appMinVersion,
    },
    'app_lock': {
      'enabled': appLockEnabled,
      'algorithm': appLockAlgorithm,
      'iterations': appLockIterations,
      'salt': appLockSalt,
      'hash': appLockHash,
    },
    'outcomes': {
      'ask': outcomesAsk,
      'mandatory': outcomesMandatory,
      'note_required': outcomesNoteRequired,
      'create_lead': outcomesCreateLead,
      'list': outcomesList.map((o) => o.toJson()).toList(),
      'lead_statuses': leadStatuses.map((l) => l.toJson()).toList(),
    },
    'version': version,
  };

  bool isNumberExcluded(String number) {
    if (excludedHashes.isEmpty || excludedSalt.isEmpty) return false;
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.length < matchDigits) return false;
    final tail = digits.substring(digits.length - matchDigits);
    final hash = sha256.convert(utf8.encode(excludedSalt + tail)).toString().toLowerCase();
    return excludedHashes.contains(hash);
  }
}

class SalesTrackEvent {
  String uid;
  final String kind; // 'call', 'whatsapp_call', 'sms'
  final int time; // epoch ms
  final String direction; // 'incoming', 'outgoing', 'missed', 'rejected', 'blocked', 'voicemail', 'unknown'
  final String number;
  String name;
  final int sim;
  int duration; // seconds
  bool recording;
  final String? media; // 'voice', 'video'
  final String? app; // 'com.whatsapp', 'com.whatsapp.w4b'
  String? text;
  final String source; // 'auto', 'app', 'manual'
  String? recordingPath;
  String syncStatus; // 'pending', 'synced', 'failed'
  String recordingSyncStatus; // 'none', 'pending', 'synced', 'failed'

  SalesTrackEvent({
    required this.uid,
    required this.kind,
    required this.time,
    required this.direction,
    required this.number,
    required this.name,
    this.sim = 1,
    this.duration = 0,
    this.recording = false,
    this.media,
    this.app,
    this.text,
    this.source = 'auto',
    this.recordingPath,
    this.syncStatus = 'pending',
    this.recordingSyncStatus = 'none',
  });

  factory SalesTrackEvent.fromJson(Map<String, dynamic> json) {
    return SalesTrackEvent(
      uid: json['uid']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'call',
      time: (json['time'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      direction: json['direction']?.toString() ?? 'incoming',
      number: json['number']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sim: (json['sim'] as num?)?.toInt() ?? 1,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      recording: json['recording'] == true,
      media: json['media']?.toString(),
      app: json['app']?.toString(),
      text: json['text']?.toString(),
      source: json['source']?.toString() ?? 'auto',
      recordingPath: json['recordingPath']?.toString(),
      syncStatus: json['syncStatus']?.toString() ?? 'pending',
      recordingSyncStatus: json['recordingSyncStatus']?.toString() ?? 'none',
    );
  }

  Map<String, dynamic> toApiJson() {
    final map = <String, dynamic>{
      'uid': uid,
      'kind': kind,
      'time': time,
      'direction': direction,
      'number': number,
      'name': name,
      'sim': sim,
      'source': source,
    };

    if (kind == 'call') {
      map['duration'] = duration;
      if (recording) map['recording'] = true;
    } else if (kind == 'whatsapp_call') {
      map['duration'] = duration;
      map['media'] = media ?? 'voice';
      map['app'] = app ?? 'com.whatsapp';
    } else if (kind == 'sms' || kind == 'whatsapp_message' || kind == 'notification') {
      map['text'] = text ?? '';
      if (app != null && app!.isNotEmpty) {
        map['app'] = app;
      }
    }

    return map;
  }

  Map<String, dynamic> toStorageJson() {
    final map = toApiJson();
    map['recordingPath'] = recordingPath;
    map['syncStatus'] = syncStatus;
    map['recordingSyncStatus'] = recordingSyncStatus;
    return map;
  }
}

class OutcomeSubmission {
  final String uid;
  final String outcome;
  final String? note;
  final int? followUpAt; // epoch ms
  final int? leadStatus;
  final Map<String, dynamic>? createLead;

  OutcomeSubmission({
    required this.uid,
    required this.outcome,
    this.note,
    this.followUpAt,
    this.leadStatus,
    this.createLead,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'uid': uid,
      'outcome': outcome,
    };
    if (note != null && note!.isNotEmpty) map['note'] = note;
    if (followUpAt != null && followUpAt! > 0) map['follow_up_at'] = followUpAt;
    if (leadStatus != null && leadStatus! > 0) map['lead_status'] = leadStatus;
    if (createLead != null && createLead!.isNotEmpty) map['create_lead'] = createLead;
    return map;
  }
}

class CallListItem {
  final int leadId;
  final String name;
  final String company;
  final String number;
  final String status;
  final String state; // 'pending', 'tried', 'reached', 'skipped'
  final bool doNotCall;

  CallListItem({
    required this.leadId,
    required this.name,
    required this.company,
    required this.number,
    required this.status,
    required this.state,
    required this.doNotCall,
  });

  factory CallListItem.fromJson(Map<String, dynamic> json) {
    return CallListItem(
      leadId: (json['lead_id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      company: json['company']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      state: json['state']?.toString() ?? 'pending',
      doNotCall: json['do_not_call'] == true,
    );
  }
}

class CallListModel {
  final int id;
  final String name;
  final String due;
  final List<CallListItem> items;

  CallListModel({
    required this.id,
    required this.name,
    required this.due,
    required this.items,
  });

  factory CallListModel.fromJson(Map<String, dynamic> json) {
    final itemsList = <CallListItem>[];
    if (json['items'] is List) {
      for (final i in json['items'] as List) {
        if (i is Map<String, dynamic>) {
          itemsList.add(CallListItem.fromJson(i));
        }
      }
    }
    return CallListModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Call List',
      due: json['due']?.toString() ?? '',
      items: itemsList,
    );
  }
}
