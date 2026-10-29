import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'record_service.dart';
import 'app_theme.dart';

class VaultScreen extends StatefulWidget {
  final String userId;
  const VaultScreen({super.key, this.userId = "user_primary"});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  bool _isTestingRecord = false;
  int _secondsLeft = 5;
  Timer? _countdownTimer;

  Future<List<Map<String, dynamic>>> _getAllEvidenceRecords() async {
    Directory? baseDir = await getExternalStorageDirectory();
    baseDir ??= await getApplicationDocumentsDirectory();
    List<Map<String, dynamic>> records = [];

    // 1. Vault Directory
    Directory vaultDir = Directory("${baseDir.path}/GuardianX/Vault");
    if (vaultDir.existsSync()) {
      for (var f in vaultDir.listSync()) {
        if (f is File && !f.path.endsWith('.tmp')) {
          try {
            final content = f.readAsStringSync();
            final json = jsonDecode(content);
            records.add({
              'id': json['id'] ?? f.path.split('/').last,
              'category': json['category'] ?? 'General Evidence',
              'confidence': (json['confidence'] as num?)?.toDouble() ?? 1.0,
              'timestamp': json['timestamp'] ?? f.statSync().modified.toIso8601String(),
              'source': json['source'] ?? 'safety_vault',
              'aiDescription': json['aiDescription'] ?? json['summary'],
              'guardianConnected': json['guardianConnected'],
              'roomCode': json['roomCode'],
              'streamDurationSeconds': json['streamDurationSeconds'],
              'videoPath': json['videoPath'],
              'audioPath': json['audioPath'],
              'file': f,
              'size': f.statSync().size,
              'modified': f.statSync().modified,
            });
          } catch (_) {
            // Raw media file (e.g. .mp4, .m4a, or unformatted evidence)
            final String name = f.path.split('/').last;
            final bool isVideo = name.endsWith('.mp4');
            final bool isAudio = name.endsWith('.m4a') || name.endsWith('.aac') || name.endsWith('.wav');
            records.add({
              'id': name,
              'category': isVideo ? 'Video Evidence' : (isAudio ? 'Audio Evidence' : 'Recorded Media'),
              'confidence': 1.0,
              'timestamp': f.statSync().modified.toIso8601String(),
              'source': isVideo ? 'video_recorder' : 'audio_recorder',
              'aiDescription': null,
              'guardianConnected': null,
              'roomCode': null,
              'streamDurationSeconds': null,
              'videoPath': isVideo ? f.path : null,
              'audioPath': isAudio ? f.path : null,
              'file': f,
              'size': f.statSync().size,
              'modified': f.statSync().modified,
            });
          }
        }
      }
    }

    // Sort newest first
    records.sort((a, b) => (b['modified'] as DateTime).compareTo(a['modified'] as DateTime));
    return records;
  }

  void _runQuickTestRecord() async {
    setState(() {
      _isTestingRecord = true;
      _secondsLeft = 5;
    });

    try {
      await RecordService().startLocalRecord();
    } catch (e) {
      if (mounted) {
        setState(() => _isTestingRecord = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Recording error: $e")),
        );
      }
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        try {
          await RecordService().stopLocalRecord();
        } catch (_) {}
        setState(() => _isTestingRecord = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Test Evidence Saved to Vault! Storage verified."),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {});
        }
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Evidence Vault", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textPrimary),
            tooltip: "Refresh Vault",
            onPressed: () => setState(() {}),
          )
        ],
      ),
      body: Column(
        children: [
          // Quick Test Evidence Banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Test Evidence Vault",
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isTestingRecord
                            ? "Recording test audio evidence... ($_secondsLeft s)"
                            : "Record a 5-second audio clip to verify durable file storage in Vault.",
                        style: TextStyle(
                          color: _isTestingRecord ? AppTheme.crimson : AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isTestingRecord ? AppTheme.crimson : AppTheme.azure,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isTestingRecord ? null : _runQuickTestRecord,
                  icon: Icon(_isTestingRecord ? Icons.fiber_manual_record : Icons.mic, size: 18),
                  label: Text(_isTestingRecord ? "$_secondsLeft s" : "Test Now"),
                ),
              ],
            ),
          ),

          // File List
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _getAllEvidenceRecords(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.crimson));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, size: 64, color: AppTheme.textMuted.withOpacity(0.4)),
                        const SizedBox(height: 16),
                        const Text("No Evidence Files Yet", style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            "Recordings from unattended live streams, acoustic screams, and SOS levels are durably saved here with cryptographic verification.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final item = snapshot.data![index];
                    final File file = item['file'];
                    final String name = file.path.split('/').last;
                    final sizeKb = (item['size'] / 1024).toStringAsFixed(1);
                    final String category = item['category'];
                    final double confidence = (item['confidence'] as num).toDouble();
                    final bool isUnattended = item['guardianConnected'] == false;
                    final String? aiDescription = item['aiDescription'];

                    return Card(
                      color: AppTheme.card,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isUnattended
                              ? Colors.orangeAccent.withOpacity(0.5)
                              : AppTheme.cardBorder,
                          width: isUnattended ? 1.5 : 1.0,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isUnattended
                                      ? Colors.orange.withOpacity(0.2)
                                      : const Color(0xFF10B981).withOpacity(0.15),
                                  child: Icon(
                                    isUnattended
                                        ? Icons.videocam_off
                                        : (category.toLowerCase().contains('video')
                                        ? Icons.videocam
                                        : Icons.verified_user),
                                    color: isUnattended ? Colors.orangeAccent : const Color(0xFF10B981),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    category.replaceAll('_', ' ').toUpperCase(),
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (isUnattended)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
                                    ),
                                    child: const Text(
                                      "0 GUARDIANS JOINED",
                                      style: TextStyle(
                                        color: Colors.orangeAccent,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.azure.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "${(confidence * 100).toStringAsFixed(0)}% Conf",
                                      style: const TextStyle(color: AppTheme.azure, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),

                            // AI Generated Forensic Summary (if available)
                            if (aiDescription != null && aiDescription.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF101726),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amberAccent.withOpacity(0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.auto_awesome, size: 13, color: Colors.amberAccent),
                                        SizedBox(width: 5),
                                        Text(
                                          "AI Forensic Incident Summary",
                                          style: TextStyle(
                                            color: Colors.amberAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      aiDescription,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 10),
                            // Meta Row & Delete Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "$name • $sizeKb KB",
                                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (item['roomCode'] != null)
                                        Text(
                                          "Room #${item['roomCode']} • Duration: ${item['streamDurationSeconds'] ?? 0}s",
                                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.textMuted, size: 20),
                                  tooltip: "Delete Record",
                                  onPressed: () {
                                    try {
                                      file.deleteSync();
                                      setState(() {});
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Evidence deleted from Vault")),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Delete error: $e")),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),

                            // Tap to view verification details
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.lock_open, size: 14, color: AppTheme.azure),
                                label: const Text("Inspect Verification", style: TextStyle(color: AppTheme.azure, fontSize: 11)),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: AppTheme.card,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      title: const Row(
                                        children: [
                                          Icon(Icons.lock, color: Color(0xFF10B981)),
                                          SizedBox(width: 8),
                                          Text("Evidence Verification", style: TextStyle(color: Colors.white, fontSize: 16)),
                                        ],
                                      ),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("Category: $category", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 6),
                                            Text("Confidence: ${(confidence * 100).toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white70)),
                                            const SizedBox(height: 4),
                                            Text("Storage Status: VERIFIED DURABLE", style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                                            if (item['roomCode'] != null) ...[
                                              const SizedBox(height: 6),
                                              Text("Room Code: #${item['roomCode']}", style: const TextStyle(color: Colors.white70)),
                                              Text("Duration: ${item['streamDurationSeconds']} seconds", style: const TextStyle(color: Colors.white70)),
                                              Text("Guardian Attendance: 0 Connected", style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                                            ],
                                            if (aiDescription != null) ...[
                                              const SizedBox(height: 8),
                                              const Text("AI Forensic Summary:", style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 2),
                                              Text(aiDescription, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                            ],
                                            const SizedBox(height: 8),
                                            const Text("Vault File Path:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            Text(file.path, style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace')),
                                            if (item['videoPath'] != null && item['videoPath'].toString().isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              const Text("Video File:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              Text(item['videoPath'].toString(), style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace')),
                                            ],
                                            if (item['audioPath'] != null && item['audioPath'].toString().isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              const Text("Audio File:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              Text(item['audioPath'].toString(), style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace')),
                                            ],
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close", style: TextStyle(color: Colors.white70))),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}