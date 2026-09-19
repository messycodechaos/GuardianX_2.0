import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({super.key});
  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _startGuardianVoice();
  }

  void _startGuardianVoice() async {
    await Future.delayed(const Duration(seconds: 2));
    // The AI talks loudly so the attacker can hear it
    await _tts.setVolume(1.0);
    await _tts.speak("Hey, I'm just around the corner. I can see you on the GPS. I'm arriving in 60 seconds with the security team.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(radius: 50, backgroundColor: Colors.grey, child: Icon(Icons.person, size: 50, color: Colors.white)),
          const SizedBox(height: 20),
          const Text("Guardian Center", style: TextStyle(fontSize: 28, color: Colors.white)),
          const Text("00:14", style: TextStyle(color: Colors.green)),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _callIcon(Icons.mic_off, "Mute"),
              _callIcon(Icons.dialpad, "Keypad"),
              _callIcon(Icons.volume_up, "Speaker"),
            ],
          ),
          const SizedBox(height: 50),
          FloatingActionButton(
            backgroundColor: Colors.red,
            onPressed: () { _tts.stop(); Navigator.pop(context); },
            child: const Icon(Icons.call_end, color: Colors.white),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _callIcon(IconData i, String l) => Column(children: [Icon(i, color: Colors.white), Text(l, style: const TextStyle(color: Colors.white, fontSize: 10))]);
}