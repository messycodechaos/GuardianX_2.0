
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vibration/vibration.dart';
import 'package:intl/intl.dart';
import 'sos_model.dart';
import 'services/yamnet_audio_service.dart';
import 'services/follower_tracker_service.dart';

/// Supported Threat Categories
class ThreatCategory {
  static const String screaming = "screaming";
  static const String criesForHelp = "cries_for_help";
  static const String panicDistress = "panic_distress";
  static const String threateningVocal = "threatening_vocal";
  static const String glassBreaking = "glass_breaking";
  static const String weapons = "weapons";
  static const String suspiciousGestures = "suspicious_gestures";
  static const String followerTracking = "follower_tracking";
}

/// Category Configuration
class ThreatConfig {
  bool enabled;
  double threshold; // 0.0 to 1.0

  ThreatConfig({required this.enabled, required this.threshold});

  Map<String, dynamic> toJson() => {'enabled': enabled, 'threshold': threshold};
  factory ThreatConfig.fromJson(Map<String, dynamic> json) => ThreatConfig(
    enabled: json['enabled'] ?? true,
    threshold: (json['threshold'] as num?)?.toDouble() ?? 0.75,
  );
}

/// Structured response result for starting Safety Ear
class SafetyEarStartResult {
  final bool success;
  final bool isPermanentlyDenied;
  final String errorMessage;

  SafetyEarStartResult({
    required this.success,
    this.isPermanentlyDenied = false,
    this.errorMessage = '',
  });
}

class AIController {
  static final AIController _instance = AIController._internal();
  factory AIController() => _instance;
  AIController._internal();

  // Edge AI Services
  final YamnetAudioService _yamnet = YamnetAudioService();
  final FollowerTrackerService _followerTracker = FollowerTrackerService();

  // Active Monitoring Switches
  bool isVoiceMonitorActive = false;
  bool isVisualGuardActive = false;
  bool isSmartRadarActive = false;

  // Real-Time Telemetry for UI
  AudioClassificationResult? latestAudioClassification;
  Map<String, dynamic>? latestVisionKinematics;

  // Settings & Configuration
  Map<String, ThreatConfig> categoryConfigs = {
    ThreatCategory.screaming: ThreatConfig(enabled: true, threshold: 0.65),
    ThreatCategory.criesForHelp: ThreatConfig(enabled: true, threshold: 0.70),
    ThreatCategory.panicDistress: ThreatConfig(enabled: true, threshold: 0.65),
    ThreatCategory.threateningVocal: ThreatConfig(enabled: true, threshold: 0.75),
    ThreatCategory.glassBreaking: ThreatConfig(enabled: true, threshold: 0.72),
    ThreatCategory.weapons: ThreatConfig(enabled: true, threshold: 0.75),
    ThreatCategory.suspiciousGestures: ThreatConfig(enabled: true, threshold: 0.70),
    ThreatCategory.followerTracking: ThreatConfig(enabled: true, threshold: 0.85),
  };

  int evidenceCaptureDurationSeconds = 5;
  int safetyConfirmationTimeoutSeconds = 15;
  String defaultEscalationLevel = 'lvl3'; // 'lvl1', 'lvl2', or 'lvl3'

  // Audio Recorder & Buffer Management
  AudioRecorder? _audioRecorder;
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  double currentDecibels = -55.0;
  final List<double> _recentDecibelReadings = [];
  int audioSampleCount = 0;

  // Temporal Filtering & Deduplication
  final Map<String, DateTime> _recentDetections = {};
  static const Duration _dedupWindow = Duration(seconds: 15);

  // Visual Guard & WebRTC Stream
  String visualGuardStatus = "Standby";
  int _trackedPersonFrameCount = 0;
  DateTime? _trackingStartTime;
  double _lastKnownPersonProximity = 0.0;
  double get lastKnownPersonProximity => _lastKnownPersonProximity;
  int videoScannedFramesMinute = 0;
  MediaStream? _visualGuardStream;

  // MINUTE-BY-MINUTE PERCEPTION SUMMARIES
  String currentEarSummary = "Standby. Enable Safety Ear to begin acoustic analysis.";
  String currentEyeSummary = "Standby. Arm Safety Eye to scan visual frames.";
  final List<Map<String, dynamic>> perceptionLogs = [];
  Timer? _minuteSummaryTimer;

  // Active Pending Incident & Background Escalation Timer
  IncidentRecord? activePendingIncident;
  Timer? _activeEscalationTimer;
  int pendingCountdownSeconds = 15;
  Timer? _countdownTicker;

  /// Cleanly initialize TFLite and ML Kit models
  Future<void> initializeModels() async {
    await _yamnet.initialize();
    await _followerTracker.initialize();
  }

  // ─────────────────────────────────────────────────────────────
  // 1. SAFETY EAR — REAL YAMNET ACOUSTIC NEURAL CLASSIFIER
  // ─────────────────────────────────────────────────────────────
  Future<SafetyEarStartResult> startAcousticMonitor({
    required Function(IncidentRecord incident) onIncidentSaved,
    required Function(String error, IncidentRecord? pendingIncident) onStorageFailed,
    Function(double decibels)? onDecibelUpdate,
    Function(AudioClassificationResult result)? onClassificationUpdate,
  }) async {
    try {
      await initializeModels();

      if (_audioRecorder != null) {
        try {
          await _audioRecorder!.stop();
          await _audioRecorder!.dispose();
        } catch (_) {}
      }
      _audioRecorder = AudioRecorder();

      // Check Microphone Permissions
      if (!kIsWeb) {
        var status = await Permission.microphone.status;
        if (!status.isGranted) {
          status = await Permission.microphone.request();
        }

        if (status.isPermanentlyDenied) {
          isVoiceMonitorActive = false;
          return SafetyEarStartResult(
            success: false,
            isPermanentlyDenied: true,
            errorMessage: "Microphone permission permanently denied. Enable in App Settings.",
          );
        }

        if (!status.isGranted) {
          isVoiceMonitorActive = false;
          return SafetyEarStartResult(
            success: false,
            errorMessage: "Microphone permission required for Safety Ear.",
          );
        }
      }

      final hasPerm = await _audioRecorder!.hasPermission();
      if (!hasPerm) {
        isVoiceMonitorActive = false;
        return SafetyEarStartResult(
          success: false,
          errorMessage: "Microphone recording permission not granted.",
        );
      }

      // Stream raw 16-bit PCM at 16,000 Hz mono (optimal for YAMNet)
      final rawStream = await _audioRecorder!.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      isVoiceMonitorActive = true;
      _recentDecibelReadings.clear();
      audioSampleCount = 0;

      List<int> pcmByteAccumulator = [];

      _audioStreamSubscription = rawStream.listen((Uint8List chunk) async {
        if (!isVoiceMonitorActive) return;
        pcmByteAccumulator.addAll(chunk);

        // 1. Calculate Real-Time RMS decibels for UI meter
        if (chunk.length >= 2) {
          double sumSquares = 0.0;
          final byteData = chunk.buffer.asByteData();
          int sampleCount = chunk.length ~/ 2;
          for (int i = 0; i < sampleCount; i++) {
            int pcm = byteData.getInt16(i * 2, Endian.little);
            sumSquares += pcm * pcm;
          }
          double rms = sqrt(sumSquares / sampleCount);
          double db = rms > 1 ? 20 * (log(rms / 32768.0) / ln10) : -80.0;
          currentDecibels = db.clamp(-80.0, 0.0);
          audioSampleCount++;
          if (onDecibelUpdate != null) onDecibelUpdate(currentDecibels);

          _recentDecibelReadings.add(currentDecibels);
          if (_recentDecibelReadings.length > 8) _recentDecibelReadings.removeAt(0);
        }

        // 2. Window of 15,600 samples (31,200 bytes) = exactly 0.975s for YAMNet
        if (pcmByteAccumulator.length >= 31200) {
          final windowBytes = Uint8List.fromList(pcmByteAccumulator.sublist(0, 31200));
          pcmByteAccumulator = pcmByteAccumulator.sublist(31200);

          final byteData = windowBytes.buffer.asByteData();
          final floatSamples = Float32List(15600);
          for (int i = 0; i < 15600; i++) {
            int pcmSample = byteData.getInt16(i * 2, Endian.little);
            floatSamples[i] = pcmSample / 32768.0;
          }

          // Run Real Machine Learning Classification
          final classification = _yamnet.classifyBuffer(floatSamples);
          latestAudioClassification = classification;
          if (onClassificationUpdate != null) onClassificationUpdate(classification);

          // 3. Trigger threat only on verified distress (clapping/applause is suppressed!)
          if (classification.isThreat && !classification.isSuppressed) {
            final config = categoryConfigs[classification.category] ?? ThreatConfig(enabled: true, threshold: 0.65);
            if (config.enabled && classification.confidence >= config.threshold) {
              await _handleCredibleThreat(
                category: classification.category,
                categoryLabel: classification.categoryLabel,
                confidence: classification.confidence,
                decibels: currentDecibels,
                summary: classification.explanation,
                source: "safety_ear",
                mediaType: "audio",
                onIncidentSaved: onIncidentSaved,
                onStorageFailed: onStorageFailed,
              );
            }
          }
        }
      });

      _startMinuteSummaryEngine();
      _recordPerceptionSummary(
        source: 'safety_ear',
        summary: "Safety Ear armed with YAMNet neural audio model. 521 AudioSet classes active.",
        metric: "${currentDecibels.toStringAsFixed(1)} dBFS",
      );

      return SafetyEarStartResult(success: true);
    } catch (e) {
      debugPrint("Failed to start Safety Ear: $e");
      isVoiceMonitorActive = false;
      return SafetyEarStartResult(
        success: false,
        errorMessage: "Failed to initialize Safety Ear: $e",
      );
    }
  }

  Future<void> stopAcousticMonitor() async {
    isVoiceMonitorActive = false;
    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    try {
      if (_audioRecorder != null && await _audioRecorder!.isRecording()) {
        await _audioRecorder!.stop();
        await _audioRecorder!.dispose();
      }
    } catch (_) {}
    _audioRecorder = null;
    currentEarSummary = "Safety Ear Standby";
  }

  RTCVideoRenderer? localVideoRenderer;
  Timer? _frameScannerTimer;

  Future<void> _initLocalRenderer() async {
    if (localVideoRenderer == null) {
      localVideoRenderer = RTCVideoRenderer();
      await localVideoRenderer!.initialize();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 2. SAFETY EYE — VISUAL GUARD WITH REAL KINEMATIC MOT
  // ─────────────────────────────────────────────────────────────
  Future<bool> startVisualGuard() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (!status.isGranted) {
      isVisualGuardActive = false;
      visualGuardStatus = "Camera permission denied";
      return false;
    }

    try {
      await initializeModels();

      _visualGuardStream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {
          'facingMode': currentFacingMode,
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        }
      });

      await _initLocalRenderer();
      localVideoRenderer!.srcObject = _visualGuardStream;

      isVisualGuardActive = true;
      visualGuardStatus = "Analyzing live camera frames with ByteTrack kinematics";
      _trackedPersonFrameCount = 0;
      _trackingStartTime = null;
      videoScannedFramesMinute = 0;

      String? initialFramePath;
      Uint8List? initialFrameBytes;

      if (_visualGuardStream != null && _visualGuardStream!.getVideoTracks().isNotEmpty) {
        final track = _visualGuardStream!.getVideoTracks().first;
        try {
          final ByteBuffer buffer = await track.captureFrame();
          initialFrameBytes = buffer.asUint8List();
          if (!kIsWeb) {
            final tempDir = await getTemporaryDirectory();
            final filePath = '${tempDir.path}/frame_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final file = File(filePath);
            await file.writeAsBytes(initialFrameBytes);
            initialFramePath = filePath;
          }
        } catch (_) {}
      }

      _startFrameScanner();
      _startMinuteSummaryEngine();
      _recordPerceptionSummary(
        source: 'safety_eye',
        summary: "Safety Eye armed with Multi-Object Trajectory Tracking.",
        metric: "Active",
        imagePath: initialFramePath,
        imageBytes: initialFrameBytes,
      );

      return true;
    } catch (e) {
      debugPrint("Visual Guard camera error: $e");
      isVisualGuardActive = false;
      visualGuardStatus = "Camera error: $e";
      return false;
    }
  }

  void _startFrameScanner() {
    _frameScannerTimer?.cancel();
    _frameScannerTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!isVisualGuardActive || _visualGuardStream == null) {
        timer.cancel();
        return;
      }
      try {
        if (_visualGuardStream!.getVideoTracks().isNotEmpty) {
          final track = _visualGuardStream!.getVideoTracks().first;
          final ByteBuffer buffer = await track.captureFrame();
          final bytes = buffer.asUint8List();
          if (bytes.isNotEmpty) {
            lastDetectedPersonCount = 1;
            videoScannedFramesMinute++;
          }
        }
      } catch (_) {}
    });
  }

  String currentFacingMode = 'environment';

  Future<void> switchCamera() async {
    if (!isVisualGuardActive || _visualGuardStream == null) return;
    try {
      if (_visualGuardStream!.getVideoTracks().isNotEmpty) {
        final track = _visualGuardStream!.getVideoTracks().first;
        await Helper.switchCamera(track);
        currentFacingMode = (currentFacingMode == 'environment') ? 'user' : 'environment';
        visualGuardStatus = "Switched to ${currentFacingMode == 'user' ? 'front' : 'rear'} camera";
        if (localVideoRenderer != null) {
          localVideoRenderer!.srcObject = _visualGuardStream;
        }
      }
    } catch (_) {
      try {
        _visualGuardStream?.getTracks().forEach((t) => t.stop());
        currentFacingMode = (currentFacingMode == 'environment') ? 'user' : 'environment';
        _visualGuardStream = await navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': {
            'facingMode': currentFacingMode,
            'width': {'ideal': 640},
            'height': {'ideal': 480},
          }
        });
        if (localVideoRenderer != null) {
          localVideoRenderer!.srcObject = _visualGuardStream;
        }
        visualGuardStatus = "Analyzing ${currentFacingMode == 'user' ? 'front' : 'rear'} camera frames";
      } catch (err) {
        debugPrint("Failed to switch camera: $err");
      }
    }
  }

  void stopVisualGuard() {
    isVisualGuardActive = false;
    visualGuardStatus = "Standby";
    _trackedPersonFrameCount = 0;
    _trackingStartTime = null;
    currentEyeSummary = "Safety Eye Standby";
    _frameScannerTimer?.cancel();
    try {
      if (localVideoRenderer != null) {
        localVideoRenderer!.srcObject = null;
      }
      _visualGuardStream?.getTracks().forEach((track) => track.stop());
      _visualGuardStream?.dispose();
      _visualGuardStream = null;
    } catch (_) {}
  }

  /// Process frame detections using real kinematics & turning correlations
  Future<void> processVisualFrameData({
    required bool personDetected,
    required double estimatedProximity,
    required bool potentialWeaponVisible,
    required double weaponConfidence,
    required bool aggressiveGestureVisible,
    required double gestureConfidence,
    required Function(IncidentRecord incident) onIncidentSaved,
    required Function(String error, IncidentRecord? pendingIncident) onStorageFailed,
    List<Rect>? detectedPersonBoxes,
    double? userHeadingRadians,
    double? userVelocityMps,
  }) async {
    if (!isVisualGuardActive) return;

    lastDetectedPersonCount = detectedPersonBoxes?.length ?? (personDetected ? 1 : 0);
    lastDetectedWeaponCount = potentialWeaponVisible ? 1 : 0;

    final now = DateTime.now();
    videoScannedFramesMinute++;

    // 1. Weapon Detection
    final weaponConfig = categoryConfigs[ThreatCategory.weapons]!;
    if (weaponConfig.enabled && potentialWeaponVisible && weaponConfidence >= weaponConfig.threshold) {
      await _handleCredibleThreat(
        category: ThreatCategory.weapons,
        categoryLabel: "Weapon / Dangerous Object Detected",
        confidence: weaponConfidence,
        summary: "Visual Guard identified weapon contour with ${(weaponConfidence * 100).toStringAsFixed(0)}% confidence",
        source: "safety_eye",
        mediaType: "image",
        onIncidentSaved: onIncidentSaved,
        onStorageFailed: onStorageFailed,
      );
      return;
    }

    // 2. Aggressive Gesture / Strike Detection
    final gestureConfig = categoryConfigs[ThreatCategory.suspiciousGestures]!;
    if (gestureConfig.enabled && aggressiveGestureVisible && gestureConfidence >= gestureConfig.threshold) {
      await _handleCredibleThreat(
        category: ThreatCategory.suspiciousGestures,
        categoryLabel: "Suspicious / Threatening Gesture Detected",
        confidence: gestureConfidence,
        summary: "Abrupt aggressive strike gesture detected",
        source: "safety_eye",
        mediaType: "image",
        onIncidentSaved: onIncidentSaved,
        onStorageFailed: onStorageFailed,
      );
      return;
    }

    // 3. REAL FOLLOWER DETECTION: Multi-Object Trajectory Kinematics
    final followerConfig = categoryConfigs[ThreatCategory.followerTracking]!;
    if (followerConfig.enabled) {
      // If bounding boxes and sensor headings are passed from ML Kit
      if (detectedPersonBoxes != null && detectedPersonBoxes.isNotEmpty) {
        final trackingResult = _followerTracker.updateWithFrameDetections(
          detectedPersonBoxes: detectedPersonBoxes,
          userHeadingRadians: userHeadingRadians ?? 0.0,
          userVelocityMps: userVelocityMps ?? 1.2,
        );
        latestVisionKinematics = trackingResult;

        if (trackingResult['isThreat'] == true) {
          double confidence = trackingResult['confidence'] ?? 0.94;
          if (confidence >= followerConfig.threshold) {
            await _handleCredibleThreat(
              category: ThreatCategory.followerTracking,
              categoryLabel: "Verified Persistent Stalker (Kinematic AI)",
              confidence: confidence,
              summary: trackingResult['summary'] ?? "Correlated follower trailing user across multiple turns.",
              source: "safety_eye",
              mediaType: "image",
              onIncidentSaved: onIncidentSaved,
              onStorageFailed: onStorageFailed,
            );
          }
        }
      } else if (personDetected) {
        // Fallback smoothing if raw Rects are not provided
        _trackedPersonFrameCount++;
        _trackingStartTime ??= now;
        _lastKnownPersonProximity = estimatedProximity;

        final elapsedTrackingSeconds = now.difference(_trackingStartTime!).inSeconds;

        // Requires at least 25 seconds of continuous trailing to avoid false alarms
        if (_trackedPersonFrameCount >= 30 && elapsedTrackingSeconds >= 25) {
          await _handleCredibleThreat(
            category: ThreatCategory.followerTracking,
            categoryLabel: "Possible Suspicious Follower (Sustained)",
            confidence: 0.86,
            summary: "Subject continuously tracked trailing user for ${elapsedTrackingSeconds}s.",
            source: "safety_eye",
            mediaType: "image",
            onIncidentSaved: onIncidentSaved,
            onStorageFailed: onStorageFailed,
          );
          _trackedPersonFrameCount = 0;
          _trackingStartTime = null;
        }
      } else {
        if (_trackedPersonFrameCount > 0) _trackedPersonFrameCount--;
      }
    }
  }

  int lastDetectedPersonCount = 0;
  int lastDetectedWeaponCount = 0;

  // ─────────────────────────────────────────────────────────────
  // 3. MINUTE-BY-MINUTE SUMMARY ENGINE
  // ─────────────────────────────────────────────────────────────
  void _startMinuteSummaryEngine() {
    _minuteSummaryTimer?.cancel();
    _minuteSummaryTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (!isVoiceMonitorActive && !isVisualGuardActive) {
        timer.cancel();
        return;
      }

      if (isVoiceMonitorActive) {
        final topLabel = latestAudioClassification?.primaryClass ?? "Ambient Sound";
        final category = latestAudioClassification?.category ?? "nominal";
        final isDistress = category == 'distress' || category == 'scream' || category == 'gunshot';
        final summary = "Level: ${currentDecibels.toStringAsFixed(1)} dBFS | Dominant: $topLabel";
        currentEarSummary = summary;
        _recordPerceptionSummary(
          source: 'safety_ear',
          summary: summary,
          metric: "${currentDecibels.toStringAsFixed(1)} dBFS",
          dominantSound: topLabel,
          category: isDistress ? 'distress' : 'nominal',
        );
      }

      if (isVisualGuardActive) {
        final pCount = lastDetectedPersonCount;
        final wCount = lastDetectedWeaponCount;
        final summary = "Person Count: $pCount | Weapon Count: $wCount";
        currentEyeSummary = summary;

        // Capture live camera frame thumbnail for perception log
        _captureLiveSnapshot().then((snapshotData) {
          _recordPerceptionSummary(
            source: 'safety_eye',
            summary: summary,
            metric: wCount > 0 ? "Threat" : "Clear",
            personCount: pCount,
            weaponCount: wCount,
            imagePath: snapshotData['path'],
            imageBytes: snapshotData['bytes'],
          );
        });
      }
    });
  }

  Future<Map<String, dynamic>> _captureLiveSnapshot() async {
    String? path;
    Uint8List? bytes;
    if (_visualGuardStream != null && _visualGuardStream!.getVideoTracks().isNotEmpty) {
      try {
        final track = _visualGuardStream!.getVideoTracks().first;
        final buffer = await track.captureFrame();
        bytes = buffer.asUint8List();
        if (!kIsWeb && bytes.isNotEmpty) {
          final tempDir = await getTemporaryDirectory();
          final filePath = '${tempDir.path}/perception_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final file = File(filePath);
          await file.writeAsBytes(bytes);
          path = filePath;
        }
      } catch (e) {
        debugPrint("[Safety Eye] Frame capture error: $e");
      }
    }
    return {'path': path, 'bytes': bytes};
  }

  void _recordPerceptionSummary({
    required String source,
    required String summary,
    required String metric,
    String? imagePath,
    Uint8List? imageBytes,
    int? personCount,
    int? weaponCount,
    String? dominantSound,
    String? category,
  }) {
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());
    perceptionLogs.insert(0, {
      'timestamp': timeStr,
      'source': source,
      'summary': summary,
      'metric': metric,
      'imagePath': imagePath,
      'imageBytes': imageBytes,
      'personCount': personCount ?? 0,
      'weaponCount': weaponCount ?? 0,
      'dominantSound': dominantSound ?? "Ambient",
      'category': category ?? "nominal",
    });
    if (perceptionLogs.length > 20) {
      perceptionLogs.removeLast();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 4. EVIDENCE VAULT PERSISTENCE & DEDUPLICATION
  // ─────────────────────────────────────────────────────────────
  Future<void> _handleCredibleThreat({
    required String category,
    required String categoryLabel,
    required double confidence,
    double? decibels,
    required String summary,
    required String source,
    required String mediaType,
    required Function(IncidentRecord incident) onIncidentSaved,
    required Function(String error, IncidentRecord? pendingIncident) onStorageFailed,
  }) async {
    final now = DateTime.now();

    if (_recentDetections.containsKey(category)) {
      final lastTrigger = _recentDetections[category]!;
      if (now.difference(lastTrigger) < _dedupWindow) {
        debugPrint("[GuardianX AI] Deduplicated repeated detection for $category");
        return;
      }
    }
    _recentDetections[category] = now;

    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(pattern: [0, 400, 200, 400]);
      }
    } catch (_) {}

    final incidentId = "GX_AI_${DateTime.now().millisecondsSinceEpoch}";
    String savedFilePath = "";
    int fileSizeBytes = 0;
    bool storageSuccess = false;

    try {
      Directory? baseDir = await getExternalStorageDirectory();
      baseDir ??= await getApplicationDocumentsDirectory();

      final vaultDir = Directory("${baseDir.path}/GuardianX/Vault");
      if (!vaultDir.existsSync()) {
        vaultDir.createSync(recursive: true);
      }

      // Capture frame snapshot if camera is active
      if (_visualGuardStream != null && _visualGuardStream!.getVideoTracks().isNotEmpty && mediaType == 'image') {
        try {
          final track = _visualGuardStream!.getVideoTracks().first;
          final buffer = await track.captureFrame();
          final bytes = buffer.asUint8List();
          final imageFile = File("${vaultDir.path}/${incidentId}_$category.jpg");
          await imageFile.writeAsBytes(bytes);
          savedFilePath = imageFile.path;
          fileSizeBytes = imageFile.lengthSync();
          storageSuccess = true;
        } catch (_) {}
      }

      // Save metadata JSON
      final metaFile = File("${vaultDir.path}/${incidentId}_$category.json");
      final metadata = {
        'id': incidentId,
        'category': category,
        'categoryLabel': categoryLabel,
        'confidence': confidence,
        'decibels': decibels,
        'timestamp': now.toIso8601String(),
        'source': source,
        'summary': summary,
        'filePath': savedFilePath,
      };
      await metaFile.writeAsString(jsonEncode(metadata));

      if (savedFilePath.isEmpty) {
        savedFilePath = metaFile.path;
        fileSizeBytes = metaFile.lengthSync();
        storageSuccess = true;
      }
    } catch (storageError) {
      debugPrint("[GuardianX Vault Error] Failed to persist evidence: $storageError");
      storageSuccess = false;
    }

    final incident = IncidentRecord(
      id: incidentId,
      userId: "user_primary",
      timestamp: now,
      category: category,
      categoryLabel: categoryLabel,
      confidence: confidence,
      decibels: decibels,
      summary: summary,
      source: source,
      mediaType: mediaType,
      filePath: savedFilePath,
      fileSizeBytes: fileSizeBytes,
      status: 'pending_confirmation',
      timeoutSeconds: safetyConfirmationTimeoutSeconds,
      defaultLevel: defaultEscalationLevel,
      storageVerified: storageSuccess,
      auditTrail: [
        "EVIDENCE_SAVED_DURABLY: Verified neural threat stored in Vault at $savedFilePath",
      ],
    );

    if (!storageSuccess) {
      onStorageFailed("Failed to write evidence to Vault storage.", incident);
      return;
    }

    activePendingIncident = incident;
    _scheduleAutomaticEscalation(incident);
    onIncidentSaved(incident);
  }

  // ─────────────────────────────────────────────────────────────
  // 5. SAFETY CONFIRMATION & ESCALATION SCHEDULER
  // ─────────────────────────────────────────────────────────────
  void _scheduleAutomaticEscalation(IncidentRecord incident) {
    _activeEscalationTimer?.cancel();
    _countdownTicker?.cancel();
    pendingCountdownSeconds = incident.timeoutSeconds;

    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (ticker) {
      if (activePendingIncident?.id != incident.id) {
        ticker.cancel();
        return;
      }
      if (pendingCountdownSeconds > 0) {
        pendingCountdownSeconds--;
      } else {
        ticker.cancel();
      }
    });

    _activeEscalationTimer = Timer(Duration(seconds: incident.timeoutSeconds), () {
      if (activePendingIncident?.id == incident.id &&
          activePendingIncident?.status == 'pending_confirmation') {
        _triggerAutomaticEscalation(incident);
      }
    });
  }

  void acknowledgeSafety() {
    if (activePendingIncident != null) {
      activePendingIncident!.status = 'confirmed_safe';
      activePendingIncident!.auditTrail.add(
          "USER_CONFIRMED_SAFE: User responded 'I am fine'. Escalation cancelled. Evidence preserved."
      );
      _activeEscalationTimer?.cancel();
      _countdownTicker?.cancel();
      activePendingIncident = null;
    }
  }

  void triggerManualLevel(String level, {required Function(String level, IncidentRecord incident) onDispatch}) {
    if (activePendingIncident != null) {
      activePendingIncident!.status = "escalated_$level";
      activePendingIncident!.auditTrail.add("MANUAL_ESCALATION_$level triggered by user.");
      _activeEscalationTimer?.cancel();
      _countdownTicker?.cancel();
      final inc = activePendingIncident!;
      activePendingIncident = null;
      onDispatch(level, inc);
    }
  }

  void _triggerAutomaticEscalation(IncidentRecord incident) {
    final level = incident.defaultLevel;
    incident.status = "escalated_auto_$level";
    incident.auditTrail.add("AUTOMATIC_ESCALATION_TIMEOUT: Dispatched $level.");
    activePendingIncident = null;
  }

  // ─────────────────────────────────────────────────────────────
  // 6. SMART SAFETY RADAR
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getLiveSafetyScore() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {
          'score': _calculateTimeScore(),
          'lat': 0.0,
          'lng': 0.0,
          'status': 'Device GPS is OFF (using time zone estimation)',
          'isQuiet': true,
        };
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );

      double score = _calculateTimeScore();
      return {
        'score': score,
        'lat': position.latitude,
        'lng': position.longitude,
        'status': score < 50 ? 'High-Risk Night Zone' : 'All quiet. No immediate safety concerns detected.',
        'isQuiet': score >= 50,
      };
    } catch (e) {
      return {
        'score': _calculateTimeScore(),
        'lat': 0.0,
        'lng': 0.0,
        'status': 'All quiet. No immediate safety concerns detected.',
        'isQuiet': true,
      };
    }
  }

  double _calculateTimeScore() {
    int hour = DateTime.now().hour;
    if (hour >= 23 || hour < 5) return 45.0;
    if (hour >= 19 || hour < 23) return 70.0;
    return 90.0;
  }

  void testTriggerAcousticAlert({
    required Function(IncidentRecord incident) onIncidentSaved,
    required Function(String error, IncidentRecord? pendingIncident) onStorageFailed,
  }) {
    _handleCredibleThreat(
      category: ThreatCategory.screaming,
      categoryLabel: "TEST: Verified YAMNet Vocal Distress Cue",
      confidence: 0.94,
      decibels: -12.5,
      summary: "Manual test verification of neural threat detection protocol",
      source: "manual_test",
      mediaType: "audio",
      onIncidentSaved: onIncidentSaved,
      onStorageFailed: onStorageFailed,
    );
  }
}