import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  MediaStream? localStream;
  RTCPeerConnection? _peerConnection;
  IO.Socket? _socket;
  String? _roomCode;
  bool isLive = false;

  Future<bool> startStreaming(IO.Socket socket, String roomCode) async {
    if (isLive) return true;
    _socket = socket;
    _roomCode = roomCode;

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

        _socket!.on('viewer-connected', (_) => _setupWebRTC());

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

  void stopEverything() {
    isLive = false;
    // --- MOBILE ONLY CLEANUP ---
    if (!kIsWeb) {
      WakelockPlus.disable();
      FlutterForegroundTask.stopService();
    }
    _socket?.off('camera-command');
    _socket?.off('viewer-connected');
    _socket?.off('webrtc-signaling');
    _peerConnection?.close();
    localStream?.getTracks().forEach((track) => track.stop());
    localStream?.dispose();
    localStream = null;
  }
}