import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

import 'nxn_cube_controller.dart';
import 'nxn_cube_painter.dart';
import 'nxn_cube_state.dart';
import 'nxn_projection.dart';

/// Interactive n×n cube: drag on the cube turns the grabbed layer (follows the
/// finger, snaps to the nearest quarter/half turn); drag off it orbits.
class NxnCubeView extends StatefulWidget {
  const NxnCubeView({super.key, required this.controller, this.onMove});

  final NxnCubeController controller;

  /// Called after a finger turn is committed.
  final ValueChanged<NxnMove>? onMove;

  @override
  State<NxnCubeView> createState() => _NxnCubeViewState();
}

enum _Mode { none, deciding, orbiting, turning }

class _NxnCubeViewState extends State<NxnCubeView>
    with SingleTickerProviderStateMixin {
  static const _decidePx = 8.0;
  static const _orbitSpeed = 0.01;

  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  )..addListener(_onSnapTick);

  Size _size = Size.zero;
  _Mode _mode = _Mode.none;
  Offset? _start;

  // Active turn.
  int _axis = 0;
  int _layer = 0;
  Offset _tangent = Offset.zero; // screen px per radian
  double _angle = 0;
  double _snapFrom = 0;
  double _snapTo = 0;

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  NxnCubeController get _c => widget.controller;

  NxnProjection _projection() => NxnProjection(
        size: _size,
        n: _c.n,
        rotationX: _c.rotationX,
        rotationY: _c.rotationY,
      );

  void _onPanStart(DragStartDetails d) {
    if (_snap.isAnimating) _finishSnap();
    _start = d.localPosition;
    _mode = _Mode.deciding;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final start = _start;
    if (start == null) return;
    final total = d.localPosition - start;

    if (_mode == _Mode.deciding) {
      if (total.distance < _decidePx) return;
      _mode = widget.onMove != null && _beginTurn(start, total)
          ? _Mode.turning
          : _Mode.orbiting;
    }

    switch (_mode) {
      case _Mode.turning:
        final len2 = _tangent.distanceSquared;
        _angle = ((total.dx * _tangent.dx + total.dy * _tangent.dy) / len2)
            .clamp(-math.pi - 0.3, math.pi + 0.3);
        _c.turn = NxnTurn(_axis, _layer, _angle);
      case _Mode.orbiting:
        _c.orbit(dx: d.delta.dx * _orbitSpeed, dy: d.delta.dy * _orbitSpeed);
      case _Mode.deciding:
      case _Mode.none:
        break;
    }
  }

  /// Picks the layer to turn for a drag that started at [start].
  bool _beginTurn(Offset start, Offset total) {
    final proj = _projection();
    final hit = nxnHitTest(_c.state, proj, start);
    if (hit == null) return false;

    final normalAxis = hit.normal.$1 != 0 ? 0 : (hit.normal.$2 != 0 ? 1 : 2);
    final grab = NxnProjection.cubieCenter(hit.pos) +
        NxnProjection.vec(hit.normal) * 0.5;
    final grabScreen = proj.project(grab);

    var bestScore = -1.0;
    for (final axis in [0, 1, 2]) {
      if (axis == normalAxis) continue;
      const eps = 0.01;
      final rot = switch (axis) {
        0 => Matrix4.rotationX(eps),
        1 => Matrix4.rotationY(eps),
        _ => Matrix4.rotationZ(eps),
      };
      final moved = proj.project(rot.transform3(Vector3.copy(grab)));
      final tangent = (moved - grabScreen) / eps;
      if (tangent.distance < 1e-3) continue;
      final score = (total.dx * tangent.dx + total.dy * tangent.dy).abs() /
          tangent.distance;
      if (score > bestScore) {
        bestScore = score;
        _axis = axis;
        _layer = axisOf(hit.pos, axis);
        _tangent = tangent;
      }
    }
    _angle = 0;
    return bestScore >= 0;
  }

  void _onPanEnd(DragEndDetails d) {
    if (_mode == _Mode.turning) {
      final quarters = (_angle / (math.pi / 2)).round().clamp(-2, 2);
      _snapFrom = _angle;
      _snapTo = quarters * math.pi / 2;
      _snap.forward(from: 0).whenComplete(_finishSnap);
    }
    _mode = _Mode.none;
    _start = null;
  }

  void _onSnapTick() {
    final t = Curves.easeOut.transform(_snap.value);
    _c.turn = NxnTurn(_axis, _layer, _snapFrom + (_snapTo - _snapFrom) * t);
  }

  void _finishSnap() {
    if (_c.turn == null) return;
    _snap.stop();
    final quarters = (_snapTo / (math.pi / 2)).round();
    _c.turn = null;
    if (quarters == 0) return;
    final move = NxnMove(_axis, _layer, quarters.abs() == 2 ? 2 : quarters);
    _c.apply(move);
    widget.onMove?.call(move);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: ListenableBuilder(
            listenable: _c,
            builder: (context, _) => CustomPaint(
              size: _size,
              painter: NxnCubePainter(
                state: _c.state,
                rotationX: _c.rotationX,
                rotationY: _c.rotationY,
                turn: _c.turn,
              ),
            ),
          ),
        );
      },
    );
  }
}
