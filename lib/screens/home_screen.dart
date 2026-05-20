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
                Icon(
                  Icons.straighten,
                  size: 80,
                  color: Colors.blueAccent.withAlpha(180),
                ),
                const SizedBox(height: 24),
                const Text(
                  "I Measure",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Measure real-world distances\nusing augmented reality",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[400],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () => _startMeasurement(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.camera_alt, size: 24),
                    label: const Text(
                      "Start Measurement",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
      if (context.mounted) {
        _showPermissionDialog(context);
      }
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
