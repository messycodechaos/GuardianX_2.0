import 'dart:math';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';

class RemoteManager {
  static final RemoteManager _instance = RemoteManager._internal();
  factory RemoteManager() => _instance;
  RemoteManager._internal();

  IO.Socket? socket;
  String? myHostCode;
  List<String> roomHistory = [];

  Future<void> init() async {
    // Connect to your specific Render server
    socket = IO.io('https://safely-871c.onrender.com',
        IO.OptionBuilder().setTransports(['websocket']).build());

    SharedPreferences prefs = await SharedPreferences.getInstance();
    myHostCode = prefs.getString('my_host_code');
    roomHistory = prefs.getStringList('view_history') ?? [];

    if (myHostCode == null) {
      await regenerateHostCode(); // Generate first time
    }
  }

  // Generate a new code and save it
  Future<void> regenerateHostCode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    myHostCode = (1000 + Random().nextInt(9000)).toString();
    await prefs.setString('my_host_code', myHostCode!);
  }

  Future<void> saveToHistory(String code) async {
    if (roomHistory.contains(code) || code.isEmpty) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    roomHistory.insert(0, code);
    if (roomHistory.length > 5) roomHistory.removeLast();
    await prefs.setStringList('view_history', roomHistory);
  }
}