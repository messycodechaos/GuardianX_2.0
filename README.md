# GuardianX - Flutter Mobile Application (v3.0)

This is the complete, official **Flutter** project ready to open and run in **Android Studio**.

## 🚀 How to Open in Android Studio

1. Open **Android Studio**.
2. Click **File -> Open...** (or "Open" on the welcome screen).
3. Select this `flutter_project` directory and click **OK**.
4. Android Studio will recognize it as a Flutter/Dart project.
5. In the terminal or prompt, run:
   ```bash
   flutter pub get
   ```
6. Connect your physical Android phone (with USB Debugging enabled) or start an Android Emulator.
7. Click the green **Run ▶️** button in the top toolbar!

## 📦 Generating Release APK

To create an installable `.apk` file for Android phones:
```bash
flutter build apk --release
```
The APK will be generated at:
`build/app/outputs/flutter-apk/app-release.apk`

## 🛠️ Project Structure
- `lib/main.dart` - Entry point, Cinematic Splash Screen with Ken Burns effect, and Auth.
- `lib/host_screen.dart` - Host broadcast room, audio/video live indicator, camera flip.
- `lib/viewer_screen.dart` - Remote WebRTC viewer with optical zoom, night vision, torch, brightness.
- `lib/ai_screen.dart` & `ai_controller.dart` - AI Threat Radar, Safety Ear (acoustic voice monitor).
- `lib/navigation_screen.dart` - Safe GPS navigation & safe havens routing.
- `lib/otp_screen.dart` - 2FA OTP verification with demo code fallback (`1234`).
- `lib/fake_call_screen.dart` - Audio caller simulator.
- `lib/VaultScreen.dart` - Forensic evidence vault.
- `android/` - Full Android configuration with Gradle 8.2, Kotlin 1.9.22, minSdk 23, and all camera/audio/location permissions.
