import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../features/pyraminx/domain/pyraminx_scramble.dart';
import 'pyraminx_model.dart';

/// A part of the Pyraminx being turned (by a finger or an animation).
class PyraminxTurn {
  const PyraminxTurn(this.axis, this.tip, this.angle);
  final int axis;
  final bool tip;

  /// Radians about the outward vertex axis (negative = clockwise).
  final double angle;
}

/// Owns a Pyraminx's state, camera, in-progress turn and animation queue.
class PyraminxController extends ChangeNotifier {
  PyraminxController({PyraminxState? initial})
      : _state = initial?.copy() ?? PyraminxState.solved();

  static const double initialRotationX = 0.16;
  static const double initialRotationY = -0.95;

  PyraminxState _state;
  double _rotX = initialRotationX;
  double _rotY = initialRotationY;
  PyraminxTurn? _turn;
  final Queue<PyraminxMove> _queue = Queue();
  PyraminxMove? _pending;

  PyraminxState get state => _state;
  double get rotationX => _rotX;
  double get rotationY => _rotY;
  PyraminxTurn? get turn => _turn;
  bool get isSolved => _state.isSolved;

  /// Move currently animating (driven by the view), or null.
  PyraminxMove? get pending => _pending;
  bool get hasQueuedWork => _pending != null || _queue.isNotEmpty;

  void orbit({double dx = 0, double dy = 0}) {
    _rotY += dx;
    _rotX = (_rotX + dy).clamp(-1.5, 1.5);
    notifyListeners();
  }

  void setView({required double rotationX, required double rotationY}) {
    _rotX = rotationX;
    _rotY = rotationY;
    notifyListeners();
  }

  void resetCamera() => setView(
      rotationX: initialRotationX, rotationY: initialRotationY);

  set turn(PyraminxTurn? value) {
    _turn = value;
    notifyListeners();
  }

  void apply(PyraminxMove move) {
    _state.apply(move);
    notifyListeners();
  }

  void replaceState(PyraminxState state) {
    _queue.clear();
    _pending = null;
    _turn = null;
    _state = state.copy();
    notifyListeners();
  }

  void setSticker(int slot, int color) {
    _state.colors[slot] = color;
    notifyListeners();
  }

  void reset() => replaceState(PyraminxState.solved());

  /// WCA-style random scramble applied to a solved puzzle; returns its text.
  String scramble({math.Random? rng}) {
    final text = pyraminxScramble(rng: rng);
    replaceState(PyraminxState.solved()..applyAll(PyraminxMove.parseAll(text)));
    return text;
  }

  /// Queues animated moves (played by a [PyraminxView]).
  void playSequence(Iterable<PyraminxMove> moves) {
    _queue.addAll(moves);
    _startNext();
  }

  void _startNext() {
    if (_pending != null || _queue.isEmpty) return;
    _pending = _queue.removeFirst();
    notifyListeners();
  }

  /// Called by the view when the pending animation finishes.
  void commitPending() {
    final move = _pending;
    if (move == null) return;
    _pending = null;
    _turn = null;
    _state.apply(move);
    notifyListeners();
    _startNext();
  }
}
