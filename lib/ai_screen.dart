import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
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

            final secondsLeft = ai.pendingCountdownSeconds;

            return AlertDialog(
              backgroundColor: const Color(0xFF1B0B0E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.redAccent, width: 2),
              ),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "CRITICAL SAFETY PROMPT",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        incident.categoryLabel.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      incident.summary,
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    // Evidence Vault Persistence confirmation
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock, color: Colors.greenAccent, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Evidence safely saved to Vault:\n${incident.filePath.split('/').last}",
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Automatic Escalation Countdown
                    Center(
                      child: Column(
                        children: [
                          Text(
                            "Auto-Escalation to ${incident.defaultLevel.toUpperCase()} in:",
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${secondsLeft}s",
                            style: TextStyle(
                              color: secondsLeft <= 5 ? Colors.redAccent : Colors.orangeAccent,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                // 1. "I AM FINE" (Preserves evidence, cancels escalation)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.greenAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      ai.acknowledgeSafety();
                      Navigator.of(dialogCtx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Acknowledge: You are marked SAFE. Incident recorded in Vault."),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    child: const Text(
                      "I AM FINE (Cancel Escalation)",
                      style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // 2. Manual Level Escalations (Requirements 4 & 5)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[800],
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          ai.triggerManualLevel(
                            'lvl1',
                            onDispatch: (lvl, inc) => _dispatchCustomAlert(lvl, inc),
                          );
                          Navigator.of(dialogCtx).pop();
                        },
                        child: const Text("Lvl 1 Alert", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[900],
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          ai.triggerManualLevel(
                            'lvl2',
                            onDispatch: (lvl, inc) => _dispatchCustomAlert(lvl, inc),
                          );
                          Navigator.of(dialogCtx).pop();
                        },
                        child: const Text("Lvl 2 Alert", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[900],
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          ai.triggerManualLevel(
                            'lvl3',
                            onDispatch: (lvl, inc) => _dispatchCustomAlert(lvl, inc),
                          );
                          Navigator.of(dialogCtx).pop();
                        },
                        child: const Text("Lvl 3 Alert", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showStorageFailureDialog(String error, IncidentRecord? incident) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Evidence Vault Warning", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        content: Text(
          "$error\n\nIncident evidence could not be durably recorded. Automatic dispatch paused.",
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Acknowledge", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _dispatchCustomAlert(String level, IncidentRecord incident) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("🚨 Dispatched $level for ${incident.categoryLabel}!"),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SENSITIVITY THRESHOLDS MODAL (Requirement 6)
  // ─────────────────────────────────────────────────────────────
  void _openThresholdsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Sensitivity Thresholds",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const Text(
                      "Adjust confidence triggers (0.50 - 0.95) to minimize false positives.",
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const Divider(height: 24, color: AppTheme.cardBorder),
                    ...ai.categoryConfigs.entries.map((entry) {
                      final category = entry.key;
                      final config = entry.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatCategoryTitle(category),
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Switch(
                                value: config.enabled,
                                activeColor: AppTheme.crimson,
                                onChanged: (val) {
                                  setModalState(() => config.enabled = val);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                          if (config.enabled)
                            Row(
                              children: [
                                const Text("Sensitivity: ", style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                Expanded(
                                  child: Slider(
                                    value: config.threshold,
                                    min: 0.50,
                                    max: 0.95,
                                    divisions: 9,
                                    label: "${(config.threshold * 100).toInt()}%",
                                    activeColor: AppTheme.azure,
                                    onChanged: (val) {
                                      setModalState(() => config.threshold = val);
                                      setState(() {});
                                    },
                                  ),
                                ),
                                Text(
                                  "${(config.threshold * 100).toInt()}%",
                                  style: const TextStyle(
                                    color: AppTheme.azure,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 6),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatCategoryTitle(String cat) {
    switch (cat) {
      case ThreatCategory.screaming:
        return "Screaming & Shouting";
      case ThreatCategory.criesForHelp:
        return "Cries for Help / Distress";
      case ThreatCategory.panicDistress:
        return "Panic / Hyperventilation";
      case ThreatCategory.threateningVocal:
        return "Aggressive / Threatening Voices";
      case ThreatCategory.glassBreaking:
        return "Glass Breaking / Sharp Impact";
      case ThreatCategory.weapons:
        return "Weapon / Sharp Object Detection";
      case ThreatCategory.suspiciousGestures:
        return "Suspicious / Strike Gestures";
      case ThreatCategory.followerTracking:
        return "Suspicious Follower Tracking";
      default:
        return cat.replaceAll('_', ' ').toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("GuardianX AI Hub", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: AppTheme.azure),
            tooltip: "Threat Sensitivity",
            onPressed: _openThresholdsModal,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─────────────────────────────────────────────────────────────
            // SMART SAFETY RADAR (Calm Normal Status - Requirement 1)
            // ─────────────────────────────────────────────────────────────
            _buildRadarStatusCard(),
            const SizedBox(height: 20),

            // ─────────────────────────────────────────────────────────────
            // MONITORING SWITCHES
            // ─────────────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Active Perception Modules",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: _openThresholdsModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.azure.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.azure.withOpacity(0.4)),
                    ),
                    child: Row(
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
                  final result = await ai.startAcousticMonitor(
                    onIncidentSaved: (inc) => _showUrgentSafetyPrompt(inc),
                    onStorageFailed: (err, inc) => _showStorageFailureDialog(err, inc),
                    onDecibelUpdate: (db) {
                      if (mounted) setState(() => _uiDecibels = db);
                    },
                  );

                  if (!result.success) {
                    setState(() => ai.isVoiceMonitorActive = false);

                    if (!mounted) return;

                    if (result.isPermanentlyDenied) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppTheme.card,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Row(
                            children: [
                              Icon(Icons.mic_off, color: Colors.redAccent),
                              SizedBox(width: 8),
                              Text("Microphone Permission", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          content: const Text(
                            "Safety Ear requires microphone access to detect screams and distress calls in real-time.\n\nPermission was permanently disabled. Please tap 'Open Settings' and enable Microphone permissions.",
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.crimson,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.settings, size: 16, color: Colors.white),
                              label: const Text("Open Settings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                Navigator.pop(ctx);
                                openAppSettings();
                              },
                            ),
                          ],
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(result.errorMessage)),
                            ],
                          ),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    return;
                  }

                  setState(() => ai.isVoiceMonitorActive = true);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("🎧 Safety Ear active! Speaking or clapping moves the live dB meter."),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
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
                            color: _uiDecibels > -25 ? Colors.redAccent : Colors.amberAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: ((_uiDecibels + 80) / 70).clamp(0.05, 1.0),
                      backgroundColor: Colors.white10,
                      color: _uiDecibels > -25 ? Colors.redAccent : Colors.amberAccent,
                      minHeight: 5,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ai.currentEarSummary,
                      style: const TextStyle(color: Colors.white60, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),

            // 2. SAFETY EYE (VISUAL GUARD)
            _aiSwitch(
              "Safety Eye (Visual Guard)",
              "Continuously scans frames for weapon contours, strike gestures & suspicious followers.",
              ai.isVisualGuardActive,
                  (v) async {
                if (v) {
                  bool success = await ai.startVisualGuard();
                  setState(() => ai.isVisualGuardActive = success);
                } else {
                  ai.stopVisualGuard();
                  setState(() => ai.isVisualGuardActive = false);
                }
              },
            ),

            // Safety Eye Status Box
            if (ai.isVisualGuardActive)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161F33),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.azure.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "👁️ Visual Perimeter Status:",
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          ai.visualGuardStatus,
                          style: const TextStyle(color: AppTheme.azure, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ai.currentEyeSummary,
                      style: const TextStyle(color: Colors.white60, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),

            // 3. SMART RADAR
            _aiSwitch(
              "Predictive Smart Radar",
              "Evaluates time, transit velocity & local safety perimeter to maintain calm normal state.",
              ai.isSmartRadarActive,
                  (v) => setState(() => ai.isSmartRadarActive = v),
            ),
            const SizedBox(height: 20),

            // ─────────────────────────────────────────────────────────────
            // AI REACTION LOGS & MINUTE AUDIT (Requirement 2)
            // ─────────────────────────────────────────────────────────────
            const Text(
              "Recent Minute-by-Minute Perception Logs",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildPerceptionLogs(),
            const SizedBox(height: 24),

            // ─────────────────────────────────────────────────────────────
            // ESCALATION DIALOG PREVIEW TEST BUTTON (Requirement 4 & 5)
            // ─────────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "System Test & Verification",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Test verification triggers the full flow: evidence writing to Vault, 15-second countdown, 'I am fine' safety confirmation, and automated escalation dispatch.",
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.crimson,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.notification_important, color: Colors.white),
                      label: const Text(
                        "Simulate Acoustic Threat (Trigger Flow)",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        ai.testTriggerAcousticAlert(
                          onIncidentSaved: (inc) => _showUrgentSafetyPrompt(inc),
                          onStorageFailed: (err, inc) => _showStorageFailureDialog(err, inc),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGET HELPERS
  // ─────────────────────────────────────────────────────────────
  Widget _buildRadarStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isRadarCalm ? const Color(0xFF0F1E1C) : const Color(0xFF261014),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isRadarCalm ? Colors.green.withOpacity(0.4) : Colors.red.withOpacity(0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isRadarCalm ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
            ),
            child: Icon(
              _isRadarCalm ? Icons.shield_outlined : Icons.warning_amber_rounded,
              color: _isRadarCalm ? Colors.greenAccent : Colors.redAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isRadarCalm ? "CALM STATUS NORMAL" : "ELEVATED ALERT",
                      style: TextStyle(
                        color: _isRadarCalm ? Colors.greenAccent : Colors.redAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      "Radar: ${ai.isSmartRadarActive ? 'Active' : 'Standby'}",
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _radarStatus,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ai.isVoiceMonitorActive || ai.isVisualGuardActive
                      ? "Acoustic and perimeter sensors active."
                      : "Monitoring is inactive. Enable Safety Ear or Safety Eye to activate radar.",
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerceptionLogs() {
    if (ai.perceptionLogs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: const Center(
          child: Text(
            "Perception logs will record every minute when Safety Ear or Eye is armed.",
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ai.perceptionLogs.length,
      itemBuilder: (context, idx) {
        final log = ai.perceptionLogs[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cardBorder.withOpacity(0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                log['source'] == 'safety_ear' ? Icons.mic : Icons.videocam,
                size: 16,
                color: log['source'] == 'safety_ear' ? Colors.amber : Colors.blueAccent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          log['source'] == 'safety_ear' ? "Safety Ear Acoustic Log" : "Safety Eye Visual Log",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          log['timestamp'],
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      log['summary'],
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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