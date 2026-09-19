import 'package:flutter/material.dart';
import 'ai_controller.dart';
import 'fake_call_screen.dart';

class AIScreen extends StatefulWidget {
  const AIScreen({super.key});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  final AIController ai = AIController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("AI Defense Layer", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. ACOUSTIC MONITOR (SAFETY EAR)
          _aiSwitch(
            "Safety Ear (Voice Monitor)",
            "Automatically triggers SOS if it hears screams or glass breaking.",
            ai.isVoiceMonitorActive,
                (v) async {
              if (v) {
                bool success = await ai.startAcousticMonitor((reason, db) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(child: Text("🚨 $reason (${db.toStringAsFixed(1)} dB)")),
                        ],
                      ),
                      backgroundColor: Colors.redAccent,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                });

                setState(() => ai.isVoiceMonitorActive = success);

                if (!mounted) return;
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("🎧 Safety Ear listening! (Clap loudly or tap TEST NOW)"),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 4),
                      action: SnackBarAction(
                        label: "TEST NOW",
                        textColor: Colors.white,
                        onPressed: () {
                          ai.testTriggerAcousticAlert((reason, db) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("🚨 $reason (${db.toStringAsFixed(1)} dB)"),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          });
                        },
                      ),
                    ),
                  );
                } else {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Microphone Permission Required"),
                      content: const Text("Safety Ear needs microphone access to detect screams. Please grant permission in device settings."),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
                      ],
                    ),
                  );
                }
              } else {
                await ai.stopAcousticMonitor();
                setState(() => ai.isVoiceMonitorActive = false);
              }
            },
          ),

          // 2. VISUAL GUARD (SAFETY EYE)
          _aiSwitch(
            "Safety Eye (Visual Guard)",
            "AI analyzes camera frames for weapons or suspicious followers.",
            ai.isVisualGuardActive,
                (v) async {
              if (v) {
                bool success = await ai.startVisualGuard();
                setState(() => ai.isVisualGuardActive = success);
                if (!mounted) return;
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("👁️ Safety Eye Armed: ${ai.visualGuardStatus}"),
                      backgroundColor: Colors.blueAccent,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                } else {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Camera Permission Required"),
                      content: const Text("Visual Guard requires camera access. Please grant camera permission in device settings."),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
                      ],
                    ),
                  );
                }
              } else {
                ai.stopVisualGuard();
                setState(() => ai.isVisualGuardActive = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Safety Eye disarmed"), duration: Duration(seconds: 2)),
                );
              }
            },
          ),

          // 3. SMART SAFETY RADAR
          _aiSwitch(
            "Smart Safety Radar",
            "Notifies you if you enter high-risk areas based on historical data.",
            ai.isSmartRadarActive,
                (v) async {
              if (v) {
                setState(() => ai.isSmartRadarActive = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("📡 Querying GPS location and risk zones..."), duration: Duration(seconds: 1)),
                );
                final res = await ai.getLiveSafetyScore();
                if (!mounted) return;
                final double score = res['score'] ?? 85.0;
                final String status = res['status'] ?? 'Safe';

                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Row(
                      children: [
                        Icon(Icons.radar, color: score < 50 ? Colors.orange : Colors.green),
                        const SizedBox(width: 8),
                        const Text("Radar Diagnostics"),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Safety Score: ${score.toStringAsFixed(0)} / 100", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 8),
                        Text("Condition: $status"),
                        const SizedBox(height: 4),
                        if (res['lat'] != 0.0)
                          Text("GPS: ${res['lat'].toStringAsFixed(4)}, ${res['lng'].toStringAsFixed(4)}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Acknowledge")),
                    ],
                  ),
                );
              } else {
                setState(() => ai.isSmartRadarActive = false);
              }
            },
          ),

          const SizedBox(height: 30),

          // FAKE CALL TRIGGER BUTTON
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.phone_in_talk, color: Colors.white),
            label: const Text("Simulate Fake Guardian Call", style: TextStyle(fontSize: 16, color: Colors.white)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const FakeCallScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _aiSwitch(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.blueAccent,
            ),
          ],
        ),
      ),
    );
  }
}