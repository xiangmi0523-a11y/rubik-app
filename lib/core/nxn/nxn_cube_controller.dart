import 'package:flutter/foundation.dart';

import 'nxn_cube_state.dart';
import 'nxn_projection.dart';

/// Owns an n×n cube's state, camera and in-progress turn.
class NxnCubeController extends ChangeNotifier {
  NxnCubeController(this.n) : _state = NxnCubeState.solved(n);

  final int n;

  static const double initialRotationX = 0.5;
  static const double initialRotationY = -0.6;

  NxnCubeState _state;
  double _rotX = initialRotationX;
  double _rotY = initialRotationY;
  NxnTurn? _turn;

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

  void resetCamera() {
    _rotX = initialRotationX;
    _rotY = initialRotationY;
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

  void reset() {
    _state = NxnCubeState.solved(n);
    _turn = null;
    notifyListeners();
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
