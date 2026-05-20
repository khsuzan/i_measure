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
  String _statusText = "Aim crosshair at a surface and tap to place Point A";
  String _resultCm = "";
  String _resultFtIn = "";

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
                    if (_resultCm.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildValueColumn(_resultCm, "cm"),
                          ),
                          Container(
                            width: 1,
                            height: 44,
                            color: Colors.white24,
                          ),
                          Expanded(
                            child: _buildValueColumn(_resultFtIn, "ft / in"),
                          ),
                        ],
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

  Widget _buildValueColumn(String value, String unit) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.cyanAccent,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          unit,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 12,
          ),
        ),
      ],
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
        _statusText = "Point A set. Aim crosshair and tap for Point B.";
      });
    } else if (_state == MeasureState.pointASet) {
      _pointB = position;
      final distance = _pointA!.distanceTo(_pointB!);
      setState(() {
        _state = MeasureState.complete;
        _resultCm = _formatCm(distance);
        _resultFtIn = _formatFeetInches(distance);
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

  String _formatCm(double meters) {
    return (meters * 100).toStringAsFixed(1);
  }

  String _formatFeetInches(double meters) {
    final totalInches = meters * 39.3701;
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    return "$feet' ${inches.toStringAsFixed(1)}\"";
  }

  void _reset() {
    setState(() {
      _pointA = null;
      _pointB = null;
      _state = MeasureState.idle;
      _statusText = "Aim crosshair at a surface and tap to place Point A";
      _resultCm = "";
      _resultFtIn = "";
    });
  }
}
