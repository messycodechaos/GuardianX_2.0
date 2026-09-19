import 'package:flutter/material.dart';
import 'camera_service.dart';

class HostScreen extends StatefulWidget {
  final String roomCode;
  const HostScreen({Key? key, required this.roomCode}) : super(key: key);
  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const Text("Host Dashboard"), backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mic, color: Colors.green, size: 50),
            const Text("AUDIO & VIDEO LIVE", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text(widget.roomCode, style: const TextStyle(color: Colors.white, fontSize: 60, fontWeight: FontWeight.bold, letterSpacing: 10)),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              icon: const Icon(Icons.flip_camera_android),
              label: const Text("FLIP CAMERA"),
              onPressed: () {
                // CameraService().switchCamera();
                setState(() {});
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Back to Home")),
          ],
        ),
      ),
    );
  }
}