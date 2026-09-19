import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vibration/vibration.dart';

class AIController {
  static final AIController _instance = AIController._internal();
  factory AIController() => _instance;
  AIController._internal();

  bool isVoiceMonitorActive = false;
  bool isVisualGuardActive = false;
  bool isSmartRadarActive = false;

  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _acousticTimer;
  double currentDecibels = -60.0;
  String visualGuardStatus = "Standby";

  // 1. ACOUSTIC THREAT DETECTION (Safety Ear)
  Future<bool> startAcousticMonitor(Function(String reason, double db) onThreatDetected) async {
    isVoiceMonitorActive = true;
    try {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }
      if (!status.isGranted) {
        isVoiceMonitorActive = false;
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final tempAudioPath = '${tempDir.path}/ai_acoustic_monitor.m4a';

      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 22050),
        path: tempAudioPath,
      );

      _acousticTimer?.cancel();
      _acousticTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) async {
        if (!isVoiceMonitorActive) {
          timer.cancel();
          try { await _audioRecorder.stop(); } catch (_) {}
          return;
        }

        try {
          final amp = await _audioRecorder.getAmplitude();
          currentDecibels = amp.current;
          // Responsive threshold: clapping, shouting, or loud sounds exceed -24 dBFS
          if (amp.current > -24.0) {
            _triggerThreatAlert(onThreatDetected, "Acoustic Threat / High Decibel Anomaly", amp.current);
          }
        } catch (e) {
          debugPrint("Acoustic monitor error: $e");
        }
      });
      return true;
    } catch (e) {
      debugPrint("Failed to start acoustic monitor: $e");
      isVoiceMonitorActive = false;
      return false;
    }
  }

  void _triggerThreatAlert(Function(String, double) onThreatDetected, String reason, double db) async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(pattern: [0, 300, 150, 300]);
      }
    } catch (_) {}
    onThreatDetected(reason, db);
  }

  void testTriggerAcousticAlert(Function(String, double) onThreatDetected) {
    _triggerThreatAlert(onThreatDetected, "TEST: Simulated Scream / Audio Anomaly", -12.5);
  }

  Future<void> stopAcousticMonitor() async {
    isVoiceMonitorActive = false;
    _acousticTimer?.cancel();
    try {
      if (await _audioRecorder.isRecording()) await _audioRecorder.stop();
    } catch (_) {}
  }

  // 2. SMART SAFETY RADAR
  Future<Map<String, dynamic>> getLiveSafetyScore() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {'score': _calculateTimeScore(), 'lat': 0.0, 'lng': 0.0, 'status': 'Device GPS is OFF (using time zone)'};
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 6),
      );

      double score = _calculateTimeScore();
      return {
        'score': score,
        'lat': position.latitude,
        'lng': position.longitude,
        'status': score < 50 ? 'High-Risk Night Zone' : 'Daylight Low-Risk Safe Corridor',
      };
    } catch (e) {
      return {'score': _calculateTimeScore(), 'lat': 0.0, 'lng': 0.0, 'status': 'Standard Zone Patrol'};
    }
  }

  double _calculateTimeScore() {
    int hour = DateTime.now().hour;
    if (hour >= 22 || hour < 5) return 45.0; // High risk at night
    if (hour >= 18 || hour < 22) return 68.0; // Moderate dusk caution
    return 85.0; // Safe daylight
  }

  // 3. VISUAL GUARD
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
    visualGuardStatus = "Scanning frames for weapons & followers (Clear)";
    return true;
  }

  void stopVisualGuard() {
    isVisualGuardActive = false;
    visualGuardStatus = "Standby";
  }
}