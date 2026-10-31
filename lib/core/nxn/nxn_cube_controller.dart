import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:flutter/painting.dart' show Color;

import 'nxn_cube_state.dart';
import 'nxn_projection.dart';

/// Owns an n×n cube's state, camera and in-progress turn.
class NxnCubeController extends ChangeNotifier {
  NxnCubeController(this.n, {NxnCubeState? initial})
      : _state = initial?.copy() ?? NxnCubeState.solved(n);

  final int n;

  static const double initialRotationX = 0.5;
  static const double initialRotationY = -0.6;

  NxnCubeState _state;
  double _rotX = initialRotationX;
  double _rotY = initialRotationY;
  NxnTurn? _turn;
  final Queue<NxnBlockMove> _queue = Queue();
  NxnBlockMove? _pending;

  /// Playback speed factor for queued animations (1 = normal).
  double speed = 1;

  /// Turn currently animating (driven by an [NxnCubeView]), or null.
  NxnBlockMove? get pending => _pending;
  bool get hasQueuedWork => _pending != null || _queue.isNotEmpty;

  NxnCubeState get state => _state;
  double get rotationX => _rotX;
  double get rotationY => _rotY;
  NxnTurn? get turn => _turn;
  bool get isSolved => _state.isSolved;

  /// Orbits the camera; positive dx/dy follow a finger moving right/down.
  void orbit({double dx = 0, double dy = 0}) {
    _rotY += dx;
    _rotX = (_rotX + dy).clamp(-1.5, 1.5);
    notifyListeners();
  }

  void resetCamera() => setView(
      rotationX: initialRotationX, rotationY: initialRotationY);

  void setView({required double rotationX, required double rotationY}) {
    _rotX = rotationX;
    _rotY = rotationY;
    notifyListeners();
  }

  set turn(NxnTurn? value) {
    _turn = value;
    notifyListeners();
  }

  void apply(NxnMove move) {
    _state.apply(move);
    notifyListeners();
  }

  void reset() => replaceState(NxnCubeState.solved(n));

  void replaceState(NxnCubeState state) {
    _queue.clear();
    _pending = null;
    _turn = null;
    _state = state.copy();
    notifyListeners();
  }

  /// Paints one sticker (colour input).
  void setSticker(IVec pos, IVec normal, Color color) {
    for (final c in _state.cubies) {
      if (c.pos == pos && c.stickers.containsKey(normal)) {
        c.stickers[normal] = color;
        notifyListeners();
        return;
      }
    }
  }

  /// Queues animated single-layer moves.
  void playSequence(Iterable<NxnMove> moves) =>
      playBlocks(moves.map(NxnBlockMove.single));

  /// Queues animated turns; a wide turn animates all its layers together.
  void playBlocks(Iterable<NxnBlockMove> blocks) {
    _queue.addAll(blocks);
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
    _state.applyBlock(move);
    notifyListeners();
    _startNext();
  }

  /// Applies a random scramble and returns it in standard notation.
  String scramble() {
    final moves = NxnCubeState.randomScramble(n);
    _state = NxnCubeState.solved(n)..applyAll(moves);
    _turn = null;
    notifyListeners();
    return moves.map((m) => m.notation(n)).join(' ');
  }
}
