import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

import '../models/cube_move.dart';
import '../models/cubie_model.dart';
import '../models/puzzle_cube_state.dart';
import '../rendering/cube_geometry.dart';
import '../rendering/cube_hit_test.dart';
import '../rendering/realistic_cube_renderer.dart';
import '../rendering/turn_highlight.dart';

/// Drives a [Cube] widget: owns the cube state, queues animated moves, and
/// tracks the view rotation.
///
/// It is a [ChangeNotifier]; the widget rebuilds whenever the state, the
/// pending move, or the view rotation changes.
class CubeController extends ChangeNotifier {
  /// Creates a controller. [initialState] defaults to a solved cube and
  /// [moveDuration] controls how long each animated turn takes.
  CubeController({
    this.moveDuration = const Duration(milliseconds: 350),
    PuzzleCubeState? initialState,
    this.initialViewRotationX = 0,
    this.initialViewRotationY = 0,
  })  : _state = initialState ?? PuzzleCubeState.solved(),
        _viewRotX = initialViewRotationX,
        _viewRotY = initialViewRotationY;

  /// How long a single animated quarter-turn takes. Changing it takes effect
  /// from the next turn (used for playback speed).
  Duration moveDuration;

  /// The view rotation about x restored by [resetCamera].
  final double initialViewRotationX;

  /// The view rotation about y restored by [resetCamera].
  final double initialViewRotationY;

  final Queue<CubeMove> _queue = Queue<CubeMove>();

  PuzzleCubeState _state;
  CubeMove? _pending;
  double _viewRotX;
  double _viewRotY;

  /// The current cube state.
  PuzzleCubeState get state => _state;

  /// The move currently animating, or null if none.
  CubeMove? get pendingMove => _pending;

  /// Whether a move animation is in progress.
  bool get isAnimating => _pending != null;

  /// Whether a move is animating or queued.
  bool get hasQueuedWork => _pending != null || _queue.isNotEmpty;

  /// Whether the cube is solved and idle.
  bool get isSolved => !hasQueuedWork && _state.isSolved;

  /// Current view rotation about x (radians).
  double get viewRotationX => _viewRotX;

  /// Current view rotation about y (radians).
  double get viewRotationY => _viewRotY;

  /// Adds to the view rotation by ([dx], [dy]) radians.
  void rotateView({double dx = 0, double dy = 0}) {
    if (dx == 0 && dy == 0) return;
    _viewRotY += dx;
    _viewRotX += dy;
    notifyListeners();
  }

  /// Restores the view rotation to its initial orientation.
  void resetCamera() {
    _viewRotX = initialViewRotationX;
    _viewRotY = initialViewRotationY;
    notifyListeners();
  }

  /// Queues a single animated [move].
  void play(CubeMove move) {
    _queue.add(move);
    _tryStartNext();
  }

  /// Queues a sequence of animated [moves], played in order.
  void playSequence(Iterable<CubeMove> moves) {
    _queue.addAll(moves);
    _tryStartNext();
  }

  /// Applies [move] to the state immediately, with no animation. Used to commit
  /// a drag-turn whose rotation the gesture has already shown on screen.
  void applyMoveInstant(CubeMove move) {
    if (hasQueuedWork) return;
    _state.applyMove(move);
    notifyListeners();
  }

  /// Clears any queued work and resets to a solved cube.
  void reset() {
    _queue.clear();
    _pending = null;
    _state = PuzzleCubeState.solved();
    notifyListeners();
  }

  /// Replaces the state with a random scramble of [moves] turns (see
  /// [PuzzleCubeState.random]).
  void scramble({int moves = 25, int? seed}) {
    _queue.clear();
    _pending = null;
    _state = PuzzleCubeState.random(moves: moves, seed: seed);
    notifyListeners();
  }

  /// Paints a sticker (ignored while a move is animating). See
  /// [PuzzleCubeState.setStickerColor].
  void setStickerColor({
    required int x,
    required int y,
    required int z,
    required CubieFace face,
    required Color color,
  }) {
    if (isAnimating) return;
    if (_state.setStickerColor(x: x, y: y, z: z, face: face, color: color)) {
      notifyListeners();
    }
  }

  /// Replaces the entire cube state (ignored while a move is animating).
  void replaceState(PuzzleCubeState newState) {
    if (isAnimating) return;

    _queue.clear();
    _pending = null;
    _state = newState.copy();
    notifyListeners();
  }

  void _commitPending() {
    final move = _pending;
    if (move == null) return;
    _state.applyMove(move);
    _pending = null;
    notifyListeners();
    _tryStartNext();
  }

  void _tryStartNext() {
    if (_pending != null || _queue.isEmpty) return;
    _pending = _queue.removeFirst();
    notifyListeners();
  }
}

/// An interactive 3D cube widget driven by a [CubeController].
///
/// Drag off the cube to orbit the view. If [onMove] is provided, dragging *on*
/// the cube turns the grabbed layer (following the finger, snapping to the
/// nearest quarter-turn on release). If [onFaceTap] is provided, tapping a face
/// reports the front-most face under the tap.
class Cube extends StatefulWidget {
  /// Creates an interactive cube widget.
  const Cube({
    super.key,
    required this.controller,
    this.enableGestures = true,
    this.onFaceTap,
    this.onMove,
    this.highlightTurns = false,
  });

  /// The controller that owns the cube state and view rotation.
  final CubeController controller;

  /// Keep the turning layer bright and dim the rest while queued moves play
  /// (see [TurnHighlight]). Off: the cube looks exactly as before.
  final bool highlightTurns;

  /// Whether drag/tap gestures are handled. When false the cube is display-only.
  final bool enableGestures;

  /// Called when the user taps a visible face of the cube, with the cube face
  /// that is front-most under the tap (so a tap never "passes through" to the
  /// opposite side). Null disables tap-to-select.
  final void Function(CubieFace face)? onFaceTap;

  /// Called when the user finishes a drag that turns a layer, with the committed
  /// move. Providing this enables drag-to-turn: dragging *on* the cube turns the
  /// grabbed layer (following the finger, snapping on release); dragging off the
  /// cube still orbits the view. Null disables drag-to-turn (all drags orbit).
  final void Function(CubeMove move)? onMove;

  @override
  State<Cube> createState() => _CubeState();
}

typedef _MovePlan = ({
  bool Function(CubieModel cubie) inSlice,
  Matrix4 Function(double t) matrixAt,
});

enum _GestureMode { none, deciding, orbiting, turning }

class _CubeState extends State<Cube> with TickerProviderStateMixin {
  late final AnimationController _anim;
  late final AnimationController _snap;
  _MovePlan? _activePlan;

  final TurnHighlight _highlight = TurnHighlight();
  late final Ticker _highlightTicker = createTicker(_onHighlightTick);
  final _highlightRepaint = ValueNotifier<int>(0);
  Duration _highlightLast = Duration.zero;
  PuzzleCubeState? _shownState;

  // ── Drag-to-turn state ──────────────────────────────
  static const double _kDecidePx = 12;
  static const double _kSnapThreshold = math.pi / 4;
  static const double _kMaxAngle = math.pi / 2 + 0.45;

  _GestureMode _mode = _GestureMode.none;
  Offset? _panStart;
  CubeDrag? _drag;
  double _dragAngle = 0;
  Size _size = Size.zero;

  double _snapBegin = 0;
  double _snapEnd = 0;
  CubeMove? _snapMove;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: widget.controller.moveDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          // Reset before committing: _commitPending() starts the next queued
          // move's animation, so resetting afterwards would clobber it and
          // stall the sequence after a single move.
          _anim.reset();
          _highlight.end();
          widget.controller._commitPending();
        }
      });
    _snap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    )
      ..addListener(_onSnapTick)
      ..addStatusListener(_onSnapStatus);
    _shownState = widget.controller.state;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant Cube oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _anim.duration = widget.controller.moveDuration;
      _resetHighlight();
    }
    if (oldWidget.highlightTurns && !widget.highlightTurns) _resetHighlight();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _highlightTicker.dispose();
    _highlightRepaint.dispose();
    _anim.dispose();
    _snap.dispose();
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

  void _onControllerChanged() {
    // A replaced state (jump, reset, scramble) shows no turn.
    if (!identical(widget.controller.state, _shownState)) {
      _shownState = widget.controller.state;
      _resetHighlight();
    }
    final move = widget.controller.pendingMove;
    if (move != null && !_anim.isAnimating) {
      final plan = _planFor(move);
      setState(() => _activePlan = plan);
      _anim.duration = widget.controller.moveDuration;
      if (widget.highlightTurns) {
        // Exactly the cubies the painter rotates for this move.
        _highlight.begin(
          [
            for (final c in widget.controller.state.cubies)
              if (plan.inSlice(c)) (c.x, c.y, c.z),
          ],
          widget.controller.moveDuration,
        );
        if (!_highlightTicker.isActive) {
          _highlightLast = Duration.zero;
          _highlightTicker.start();
        }
      }
      _anim.forward();
    } else if (move == null) {
      setState(() => _activePlan = null);
    }
  }

  // ── Drag gesture ────────────────────────────────────
  void _onPanStart(DragStartDetails details) {
    if (_snap.isAnimating) _snap.stop();
    _panStart = details.localPosition;
    _mode = _GestureMode.deciding;
    _drag = null;
    _dragAngle = 0;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final start = _panStart;
    if (start == null) return;
    final cumulative = details.localPosition - start;

    if (_mode == _GestureMode.deciding) {
      if (cumulative.distance < _kDecidePx) return;
      CubeDrag? drag;
      if (widget.onMove != null && !widget.controller.hasQueuedWork) {
        drag = cubeDragFor(
          start: start,
          delta: cumulative,
          size: _size,
          scale: cubeViewScale(_size),
          viewRotationX: widget.controller.viewRotationX,
          viewRotationY: widget.controller.viewRotationY,
        );
      }
      _mode = drag != null ? _GestureMode.turning : _GestureMode.orbiting;
      _drag = drag;
    }

    switch (_mode) {
      case _GestureMode.turning:
        final drag = _drag!;
        final along =
            cumulative.dx * drag.tangent.dx + cumulative.dy * drag.tangent.dy;
        final angle =
            (along / drag.pixelsPerRadian).clamp(-_kMaxAngle, _kMaxAngle);
        setState(() => _dragAngle = angle);
      case _GestureMode.orbiting:
        widget.controller.rotateView(
          dx: details.delta.dx * 0.01,
          dy: details.delta.dy * 0.01,
        );
      case _GestureMode.deciding:
      case _GestureMode.none:
        break;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_mode == _GestureMode.turning) _settleDrag();
    _mode = _GestureMode.none;
    _panStart = null;
  }

  void _settleDrag() {
    final drag = _drag;
    if (drag == null) return;
    final a = _dragAngle;
    if (a >= _kSnapThreshold) {
      _snapMove = drag.posMove;
      _snapEnd = math.pi / 2;
    } else if (a <= -_kSnapThreshold) {
      _snapMove = drag.posMove.inverse;
      _snapEnd = -math.pi / 2;
    } else {
      _snapMove = null;
      _snapEnd = 0;
    }
    _snapBegin = a;
    _snap
      ..reset()
      ..forward();
  }

  void _onSnapTick() {
    final t = Curves.easeOut.transform(_snap.value);
    setState(() => _dragAngle = _snapBegin + (_snapEnd - _snapBegin) * t);
  }

  void _onSnapStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final move = _snapMove;
    _snapMove = null;
    // Clear the drag overlay and commit in the same turn: the slice is already
    // drawn at ±90°, so applying the move to the state and dropping the overlay
    // produces identical pixels — no visible jump.
    setState(() {
      _drag = null;
      _dragAngle = 0;
    });
    if (move != null) widget.onMove?.call(move);
    _snap.reset();
  }

  _MovePlan _planFor(CubeMove move) {
    const q = math.pi / 2;
    switch (move) {
      case CubeMove.r:
        return (
          inSlice: (c) => c.x == 1,
          matrixAt: (t) => Matrix4.identity()..rotateX(t * q),
        );
      case CubeMove.ri:
        return (
          inSlice: (c) => c.x == 1,
          matrixAt: (t) => Matrix4.identity()..rotateX(-t * q),
        );
      case CubeMove.l:
        return (
          inSlice: (c) => c.x == -1,
          matrixAt: (t) => Matrix4.identity()..rotateX(-t * q),
        );
      case CubeMove.li:
        return (
          inSlice: (c) => c.x == -1,
          matrixAt: (t) => Matrix4.identity()..rotateX(t * q),
        );
      case CubeMove.d:
        return (
          inSlice: (c) => c.y == 1,
          matrixAt: (t) => Matrix4.identity()..rotateY(-t * q),
        );
      case CubeMove.di:
        return (
          inSlice: (c) => c.y == 1,
          matrixAt: (t) => Matrix4.identity()..rotateY(t * q),
        );
      case CubeMove.u:
        return (
          inSlice: (c) => c.y == -1,
          matrixAt: (t) => Matrix4.identity()..rotateY(t * q),
        );
      case CubeMove.ui:
        return (
          inSlice: (c) => c.y == -1,
          matrixAt: (t) => Matrix4.identity()..rotateY(-t * q),
        );
      case CubeMove.f:
        return (
          inSlice: (c) => c.z == 1,
          matrixAt: (t) => Matrix4.identity()..rotateZ(t * q),
        );
      case CubeMove.fi:
        return (
          inSlice: (c) => c.z == 1,
          matrixAt: (t) => Matrix4.identity()..rotateZ(-t * q),
        );
      case CubeMove.b:
        return (
          inSlice: (c) => c.z == -1,
          matrixAt: (t) => Matrix4.identity()..rotateZ(-t * q),
        );
      case CubeMove.bi:
        return (
          inSlice: (c) => c.z == -1,
          matrixAt: (t) => Matrix4.identity()..rotateZ(t * q),
        );
      // Middle slices.
      case CubeMove.m:
        return (
          inSlice: (c) => c.x == 0,
          matrixAt: (t) => Matrix4.identity()..rotateX(-t * q),
        );
      case CubeMove.mi:
        return (
          inSlice: (c) => c.x == 0,
          matrixAt: (t) => Matrix4.identity()..rotateX(t * q),
        );
      case CubeMove.e:
        return (
          inSlice: (c) => c.y == 0,
          matrixAt: (t) => Matrix4.identity()..rotateY(-t * q),
        );
      case CubeMove.ei:
        return (
          inSlice: (c) => c.y == 0,
          matrixAt: (t) => Matrix4.identity()..rotateY(t * q),
        );
      case CubeMove.s:
        return (
          inSlice: (c) => c.z == 0,
          matrixAt: (t) => Matrix4.identity()..rotateZ(t * q),
        );
      case CubeMove.si:
        return (
          inSlice: (c) => c.z == 0,
          matrixAt: (t) => Matrix4.identity()..rotateZ(-t * q),
        );
    }
  }

  Matrix4 _sliceRotation(int axis, double angle) {
    final m = Matrix4.identity();
    switch (axis) {
      case 0:
        m.rotateX(angle);
      case 1:
        m.rotateY(angle);
      default:
        m.rotateZ(angle);
    }
    return m;
  }

  int _coordOnAxis(CubieModel c, int axis) =>
      axis == 0 ? c.x : (axis == 1 ? c.y : c.z);

  @override
  Widget build(BuildContext context) {
    final viewport = AnimatedBuilder(
      animation: Listenable.merge([_anim, _highlightRepaint]),
      builder: (context, _) {
        final viewMatrix = Matrix4.identity()
          ..rotateX(widget.controller.viewRotationX)
          ..rotateY(widget.controller.viewRotationY);

        final Matrix4 sliceMatrix;
        final bool Function(CubieModel) inSlice;
        final drag = _drag;
        if (drag != null) {
          sliceMatrix = _sliceRotation(drag.axis, _dragAngle);
          inSlice = (c) => _coordOnAxis(c, drag.axis) == drag.layer;
        } else {
          final plan = _activePlan;
          sliceMatrix = plan?.matrixAt(_anim.value) ?? Matrix4.identity();
          inSlice = plan?.inSlice ?? (_) => false;
        }

        return CustomPaint(
          size: Size.infinite,
          painter: CubePainter(
            cubies: widget.controller.state.cubies,
            viewMatrix: viewMatrix,
            sliceMatrix: sliceMatrix,
            inSlice: inSlice,
            brightness: widget.highlightTurns
                ? (c) => _highlight.brightnessOf((c.x, c.y, c.z))
                : null,
          ),
        );
      },
    );

    if (!widget.enableGestures) return viewport;

    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onTapUp: widget.onFaceTap == null
              ? null
              : (details) {
                  final face = cubeFaceAtTap(
                    tap: details.localPosition,
                    size: _size,
                    scale: cubeViewScale(_size),
                    viewRotationX: widget.controller.viewRotationX,
                    viewRotationY: widget.controller.viewRotationY,
                  );
                  if (face != null) widget.onFaceTap!(face);
                },
          child: viewport,
        );
      },
    );
  }
}

/// Pixels per model unit used by the [Cube] widget (and its hit tests): the
/// cube's model extent ([kCubeFitSpread]) fitted to the viewport.
double cubeViewScale(Size size) =>
    size.isEmpty ? 0 : math.min(size.width, size.height) / 2 / kCubeFitSpread;

/// Draws the cube with [RealisticCubeRenderer] using the same projection as
/// the hit tests: perspective · scale(s, -s, -s) · view · slice.
class CubePainter extends CustomPainter {
  /// Creates the painter for one frame.
  CubePainter({
    required this.cubies,
    required this.viewMatrix,
    required this.sliceMatrix,
    required this.inSlice,
    this.brightness,
  });

  /// Cubies of the cube, at their positions before the current turn.
  final List<CubieModel> cubies;

  /// Camera rotation.
  final Matrix4 viewMatrix;

  /// Rotation of the turning layer at this frame.
  final Matrix4 sliceMatrix;

  /// Whether a cubie is in the turning layer (rotated by [sliceMatrix]).
  final bool Function(CubieModel) inSlice;

  /// Light multiplier per cubie (the turn highlight); null = 1.
  final double Function(CubieModel)? brightness;

  static final _renderer = RealisticCubeRenderer();

  static final _faces = <(CubieFace, Vector3, Vector3, Vector3)>[
    (CubieFace.xPos, Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)),
    (CubieFace.xNeg, Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)),
    (CubieFace.yPos, Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)),
    (CubieFace.yNeg, Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)),
    (CubieFace.zPos, Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)),
    (CubieFace.zNeg, Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 1, 0)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = cubeViewScale(size);
    if (scale <= 0) return;
    final flip = Matrix4.identity()..scaleByDouble(scale, -scale, -scale, 1);
    final perspective = Matrix4.identity()..setEntry(3, 2, -0.001);
    final camera = Vector3(0, 0, 1000); // where w = 1 - 0.001 z vanishes
    final cx = size.width / 2;
    final cy = size.height / 2;

    // A turning layer splits the cube into slabs along the turn axis; drawing
    // them slab by slab (back to front) keeps them from cutting into each
    // other mid-turn.
    final sliceCubies = cubies.where(inSlice).toList();
    int? sliceAxis;
    int? sliceLayer;
    if (sliceCubies.isNotEmpty) {
      for (final axis in const [0, 1, 2]) {
        final values = sliceCubies.map((c) => _coord(c, axis)).toSet();
        if (values.length == 1) {
          sliceAxis = axis;
          sliceLayer = values.first;
          break;
        }
      }
    }

    final draws = <CubieDraw>[];
    for (final cubie in cubies) {
      final model =
          inSlice(cubie) ? viewMatrix.multiplied(sliceMatrix) : viewMatrix;
      final eye = flip.multiplied(model); // screen-aligned, pre-perspective
      final full = perspective.multiplied(eye);
      Offset project(Vector3 p) {
        final v = full.perspectiveTransform(Vector3.copy(p));
        return Offset(cx + v.x, cy + v.y);
      }

      final center = Vector3(
        cubie.x * kCubeSpacing,
        cubie.y * kCubeSpacing,
        cubie.z * kCubeSpacing,
      );
      final faces = <CubieFaceDraw>[];
      for (final (face, n, u0, v0) in _faces) {
        final faceCenter = center + n * kCubieHalf;
        final u = u0 * kCubieHalf;
        final v = v0 * kCubieHalf;
        final eyeCenter = eye.transform3(Vector3.copy(faceCenter));
        final eyeNormal = eye.rotated3(Vector3.copy(n))..normalize();
        if (eyeNormal.dot(camera - eyeCenter) <= 0) continue; // back face
        faces.add(
          CubieFaceDraw(
            at: (a, b) => project(faceCenter + u * a + v * b),
            normal: eyeNormal,
            sticker: cubie.faces[face],
          ),
        );
      }
      if (faces.isEmpty) continue;
      draws.add(
        CubieDraw(
          depth: eye.transform3(Vector3.copy(center)).z,
          group: _groupOf(cubie, sliceAxis, sliceLayer),
          brightness: brightness?.call(cubie) ?? 1,
          faces: faces,
        ),
      );
    }
    _renderer.paint(
      canvas,
      size,
      draws,
      extent: kCubeHalfExtent * scale * 1.15,
    );
  }

  static int _coord(CubieModel c, int axis) =>
      axis == 0 ? c.x : (axis == 1 ? c.y : c.z);

  /// Slab index along the turn axis (-1 below, 0 the turning layer, 1 above),
  /// or 0 for everything when nothing turns.
  static int _groupOf(CubieModel c, int? axis, int? layer) {
    if (axis == null || layer == null) return 0;
    return (_coord(c, axis) - layer).sign;
  }

  @override
  bool shouldRepaint(covariant CubePainter old) => true;
}
