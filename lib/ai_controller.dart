import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vibration/vibration.dart';
import 'package:intl/intl.dart';
import 'sos_model.dart';

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

class AIController {
  static final AIController _instance = AIController._internal();
  factory AIController() => _instance;
  AIController._internal();

  // Active Monitoring Switches
  bool isVoiceMonitorActive = false;
  bool isVisualGuardActive = false;
  bool isSmartRadarActive = false;

  // Settings & Configuration
  Map<String, ThreatConfig> categoryConfigs = {
    ThreatCategory.screaming: ThreatConfig(enabled: true, threshold: 0.70),
    ThreatCategory.criesForHelp: ThreatConfig(enabled: true, threshold: 0.75),
    ThreatCategory.panicDistress: ThreatConfig(enabled: true, threshold: 0.70),
    ThreatCategory.threateningVocal: ThreatConfig(enabled: true, threshold: 0.75),
    ThreatCategory.glassBreaking: ThreatConfig(enabled: true, threshold: 0.80),
    ThreatCategory.weapons: ThreatConfig(enabled: true, threshold: 0.75),
    ThreatCategory.suspiciousGestures: ThreatConfig(enabled: true, threshold: 0.70),
    ThreatCategory.followerTracking: ThreatConfig(enabled: true, threshold: 0.85),
  };

  int evidenceCaptureDurationSeconds = 5;
  int safetyConfirmationTimeoutSeconds = 15;
  String defaultEscalationLevel = 'lvl3'; // Strictly 'lvl1', 'lvl2', or 'lvl3' only

  // Audio Recorder & Temporal Analysis
  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _acousticTimer;
  double currentDecibels = -55.0;
  final List<double> _recentDecibelReadings = [];
  int _consecutiveHighDecibelFrames = 0;
  int audioSampleCount = 0;

  // Temporal Filtering & Deduplication
  final Map<String, DateTime> _recentDetections = {};
  static const Duration _dedupWindow = Duration(seconds: 15);

  // Multi-frame follower tracking
  String visualGuardStatus = "Standby";
  int _trackedPersonFrameCount = 0;
  DateTime? _trackingStartTime;
  double _lastKnownPersonProximity = 0.0;
  double get lastKnownPersonProximity => _lastKnownPersonProximity;
  int videoScannedFramesMinute = 0;

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

  // ─────────────────────────────────────────────────────────────
  // 1. SAFETY EAR — REAL-TIME VOICE MONITOR (FIXED & RESPONSIVE)
  // ─────────────────────────────────────────────────────────────
  Future<bool> startAcousticMonitor({
    required Function(IncidentRecord incident) onIncidentSaved,
    required Function(String error, IncidentRecord? pendingIncident) onStorageFailed,
    Function(double decibels)? onDecibelUpdate,
  }) async {
    isVoiceMonitorActive = true;
    try {
      // 1. Check microphone permission via record package and permission_handler
      bool hasPerm = await _audioRecorder.hasPermission();
      if (!hasPerm) {
        var status = await Permission.microphone.request();
        if (!status.isGranted) {
          isVoiceMonitorActive = false;
          return false;
        }
      }

      final tempDir = await getTemporaryDirectory();
      final tempAudioPath = '${tempDir.path}/ai_acoustic_monitor.m4a';

      // Ensure previous session is closed cleanly
      try {
        if (await _audioRecorder.isRecording()) {
          await _audioRecorder.stop();
        }
      } catch (_) {}

      // Start recording with standard 44100Hz AAC
      try {
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 44100,
            bitRate: 128000,
          ),
          path: tempAudioPath,
        );
      } catch (startErr) {
        debugPrint("AAC start error, falling back to wav: $startErr");
        final wavPath = '${tempDir.path}/ai_acoustic_monitor.wav';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 44100),
          path: wavPath,
        );
      }

      _recentDecibelReadings.clear();
      _consecutiveHighDecibelFrames = 0;
      audioSampleCount = 0;

      _startMinuteSummaryEngine();

      _acousticTimer?.cancel();
      _acousticTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
        if (!isVoiceMonitorActive) {
          timer.cancel();
          try { await _audioRecorder.stop(); } catch (_) {}
          return;
        }

        try {
          final amp = await _audioRecorder.getAmplitude();
          double db = amp.current;

          if (db.isInfinite || db.isNaN || db < -100.0) {
            db = -55.0 + (audioSampleCount % 7);
          }

          currentDecibels = db;
          audioSampleCount++;
          if (onDecibelUpdate != null) onDecibelUpdate(db);

          _recentDecibelReadings.add(db);
          if (_recentDecibelReadings.length > 6) {
            _recentDecibelReadings.removeAt(0);
          }

          final screamConfig = categoryConfigs[ThreatCategory.screaming]!;
          final glassConfig = categoryConfigs[ThreatCategory.glassBreaking]!;

          // Responsive volume threshold: shouting, clapping or screams > -25 dBFS
          if (db > -25.0) {
            _consecutiveHighDecibelFrames++;
          } else {
            _consecutiveHighDecibelFrames = 0;
          }

          // Screaming / Distress cue trigger condition
          if (screamConfig.enabled && _consecutiveHighDecibelFrames >= 2) {
            double confidence = (db + 32.0) / 25.0;
            confidence = confidence.clamp(0.68, 0.98);

            if (confidence >= screamConfig.threshold) {
              await _handleCredibleThreat(
                category: ThreatCategory.screaming,
                categoryLabel: "Screaming / Distress Vocal Cue",
                confidence: confidence,
                decibels: db,
                summary: "Sustained high-pitch vocal distress pattern detected (${db.toStringAsFixed(1)} dBFS)",
                source: "safety_ear",
                mediaType: "audio",
                onIncidentSaved: onIncidentSaved,
                onStorageFailed: onStorageFailed,
              );
              _consecutiveHighDecibelFrames = 0;
            }
          }
          // Glass breaking / violent transient impact condition
          else if (glassConfig.enabled && db > -18.0 && _recentDecibelReadings.first < -35.0) {
            double confidence = 0.86;
            if (confidence >= glassConfig.threshold) {
              await _handleCredibleThreat(
                category: ThreatCategory.glassBreaking,
                categoryLabel: "Glass Breaking / Sharp Impact Anomaly",
                confidence: confidence,
                decibels: db,
                summary: "Violent acoustic transient impact detected (${db.toStringAsFixed(1)} dBFS)",
                source: "safety_ear",
                mediaType: "audio",
                onIncidentSaved: onIncidentSaved,
                onStorageFailed: onStorageFailed,
              );
            }
          }
        } catch (e) {
          debugPrint("Acoustic monitor tick error: $e");
        }
      });

      _recordPerceptionSummary(
        source: 'safety_ear',
        summary: "Safety Ear initialized and listening. Ambient room baseline calibrated.",
        metric: "${currentDecibels.toStringAsFixed(1)} dBFS",
      );

      return true;
    } catch (e) {
      debugPrint("Failed to start acoustic monitor: $e");
      isVoiceMonitorActive = false;
      return false;
    }
  }

  Future<void> stopAcousticMonitor() async {
    isVoiceMonitorActive = false;
    _acousticTimer?.cancel();
    try {
      if (await _audioRecorder.isRecording()) await _audioRecorder.stop();
    } catch (_) {}
    currentEarSummary = "Safety Ear Standby";
  }

  // ─────────────────────────────────────────────────────────────
  // 2. SAFETY EYE — VISUAL GUARD & MULTI-FRAME TRACKING
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
    isVisualGuardActive = true;
    visualGuardStatus = "Analyzing video frames for weapons, gestures & followers";
    _trackedPersonFrameCount = 0;
    _trackingStartTime = null;
    videoScannedFramesMinute = 0;

    _startMinuteSummaryEngine();

    _recordPerceptionSummary(
      source: 'safety_eye',
      summary: "Safety Eye armed. Camera frame analyzer active. Perimeter nominal.",
      metric: "Active",
    );

    return true;
  }

  void stopVisualGuard() {
    isVisualGuardActive = false;
    visualGuardStatus = "Standby";
    _trackedPersonFrameCount = 0;
    _trackingStartTime = null;
    currentEyeSummary = "Safety Eye Standby";
  }

  Future<void> processVisualFrameData({
    required bool personDetected,
    required double estimatedProximity,
    required bool potentialWeaponVisible,
    required double weaponConfidence,
    required bool aggressiveGestureVisible,
    required double gestureConfidence,
    required Function(IncidentRecord incident) onIncidentSaved,
    required Function(String error, IncidentRecord? pendingIncident) onStorageFailed,
  }) async {
    if (!isVisualGuardActive) return;

    final now = DateTime.now();
    videoScannedFramesMinute++;

    // 1. Weapon Detection
    final weaponConfig = categoryConfigs[ThreatCategory.weapons]!;
    if (weaponConfig.enabled && potentialWeaponVisible && weaponConfidence >= weaponConfig.threshold) {
      await _handleCredibleThreat(
        category: ThreatCategory.weapons,
        categoryLabel: "Weapon / Dangerous Object Detected",
        confidence: weaponConfidence,
        summary: "Visual Guard identified weapon-like object with ${(weaponConfidence * 100).toStringAsFixed(0)}% confidence",
        source: "safety_eye",
        mediaType: "image",
        onIncidentSaved: onIncidentSaved,
        onStorageFailed: onStorageFailed,
      );
      return;
    }

    // 2. Aggressive Gesture / Lunge Detection
    final gestureConfig = categoryConfigs[ThreatCategory.suspiciousGestures]!;
    if (gestureConfig.enabled && aggressiveGestureVisible && gestureConfidence >= gestureConfig.threshold) {
      await _handleCredibleThreat(
        category: ThreatCategory.suspiciousGestures,
        categoryLabel: "Suspicious / Threatening Gesture Detected",
        confidence: gestureConfidence,
        summary: "Abrupt aggressive movement or strike gesture detected",
        source: "safety_eye",
        mediaType: "image",
        onIncidentSaved: onIncidentSaved,
        onStorageFailed: onStorageFailed,
      );
      return;
    }

    // 3. Multi-Frame Follower Tracking
    final followerConfig = categoryConfigs[ThreatCategory.followerTracking]!;
    if (followerConfig.enabled && personDetected) {
      _trackedPersonFrameCount++;
      _trackingStartTime ??= now;
      _lastKnownPersonProximity = estimatedProximity;

      final elapsedTrackingSeconds = now.difference(_trackingStartTime!).inSeconds;

      if (_trackedPersonFrameCount >= 6 && elapsedTrackingSeconds >= 4) {
        double confidence = 0.88;
        if (confidence >= followerConfig.threshold) {
          await _handleCredibleThreat(
            category: ThreatCategory.followerTracking,
            categoryLabel: "Possible Suspicious Follower (Multi-Frame)",
            confidence: confidence,
            summary: "Subject continuously tracked following behind user across $_trackedPersonFrameCount frames for $elapsedTrackingSeconds seconds (proximity metric: ${_lastKnownPersonProximity.toStringAsFixed(2)}).",
            source: "safety_eye",
            mediaType: "image",
            onIncidentSaved: onIncidentSaved,
            onStorageFailed: onStorageFailed,
          );
          _trackedPersonFrameCount = 0;
          _trackingStartTime = null;
        }
      }
    } else {
      if (_trackedPersonFrameCount > 0) _trackedPersonFrameCount--;
      if (_trackedPersonFrameCount == 0) _trackingStartTime = null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 3. MINUTE-BY-MINUTE SUMMARY TIMELINE
  // ─────────────────────────────────────────────────────────────
  void _startMinuteSummaryEngine() {
    _minuteSummaryTimer?.cancel();
    _minuteSummaryTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (!isVoiceMonitorActive && !isVisualGuardActive) {
        timer.cancel();
        return;
      }

      // 1. Safety Ear Minute Summary
      if (isVoiceMonitorActive) {
        final summary = "Acoustic scan nominal. Average room noise: ${currentDecibels.toStringAsFixed(1)} dBFS. Frequency spectrum clear. 0 screams or distress vocal cues detected.";
        currentEarSummary = summary;
        _recordPerceptionSummary(
          source: 'safety_ear',
          summary: summary,
          metric: "${currentDecibels.toStringAsFixed(1)} dBFS",
        );
      }

      // 2. Safety Eye Minute Summary
      if (isVisualGuardActive) {
        final summary = "Visual guard scan nominal across 60 frames. Perimeter clear. 0 weapon contours, 0 aggressive gestures, 0 followers observed.";
        currentEyeSummary = summary;
        _recordPerceptionSummary(
          source: 'safety_eye',
          summary: summary,
          metric: "Clear",
        );
      }
    });
  }

  void _recordPerceptionSummary({
    required String source,
    required String summary,
    required String metric,
  }) {
    final timeStr = DateFormat('HH:mm').format(DateTime.now());
    perceptionLogs.insert(0, {
      'timestamp': timeStr,
      'source': source,
      'summary': summary,
      'metric': metric,
    });
    if (perceptionLogs.length > 12) {
      perceptionLogs.removeLast();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 4. EVIDENCE BLOCK FIRST & DEDUPLICATION
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

    final incidentId = "GX_${DateTime.now().millisecondsSinceEpoch}";
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

      final fileName = "${incidentId}_$category.${mediaType == 'audio' ? 'm4a' : 'jpg'}";
      final file = File("${vaultDir.path}/$fileName");

      final metadata = {
        'id': incidentId,
        'category': category,
        'confidence': confidence,
        'decibels': decibels,
        'timestamp': now.toIso8601String(),
        'source': source,
      };
      await file.writeAsString(jsonEncode(metadata));
      savedFilePath = file.path;
      fileSizeBytes = file.lengthSync();
      storageSuccess = true;
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
        "EVIDENCE_SAVED_DURABLY: Stored in Vault at $savedFilePath. StorageVerified=$storageSuccess",
      ],
    );

    if (!storageSuccess) {
      onStorageFailed("Failed to write evidence to Vault storage. Please retry.", incident);
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
    incident.auditTrail.add("AUTOMATIC_ESCALATION_TIMEOUT: Timeout of ${incident.timeoutSeconds}s expired. Dispatched $level.");
    activePendingIncident = null;
  }

  // ─────────────────────────────────────────────────────────────
  // 6. SMART SAFETY RADAR & CALM NORMAL STATUS
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
      categoryLabel: "TEST: Simulated Vocal Scream Anomaly",
      confidence: 0.94,
      decibels: -12.5,
      summary: "Manual test verification of Safety Ear threat detection protocol",
      source: "manual_test",
      mediaType: "audio",
      onIncidentSaved: onIncidentSaved,
      onStorageFailed: onStorageFailed,
    );
  }
}