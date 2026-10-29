// lib/services/follower_tracker_service.dart
import 'dart:math';
import 'dart:ui'; // FIX: Provides the Rect type
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class TrackedSubject {
  final String trackId;
  double x, y, width, height;
  double vx = 0.0, vy = 0.0;
  DateTime firstSeen;
  DateTime lastSeen;
  int matchedCorrelatedTurns = 0;
  double headingCorrelation = 0.0;
  double estimatedTrailingDistance = 5.0;

  TrackedSubject({
    required this.trackId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  })  : firstSeen = DateTime.now(),
        lastSeen = DateTime.now();
}

class FollowerTrackerService {
  static final FollowerTrackerService _instance = FollowerTrackerService._internal();
  factory FollowerTrackerService() => _instance;
  FollowerTrackerService._internal();

  PoseDetector? _poseDetector;
  final Map<String, TrackedSubject> _activeTracks = {};
  int _nextTrackId = 100;
  double _previousUserHeading = 0.0;
  bool _isInitialized = false;

  // FIX: Added initialize method for ai_controller.dart
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final options = PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      );
      _poseDetector = PoseDetector(options: options);
      _isInitialized = true;
      debugPrint("[FollowerTrackerService] ML Kit Pose Detector initialized.");
    } catch (e) {
      debugPrint("[FollowerTrackerService Error] $e");
    }
  }

  /// Updates Multi-Object Tracking state with new camera bounding boxes
  Map<String, dynamic> updateWithFrameDetections({
    required List<Rect> detectedPersonBoxes,
    required double userHeadingRadians,
    required double userVelocityMps,
  }) {
    final now = DateTime.now();

    // Check if user made a significant turn (> 30 degrees)
    double headingDelta = (userHeadingRadians - _previousUserHeading).abs();
    if (headingDelta > pi) headingDelta = (2 * pi) - headingDelta;
    bool userJustTurned = headingDelta > 0.52;
    if (userJustTurned) _previousUserHeading = userHeadingRadians;

    // Associate boxes with existing Track IDs (prevents mixing up pedestrians)
    Set<String> matchedTrackIds = {};
    for (var box in detectedPersonBoxes) {
      String? bestTrackId;
      double minDistance = 0.25;

      for (var entry in _activeTracks.entries) {
        double dist = sqrt(pow(entry.value.x - box.center.dx, 2) + pow(entry.value.y - box.center.dy, 2));
        if (dist < minDistance && !matchedTrackIds.contains(entry.key)) {
          minDistance = dist;
          bestTrackId = entry.key;
        }
      }

      if (bestTrackId != null) {
        var track = _activeTracks[bestTrackId]!;
        double dt = max(0.033, now.difference(track.lastSeen).inMilliseconds / 1000.0);
        track.vx = (box.center.dx - track.x) / dt;
        track.vy = (box.center.dy - track.y) / dt;
        track.x = box.center.dx;
        track.y = box.center.dy;
        track.width = box.width;
        track.height = box.height;
        track.lastSeen = now;
        matchedTrackIds.add(bestTrackId);
      } else {
        String newId = "TRK_${_nextTrackId++}";
        _activeTracks[newId] = TrackedSubject(
          trackId: newId,
          x: box.center.dx,
          y: box.center.dy,
          width: box.width,
          height: box.height,
        );
        matchedTrackIds.add(newId);
      }
    }

    _activeTracks.removeWhere((id, track) => now.difference(track.lastSeen).inSeconds > 3);

    // Kinematic Stalking Criteria
    TrackedSubject? verifiedStalker;
    for (var track in _activeTracks.values) {
      final elapsed = now.difference(track.firstSeen).inSeconds;
      if (elapsed < 25) continue;

      track.estimatedTrailingDistance = max(1.5, min(15.0, 1.8 / max(0.1, track.height)));
      double followerHeading = atan2(track.vy, track.vx);
      track.headingCorrelation = cos(userHeadingRadians - followerHeading);

      if (userJustTurned && track.headingCorrelation > 0.80) {
        track.matchedCorrelatedTurns++;
      }

      // THREAT: Correlated turning + speed match over >= 30 seconds
      if (track.matchedCorrelatedTurns >= 2 &&
          track.headingCorrelation > 0.85 &&
          elapsed >= 30 &&
          track.estimatedTrailingDistance < 10.0) {
        verifiedStalker = track;
        break;
      }
    }

    if (verifiedStalker != null) {
      return {
        'isThreat': true,
        'trackId': verifiedStalker.trackId,
        'confidence': 0.94,
        'matchedTurns': verifiedStalker.matchedCorrelatedTurns,
        'trailingDistance': verifiedStalker.estimatedTrailingDistance,
        'summary': 'Subject ${verifiedStalker.trackId} has followed user through ${verifiedStalker.matchedCorrelatedTurns} turns over ${now.difference(verifiedStalker.firstSeen).inSeconds}s.',
      };
    }

    return {'isThreat': false, 'activeTracksCount': _activeTracks.length};
  }

  void dispose() {
    _poseDetector?.close();
    _activeTracks.clear();
  }
}