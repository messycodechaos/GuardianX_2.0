import 'package:flutter/material.dart';

class EmergencyContact {
  String id, name, number;
  EmergencyContact({required this.id, required this.name, required this.number});
}

class SOSLevel {
  String name; Color color;
  bool sendSMS, autoSms, sendWhatsApp, recordAudio, recordVideo, liveStream, notifyPolice, notifyHospital, noticeSafetyPlaces;
  String customMessage, activationGesture;

  SOSLevel({
    required this.name, required this.color,
    this.sendSMS = true,
    this.autoSms = true, // Default to Automatic
    this.sendWhatsApp = true,
    this.recordAudio = true,
    this.recordVideo = true,
    this.liveStream = true,
    this.notifyPolice = true,
    this.notifyHospital = true,
    this.noticeSafetyPlaces = true,
    required this.customMessage,
    required this.activationGesture,
  });
}