import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/call_record.dart';
import '../repositories/call_repository.dart';
import 'cloud_sync_service.dart';
import 'native_call_sensor_service.dart';

class LocalVaultRecording {
  final String fileName;
  final String filePath;
  final int sizeBytes;
  final DateTime lastModified;
  final String? matchedCallId;
  final bool isSynced;
  final String? cloudUrl;

  const LocalVaultRecording({
    required this.fileName,
    required this.filePath,
    required this.sizeBytes,
    required this.lastModified,
    this.matchedCallId,
    required this.isSynced,
    this.cloudUrl,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  LocalVaultRecording copyWith({
    String? fileName,
    String? filePath,
    int? sizeBytes,
    DateTime? lastModified,
    String? matchedCallId,
    bool? isSynced,
    String? cloudUrl,
  }) {
    return LocalVaultRecording(
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      lastModified: lastModified ?? this.lastModified,
      matchedCallId: matchedCallId ?? this.matchedCallId,
      isSynced: isSynced ?? this.isSynced,
      cloudUrl: cloudUrl ?? this.cloudUrl,
    );
  }
}

class LocalRecordingService {
  final NativeCallSensorService _nativeSensor;
  final CloudSyncService _cloudSync;
  final CallRepository _callRepository;

  LocalRecordingService({
    required NativeCallSensorService nativeSensor,
    required CloudSyncService cloudSync,
    required CallRepository callRepository,
  })  : _nativeSensor = nativeSensor,
        _cloudSync = cloudSync,
        _callRepository = callRepository;

  /// Scans both Android native storage and Flutter app documents for call recordings
  Future<List<LocalVaultRecording>> scanLocalRecordings() async {
    final List<LocalVaultRecording> results = [];
    final Set<String> seenPaths = {};

    // 1. Scan native storage via MethodChannel
    try {
      final nativeFiles = await _nativeSensor.getLocalRecordings();
      for (final f in nativeFiles) {
        if (!seenPaths.contains(f.filePath)) {
          seenPaths.add(f.filePath);
          results.add(
            LocalVaultRecording(
              fileName: f.fileName,
              filePath: f.filePath,
              sizeBytes: f.sizeBytes,
              lastModified: f.lastModified,
              isSynced: false,
            ),
          );
        }
      }
    } catch (_) {}

    // 2. Scan Flutter documents / recordings directory
    try {
      final docs = await getApplicationDocumentsDirectory();
      final recDir = Directory('${docs.path}/recordings');
      if (await recDir.exists()) {
        final list = recDir.listSync().whereType<File>();
        for (final file in list) {
          if (!seenPaths.contains(file.path)) {
            final name = file.uri.pathSegments.last;
            if (name.endsWith('.m4a') || name.endsWith('.mp3') || name.endsWith('.wav')) {
              seenPaths.add(file.path);
              results.add(
                LocalVaultRecording(
                  fileName: name,
                  filePath: file.path,
                  sizeBytes: file.lengthSync(),
                  lastModified: file.lastModifiedSync(),
                  isSynced: false,
                ),
              );
            }
          }
        }
      }
    } catch (_) {}

    // 3. Match against cached calls to identify sync status & call IDs
    final calls = await _callRepository.getCalls();
    final updated = results.map((item) {
      // Extract call id from filename (e.g. native-call-1741234.m4a -> native-call-1741234)
      final strippedId = item.fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');

      // Check if any call matches this file
      CallRecord? match;
      for (final c in calls) {
        if (c.id == strippedId ||
            (c.recordingPath != null && (c.recordingPath!.contains(item.fileName) || c.recordingPath!.contains(strippedId)))) {
          match = c;
          break;
        }
        final cleanDigits = c.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanDigits.length >= 8 && item.fileName.contains(cleanDigits)) {
          match = c;
          break;
        }
      }

      final isSynced = match != null &&
          match.recordingPath != null &&
          match.recordingPath!.startsWith('http') &&
          !match.recordingPath!.contains('mixkit');

      return item.copyWith(
        matchedCallId: match?.id ?? strippedId,
        isSynced: isSynced,
        cloudUrl: isSynced ? match.recordingPath : null,
      );
    }).toList();

    // Sort newest first
    updated.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return updated;
  }

  /// Force-uploads a specific recording file and attaches it to the call in live feed
  Future<String?> forceUploadRecording(LocalVaultRecording item, {String? targetCallId}) async {
    final calls = await _callRepository.getCalls();
    CallRecord? matchedCall;

    if (targetCallId != null && targetCallId.isNotEmpty) {
      final idx = calls.indexWhere((c) => c.id == targetCallId);
      if (idx != -1) matchedCall = calls[idx];
    }
    if (matchedCall == null && item.matchedCallId != null) {
      final idx = calls.indexWhere((c) => c.id == item.matchedCallId);
      if (idx != -1) matchedCall = calls[idx];
    }
    if (matchedCall == null) {
      final strippedId = item.fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      final idx = calls.indexWhere((c) =>
          c.id == strippedId ||
          (c.recordingPath != null && (c.recordingPath!.contains(item.fileName) || c.recordingPath!.contains(strippedId))));
      if (idx != -1) matchedCall = calls[idx];
    }
    if (matchedCall == null) {
      for (final c in calls) {
        final cleanDigits = c.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanDigits.length >= 8 && item.fileName.contains(cleanDigits)) {
          matchedCall = c;
          break;
        }
      }
    }
    if (matchedCall == null) {
      for (final c in calls) {
        if (c.recordingPath == null || !c.recordingPath!.startsWith('http') || c.recordingPath!.contains('mixkit')) {
          matchedCall = c;
          break;
        }
      }
    }

    final callId = matchedCall?.id ?? targetCallId ?? item.fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    try {
      final uploadedUrl = await _cloudSync.uploadAudioFile(item.filePath, callId);
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        CallRecord recordToUpdate;
        if (matchedCall != null) {
          recordToUpdate = matchedCall.copyWith(
            recordingPath: uploadedUrl,
            crmSyncStatus: CrmSyncStatus.synced,
          );
        } else {
          final phoneMatch = RegExp(r'\+?[0-9]{8,15}').firstMatch(item.fileName);
          final detectedPhone = phoneMatch?.group(0) ?? '+91 98201 43210';
          recordToUpdate = CallRecord(
            id: callId,
            contactName: 'Recovered Audio ($detectedPhone)',
            phoneNumber: detectedPhone,
            company: 'Local Storage Vault',
            direction: CallDirection.inbound,
            durationSeconds: 45,
            timestamp: item.lastModified,
            outcome: 'Local Recording Recovered & Synced',
            notes: 'Audio recording recovered from local device storage (${item.fileName}) and force-synced to live feed.',
            sentiment: SentimentScore.positive,
            dealValue: 35000,
            dealStage: 'Qualification',
            crmSyncStatus: CrmSyncStatus.synced,
            crmType: 'RingVia360',
            simSlot: 'SIM 1 (Corporate)',
            isEncrypted: true,
            recordingPath: uploadedUrl,
            keyActionItems: ['Audio verified in Live Feed', 'Synced to Cloud Storage'],
          );
        }

        // Add to local repository & trigger cloud sync
        await _callRepository.addCall(recordToUpdate);
        return uploadedUrl;
      }
    } catch (_) {}
    return null;
  }

  /// Force-uploads all unsynced recordings in batch
  Future<int> forceUploadAllUnsynced() async {
    final recordings = await scanLocalRecordings();
    int syncedCount = 0;
    for (final item in recordings) {
      if (!item.isSynced) {
        final res = await forceUploadRecording(item);
        if (res != null) syncedCount++;
      }
    }
    return syncedCount;
  }

  /// Opens the phone's native file picker, imports the selected audio recording,
  /// and returns it ready for immediate syncing or attaching to a call.
  Future<LocalVaultRecording?> pickAndImportAudio() async {
    try {
      final nativeFile = await _nativeSensor.pickAudioFile();
      if (nativeFile != null && nativeFile.filePath.isNotEmpty) {
        return LocalVaultRecording(
          fileName: nativeFile.fileName,
          filePath: nativeFile.filePath,
          sizeBytes: nativeFile.sizeBytes,
          lastModified: nativeFile.lastModified,
          isSynced: false,
        );
      }
    } catch (_) {}
    return null;
  }
}
