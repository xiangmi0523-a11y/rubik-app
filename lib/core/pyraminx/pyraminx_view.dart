import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:puzzle_cube/puzzle_cube.dart' show TurnHighlight;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'pyraminx_controller.dart';
import 'pyraminx_model.dart';
import 'pyraminx_painter.dart';
import 'pyraminx_projection.dart';

/// Interactive Pyraminx. Drag a tip to turn the tip, any other sticker to
/// turn its layer (follows the finger, snaps to 120°); drag off it orbits.
/// [onSlotTap] (if set) reports taps on stickers, e.g. for colouring.
class PyraminxView extends StatefulWidget {
  const PyraminxView({
    super.key,
    required this.controller,
    this.onMove,
    this.onSlotTap,
    this.moveDuration = const Duration(milliseconds: 280),
    this.highlightTurns = false,
  });

  final PyraminxController controller;
  final ValueChanged<PyraminxMove>? onMove;
  final ValueChanged<int>? onSlotTap;
  final Duration moveDuration;

  /// Keep the turning part bright and dim the rest while queued turns play
  /// (the player). Off: the puzzle looks exactly as before.
  final bool highlightTurns;

  @override
  State<PyraminxView> createState() => _PyraminxViewState();
}

enum _Mode { none, deciding, orbiting, turning }

class _PyraminxViewState extends State<PyraminxView>
    with TickerProviderStateMixin {
  static const _decidePx = 12.0;
  static const _edgeGrabPx = 16.0;
  static const _third = 2 * math.pi / 3;

  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  )..addListener(_onSnapTick);
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: widget.moveDuration)
        ..addListener(_onAnimTick)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) {
            _anim.reset();
            _animating = null;
            _highlight.end();
            widget.controller.commitPending();
          }
        });

  /// Turning part bright, the rest dimmed (only with [highlightTurns]).
  final TurnHighlight _highlight = TurnHighlight();
  late final Ticker _highlightTicker = createTicker(_onHighlightTick);
  final _highlightRepaint = ValueNotifier<int>(0);
  Duration _highlightLast = Duration.zero;
  PyraminxState? _shownState;

  Size _size = Size.zero;
  _Mode _mode = _Mode.none;
  Offset? _start;
  int _axis = 0;
  bool _tip = false;
  Offset _tangent = Offset.zero;
  double _angle = 0;
  double _snapFrom = 0;
  double _snapTo = 0;

  PyraminxController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _shownState = _c.state;
    _c.addListener(_onController);
  }

  @override
  void didUpdateWidget(covariant PyraminxView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
      _resetHighlight();
    }
    if (old.highlightTurns && !widget.highlightTurns) _resetHighlight();
  }

  @override
  void dispose() {
    _c.removeListener(_onController);
    _highlightTicker.dispose();
    _highlightRepaint.dispose();
    _snap.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _resetHighlight() {
    _highlight.reset();
    if (_highlightTicker.isActive) _highlightTicker.stop();
    _highlightRepaint.value++;
  }

  void _onHighlightTick(Duration elapsed) {
    final dt = elapsed - _highlightLast;
    _highlightLast = elapsed;
    final changing = _highlight.tick(dt);
    _highlightRepaint.value++;
    if (!changing) _highlightTicker.stop();
  }

  /// The queued move currently being animated. Guards against restarting:
  /// `forward(from: 0)` notifies listeners before `isAnimating` turns true.
  PyraminxMove? _animating;

  void _onController() {
    // A replaced state (jump, reset) shows no turn: drop any highlight.
    if (!identical(_c.state, _shownState)) {
      _shownState = _c.state;
      _resetHighlight();
    }
    final pending = _c.pending;
    if (pending == null || identical(pending, _animating)) return;
    _animating = pending;
    _anim.duration = widget.moveDuration * (1 / _c.speed);
    if (widget.highlightTurns) {
      // Exactly the sticker slots the painter rotates for this turn.
      final slots = PyraminxGeometry.slots;
      _highlight.begin([
        for (var i = 0; i < slots.length; i++)
          if (PyraminxGeometry.inRegion(slots[i], pending.axis, pending.tip)) i,
      ], _anim.duration!);
      if (!_highlightTicker.isActive) {
        _highlightLast = Duration.zero;
        _highlightTicker.start();
      }
    }
    _anim.forward(from: 0);
  }

  void _onAnimTick() {
    final move = _c.pending;
    if (move == null) return;
    final t = Curves.easeInOut.transform(_anim.value);
    _c.turn = PyraminxTurn(move.axis, move.tip, move.angle * t);
  }

  PyraminxProjection _projection() => PyraminxProjection(
        size: _size,
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
        _angle = ((total.dx * _tangent.dx + total.dy * _tangent.dy) /
                _tangent.distanceSquared)
            .clamp(-_third - 0.4, _third + 0.4);
        _c.turn = PyraminxTurn(_axis, _tip, _angle);
      case _Mode.orbiting:
        _c.orbit(dx: d.delta.dx * 0.01, dy: d.delta.dy * 0.01);
      case _Mode.deciding:
      case _Mode.none:
        break;
    }
  }

  bool _beginTurn(Offset start, Offset total) {
    final proj = _projection();
    final slot = pyraminxHitTest(proj, start, tolerance: _edgeGrabPx);
    if (slot == null) return false;
    final s = PyraminxGeometry.slots[slot];

    // Tips turn alone; other stickers turn one of the layers they belong to.
    final candidates = <(int, bool)>[];
    for (var a = 0; a < 4; a++) {
      if (PyraminxGeometry.inRegion(s, a, true)) {
        candidates
          ..clear()
          ..add((a, true));
        break;
      }
      if (PyraminxGeometry.inRegion(s, a, false)) candidates.add((a, false));
    }
    final grabScreen = proj.project(s.centroid);
    var bestScore = -1.0;
    for (final (axis, tip) in candidates) {
      const eps = 0.01;
      final moved = proj.project(PyraminxGeometry.rotation(axis, eps)
          .transform3(Vector3.copy(s.centroid)));
      final tangent = (moved - grabScreen) / eps;
      if (tangent.distance < 1e-3) continue;
      final score = (total.dx * tangent.dx + total.dy * tangent.dy).abs() /
          tangent.distance;
      if (score > bestScore) {
        bestScore = score;
        _axis = axis;
        _tip = tip;
        _tangent = tangent;
      }
    }
    _angle = 0;
    return bestScore >= 0;
  }

  void _onPanEnd(DragEndDetails d) {
    if (_mode == _Mode.turning) {
      final steps = (_angle / _third).round().clamp(-1, 1);
      _snapFrom = _angle;
      _snapTo = steps * _third;
      _snap.forward(from: 0).whenComplete(_finishSnap);
    }
    _mode = _Mode.none;
    _start = null;
  }

  void _onSnapTick() {
    final t = Curves.easeOut.transform(_snap.value);
    _c.turn = PyraminxTurn(_axis, _tip, _snapFrom + (_snapTo - _snapFrom) * t);
  }

  void _finishSnap() {
    if (_c.turn == null) return;
    _snap.stop();
    final steps = (_snapTo / _third).round();
    _c.turn = null;
    if (steps == 0) return;
    final move = PyraminxMove(_axis, tip: _tip, clockwise: steps < 0);
    _c.apply(move);
    widget.onMove?.call(move);
  }

  void _onTapUp(TapUpDetails d) {
    final slot = pyraminxHitTest(_projection(), d.localPosition);
    if (slot != null) widget.onSlotTap!(slot);
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
          onTapUp: widget.onSlotTap == null ? null : _onTapUp,
          child: ListenableBuilder(
            listenable: Listenable.merge([_c, _highlightRepaint]),
            builder: (context, _) => CustomPaint(
              size: _size,
              painter: PyraminxPainter(
                colors: _c.state.colors,
                rotationX: _c.rotationX,
                rotationY: _c.rotationY,
                turn: _c.turn,
                brightness:
                    widget.highlightTurns ? (i) => _highlight.brightnessOf(i) : null,
              ),
            ),
          ),
        );
      },
    );
  }
}
