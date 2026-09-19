import 'dart:io';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class VideoRecordService {
  static final VideoRecordService _instance = VideoRecordService._internal();
  factory VideoRecordService() => _instance;
  VideoRecordService._internal();

  MediaRecorder? _mediaRecorder;

  Future<String> _getFolderPath() async {
    Directory? baseDir = await getExternalStorageDirectory();
    String newPath = "${baseDir!.path}/GuardianX/Video";
    Directory(newPath).createSync(recursive: true);
    return newPath;
  }

  Future<void> startVideoRecording(MediaStream stream) async {
    try {
      final folder = await _getFolderPath();
      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String filePath = '$folder/VID_$timestamp.mp4';

      _mediaRecorder = MediaRecorder();

      // Start recording the first video track from the stream
      await _mediaRecorder!.start(
        filePath,
        videoTrack: stream.getVideoTracks().first,
      );

      print("🎥 Background Video Started: $filePath");
    } catch (e) {
      print("Video Service Error: $e");
    }
  }

  Future<void> stopVideoRecording() async {
    if (_mediaRecorder != null) {
      await _mediaRecorder!.stop();
      _mediaRecorder = null;
      print("✅ Video Saved to Gallery folder.");
    }
  }
}