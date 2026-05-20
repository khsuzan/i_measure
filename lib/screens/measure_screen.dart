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
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(50),
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: Center(
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Card(
              color: Colors.black.withAlpha(190),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _statusText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_resultText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _resultText,
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          if (_state == MeasureState.complete)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: FilledButton.icon(
                  onPressed: _reset,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text(
                    "Measure Again",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
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
