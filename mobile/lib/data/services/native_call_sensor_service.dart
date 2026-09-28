import 'dart:async';
import 'package:flutter/services.dart';

/// Represents a native phone call state event received from the Android layer.
enum NativeCallState { ringing, connected, disconnected, recordingReady }

class NativeCallEvent {
  final NativeCallState state;
  final String phoneNumber;
  final String? callId;
  final int durationSeconds;
  final String? recordingPath;

  const NativeCallEvent({
    required this.state,
    required this.phoneNumber,
    this.callId,
    this.durationSeconds = 0,
    this.recordingPath,
  });
}

/// Represents a local audio file stored on the device
class LocalRecordingFile {
  final String fileName;
  final String filePath;
  final int sizeBytes;
  final DateTime lastModified;

  const LocalRecordingFile({
    required this.fileName,
    required this.filePath,
    required this.sizeBytes,
    required this.lastModified,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory LocalRecordingFile.fromMap(Map<dynamic, dynamic> map) {
    return LocalRecordingFile(
      fileName: map['fileName']?.toString() ?? 'audio_recording.m4a',
      filePath: map['filePath']?.toString() ?? '',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      lastModified: map['lastModified'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['lastModified'] as num).toInt())
          : DateTime.now(),
    );
  }
}

/// Represents a call that was recorded while the app was backgrounded.
/// Retrieved from Android SharedPreferences via the pending_call MethodChannel.
class PendingNativeCall {
  final String callId;
  final String phoneNumber;
  final int durationSeconds;
  final String? recordingPath;
  final DateTime timestamp;

  const PendingNativeCall({
    required this.callId,
    required this.phoneNumber,
    required this.durationSeconds,
    this.recordingPath,
    required this.timestamp,
  });

  factory PendingNativeCall.fromMap(Map<dynamic, dynamic> map) {
    return PendingNativeCall(
      callId:          map['callId']?.toString() ?? '',
      phoneNumber:     map['phoneNumber']?.toString() ?? '',
      durationSeconds: (map['duration'] as int?) ?? 0,
      recordingPath:   map['recordingPath']?.toString(),
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Bridges the Android [PhoneStateReceiver] + [CallRecordingService] into Dart.
///
/// Two channels:
///  1. EventChannel  `com.ringvia360/call_sensor`    -> live call state stream
///  2. MethodChannel `com.ringvia360/pending_call`   -> read background-recorded call & scan recordings
class NativeCallSensorService {
  static const _eventChannel  = EventChannel('com.ringvia360/call_sensor');
  static const _methodChannel = MethodChannel('com.ringvia360/pending_call');

  StreamSubscription<dynamic>? _sub;
  final _controller = StreamController<NativeCallEvent>.broadcast();

  Stream<NativeCallEvent> get callEvents => _controller.stream;

  NativeCallSensorService() {
    _sub = _eventChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        if (data is! Map) return;
        final rawState = data['state'] as String? ?? '';
        final number   = data['phoneNumber'] as String? ?? '';
        final callId   = data['callId'] as String?;
        final duration = (data['duration'] as num?)?.toInt() ?? 0;
        final recPath  = data['recordingPath'] as String?;

        final state = switch (rawState) {
          'ringing'         => NativeCallState.ringing,
          'connected'       => NativeCallState.connected,
          'disconnected'    => NativeCallState.disconnected,
          'recording_ready' => NativeCallState.recordingReady,
          _                 => null,
        };

        if (state != null) {
          _controller.add(NativeCallEvent(
            state: state,
            phoneNumber: number,
            callId: callId,
            durationSeconds: duration,
            recordingPath: recPath,
          ));
        }
      },
      onError: (_) {/* absorb channel errors on non-Android platforms */},
    );
  }

  /// Call this when the Flutter app resumes from background.
  Future<PendingNativeCall?> checkPendingCall() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getPendingCall',
      );
      if (result != null && result['callId'] != null) {
        return PendingNativeCall.fromMap(result);
      }
    } catch (_) {}
    return null;
  }

  /// Retrieves list of all local call audio files saved on device storage
  Future<List<LocalRecordingFile>> getLocalRecordings() async {
    try {
      final result = await _methodChannel.invokeListMethod<dynamic>('getLocalRecordings');
      if (result != null) {
        return result
            .whereType<Map<dynamic, dynamic>>()
            .map((m) => LocalRecordingFile.fromMap(m))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Opens Android system audio picker to select any call recording from device storage
  Future<LocalRecordingFile?> pickAudioFile() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('pickAudioFile');
      if (result != null && result['filePath'] != null) {
        return LocalRecordingFile.fromMap(result);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> hasOverlayPermission() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('hasOverlayPermission');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> requestOverlayPermission() async {
    try {
      await _methodChannel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
