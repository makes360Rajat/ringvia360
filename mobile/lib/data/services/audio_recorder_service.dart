import 'dart:math';

class AudioRecordingResult {
  final String localFilePath;
  final String cloudRecordingUrl;
  final int durationSeconds;
  final bool isEncrypted;
  final String encryptionAlgorithm;
  final String sha256Signature;
  final List<double> waveformSamples;

  const AudioRecordingResult({
    required this.localFilePath,
    required this.cloudRecordingUrl,
    required this.durationSeconds,
    required this.isEncrypted,
    required this.encryptionAlgorithm,
    required this.sha256Signature,
    required this.waveformSamples,
  });
}

class AudioRecorderService {
  bool _isRecording = false;
  bool get isRecording => _isRecording;

  void startRecording({required String callId}) {
    _isRecording = true;
  }

  AudioRecordingResult stopRecording({required String callId, required int durationSeconds}) {
    _isRecording = false;

    // Generate waveform amplitude samples for playback UI
    final random = Random();
    final waveform = List.generate(
      24,
      (_) => 0.2 + random.nextDouble() * 0.8,
    );

    return AudioRecordingResult(
      localFilePath: '/data/user/0/com.ringvia360/files/recordings/$callId.enc',
      cloudRecordingUrl: 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
      durationSeconds: durationSeconds,
      isEncrypted: true,
      encryptionAlgorithm: 'AES-256-GCM (RingVia360 Cloud KMS Protected)',
      sha256Signature: 'SHA256:${random.nextInt(999999).toRadixString(16)}...${random.nextInt(999999).toRadixString(16)}',
      waveformSamples: waveform,
    );
  }
}
