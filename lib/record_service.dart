import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class RecordService {
  static final RecordService _instance = RecordService._internal();
  factory RecordService() => _instance;
  RecordService._internal();

  final AudioRecorder _recorder = AudioRecorder();

  // The path where we will store all audio files
  Future<String> _getFolderPath() async {
    // For Android, we use the public 'Music' folder so it shows in the gallery
    Directory? baseDir = await getExternalStorageDirectory(); // App-specific external
    String newPath = "${baseDir!.path}/GuardianX/Audio";
    Directory(newPath).createSync(recursive: true);
    return newPath;
  }

  Future<void> startLocalRecord() async {
    try {
      if (await _recorder.hasPermission()) {
        final folder = await _getFolderPath();
        final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final String filePath = '$folder/AUD_$timestamp.m4a';

        const config = RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100
        );

        await _recorder.start(config, path: filePath);
        print("⏺️ Background Audio Started: $filePath");
      }
    } catch (e) {
      print("Audio Service Error: $e");
    }
  }

  Future<void> stopLocalRecord() async {
    await _recorder.stop();
    print("✅ Audio Recording Saved.");
  }
}