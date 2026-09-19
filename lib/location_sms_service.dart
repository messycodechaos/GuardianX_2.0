import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sos_model.dart';

class LocationSmsService {
  static final LocationSmsService _instance = LocationSmsService._internal();
  factory LocationSmsService() => _instance;
  LocationSmsService._internal();

  Timer? _loopTimer;

  Future<void> triggerAlerts({
    required List<EmergencyContact> contacts,
    required String roomCode,
    required String customMsg,
    required bool useSMS,
    required bool useWA,
    String? groupLink, // Added parameter for WhatsApp Group Link
  }) async {
    // 1. Get current GPS coordinates
    Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    String mapLink = "https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}";
    String fullMessage = "🚨 SOS ALERT 🚨\n$customMsg\n\n📍 Location: $mapLink\n🔑 Watch Code: $roomCode";

    // 2. SMS LOGIC (One Window Mode)
    if (useSMS) {
      // Concatenate all numbers with a comma to open them all in one single SMS window
      String allNumbers = contacts.map((e) => e.number).join(',');
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: allNumbers,
        queryParameters: {'body': fullMessage},
      );
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      }
    }

    // 3. WHATSAPP LOGIC (Group or Individual)
    if (useWA) {
      if (groupLink != null && groupLink.isNotEmpty) {
        // Mode A: Open the specifically provided WhatsApp Safety Group Link
        String cleanLink = groupLink.trim();
        if (!cleanLink.startsWith('http')) cleanLink = 'https://$cleanLink';
        final Uri waGroupUri = Uri.parse(cleanLink);

        if (await canLaunchUrl(waGroupUri)) {
          await launchUrl(waGroupUri, mode: LaunchMode.externalApplication);
        }
      } else if (contacts.isNotEmpty) {
        // Mode B: Fallback to individual chat if no group link is provided
        String waUrl = "https://wa.me/${contacts[0].number}?text=${Uri.encodeComponent(fullMessage)}";
        final Uri waUri = Uri.parse(waUrl);

        if (await canLaunchUrl(waUri)) {
          await launchUrl(waUri, mode: LaunchMode.externalApplication);
        }
      }
    }
  }

  // Loop logic maintained for periodic updates (Requires manual sending since background_sms is removed)
  void startUpdateLoop(List<EmergencyContact> contacts, String roomCode) {
    _loopTimer?.cancel();
    _loopTimer = Timer.periodic(const Duration(minutes: 5), (t) async {
      Position p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      print("Update: User currently at ${p.latitude}, ${p.longitude}");
      // Note: Periodic background sending without a background library is restricted by Android/iOS.
    });
  }

  void stop() => _loopTimer?.cancel();
}