import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:math' as math;

class ViewerScreen extends StatefulWidget {
  final IO.Socket socket;
  final String roomCode;
  const ViewerScreen({Key? key, required this.socket, required this.roomCode}) : super(key: key);
  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;

  // Settings States
  double _brightness = 1.0;
  double _nightMode = 0.0;
  double _zoom = 1.0;
  int _rotation = 0;
  bool _isMirrored = false;
  bool _isTorchOn = false;
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    _initViewer();
  }

  Future<void> _initViewer() async {
    await _remoteRenderer.initialize();
    widget.socket.emit('join-as-viewer', widget.roomCode);

    widget.socket.on('webrtc-signaling', (data) async {
      if (data['type'] == 'offer') {
        _peerConnection = await createPeerConnection({
          'iceServers': [
            {'urls': 'stun:stun.l.google.com:19302'},
            // Add your TURN credentials here if needed
          ]
        });
        _peerConnection!.onTrack = (event) {
          if (event.track.kind == 'video') {
            setState(() => _remoteRenderer.srcObject = event.streams[0]);
          }
        };
        _peerConnection!.onIceCandidate = (candidate) => widget.socket.emit('webrtc-signaling', {'roomId': widget.roomCode, 'type': 'candidate', 'candidate': candidate.candidate, 'sdpMid': candidate.sdpMid, 'sdpMLineIndex': candidate.sdpMLineIndex});
        await _peerConnection!.setRemoteDescription(RTCSessionDescription(data['sdp'], data['type']));
        var answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);
        widget.socket.emit('webrtc-signaling', {'roomId': widget.roomCode, 'type': 'answer', 'sdp': answer.sdp});
      } else if (data['type'] == 'candidate') {
        await _peerConnection?.addCandidate(RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']));
      }
    });
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    _peerConnection?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Advanced Color Matrix for Brightness and Night Mode (ISO boost)
    final double b = _brightness;
    final double o = _nightMode * 100; // Offset gain
    final List<double> matrix = [
      b, 0, 0, 0, o,
      0, b, 0, 0, o,
      0, 0, b, 0, o,
      0, 0, 0, 1, 0,
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. VIDEO DISPLAY WITH FILTERS & ROTATION
          Center(
            child: ClipRect(
              child: Transform.scale(
                scale: _zoom,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(_isMirrored ? math.pi : 0),
                  child: RotatedBox(
                    quarterTurns: _rotation,
                    child: ColorFiltered(
                      colorFilter: ColorFilter.matrix(matrix),
                      child: _remoteRenderer.srcObject != null
                          ? RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                          : const CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. TOP BAR (Settings Toggle)
          Positioned(
            top: 40, right: 20,
            child: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white, size: 30),
              onPressed: () => setState(() => _showSettings = !_showSettings),
            ),
          ),

          // 3. SETTINGS PANEL (Mimicking your image)
          if (_showSettings)
            Positioned(
              bottom: 20, left: 15, right: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brightness Slider
                    _buildSliderRow(Icons.sunny, _brightness, 0.5, 3.0, (v) => setState(() => _brightness = v)),
                    // Night Mode Slider
                    _buildSliderRow(Icons.nights_stay, _nightMode, 0.0, 1.0, (v) => setState(() => _nightMode = v)),
                    // Zoom Slider
                    _buildSliderRow(Icons.zoom_in, _zoom, 1.0, 5.0, (v) {
                      setState(() => _zoom = v);
                      widget.socket.emit('camera-command', {'roomId': widget.roomCode, 'zoom': v});
                    }),
                    const SizedBox(height: 20),
                    // Action Buttons Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildActionButton(Icons.rotate_right, () => setState(() => _rotation = (_rotation + 1) % 4)),
                        _buildActionButton(Icons.flip, () => setState(() => _isMirrored = !_isMirrored)),
                        _buildActionButton(_isTorchOn ? Icons.flash_on : Icons.flash_off, () {
                          setState(() => _isTorchOn = !_isTorchOn);
                          widget.socket.emit('camera-command', {'roomId': widget.roomCode, 'torch': _isTorchOn});
                        }),
                        _buildActionButton(Icons.flip_camera_android, () {
                          widget.socket.emit('camera-command', {'roomId': widget.roomCode, 'command': 'switch'});
                        }),
                        // OK Button
                        ElevatedButton(
                          onPressed: () => setState(() => _showSettings = false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF3E5F5),
                            foregroundColor: Colors.deepPurple,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                          ),
                          child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSliderRow(IconData icon, double value, double min, double max, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: Colors.black87, size: 22),
          Expanded(
            child: Slider(
              value: value,
              min: min, max: max,
              activeColor: Colors.deepPurple,
              inactiveColor: Colors.deepPurple.withOpacity(0.2),
              onChanged: onChanged,
            ),
          ),
          Text(value.toStringAsFixed(1), style: const TextStyle(color: Colors.black87, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: Colors.black87, size: 26),
      onPressed: onPressed,
    );
  }
}
