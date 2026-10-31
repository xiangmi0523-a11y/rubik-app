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
  const NxnCubeView({
    super.key,
    required this.controller,
    this.onMove,
    this.onStickerTap,
    this.moveDuration = const Duration(milliseconds: 260),
  });

  final NxnCubeController controller;

  /// Called after a finger turn is committed.
  final ValueChanged<NxnMove>? onMove;

  /// Taps on stickers (e.g. for colouring); null disables tap handling.
  final ValueChanged<NxnStickerHit>? onStickerTap;

  /// Duration of each queued (programmatic) move animation.
  final Duration moveDuration;

  @override
  State<NxnCubeView> createState() => _NxnCubeViewState();
}

enum _Mode { none, deciding, orbiting, turning }

class _NxnCubeViewState extends State<NxnCubeView>
    with TickerProviderStateMixin {
  static const _decidePx = 12.0;
  static const _edgeGrabPx = 16.0;
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

  late final AnimationController _anim =
      AnimationController(vsync: this, duration: widget.moveDuration)
        ..addListener(_onAnimTick)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) {
            _anim.reset();
            _animating = null;
            widget.controller.commitPending();
          }
        });

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
  }

  @override
  void didUpdateWidget(covariant NxnCubeView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _snap.dispose();
    _anim.dispose();
    super.dispose();
  }

  /// The queued move currently being animated. Guards against restarting:
  /// `forward(from: 0)` notifies listeners before `isAnimating` turns true.
  NxnMove? _animating;

  void _onController() {
    final pending = _c.pending;
    if (pending == null || identical(pending, _animating)) return;
    _animating = pending;
    _anim.forward(from: 0);
  }

  void _onAnimTick() {
    final move = _c.pending;
    if (move == null) return;
    final t = Curves.easeInOut.transform(_anim.value);
    final target = (move.turns == 2 ? 2 : move.turns) * math.pi / 2;
    _c.turn = NxnTurn(move.axis, move.layer, target * t);
  }

  void _onTapUp(TapUpDetails d) {
    final hit = nxnHitTest(_c.state, _projection(), d.localPosition);
    if (hit != null) widget.onStickerTap!(hit);
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
      _mode = widget.onMove != null && !_c.hasQueuedWork &&
              _beginTurn(start, total)
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
  ///
  /// The swipe is decomposed into the grabbed face's two in-plane axes (in
  /// world units). Moving along one axis turns the layer about the other.
  /// Unlike comparing screen angles, this stays right on steeply
  /// foreshortened faces, where both axes point almost the same way on screen.
  bool _beginTurn(Offset start, Offset total) {
    final proj = _projection();
    final hit = nxnHitTest(_c.state, proj, start, tolerance: _edgeGrabPx);
    if (hit == null) return false;

    final normalAxis = hit.normal.$1 != 0 ? 0 : (hit.normal.$2 != 0 ? 1 : 2);
    final grab = NxnProjection.cubieCenter(hit.pos) +
        NxnProjection.vec(hit.normal) * 0.5;
    final grabScreen = proj.project(grab);
    final inPlane = [0, 1, 2]..remove(normalAxis);

    Offset screenDir(int axis) {
      final unit = Vector3.zero()..[axis] = 0.01;
      return (proj.project(grab + unit) - grabScreen) / 0.01;
    }

    final a = inPlane[0];
    final b = inPlane[1];
    final dirA = screenDir(a);
    final dirB = screenDir(b);
    final det = dirA.dx * dirB.dy - dirA.dy * dirB.dx;
    double alongA;
    double alongB;
    if (det.abs() > 1e-6) {
      alongA = (total.dx * dirB.dy - total.dy * dirB.dx) / det;
      alongB = (dirA.dx * total.dy - dirA.dy * total.dx) / det;
    } else {
      alongA = (total.dx * dirA.dx + total.dy * dirA.dy) / dirA.distance;
      alongB = (total.dx * dirB.dx + total.dy * dirB.dy) / dirB.distance;
    }
    // Swiping along A turns the layer about B, and vice versa.
    final axis = alongA.abs() >= alongB.abs() ? b : a;

    const eps = 0.01;
    final rot = switch (axis) {
      0 => Matrix4.rotationX(eps),
      1 => Matrix4.rotationY(eps),
      _ => Matrix4.rotationZ(eps),
    };
    final tangent =
        (proj.project(rot.transform3(Vector3.copy(grab))) - grabScreen) / eps;
    if (tangent.distance < 1e-3) return false;
    _axis = axis;
    _layer = axisOf(hit.pos, axis);
    _tangent = tangent;
    _angle = 0;
    return true;
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
          onTapUp: widget.onStickerTap == null ? null : _onTapUp,
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
