// lib/services/yamnet_audio_service.dart
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class AudioClassificationResult {
  final bool isThreat;
  final String category;
  final String categoryLabel;
  final double confidence;
  final bool isSuppressed;
  final String primaryClass;
  final String explanation;

  AudioClassificationResult({
    required this.isThreat,
    required this.category,
    required this.categoryLabel,
    required this.confidence,
    required this.isSuppressed,
    required this.primaryClass,
    required this.explanation,
  });
}

class YamnetAudioService {
  static final YamnetAudioService _instance = YamnetAudioService._internal();
  factory YamnetAudioService() => _instance;
  YamnetAudioService._internal();

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;

  // AudioSet Class Indices
  static const int SCREAMING_INDEX = 12;      // "Screaming"
  static const int SHOUT_INDEX = 11;          // "Shout"
  static const int CRYING_SOBBING_INDEX = 13; // "Crying, sobbing"
  static const int GLASS_BREAK_INDEX = 441;   // "Glass"
  static const int GUNSHOT_INDEX = 428;       // "Gunshot"

  // Benign Indices to Suppress (Prevents False Alarms)
  static const int CLAPPING_INDEX = 58;       // "Clapping"
  static const int LAUGHTER_INDEX = 16;       // "Laughter"
  static const int DOOR_SLAM_INDEX = 392;     // "Slam"

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
        'assets/models/yamnet.tflite',
        options: options,
      );
      final labelData = await rootBundle.loadString('assets/models/yamnet_label_map.txt');
      _labels = labelData.split('\n').map((l) => l.trim()).toList();
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint("[YamnetAudioService Error] $e");
      return false;
    }
  }

  /// Classifies 15,600 float32 PCM samples @ 16kHz (0.975s window)
  AudioClassificationResult classifyBuffer(Float32List pcm16kSamples) {
    if (!_isInitialized || _interpreter == null) {
      return AudioClassificationResult(
        isThreat: false,
        category: 'uninitialized',
        categoryLabel: 'YAMNet not initialized',
        confidence: 0.0,
        isSuppressed: false,
        primaryClass: 'none',
        explanation: 'Model not loaded',
      );
    }

    // Input shape: [15600], Output shape: [1, 521]
    var input = [pcm16kSamples];
    var output = List<double>.filled(521, 0.0).reshape([1, 521]);

    _interpreter!.run(input, output);
    final List<double> probs = List<double>.from(output[0]);

    final double screamProb = probs[SCREAMING_INDEX];
    final double shoutProb = probs[SHOUT_INDEX];
    final double cryingProb = probs[CRYING_SOBBING_INDEX];
    final double glassProb = probs[GLASS_BREAK_INDEX];
    final double clappingProb = probs[CLAPPING_INDEX];
    final double laughterProb = probs[LAUGHTER_INDEX];

    // 1. SUPPRESSION GATE: If clapping or laughter dominates, abort SOS
    if (clappingProb > 0.45 || laughterProb > 0.50) {
      return AudioClassificationResult(
        isThreat: false,
        category: 'benign_noise_suppressed',
        categoryLabel: 'Harmless Noise Filtered',
        confidence: max(clappingProb, laughterProb),
        isSuppressed: true,
        primaryClass: clappingProb > laughterProb ? 'Clapping' : 'Laughter',
        explanation: 'Loud volume detected but identified as harmless clapping/laughter.',
      );
    }

    // 2. VERIFIED VOCAL DISTRESS
    double vocalThreatScore = max(screamProb, max(shoutProb * 0.9, cryingProb));
    if (vocalThreatScore >= 0.65) {
      return AudioClassificationResult(
        isThreat: true,
        category: 'screaming',
        categoryLabel: 'Verified Human Vocal Distress Cue',
        confidence: vocalThreatScore,
        isSuppressed: false,
        primaryClass: screamProb >= cryingProb ? 'Screaming' : 'Crying',
        explanation: 'Neural acoustic classification verified human distress.',
      );
    }

    // 3. VERIFIED GLASS BREAKING
    if (glassProb >= 0.72) {
      return AudioClassificationResult(
        isThreat: true,
        category: 'glass_breaking',
        categoryLabel: 'Window Glass Shatter Signature',
        confidence: glassProb,
        isSuppressed: false,
        primaryClass: 'Glass Breaking',
        explanation: 'Violent high-frequency glass resonance confirmed.',
      );
    }

    return AudioClassificationResult(
      isThreat: false,
      category: 'nominal',
      categoryLabel: 'Ambient Sound Nominal',
      confidence: 0.90,
      isSuppressed: false,
      primaryClass: 'Ambient',
      explanation: 'No threat signatures detected.',
    );
  }
}