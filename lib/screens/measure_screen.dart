import 'dart:math' as math;

import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

enum MeasureMode { line, triangle, rectangle }
enum MeasureState { idle, pointASet, pointBSet, pointCSet, complete }

class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key});

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen> {
  ARKitController? _controller;

  MeasureMode _mode = MeasureMode.line;
  MeasureState _state = MeasureState.idle;

  vector.Vector3? _pointA;
  vector.Vector3? _pointB;
  vector.Vector3? _pointC;
  vector.Vector3? _pointD;
  String _statusText = "Aim at a surface and tap +";
  String _resultLabelLine1 = "";
  String _resultValueCm1 = "";
  String _resultValueFtIn1 = "";
  String _resultLabelLine2 = "";
  String _resultValueCm2 = "";
  String _resultValueFtIn2 = "";

  ARKitNode? _nodeA;
  ARKitNode? _nodeB;
  ARKitNode? _nodeC;
  ARKitNode? _nodeD;
  final List<ARKitNode> _lineNodes = [];
  final List<ARKitNode> _previewNodes = [];
  vector.Vector3? _previewPos;
  String _liveDistanceText = "";
  bool _busy = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showTwoLines = _resultLabelLine2.isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          ARKitSceneView(
            onARKitViewCreated: _onARKitViewCreated,
            planeDetection: ARPlaneDetection.horizontal,
            showFeaturePoints: false,
            enableTapRecognizer: false,
          ),

          Center(
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(50),
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: Center(
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
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
                    if (_state == MeasureState.idle)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Wrap(
                          spacing: 8,
                          children: [
                            _modeChip(MeasureMode.line, "Line"),
                            _modeChip(MeasureMode.triangle, "Triangle"),
                            _modeChip(MeasureMode.rectangle, "Rectangle"),
                          ],
                        ),
                      ),
                    Text(
                      _liveDistanceText.isNotEmpty
                          ? _liveDistanceText
                          : _statusText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_resultValueCm1.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _resultRow(
                        _resultLabelLine1,
                        _resultValueCm1,
                        _resultValueFtIn1,
                      ),
                      if (showTwoLines) ...[
                        const SizedBox(height: 8),
                        _resultRow(
                          _resultLabelLine2,
                          _resultValueCm2,
                          _resultValueFtIn2,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: _state == MeasureState.complete
                  ? FilledButton.icon(
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
                        "Clear",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : FloatingActionButton(
                      onPressed: _addPoint,
                      backgroundColor: Colors.white,
                      child: const Icon(
                        Icons.add,
                        color: Colors.black,
                        size: 32,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(MeasureMode chipMode, String label) {
    final selected = _mode == chipMode;
    return GestureDetector(
      onTap: selected
          ? null
          : () {
              _reset();
              setState(() => _mode = chipMode);
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white12,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white60,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _resultRow(String label, String cm, String ftIn) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            cm,
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(width: 1, height: 30, color: Colors.white24),
        Expanded(
          child: Text(
            ftIn,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  void _onARKitViewCreated(ARKitController controller) {
    _controller = controller;
    _controller!.updateAtTime = _updateAtTime;
  }

  void _updateAtTime(double time) {
    if (_busy) return;
    if (_state == MeasureState.idle || _state == MeasureState.complete) return;
    _busy = true;

    _controller!.performHitTest(x: 0.5, y: 0.5).then((results) {
      _busy = false;
      if (_state == MeasureState.idle || _state == MeasureState.complete) return;

      final hit = _findBestHit(results);
      if (hit == null) return;

      final pos = vector.Vector3(
        hit.worldTransform.getColumn(3).x,
        hit.worldTransform.getColumn(3).y,
        hit.worldTransform.getColumn(3).z,
      );

      _updatePreview(pos);
    });
  }

  ARKitTestResult? _findBestHit(List<ARKitTestResult> results) {
    for (final r in results) {
      if (r.type == ARKitHitTestResultType.existingPlaneUsingExtent ||
          r.type == ARKitHitTestResultType.existingPlane ||
          r.type == ARKitHitTestResultType.featurePoint) {
        return r;
      }
    }
    return null;
  }

  void _updatePreview(vector.Vector3 pos) {
    if (_previewPos != null && _previewPos!.distanceTo(pos) < 0.005) return;
    _previewPos = pos;

    _clearPreviewNodes();

    if (_state == MeasureState.pointASet) {
      _addPreviewDot(pos, 0.003);
      _addPreviewCylinder(_pointA!, pos, 0.003);
      final dist = _pointA!.distanceTo(pos);
      setState(() {
        _liveDistanceText = _formatDistance(dist);
      });
    } else if (_state == MeasureState.pointBSet) {
      _addPreviewDot(pos, 0.003);
      _addPreviewCylinder(_pointB!, pos, 0.003);
      if (_mode == MeasureMode.rectangle || _mode == MeasureMode.triangle) {
        final ab = _pointA!.distanceTo(_pointB!);
        final bc = _pointB!.distanceTo(pos);
        final ca = pos.distanceTo(_pointA!);
        setState(() {
          _liveDistanceText = "${_formatCm(ab)} → ${_formatCm(bc)}  |  ${_formatCm(ca)}";
        });
      }
    } else if (_state == MeasureState.pointCSet) {
      _addPreviewDot(pos, 0.003);
      _addPreviewCylinder(_pointC!, pos, 0.003);
      _addPreviewCylinder(pos, _pointA!, 0.003);
    }
  }

  void _clearPreviewNodes() {
    for (final n in _previewNodes) {
      _controller?.remove(n.name);
    }
    _previewNodes.clear();
  }

  void _addPreviewDot(vector.Vector3 position, double radius) {
    final material = ARKitMaterial(
      diffuse: ARKitMaterialProperty.color(Colors.white.withAlpha(180)),
      lightingModelName: ARKitLightingModel.constant,
    );
    final sphere = ARKitSphere(materials: [material], radius: radius);
    final node = ARKitNode(geometry: sphere, position: position);
    _controller?.add(node);
    _previewNodes.add(node);
  }

  void _addPreviewCylinder(
      vector.Vector3 a, vector.Vector3 b, double radius) {
    final mid = vector.Vector3(
      (a.x + b.x) / 2,
      (a.y + b.y) / 2,
      (a.z + b.z) / 2,
    );
    final dist = a.distanceTo(b);
    if (dist < 0.001) return;
    final dir = (b - a).normalized();

    final from = vector.Vector3(0, 1, 0);
    final cross = from.cross(dir);
    vector.Vector4 rotation;
    if (cross.length < 1e-6) {
      rotation = from.dot(dir) > 0
          ? vector.Vector4(0, 0, 0, 0)
          : vector.Vector4(1, 0, 0, math.pi);
    } else {
      final axis = cross.normalized();
      final angle = math.acos(from.dot(dir).clamp(-1.0, 1.0));
      rotation = vector.Vector4(axis.x, axis.y, axis.z, angle);
    }

    final material = ARKitMaterial(
      diffuse: ARKitMaterialProperty.color(Colors.white.withAlpha(120)),
      lightingModelName: ARKitLightingModel.constant,
    );
    final cylinder = ARKitCylinder(
      materials: [material],
      radius: radius,
      height: dist,
    );
    final node = ARKitNode(
      geometry: cylinder,
      position: mid,
      rotation: rotation,
    );
    _controller?.add(node);
    _previewNodes.add(node);
  }

  void _addPoint() {
    if (_busy) return;
    _busy = true;

    _controller!.performHitTest(x: 0.5, y: 0.5).then((results) {
      _busy = false;

      final hit = _findBestHit(results);
      if (hit == null) return;

      final pos = vector.Vector3(
        hit.worldTransform.getColumn(3).x,
        hit.worldTransform.getColumn(3).y,
        hit.worldTransform.getColumn(3).z,
      );

      switch (_state) {
        case MeasureState.idle:
          _placePointA(pos);
        case MeasureState.pointASet:
          _placePointB(pos);
        case MeasureState.pointBSet:
          _placePointC(pos);
        case MeasureState.pointCSet:
          _placePointD(pos);
        case MeasureState.complete:
          break;
      }
    });
  }

  void _placePointA(vector.Vector3 position) {
    _pointA = position;
    _nodeA = _makeDot(position);
    _controller?.add(_nodeA!);

    setState(() {
      _state = MeasureState.pointASet;
      switch (_mode) {
        case MeasureMode.line:
          _statusText = "Move phone and tap + for Point B";
        case MeasureMode.triangle:
          _statusText = "Tap + for Point B";
        case MeasureMode.rectangle:
          _statusText = "Tap + for Point B";
      }
    });
  }

  void _placePointB(vector.Vector3 position) {
    _pointB = position;
    _clearPreviewNodes();
    _previewPos = null;

    _nodeB = _makeDot(position);
    _controller?.add(_nodeB!);

    if (_mode == MeasureMode.line) {
      _addDottedLine(_pointA!, _pointB!);
      final distance = _pointA!.distanceTo(_pointB!);
      setState(() {
        _state = MeasureState.complete;
        _resultLabelLine1 = "";
        _resultValueCm1 = _formatCm(distance);
        _resultValueFtIn1 = _formatFeetInches(distance);
        _statusText = _formatDistance(distance);
        _liveDistanceText = "";
      });
    } else {
      _addDottedLine(_pointA!, _pointB!);
      setState(() {
        _state = MeasureState.pointBSet;
        _statusText = _mode == MeasureMode.triangle
            ? "Tap + for Point C"
            : "Tap + for Point C";
        _liveDistanceText = "";
      });
    }
  }

  void _placePointC(vector.Vector3 position) {
    _pointC = position;
    _clearPreviewNodes();
    _previewPos = null;

    _nodeC = _makeDot(position);
    _controller?.add(_nodeC!);

    _addDottedLine(_pointB!, _pointC!);

    if (_mode == MeasureMode.triangle) {
      _addDottedLine(_pointC!, _pointA!);
      final area = _triangleArea(_pointA!, _pointB!, _pointC!);
      final sideA = _pointB!.distanceTo(_pointC!);
      final sideB = _pointC!.distanceTo(_pointA!);
      final sideC = _pointA!.distanceTo(_pointB!);
      final perim = sideA + sideB + sideC;
      setState(() {
        _state = MeasureState.complete;
        _resultLabelLine1 = "Area";
        _resultValueCm1 = "${_areaCm(area)} cm²";
        _resultValueFtIn1 = "${_areaSqFt(area)} ft²";
        _resultLabelLine2 = "Perimeter";
        _resultValueCm2 = "${_formatCm(perim)} cm";
        _resultValueFtIn2 = _formatFeetInches(perim);
        _liveDistanceText = "";
      });
    } else {
      setState(() {
        _state = MeasureState.pointCSet;
        _statusText = "Tap + for Point D";
        _liveDistanceText = "";
      });
    }
  }

  void _placePointD(vector.Vector3 position) {
    _pointD = position;
    _clearPreviewNodes();
    _previewPos = null;

    _nodeD = _makeDot(position);
    _controller?.add(_nodeD!);

    _addDottedLine(_pointC!, _pointD!);
    _addDottedLine(_pointD!, _pointA!);

    final area = _quadrilateralArea(
      _pointA!, _pointB!, _pointC!, _pointD!,
    );
    final p1 = _pointA!.distanceTo(_pointB!);
    final p2 = _pointB!.distanceTo(_pointC!);
    final p3 = _pointC!.distanceTo(_pointD!);
    final p4 = _pointD!.distanceTo(_pointA!);
    final perim = p1 + p2 + p3 + p4;

    setState(() {
      _state = MeasureState.complete;
      _resultLabelLine1 = "Area";
      _resultValueCm1 = "${_areaCm(area)} cm²";
      _resultValueFtIn1 = "${_areaSqFt(area)} ft²";
      _resultLabelLine2 = "Perimeter";
      _resultValueCm2 = "${_formatCm(perim)} cm";
      _resultValueFtIn2 = _formatFeetInches(perim);
      _liveDistanceText = "";
    });
  }

  double _triangleArea(
      vector.Vector3 a, vector.Vector3 b, vector.Vector3 c) {
    final ab = b - a;
    final ac = c - a;
    final cross = ab.cross(ac);
    return cross.length * 0.5;
  }

  double _quadrilateralArea(
    vector.Vector3 a,
    vector.Vector3 b,
    vector.Vector3 c,
    vector.Vector3 d,
  ) {
    return _triangleArea(a, b, c) + _triangleArea(a, c, d);
  }

  ARKitNode _makeDot(vector.Vector3 position) {
    final material = ARKitMaterial(
      diffuse: ARKitMaterialProperty.color(Colors.white),
      lightingModelName: ARKitLightingModel.constant,
    );
    final sphere = ARKitSphere(materials: [material], radius: 0.00345);
    return ARKitNode(geometry: sphere, position: position);
  }

  void _addDottedLine(vector.Vector3 a, vector.Vector3 b) {
    const segments = 20;
    final material = ARKitMaterial(
      diffuse: ARKitMaterialProperty.color(Colors.white.withAlpha(160)),
      lightingModelName: ARKitLightingModel.constant,
    );
    final sphere = ARKitSphere(materials: [material], radius: 0.003);

    for (int i = 1; i < segments; i++) {
      final t = i / segments;
      final pos = vector.Vector3(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t,
        a.z + (b.z - a.z) * t,
      );
      final node = ARKitNode(geometry: sphere, position: pos);
      _controller?.add(node);
      _lineNodes.add(node);
    }
  }

  void _removeAllNodes() {
    _clearPreviewNodes();
    if (_nodeA != null) {
      _controller?.remove(_nodeA!.name);
      _nodeA = null;
    }
    if (_nodeB != null) {
      _controller?.remove(_nodeB!.name);
      _nodeB = null;
    }
    if (_nodeC != null) {
      _controller?.remove(_nodeC!.name);
      _nodeC = null;
    }
    if (_nodeD != null) {
      _controller?.remove(_nodeD!.name);
      _nodeD = null;
    }
    for (final n in _lineNodes) {
      _controller?.remove(n.name);
    }
    _lineNodes.clear();
    _previewPos = null;
  }

  void _reset() {
    _removeAllNodes();
    setState(() {
      _pointA = null;
      _pointB = null;
      _pointC = null;
      _pointD = null;
      _state = MeasureState.idle;
      _statusText = "Aim at a surface and tap +";
      _resultLabelLine1 = "";
      _resultValueCm1 = "";
      _resultValueFtIn1 = "";
      _resultLabelLine2 = "";
      _resultValueCm2 = "";
      _resultValueFtIn2 = "";
      _liveDistanceText = "";
    });
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

  String _areaCm(double sqMeters) {
    return (sqMeters * 10000).toStringAsFixed(1);
  }

  String _areaSqFt(double sqMeters) {
    return (sqMeters * 10.7639).toStringAsFixed(1);
  }
}
