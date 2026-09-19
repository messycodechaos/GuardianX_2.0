<div align="center">

# 🛡️ GuardianX 2.0
### Autonomous AI Personal Defense & Tactical Safety Ecosystem

[![Flutter](https://img.shields.io/badge/Flutter-3.19+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.3+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![WebRTC](https://img.shields.io/badge/WebRTC-Peer_to_Peer-333333?style=for-the-badge&logo=webrtc&logoColor=white)](https://webrtc.org)
[![Android](https://img.shields.io/badge/Android-SDK_23+-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://developer.android.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

**GuardianX 2.0** is an intelligent, offline-first personal security application that bridges proactive acoustic AI threat detection, hardware-accelerated WebRTC live-streaming, and automated multi-tier emergency dispatch.

[Explore Features](#-key-capabilities) • [Architecture](#-system-architecture) • [Quick Start](#-getting-started) • [APK Build](#-generating-release-apk)

</div>

---

## 📌 The Problem vs. The Solution

* **Traditional Panic Buttons Fail Under Duress:** Unlocking a phone, finding an app, and dialing 911 takes 20–40 critical seconds during an assault.
* **GuardianX 2.0 Autonomous Defense:** A triple-tap locked trigger, background acoustic scream analysis, tactical voice deterrence, and instant real-time telemetry dispatch to trusted guardians.

---

## ⚡ Key Capabilities

### 🧠 1. AI Defense Layer
* **🎧 Safety Ear (Acoustic Anomaly Detection):** Monitors background microphone amplitude (`dBFS`). Automatically triggers threat alarms when high-decibel screams, glass breaks, or struggle sounds are detected.
* **📡 Smart Safety Radar:** Analyzes real-time GPS coordinates and diurnal hazard metrics (night vs. daylight risk corridors) to score route safety in real-time.
* **👁️ Visual Guard:** Camera frame intake pipeline designed for real-time weapon and follower detection.
* **📞 Tactical Guardian Call (TTS Deterrent):** Simulates an incoming rescue call with dynamic Text-to-Speech audio and haptics to project presence:
  > *"Hey, I'm just around the corner. I can see you on the GPS with the security team. Stay right there on the line."*

---

### 🚨 2. Multi-Tiered SOS Engine
| Tier | Action | Protocol Triggered |
| :--- | :--- | :--- |
| **Level 1 (Check-In)** | Single Tap | Sends silent coordinate ping to emergency contacts. |
| **Level 2 (Caution)** | Double Tap | Broadcasts live GPS tracking link + SMS alert. |
| **Level 3 (Emergency)** | Long Press / Triple-Tap | Arms full defense: WebRTC live stream, background audio recording, camera video capture, WhatsApp group broadcast, and local Evidence Vault preservation. |

---

### 📹 3. Peer-to-Peer WebRTC Live Streaming
* **Zero-Latency Video:** Streams encrypted camera feed over WebRTC to trusted viewers via peer room codes.
* **Remote Tactical Viewer:** Remote guardians can toggle flashlights, zoom in optically, adjust brightness, and enable night-vision mode on the victim's device remotely.

---

### 🗄️ 4. Encrypted Evidence Vault
* **Forensic-Grade Capture:** Timestamped audio (`AUD_*.m4a`) and video (`VID_*.mp4`) evidence are recorded locally to secure app-isolated storage.
* **Offline Resilience:** Evidence is saved immediately to disk even if cellular network coverage is lost during an emergency.

---

## 🏗️ System Architecture

```text
┌──────────────────────────────────────────────────────────┐
│                   GUARDIANX CLIENT (FLUTTER)             │
├───────────────────┬───────────────────┬──────────────────┤
│    AI SENSORS     │   SOS CONTROLLER  │    WEBRTC ENGINE │
│  • Record dBFS    │  • Multi-Tier L1-3│  • Camera Stream │
│  • Geolocator GPS │  • Auto-SMS Dispatch • Remote Control│
│  • TTS Deterrent  │  • WhatsApp Bridge│  • Low-Latency P2P
└─────────┬─────────┴─────────┬─────────┴─────────┬────────┘
          │                   │                   │
          ▼                   ▼                   ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│  EVIDENCE VAULT  │ │ TELEPHONY/SMS    │ │ SOCKET.IO RELAY  │
│ Local Encrypted  │ │ Cellular Network │ │ Signaling Server │
│ Offline Storage  │ │ Emergency Pings  │ │ Remote Viewer Hub│
└──────────────────┘ └──────────────────┘ └──────────────────┘
