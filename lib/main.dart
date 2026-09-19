import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'navigation_screen.dart';
import 'otp_screen.dart';

// Service Imports
import 'sos_model.dart';
import 'camera_service.dart';
import 'host_screen.dart';
import 'viewer_screen.dart';
import 'record_service.dart';
import 'video_record_service.dart';
import 'location_sms_service.dart';
import 'ai_screen.dart'; // NEW
import 'package:email_otp/email_otp.dart';


class RemoteManager {
  static final RemoteManager _instance = RemoteManager._internal();
  factory RemoteManager() => _instance;
  RemoteManager._internal();
  IO.Socket? socket; String? myHostCode;
  String? savedGroupLink;

  Future<void> init() async {
    socket = IO.io('https://safely-871c.onrender.com', IO.OptionBuilder().setTransports(['websocket']).enableAutoConnect().build());
    SharedPreferences prefs = await SharedPreferences.getInstance();
    myHostCode = prefs.getString('h_code') ?? (1000 + Random().nextInt(9000)).toString();
    savedGroupLink = prefs.getString('wa_group_link') ?? "";
    await prefs.setString('h_code', myHostCode!);
  }

  Future<void> saveGroupLink(String link) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    savedGroupLink = link;
    await prefs.setString('wa_group_link', link);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(channelId: 'guard_final', channelName: 'GuardianX', channelImportance: NotificationChannelImportance.HIGH, priority: NotificationPriority.HIGH, iconData: const NotificationIconData(resType: ResourceType.mipmap, resPrefix: ResourcePrefix.ic, name: 'launcher')),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: const ForegroundTaskOptions(interval: 5000, allowWakeLock: true),
    );
  }
  await RemoteManager().init();
  runApp(const GuardianXApp());
}

class GuardianXApp extends StatelessWidget {
  const GuardianXApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0A0E21), primaryColor: Colors.redAccent), home: const SplashScreen());
}

// --- 1. SPLASH SCREEN (PULSING) ---
// --- THE ELITE MASTER LEVEL CINEMATIC SPLASH SCREEN ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _zoomController;
  late Animation<double> _zoomAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Setup Cinematic Zoom (Ken Burns Effect)
    _zoomController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..forward();

    _zoomAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.linear),
    );

    // 2. Setup Smooth Text Fade
    _fadeController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _fadeController.forward();

    // 3. Auto-Navigate after 6 seconds (to enjoy the art)
    Timer(const Duration(seconds: 6), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The Elite Image Link provided
    const String eliteImageUrl = "https://chatgpt.com/backend-api/estuary/content?id=file_000000001df07208b91858653e847675&ts=494381&p=fs&cid=1&sig=6728f8a7c1a06dccc5ff9559d0b9726ecd35086db0d736ff7eba2c9e8c043060&v=0";

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. THE ZOOMING BACKGROUND ARTWORK
          ScaleTransition(
            scale: _zoomAnimation,
            child: Image.network(
              eliteImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(color: Colors.black),
            ),
          ),

          // 2. PROTECTIVE VIGNETTE (Darkens edges to focus on center)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.95),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),

          // 3. OVERLAY ENERGY GLOW (Bottom area)
          Positioned(
            bottom: -50,
            left: -50,
            right: -50,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.15),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          // 4. THE BRANDING & SYSTEM STATUS
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Ultra-Modern Title
                Text(
                  "GUARDIAN X",
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 18,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: Colors.cyanAccent.withOpacity(0.7), blurRadius: 25),
                      const Shadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "ENCRYPTED SAFETY PROTOCOL v3.0",
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 6,
                    color: Colors.cyanAccent.withOpacity(0.9),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 100),

                // Minimalist Energy Bar
                Container(
                  width: 180,
                  height: 1,
                  child: const LinearProgressIndicator(
                    backgroundColor: Colors.white10,
                    color: Colors.cyanAccent,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "ESTABLISHING SECURE CLOUD LINK",
                  style: TextStyle(
                    color: Colors.white30,
                    fontSize: 7,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// --- 2. LOGIN PAGE (PASSWORD ADDED) ---

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool isSending = false;
  EmailOTP myAuth = EmailOTP();

  final emailController = TextEditingController();
  final passController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  // --- THE FIX: SMART FAIL-SAFE OTP LOGIC ---
  void _sendOTP() async {
    if (emailController.text.isEmpty || !emailController.text.contains("@")) {
      _showSnack("Please enter a valid email");
      return;
    }

    setState(() => isSending = true);

    try {
      myAuth.setConfig(
        appEmail: "guard@safety.com",
        appName: "GuardianX Hub",
        userEmail: emailController.text,
        otpLength: 4,
        otpType: OTPType.digitsOnly,
      );

      // Attempt to reach the cloud server
      bool result = await myAuth.sendOTP();

      if (result) {
        _showSnack("OTP Sent! Check your email.");
      } else {
        // FAIL-SAFE: If the server is down, we don't crash
        _showSnack("Mail Server Busy. Using Demo Code: 1234", isError: true);
      }

      // We move to OTP screen even if server fails so the demo continues
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (c) => OTPScreen(
          auth: myAuth,
          email: emailController.text,
          phone: phoneController.text,
          isDemoMode: !result, // Tell the next screen if we are in demo mode
        )));
      }
    } catch (e) {
      // If the API throws a "Failed to fetch" error (your error)
      _showSnack("Network Error. Using Demo Code: 1234", isError: true);

      Navigator.push(context, MaterialPageRoute(builder: (c) => OTPScreen(
        auth: myAuth,
        email: emailController.text,
        phone: phoneController.text,
        isDemoMode: true,
      )));
    } finally {
      setState(() => isSending = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.orange : Colors.blue,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const SizedBox(height: 80),
            const Icon(Icons.shield, size: 80, color: Colors.redAccent),
            const SizedBox(height: 20),
            const Text("GUARDIAN X", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4)),
            const SizedBox(height: 50),

            if (!isLogin) ...[
              _field(nameController, "Full Name", Icons.person_outline),
              const SizedBox(height: 15),
              _field(phoneController, "Phone", Icons.phone_android),
              const SizedBox(height: 15),
            ],

            _field(emailController, "Guardian Email", Icons.email_outlined),
            const SizedBox(height: 15),

            if (isLogin)
              _field(passController, "Security Passkey", Icons.vpn_key_outlined, isPass: true),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                onPressed: isSending ? null : (isLogin ? () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const MainNavigation()));
                } : _sendOTP),
                child: isSending
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(isLogin ? "AUTHORIZE" : "GENERATE OTP"),
              ),
            ),

            TextButton(
              onPressed: () => setState(() => isLogin = !isLogin),
              child: Text(isLogin ? "Create Account" : "Back to Login"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon, {bool isPass = false}) {
    return TextField(
      controller: ctrl,
      obscureText: isPass,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.redAccent),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}
// --- 3. MAIN NAVIGATION (CONNECTED AI TAB) ---
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override State<MainNavigation> createState() => _MainNavigationState();
}
class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  List<EmergencyContact> myContacts = [EmergencyContact(id: "1", name: "Emergency Contact", number: "911")];
  late List<SOSLevel> myLevels = [
    SOSLevel(name: "Lvl 1", color: Colors.amber, customMessage: "Checking in.", activationGesture: "Single Tap"),
    SOSLevel(name: "Lvl 2", color: Colors.orange, customMessage: "Unsafe.", activationGesture: "Double Tap"),
    SOSLevel(name: "Lvl 3", color: Colors.red, recordVideo: true, recordAudio: true, liveStream: true, customMessage: "EMERGENCY!", activationGesture: "Long Press"),
  ];

  @override void initState() { super.initState(); if (!kIsWeb) [Permission.camera, Permission.microphone, Permission.storage, Permission.location, Permission.sms].request(); }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(levels: myLevels, contacts: myContacts),
      const NavigationScreen(),
      GuardianScreen(contacts: myContacts, onUpdate: (l) => setState(() => myContacts = l)),
      ConfigScreen(levels: myLevels, onUpdate: (l) => setState(() => myLevels = l)),
      const AIScreen(), // CONNECTED
      const VaultScreen(),
      ViewerEntryTab(socket: RemoteManager().socket!)
    ];
    return Scaffold(body: IndexedStack(index: _currentIndex, children: screens), bottomNavigationBar: BottomNavigationBar(currentIndex: _currentIndex, selectedItemColor: Colors.redAccent, unselectedItemColor: Colors.white24, type: BottomNavigationBarType.fixed, onTap: (i) => setState(() => _currentIndex = i), items: const [
      BottomNavigationBarItem(icon: Icon(Icons.shield), label: "SOS"),
      BottomNavigationBarItem(icon: Icon(Icons.map), label: "Map"),
      BottomNavigationBarItem(icon: Icon(Icons.people), label: "People"),
      BottomNavigationBarItem(icon: Icon(Icons.tune), label: "Config"),
      BottomNavigationBarItem(icon: Icon(Icons.psychology), label: "AI"),
      BottomNavigationBarItem(icon: Icon(Icons.folder), label: "Vault"),
      BottomNavigationBarItem(icon: Icon(Icons.visibility), label: "Watch"),
    ]));
  }
}

// --- 4. HOME (CENTERED SOS) ---
class HomeScreen extends StatefulWidget {
  final List<SOSLevel> levels; final List<EmergencyContact> contacts;
  const HomeScreen({super.key, required this.levels, required this.contacts});
  @override State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  int taps = 0; bool armed = false; bool isRunning = false;
  void trigger(SOSLevel lvl) async {
    if (!armed) return;
    setState(() => isRunning = true);
    if (!kIsWeb) await FlutterForegroundTask.startService(notificationTitle: "GuardianX ARMED", notificationText: "Protection Active");

    // MESSAGING LOGIC (IN /TEGRATED WHATSAPP GROUP)
    await LocationSmsService().triggerAlerts(
        contacts: widget.contacts,
        roomCode: RemoteManager().myHostCode!,
        customMsg: lvl.customMessage,
        useSMS: lvl.sendSMS,
        // isAuto: lvl.autoSms,
        useWA: lvl.sendWhatsApp,
        groupLink: RemoteManager().savedGroupLink
    );



    if (lvl.recordAudio) await RecordService().startLocalRecord();
    await CameraService().startStreaming(RemoteManager().socket!, RemoteManager().myHostCode!);
    if (lvl.recordVideo && CameraService().localStream != null) await VideoRecordService().startVideoRecording(CameraService().localStream!);
    if (lvl.liveStream) Navigator.push(context, MaterialPageRoute(builder: (c) => HostScreen(roomCode: RemoteManager().myHostCode!)));
  }
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text(armed ? "READY: ${RemoteManager().myHostCode}" : "SYSTEM LOCKED", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
    const SizedBox(height: 50),
    GestureDetector(behavior: HitTestBehavior.opaque, onTap: () { if (!armed) { setState(() { taps++; if (taps >= 3) armed = true; }); } else { _showPicker(); } }, child: Container(height: 280, width: 280, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: armed ? Colors.green : Colors.redAccent, width: 4), boxShadow: [BoxShadow(color: armed ? Colors.green.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1), blurRadius: 40)]), child: Icon(Icons.power_settings_new, size: 100, color: armed ? Colors.green : Colors.redAccent))),
    const SizedBox(height: 40),
    if (isRunning) ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () { RecordService().stopLocalRecord(); VideoRecordService().stopVideoRecording(); CameraService().stopEverything(); LocationSmsService().stop(); FlutterForegroundTask.stopService(); setState(() => isRunning = false); }, child: const Text("STOP ALL PROCESSES")),
  ]));
  void _showPicker() { showModalBottomSheet(context: context, builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: widget.levels.map((l) => ListTile(leading: Icon(Icons.warning, color: l.color), title: Text(l.name), onTap: () { Navigator.pop(ctx); trigger(l); })).toList())); }
}

// --- 5. CONFIG (ALL ORIGINAL FEATURES PRESERVED) ---
class ConfigScreen extends StatefulWidget {
  final List<SOSLevel> levels; final Function onUpdate;
  const ConfigScreen({super.key, required this.levels, required this.onUpdate});
  @override State<ConfigScreen> createState() => _ConfigState();
}
class _ConfigState extends State<ConfigScreen> with SingleTickerProviderStateMixin {
  late TabController _t; @override void initState() { super.initState(); _t = TabController(length: 3, vsync: this); }
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SOS Configuration"), bottom: TabBar(controller: _t, tabs: const [Tab(text: "L1"), Tab(text: "L2"), Tab(text: "L3")])),
      body: TabBarView(controller: _t, children: widget.levels.map((l) => ListView(padding: const EdgeInsets.all(20), children: [
        SwitchListTile(title: const Text("Send SMS Alert"), value: l.sendSMS, onChanged: (v) => setState(() => l.sendSMS = v)),
        SwitchListTile(title: const Text("Background Auto-SMS"), subtitle: const Text("Sends silently by itself"), value: l.autoSms, activeColor: Colors.green, onChanged: (v) => setState(() => l.autoSms = v)),
        SwitchListTile(title: const Text("Send WhatsApp"), value: l.sendWhatsApp, onChanged: (v) => setState(() => l.sendWhatsApp = v)),
        SwitchListTile(title: const Text("Physical Audio Record"), value: l.recordAudio, onChanged: (v) => setState(() => l.recordAudio = v)),
        SwitchListTile(title: const Text("Physical Video Record"), value: l.recordVideo, onChanged: (v) => setState(() => l.recordVideo = v)),
        SwitchListTile(title: const Text("Notify Police"), value: l.notifyPolice, onChanged: (v) => setState(() => l.notifyPolice = v)),
        SwitchListTile(title: const Text("Notify Hospital"), value: l.notifyHospital, onChanged: (v) => setState(() => l.notifyHospital = v)),
        SwitchListTile(title: const Text("Notice Safety Places"), value: l.noticeSafetyPlaces, onChanged: (v) => setState(() => l.noticeSafetyPlaces = v)),
        const Text("Message:"),
        TextField(maxLines: 2, controller: TextEditingController(text: l.customMessage), decoration: const InputDecoration(border: OutlineInputBorder()), onChanged: (v) => l.customMessage = v),
        ListTile(title: const Text("Gesture"), trailing: DropdownButton<String>(value: l.activationGesture, items: ["Single Tap", "Double Tap", "Long Press"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) { setState(() => l.activationGesture = v!); widget.onUpdate(widget.levels); })),
      ])).toList()),
    );
  }
}

// --- 6. PEOPLE TAB (GROUP SETUP BRIDGE) ---
class GuardianScreen extends StatefulWidget {
  final List<EmergencyContact> contacts; final Function onUpdate;
  const GuardianScreen({super.key, required this.contacts, required this.onUpdate});
  @override State<GuardianScreen> createState() => _GuardianScreenState();
}
class _GuardianScreenState extends State<GuardianScreen> {
  final _linkCtrl = TextEditingController(text: RemoteManager().savedGroupLink);
  void _generateGroup() async {
    String allNumbers = widget.contacts.map((e) => e.number).join(", ");
    await Clipboard.setData(ClipboardData(text: allNumbers));
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Ready to Create Group"),
      content: const Text("Numbers copied. Open WhatsApp, Create Group, and Paste."),
      actions: [ElevatedButton(onPressed: () => launchUrl(Uri.parse("https://wa.me/")), child: const Text("OPEN WHATSAPP"))],
    ));
  }
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Guardian Hub"), actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _add(context))]),
      body: ListView(padding: const EdgeInsets.all(15), children: [
        Card(color: Colors.blue.withOpacity(0.1), child: Column(children: [
          const ListTile(title: Text("Setup WhatsApp Group"), subtitle: Text("One window for all alerts")),
          ElevatedButton(onPressed: _generateGroup, child: const Text("1. INITIALIZE GROUP")),
          TextField(controller: _linkCtrl, decoration: const InputDecoration(labelText: "2. Paste Group Link")),
          ElevatedButton(onPressed: () => RemoteManager().saveGroupLink(_linkCtrl.text), child: const Text("3. SAVE LINK")),
        ])),
        ...widget.contacts.map((c) => ListTile(title: Text(c.name), subtitle: Text(c.number))),
      ]),
    );
  }
  void _add(BuildContext context) {
    final n = TextEditingController(), p = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Add"), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: n, decoration: const InputDecoration(labelText: "Name")), TextField(controller: p, decoration: const InputDecoration(labelText: "Phone"))]), actions: [ElevatedButton(onPressed: () { widget.contacts.add(EmergencyContact(id: "1", name: n.text, number: p.text)); widget.onUpdate(widget.contacts); Navigator.pop(c); }, child: const Text("Save"))]));
  }
}

// --- VAULT & WATCH (UNCHANGED) ---
// --- UPDATED VAULT SCREEN FOR MAIN.DART ---
class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  // The specific forensic statement requested
  final String roomDescription =
      "“A shared student hostel room with a bed, study desks, chairs, and personal belongings. "
      "The room contains electronic devices, blankets, and storage items, indicating active daily use. "
      "The environment appears moderately organized and suitable for studying and living.”";

  Future<List<FileSystemEntity>> _getFiles() async {
    final dir = await getExternalStorageDirectory();
    return dir?.listSync() ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Vault")),
      body: Column(
        children: [
          // --- 1. VISUAL AI REPORT CARD ---
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(15),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("AI SCENE REPORT:",
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Text(
                  roomDescription,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.white10),

          // --- 2. THE FILE LIST ---
          Expanded(
            child: FutureBuilder<List<FileSystemEntity>>(
              future: _getFiles(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final files = snapshot.data!.reversed.toList();
                if (files.isEmpty) return const Center(child: Text("No physical files found."));

                return ListView.builder(
                  itemCount: files.length,
                  itemBuilder: (context, i) {
                    String name = files[i].path.split('/').last;
                    bool isVideo = name.contains('.mp4');

                    return ListTile(
                      leading: Icon(isVideo ? Icons.videocam : Icons.mic,
                          color: isVideo ? Colors.blue : Colors.orange),
                      title: Text(name, style: const TextStyle(fontSize: 12)),
                      subtitle: const Text("Verified Evidence"),
                      onTap: () {
                        // --- PRINT STATEMENT TO CONSOLE ---
                        print("ANALYZING EVIDENCE: $name");
                        print(roomDescription);

                        // Visual feedback for the user
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("AI Scene Analysis Printed to Console"))
                        );
                      },
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
class ViewerEntryTab extends StatelessWidget { final IO.Socket socket; const ViewerEntryTab({super.key, required this.socket}); @override Widget build(BuildContext context) { final c = TextEditingController(); return Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.live_tv, size: 80, color: Colors.redAccent), TextField(controller: c, decoration: const InputDecoration(labelText: "Code")), ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (x) => ViewerScreen(socket: socket, roomCode: c.text))), child: const Text("WATCH"))])); } }