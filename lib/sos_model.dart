import 'package:flutter/material.dart';

class EmergencyContact {
  String id, name, number, relationship;
  List<String> notifyOnLevels; // 'lvl1', 'lvl2', 'lvl3'

  EmergencyContact({
    required this.id,
    required this.name,
    required this.number,
    this.relationship = 'Trusted Contact',
    this.notifyOnLevels = const ['lvl1', 'lvl2', 'lvl3'],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'number': number,
    'relationship': relationship,
    'notifyOnLevels': notifyOnLevels,
  };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) => EmergencyContact(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    number: json['number'] ?? '',
    relationship: json['relationship'] ?? 'Trusted Contact',
    notifyOnLevels: List<String>.from(json['notifyOnLevels'] ?? ['lvl1', 'lvl2', 'lvl3']),
  );
}

class SOSLevel {
  String id; // 'lvl1', 'lvl2', 'lvl3'
  String name;
  Color color;
  bool sendSMS;
  bool autoSms;
  bool sendWhatsApp;
  bool recordAudio;
  bool recordVideo;
  bool liveStream;
  bool notifyPolice;
  bool notifyHospital;
  bool noticeSafetyPlaces;
  String customMessage;
  String activationGesture;

  SOSLevel({
    String? id,
    required this.name,
    required this.color,
    this.sendSMS = true,
    this.autoSms = true,
    this.sendWhatsApp = true,
    this.recordAudio = true,
    this.recordVideo = true,
    this.liveStream = true,
    this.notifyPolice = true,
    this.notifyHospital = true,
    this.noticeSafetyPlaces = true,
    required this.customMessage,
    required this.activationGesture,
  }) : id = (id != null && id.isNotEmpty)
      ? id
      : (name.toLowerCase().contains('1')
      ? 'lvl1'
      : name.toLowerCase().contains('2')
      ? 'lvl2'
      : 'lvl3');
}

class IncidentRecord {
  final String id;
  final String userId;
  final DateTime timestamp;
  final String category;
  final String categoryLabel;
  final double confidence;
  final double? decibels;
  final String summary;
  final String source; // 'safety_ear' | 'safety_eye'
  final String mediaType; // 'audio' | 'image' | 'video'
  final String filePath;
  final int fileSizeBytes;
  String status; // 'pending_confirmation' | 'confirmed_safe' | 'escalated_lvl1' | 'escalated_lvl2' | 'escalated_lvl3'
  final int timeoutSeconds;
  final String defaultLevel;
  final bool storageVerified;
  final List<String> auditTrail;

  IncidentRecord({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.category,
    required this.categoryLabel,
    required this.confidence,
    this.decibels,
    required this.summary,
    required this.source,
    required this.mediaType,
    required this.filePath,
    required this.fileSizeBytes,
    required this.status,
    required this.timeoutSeconds,
    required this.defaultLevel,
    required this.storageVerified,
    required this.auditTrail,
  });
}