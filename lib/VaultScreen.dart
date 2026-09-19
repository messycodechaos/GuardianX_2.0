import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'record_service.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  bool _isTestingRecord = false;
  int _secondsLeft = 5;
  Timer? _countdownTimer;

  Future<List<FileSystemEntity>> _getAllRecords() async {
    Directory? baseDir = await getExternalStorageDirectory();
    baseDir ??= await getApplicationDocumentsDirectory();
    List<FileSystemEntity> allFiles = [];

    // Check Audio Folder
    Directory audioDir = Directory("${baseDir.path}/GuardianX/Audio");
    if (audioDir.existsSync()) {
      allFiles.addAll(audioDir.listSync().where((f) => f is File && !f.path.endsWith('.tmp')));
    }

    // Check Video Folder
    Directory videoDir = Directory("${baseDir.path}/GuardianX/Video");
    if (videoDir.existsSync()) {
      allFiles.addAll(videoDir.listSync().where((f) => f is File && !f.path.endsWith('.tmp')));
    }

    allFiles.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return allFiles;
  }

  void _runQuickTestRecord() async {
    setState(() {
      _isTestingRecord = true;
      _secondsLeft = 5;
    });

    bool started = await RecordService().startLocalRecord();
    if (!started) {
      if (mounted) {
        setState(() => _isTestingRecord = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to start test recording. Check microphone permission.")),
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
        String? path = await RecordService().stopLocalRecord();
        setState(() => _isTestingRecord = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ Test Evidence Saved: ${path?.split('/').last ?? 'Evidence created'}"),
              backgroundColor: Colors.green,
            ),
          );
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Evidence Vault", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => setState(() {}),
          )
        ],
      ),
      body: Column(
        children: [
          // Quick Test Evidence Banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Test Evidence Vault",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isTestingRecord
                            ? "Recording test audio evidence... ($_secondsLeft s)"
                            : "Record a 5-second audio clip to verify file storage in the vault.",
                        style: TextStyle(
                          color: _isTestingRecord ? Colors.redAccent : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isTestingRecord ? Colors.redAccent : Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isTestingRecord ? null : _runQuickTestRecord,
                  icon: Icon(_isTestingRecord ? Icons.fiber_manual_record : Icons.mic, size: 18),
                  label: Text(_isTestingRecord ? "$_secondsLeft s" : "Test Now"),
                ),
              ],
            ),
          ),

          // Evidence File List
          Expanded(
            child: FutureBuilder<List<FileSystemEntity>>(
              future: _getAllRecords(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, size: 64, color: Colors.grey.withOpacity(0.4)),
                        const SizedBox(height: 16),
                        const Text("No Evidence Files Yet", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            "Recordings from SOS Level 3 or the Test button above will be stored securely here.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
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
                    FileSystemEntity file = snapshot.data![index];
                    String name = file.path.split('/').last;
                    bool isVideo = name.contains('VID_');
                    final stat = file.statSync();
                    final sizeKb = (stat.size / 1024).toStringAsFixed(1);
                    final modifiedStr = stat.modified.toString().substring(0, 19);

                    return Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isVideo ? Colors.blue.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                          child: Icon(
                            isVideo ? Icons.videocam : Icons.mic,
                            color: isVideo ? Colors.blueAccent : Colors.orangeAccent,
                          ),
                        ),
                        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text("$sizeKb KB  •  $modifiedStr", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey),
                          onPressed: () {
                            try {
                              file.deleteSync();
                              setState(() {});
                            } catch (_) {}
                          },
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Evidence Details"),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Filename: $name", style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text("Size: $sizeKb KB"),
                                  Text("Date: $modifiedStr"),
                                  const SizedBox(height: 8),
                                  const Text("Path:", style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text(file.path, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
                              ],
                            ),
                          );
                        },
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