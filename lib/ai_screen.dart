import 'dart:async';
import 'package:flutter/material.dart';
import 'ai_controller.dart';
import 'fake_call_screen.dart';
import 'app_theme.dart';
import 'sos_model.dart';

class AIScreen extends StatefulWidget {
  final List<EmergencyContact>? contacts;
  final List<SOSLevel>? levels;
  const AIScreen({super.key, this.contacts, this.levels});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  final ai = AIController();
  Timer? _statusTicker;
  String _radarStatus = "Calm radar standby";
  bool _isRadarCalm = true;
  double _uiDecibels = -55.0;

  @override
  void initState() {
    super.initState();
    _refreshRadarStatus();
    _statusTicker = Timer.periodic(const Duration(seconds: 2), (t) {
      if (mounted) setState(() {});
    });
  }

  void _refreshRadarStatus() async {
    final res = await ai.getLiveSafetyScore();
    if (mounted) {
      setState(() {
        _radarStatus = res['status'] ?? "All quiet. No immediate safety concerns detected.";
        _isRadarCalm = res['isQuiet'] ?? true;
      });
    }
  }

  @override
  void dispose() {
    _statusTicker?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // URGENT SAFETY CONFIRMATION PROMPT DIALOG (Requirements 3 & 4)
  // ─────────────────────────────────────────────────────────────
  void _showUrgentSafetyPrompt(IncidentRecord incident) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Timer.periodic(const Duration(seconds: 1), (t) {
              if (dialogCtx.mounted && ai.activePendingIncident != null) {
                setDialogState(() {});
              } else {
                t.cancel();
              }
            });

            return AlertDialog(
              backgroundColor: const Color(0xFF161F33),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFFF334B), width: 2),
              ),
              title: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF334B).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF334B), size: 40),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Possible safety concern detected.\nAre you safe?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              incident.categoryLabel,
                              style: const TextStyle(color: Color(0xFFFF334B), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF334B).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "${(incident.confidence * 100).toStringAsFixed(0)}% Conf",
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(incident.summary, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 8),
                        Row(
                          children: const [
                            Icon(Icons.lock_clock, size: 13, color: Color(0xFF10B981)),
                            SizedBox(width: 4),
                            Text("Evidence durably saved to Vault", style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer, color: Color(0xFFF59E0B), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        "Auto-Escalation in ${ai.pendingCountdownSeconds}s",
                        style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: ai.pendingCountdownSeconds / incident.timeoutSeconds,
                    color: const Color(0xFFFF334B),
                    backgroundColor: Colors.white10,
                  ),
                  const SizedBox(height: 20),

                  // EXACTLY 4 CHOICES:
                  // 1. I'm fine
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      ai.acknowledgeSafety();
                      Navigator.pop(dialogCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("✅ Safety acknowledged. Pending escalation cancelled. Evidence preserved."),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                    },
                    child: const Text("I'm fine", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                  ),
                  const SizedBox(height: 10),

                  // 2. Trigger Level 1
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF59E0B),
                      side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      ai.triggerManualLevel('lvl1', onDispatch: (lvl, inc) {
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("🚨 Triggered $lvl! Contacts alerted."), backgroundColor: const Color(0xFFF59E0B)),
                        );
                      });
                    },
                    child: const Text("Trigger Level 1", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const SizedBox(height: 8),

                  // 3. Trigger Level 2
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFA7B17),
                      side: const BorderSide(color: Color(0xFFFA7B17), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      ai.triggerManualLevel('lvl2', onDispatch: (lvl, inc) {
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("🚨 Triggered $lvl! Location sent."), backgroundColor: const Color(0xFFFA7B17)),
                        );
                      });
                    },
                    child: const Text("Trigger Level 2", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const SizedBox(height: 8),

                  // 4. Trigger Level 3
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF334B),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      ai.triggerManualLevel('lvl3', onDispatch: (lvl, inc) {
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("🚨 Triggered $lvl! Emergency dispatch activated."), backgroundColor: const Color(0xFFFF334B)),
                        );
                      });
                    },
                    child: const Text("Trigger Level 3", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showStorageFailureDialog(String error, IncidentRecord? pendingIncident) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F33),
        title: const Text("Evidence Vault Storage Error", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text("Storage status: $error\n\nIncident is held in memory and will NOT be silently lost."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Dismiss", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () {
              Navigator.pop(ctx);
              ai.testTriggerAcousticAlert(
                onIncidentSaved: (inc) => _showUrgentSafetyPrompt(inc),
                onStorageFailed: (err, inc) => _showStorageFailureDialog(err, inc),
              );
            },
            child: const Text("Retry Saving Evidence"),
          )
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // AI MODULE SETTINGS MODAL (Requirement 5)
  // ─────────────────────────────────────────────────────────────
  void _openAISettingsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "AI Module Settings",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Configure detection categories, confidence thresholds, and emergency escalation.",
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        _settingHeader("Safety Confirmation Timeout: ${ai.safetyConfirmationTimeoutSeconds} seconds"),
                        Slider(
                          value: ai.safetyConfirmationTimeoutSeconds.toDouble(),
                          min: 5,
                          max: 60,
                          divisions: 11,
                          activeColor: AppTheme.crimson,
                          label: "${ai.safetyConfirmationTimeoutSeconds}s",
                          onChanged: (val) {
                            setModalState(() => ai.safetyConfirmationTimeoutSeconds = val.round());
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 12),

                        _settingHeader("Default Automatic Escalation Level"),
                        const SizedBox(height: 6),
                        Row(
                          children: ["lvl1", "lvl2", "lvl3"].map((lvl) {
                            final isSel = ai.defaultEscalationLevel == lvl;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isSel
                                        ? (lvl == 'lvl1' ? Colors.amber : lvl == 'lvl2' ? Colors.orange : AppTheme.crimson)
                                        : AppTheme.card,
                                    side: BorderSide(color: isSel ? Colors.white : AppTheme.cardBorder),
                                  ),
                                  onPressed: () {
                                    setModalState(() => ai.defaultEscalationLevel = lvl);
                                    setState(() {});
                                  },
                                  child: Text(
                                    lvl.toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSel ? Colors.black : Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        _settingHeader("Supported Detection Categories & Thresholds"),
                        const SizedBox(height: 8),
                        ...ai.categoryConfigs.entries.map((entry) {
                          final key = entry.key;
                          final config = entry.value;
                          final label = key.replaceAll('_', ' ').toUpperCase();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                                    Switch(
                                      value: config.enabled,
                                      activeColor: AppTheme.crimson,
                                      onChanged: (v) {
                                        setModalState(() => config.enabled = v);
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                                if (config.enabled) ...[
                                  Row(
                                    children: [
                                      Text("Confidence: ${(config.threshold * 100).toStringAsFixed(0)}%", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                      Expanded(
                                        child: Slider(
                                          value: config.threshold,
                                          min: 0.50,
                                          max: 0.95,
                                          divisions: 9,
                                          activeColor: AppTheme.azure,
                                          onChanged: (v) {
                                            setModalState(() => config.threshold = v);
                                            setState(() {});
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _settingHeader(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAnyMonitoringActive = ai.isVoiceMonitorActive || ai.isVisualGuardActive;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("AI Defense Layer"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: AppTheme.textPrimary),
            onPressed: _openAISettingsModal,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.crimson,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "AUTONOMOUS THREAT SENSING",
                style: TextStyle(
                  color: AppTheme.crimson,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _openAISettingsModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.settings, size: 13, color: AppTheme.azure),
                      SizedBox(width: 4),
                      Text("Thresholds", style: TextStyle(color: AppTheme.azure, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. SAFETY EAR (VOICE MONITOR)
          _aiSwitch(
            "Safety Ear (Voice Monitor)",
            "Real-time audio detection for screaming, distress cries, threats & glass breaking.",
            ai.isVoiceMonitorActive,
                (v) async {
              if (v) {
                bool success = await ai.startAcousticMonitor(
                  onIncidentSaved: (inc) => _showUrgentSafetyPrompt(inc),
                  onStorageFailed: (err, inc) => _showStorageFailureDialog(err, inc),
                  onDecibelUpdate: (db) {
                    if (mounted) setState(() => _uiDecibels = db);
                  },
                );
                setState(() => ai.isVoiceMonitorActive = success);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("🎧 Safety Ear active! Speaking or clapping moves the live dB meter."),
                      backgroundColor: const Color(0xFF10B981),
                      action: SnackBarAction(
                        label: "SIMULATE THREAT",
                        textColor: Colors.white,
                        onPressed: () {
                          ai.testTriggerAcousticAlert(
                            onIncidentSaved: (inc) => _showUrgentSafetyPrompt(inc),
                            onStorageFailed: (err, inc) => _showStorageFailureDialog(err, inc),
                          );
                        },
                      ),
                    ),
                  );
                }
              } else {
                await ai.stopAcousticMonitor();
                setState(() => ai.isVoiceMonitorActive = false);
              }
            },
          ),

          // Safety Ear Live Decibel & Minute Summary Box
          if (ai.isVoiceMonitorActive)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161F33),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "🎙️ Voice AI Acoustic Meter:",
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "${_uiDecibels.toStringAsFixed(1)} dBFS",
                        style: TextStyle(
                          color: _uiDecibels > -25.0 ? Colors.redAccent : Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: ((_uiDecibels + 60) / 60).clamp(0.05, 1.0),
                    color: _uiDecibels > -25.0 ? Colors.redAccent : Colors.amber,
                    backgroundColor: Colors.white12,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Latest Minute Summary: ${ai.currentEarSummary}",
                    style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.3),
                  ),
                ],
              ),
            ),

          // 2. SAFETY EYE (VISUAL GUARD)
          _aiSwitch(
            "Safety Eye (Visual Guard)",
            "Camera-based detection of weapons, aggressive gestures, and multi-frame followers.",
            ai.isVisualGuardActive,
                (v) async {
              if (v) {
                bool success = await ai.startVisualGuard();
                setState(() => ai.isVisualGuardActive = success);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("👁️ Safety Eye armed: ${ai.visualGuardStatus}"),
                      backgroundColor: Colors.blueAccent,
                    ),
                  );
                }
              } else {
                ai.stopVisualGuard();
                setState(() => ai.isVisualGuardActive = false);
              }
            },
          ),

          // Safety Eye Live Minute Summary Box
          if (ai.isVisualGuardActive)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161F33),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        "👁️ Visual AI Frame Scanner:",
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "ACTIVE SCAN",
                        style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Latest Minute Summary: ${ai.currentEyeSummary}",
                    style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.3),
                  ),
                ],
              ),
            ),

          // 3. SMART SAFETY RADAR (Calm normal status display)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isAnyMonitoringActive ? const Color(0xFF10B981).withOpacity(0.4) : AppTheme.cardBorder,
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.radar,
                      color: isAnyMonitoringActive ? const Color(0xFF10B981) : AppTheme.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Smart Safety Radar",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isAnyMonitoringActive ? const Color(0xFF10B981) : AppTheme.textMuted).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isAnyMonitoringActive ? "MONITORING" : "STANDBY",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isAnyMonitoringActive ? const Color(0xFF10B981) : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isAnyMonitoringActive
                      ? "All quiet. No immediate safety concerns detected."
                      : "Monitoring is inactive. Enable Safety Ear or Safety Eye to activate radar.",
                  style: TextStyle(
                    fontSize: 13,
                    color: isAnyMonitoringActive ? const Color(0xFF10B981) : AppTheme.textSecondary,
                    fontWeight: isAnyMonitoringActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _radarStatus,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),

          // 4. MINUTE-BY-MINUTE AI PERCEPTION FEED (Builds User Trust)
          if (ai.perceptionLogs.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.history, color: AppTheme.azure, size: 18),
                      SizedBox(width: 8),
                      Text(
                        "AI Live Perception Timeline",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                      ),
                      Spacer(),
                      Text("UPDATES EVERY 60s", style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...ai.perceptionLogs.take(5).map((log) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          log['source'] == 'safety_ear' ? Icons.mic : Icons.videocam,
                          size: 16,
                          color: log['source'] == 'safety_ear' ? Colors.amber : Colors.blueAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    log['source'] == 'safety_ear' ? "Safety Ear Acoustic Log" : "Safety Eye Visual Log",
                                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                  Text(
                                    log['timestamp'] ?? '',
                                    style: const TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                log['summary'] ?? '',
                                style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),

          const SizedBox(height: 10),
          const Divider(color: AppTheme.cardBorder),
          const SizedBox(height: 16),

          // 5. DE-ESCALATION: TRIGGER FAKE GUARDIAN CALL
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.azure,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "DE-ESCALATION & DETERRENCE",
                style: TextStyle(
                  color: AppTheme.azure,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            color: AppTheme.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.cardBorder),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.azure.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_in_talk, color: AppTheme.azure),
              ),
              title: const Text(
                "Trigger Fake Guardian Call",
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: const Text(
                "Starts loud tactical AI voice dialogue to project remote security presence.",
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const FakeCallScreen())),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiSwitch(String title, String subtitle, bool val, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: val ? AppTheme.crimson.withOpacity(0.5) : AppTheme.cardBorder,
          width: 1.2,
        ),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
          ),
        ),
        value: val,
        onChanged: onChanged,
        activeColor: AppTheme.crimson,
        activeTrackColor: AppTheme.crimson.withOpacity(0.3),
      ),
    );
  }
}