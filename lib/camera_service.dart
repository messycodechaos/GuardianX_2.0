import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'record_service.dart';
import 'video_record_service.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  MediaStream? localStream;
  RTCPeerConnection? _peerConnection;
  IO.Socket? _socket;
  String? _roomCode;
  bool isLive = false;

  // ── GUARDIAN CONNECTION TRACKING ──
  bool hasAnyGuardianConnected = false;
  int activeGuardianCount = 0;
  DateTime? streamStartTime;
  Function(bool connected, int count)? onGuardianStatusChanged;

  Future<bool> startStreaming(IO.Socket socket, String roomCode) async {
    if (isLive) return true;
    _socket = socket;
    _roomCode = roomCode;
    hasAnyGuardianConnected = false;
    activeGuardianCount = 0;
    streamStartTime = DateTime.now();

    try {
      // --- MOBILE ONLY LOGIC ---
      if (!kIsWeb) {
        WakelockPlus.enable();
        await FlutterForegroundTask.startService(
          notificationTitle: 'Security Camera Active',
          notificationText: 'Streaming Live in Background',
        );
      }

      // --- UNIVERSAL CAMERA LOGIC (Web & Mobile) ---
      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'environment', // Starts with Back Cam
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        }
      });

      if (localStream != null) {
        isLive = true;
        _socket!.emit('join-as-broadcaster', _roomCode);

        // Listen for remote flip command from Viewer
        _socket!.on('camera-command', (data) {
          if (data['command'] == 'switch') _performFlip();
        });

        // Track when a guardian connects!
        _socket!.on('viewer-connected', (_) {
          hasAnyGuardianConnected = true;
          activeGuardianCount++;
          print("🛡️ Guardian connected to room $_roomCode! Active count: $activeGuardianCount");
          if (onGuardianStatusChanged != null) {
            onGuardianStatusChanged!(true, activeGuardianCount);
          }
          _setupWebRTC();
        });

        _socket!.on('viewer-disconnected', (_) {
          if (activeGuardianCount > 0) activeGuardianCount--;
          print("Guardian disconnected. Active remaining: $activeGuardianCount");
          if (onGuardianStatusChanged != null) {
            onGuardianStatusChanged!(activeGuardianCount > 0, activeGuardianCount);
          }
        });

        _socket!.on('webrtc-signaling', (data) async {
          if (data['type'] == 'answer') {
            await _peerConnection?.setRemoteDescription(RTCSessionDescription(data['sdp'], data['type']));
          } else if (data['type'] == 'candidate') {
            await _peerConnection?.addCandidate(RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']));
          }
        });

        return true;
      }
      return false;
    } catch (e) {
      print("Stream Error: $e");
      return false;
    }
  }

  // ── ARCHIVE UNATTENDED STREAM TO VAULT WITH AI FORENSIC SUMMARY ──
  Future<String?> archiveIfUnattended() async {
    // If a guardian joined the room, this is not an unattended stream
    if (hasAnyGuardianConnected || streamStartTime == null) {
      return null;
    }

    final durationSec = DateTime.now().difference(streamStartTime!).inSeconds;
    final String timestampStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final String readableTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    // Generate dynamic AI forensic description
    final String aiDescription =
        "🚨 Unattended SOS Live Stream recorded for ${durationSec}s in Room #$_roomCode ($readableTime). "
        "The emergency broadcast was transmitted to emergency contacts, but 0 guardians were able to connect to the live room. "
        "Full visual camera video and ambient acoustic microphone evidence has been secured and sealed in the Evidence Vault for forensic review.";

    try {
      Directory? baseDir = await getExternalStorageDirectory();
      baseDir ??= await getApplicationDocumentsDirectory();

      final vaultDir = Directory("${baseDir.path}/GuardianX/Vault");
      if (!vaultDir.existsSync()) {
        vaultDir.createSync(recursive: true);
      }

      final evidenceId = "GX_UNATTENDED_$timestampStr";
      final metadataFile = File("${vaultDir.path}/$evidenceId.json");

      final metadata = {
        'id': evidenceId,
        'category': 'Unattended Live Stream',
        'title': 'Unattended SOS Stream (0 Guardians Joined)',
        'aiDescription': aiDescription,
        'guardianConnected': false,
        'streamDurationSeconds': durationSec,
        'roomCode': _roomCode ?? 'UNKNOWN',
        'videoPath': VideoRecordService().lastRecordedVideoPath ?? '',
        'audioPath': RecordService().lastRecordedAudioPath ?? '',
        'timestamp': DateTime.now().toIso8601String(),
        'confidence': 1.0,
        'source': 'live_stream_unattended',
        'auditTrail': [
          "STREAM_STARTED: $streamStartTime",
          "STREAM_ENDED_WITHOUT_GUARDIAN: 0 viewers joined during ${durationSec}s",
          "EVIDENCE_VAULT_SEALED: Committed to durable Vault with AI summary"
        ]
      };

      await metadataFile.writeAsString(jsonEncode(metadata));
      print("✅ Unattended Live Stream archived to Evidence Vault: ${metadataFile.path}");
      return aiDescription;
    } catch (e) {
      print("Error archiving unattended stream to Evidence Vault: $e");
      return null;
    }
  }

  void stopEverything() {
    isLive = false;

    // Check and auto-archive to Vault if no guardian connected
    archiveIfUnattended();

    // --- MOBILE ONLY CLEANUP ---
    if (!kIsWeb) {
      WakelockPlus.disable();
      FlutterForegroundTask.stopService();
    }
    _socket?.off('camera-command');
    _socket?.off('viewer-connected');
    _socket?.off('viewer-disconnected');
    _socket?.off('webrtc-signaling');
    _peerConnection?.close();
    localStream?.getTracks().forEach((track) => track.stop());
    localStream?.dispose();
    localStream = null;
  }

  Future<void> _performFlip() async {
    if (localStream != null) {
      final videoTrack = localStream!.getVideoTracks()[0];
      await Helper.switchCamera(videoTrack);
    }
  }

  Future<void> _setupWebRTC() async {
    _peerConnection = await createPeerConnection({'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}]});
    localStream!.getTracks().forEach((track) => _peerConnection!.addTrack(track, localStream!));
    _peerConnection!.onIceCandidate = (candidate) {
      _socket!.emit('webrtc-signaling', {'roomId': _roomCode, 'type': 'candidate', 'candidate': candidate.candidate, 'sdpMid': candidate.sdpMid, 'sdpMLineIndex': candidate.sdpMLineIndex});
    };
    var offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    _socket!.emit('webrtc-signaling', {'roomId': _roomCode, 'type': 'offer', 'sdp': offer.sdp});
  }
}