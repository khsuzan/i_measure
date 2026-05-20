# I Measure — AR Measurement App Setup Guide

Cross-platform Flutter app that measures real-world distances using ARKit (iOS) / ARCore (Android).

---

## 1. Create Project

```bash
flutter create i_measure
cd i_measure
```

## 2. Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  ar_flutter_plugin_plus: ^1.1.3
  vector_math: ^2.2.0
  permission_handler: ^12.0.1
```

Run:

```bash
flutter pub get
```

---

## 3. iOS Setup

### 3.1 Info.plist

Add to `ios/Runner/Info.plist` (inside `<dict>`):

```xml
<key>NSCameraUsageDescription</key>
<string>This app requires camera access to measure real-world objects using AR.</string>
<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>arm64</string>
    <string>arkit</string>
</array>
```

### 3.2 Podfile

Set platform and add permission macro in `ios/Podfile`:

```ruby
platform :ios, '15.0'

# ... inside post_install:
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_CAMERA=1',
      ]
    end
  end
end
```

### 3.3 Install Pods

```bash
cd ios && pod install && cd ..
```

---

## 4. Android Setup

### 4.1 AndroidManifest.xml

Add to `android/app/src/main/AndroidManifest.xml` (above `<application>`):

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-feature android:name="android.hardware.camera.ar" android:required="true"/>
<uses-feature android:glEsVersion="0x00030000" android:required="true"/>
```

Inside `<application>`:

```xml
<meta-data android:name="com.google.ar.core" android:value="required"/>
```

### 4.2 build.gradle.kts

Set `minSdk = 24` in `android/app/build.gradle.kts`:

```kotlin
defaultConfig {
    minSdk = 24
}
```

---

## 5. Dart Code

### 5.1 App entry — `lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MeasureApp());
}

class MeasureApp extends StatelessWidget {
  const MeasureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'I Measure',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}
```

### 5.2 Home screen — `lib/screens/home_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'measure_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.straighten, size: 80,
                    color: Colors.blueAccent.withAlpha(180)),
                const SizedBox(height: 24),
                const Text("I Measure",
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text("Measure real-world distances\nusing augmented reality",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[400])),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity, height: 56,
                  child: FilledButton.icon(
                    onPressed: () => _startMeasurement(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.camera_alt, size: 24),
                    label: const Text("Start Measurement",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startMeasurement(BuildContext context) async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MeasureScreen()),
        );
      }
    } else if (status.isPermanentlyDenied) {
      if (context.mounted) _showPermissionDialog(context);
    }
  }

  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Camera Permission Required"),
        content: const Text(
          "Camera access is needed to measure objects using AR. "
          "Please enable it in Settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }
}
```

### 5.3 AR Measure screen — `lib/screens/measure_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin_plus/ar_flutter_plugin_plus.dart';
import 'package:ar_flutter_plugin_plus/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_plus/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_plus/models/ar_hittest_result.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

enum MeasureState { idle, pointASet, complete }

class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key});

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen> {
  ARSessionManager? _arSessionManager;

  Vector3? _pointA;
  Vector3? _pointB;
  MeasureState _state = MeasureState.idle;
  String _statusText = "Tap on a surface to place Point A";
  String _resultText = "";

  @override
  void dispose() {
    _arSessionManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ARView(
            onARViewCreated: _onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),

          Center(
            child: Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(50),
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: Center(
                child: Container(
                  width: 4, height: 4,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Colors.blueAccent,
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: 60, left: 20, right: 20,
            child: Card(
              color: Colors.black.withAlpha(190),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_statusText,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center),
                    if (_resultText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(_resultText,
                          style: const TextStyle(
                              color: Colors.cyanAccent, fontSize: 28,
                              fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ],
                  ],
                ),
              ),
            ),
          ),

          if (_state == MeasureState.complete)
            Positioned(
              bottom: 50, left: 0, right: 0,
              child: Center(
                child: FilledButton.icon(
                  onPressed: _reset,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Measure Again",
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager arObjMgr,
    ARAnchorManager arAnchMgr,
    ARLocationManager arLocMgr,
  ) {
    _arSessionManager = sessionManager;
    _arSessionManager!.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      handleTaps: true,
    );
    _arSessionManager!.onPlaneOrPointTap = _onPlaneOrPointTapped;
  }

  Future<void> _onPlaneOrPointTapped(
    List<ARHitTestResult> hitTestResults,
  ) async {
    final planeHits = hitTestResults
        .where((r) => r.type == ARHitTestResultType.plane)
        .toList();
    if (planeHits.isEmpty) return;

    final hit = planeHits.first;
    final position = Vector3(
      hit.worldTransform.getColumn(3).x,
      hit.worldTransform.getColumn(3).y,
      hit.worldTransform.getColumn(3).z,
    );

    if (_state == MeasureState.idle) {
      _pointA = position;
      setState(() {
        _state = MeasureState.pointASet;
        _statusText = "Point A set. Tap a surface for Point B.";
      });
    } else if (_state == MeasureState.pointASet) {
      _pointB = position;
      final distance = _pointA!.distanceTo(_pointB!);
      final cm = distance * 100;
      setState(() {
        _state = MeasureState.complete;
        _resultText = "${cm.toStringAsFixed(1)} cm";
        _statusText = _formatDistance(distance);
      });
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1.0) {
      return "${meters.toStringAsFixed(2)} m";
    }
    return "${(meters * 100).toStringAsFixed(1)} cm";
  }

  void _reset() {
    setState(() {
      _pointA = null;
      _pointB = null;
      _state = MeasureState.idle;
      _statusText = "Tap on a surface to place Point A";
      _resultText = "";
    });
  }
}
```

---

## 6. Project Structure

```
lib/
  main.dart                          — App entry point
  screens/
    home_screen.dart                 — Home page with permission check
    measure_screen.dart              — AR measurement screen
ios/
  Runner/
    Info.plist                       — Camera + ARKit permissions
  Podfile                            — iOS deps + PERMISSION_CAMERA=1
android/
  app/
    src/main/AndroidManifest.xml     — Camera + ARCore permissions
    build.gradle.kts                 — minSdk = 24
```

---

## 7. Build & Run

```bash
# iOS (physical device required — ARKit doesn't work on simulator)
flutter run -d <device-id>

# Android
flutter run -d <device-id>
```

---

## 8. How It Works

1. **Home screen** — User taps "Start Measurement"
2. **Permission check** — Camera permission is requested via `permission_handler`
3. **AR view** — `ar_flutter_plugin_plus` renders ARKit (iOS) / ARCore (Android) camera feed
4. **Place Point A** — User taps on a detected surface → hit test captures 3D position
5. **Place Point B** — User taps another surface → second position captured
6. **Calculate** — `Vector3.distanceTo()` computes real-world distance in meters
7. **Display** — Result shown in cm or m on the overlay card

---

## 9. Troubleshooting

| Symptom | Fix |
|---|---|
| `CryptorRSA` minimum deployment target error | Set `IPHONEOS_DEPLOYMENT_TARGET = '15.0'` in Podfile's `post_install` |
| Camera permission toggle missing in Settings | Add `PERMISSION_CAMERA=1` to `GCC_PREPROCESSOR_DEFINITIONS` in Podfile, then `pod install` |
| AR view doesn't show planes | Ensure `NSCameraUsageDescription` in Info.plist and `CAMERA` permission in AndroidManifest.xml |
| Build fails on Android | Verify `minSdk = 24` in `build.gradle.kts` and ARCore metadata in AndroidManifest.xml |
