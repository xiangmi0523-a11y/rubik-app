import 'package:cuber/cuber.dart' as cuber;
import 'package:flutter/material.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

import '../../../core/cube/app_cube_controller.dart';
import '../../../core/cube/cube_facelets.dart';
import '../../../core/nxn/nxn_cube_controller.dart';
import '../../../core/nxn/nxn_cube_state.dart';
import '../../../core/nxn/nxn_cube_view.dart';
import '../../../core/pyraminx/pyraminx_controller.dart';
import '../../../core/pyraminx/pyraminx_model.dart';
import '../../../core/pyraminx/pyraminx_view.dart';

/// A move list to play on some puzzle, starting from a given state.
abstract class PlayerScript {
  /// Moves in display notation, one per step.
  List<String> get moves;

  PuzzleStepper createStepper();
}

/// Animates a puzzle step by step for the player.
abstract class PuzzleStepper {
  /// Notifies on every state/animation change.
  Listenable get listenable;

  /// A move is animating or queued.
  bool get busy;

  /// Animates step [index] forwards, or undoes it.
  void animate(int index, {required bool forward});

  /// Instantly shows the state after the first [count] steps.
  void show(int count);

  Widget buildView();

  void dispose();
}

// ── 3x3 (puzzle_cube) ──────────────────────────────────────────────────────

class Cube3Script implements PlayerScript {
  Cube3Script({required this.colors, required this.moves});

  /// 54 colours in cuber facelet order.
  final List<Color> colors;
  @override
  final List<String> moves;

  @override
  PuzzleStepper createStepper() => _Cube3Stepper(this);
}

class _Cube3Stepper implements PuzzleStepper {
  _Cube3Stepper(this.script)
      : cube = AppCubeController(
          initialState: CubeFacelets.build(script.colors),
          moveDuration: const Duration(milliseconds: 320),
        );

  final Cube3Script script;
  final AppCubeController cube;

  List<CubeMove> _turns(int i) =>
      CubeNotation.toQuarterTurns(cuber.Move.parse(script.moves[i]));

  @override
  Listenable get listenable => cube;
  @override
  bool get busy => cube.hasQueuedWork;

  @override
  void animate(int index, {required bool forward}) => cube.playSequence(
      forward ? _turns(index) : _turns(index).reversed.map((m) => m.inverse));

  @override
  void show(int count) {
    final state = CubeFacelets.build(script.colors);
    for (var i = 0; i < count; i++) {
      _turns(i).forEach(state.applyMove);
    }
    cube.replaceState(state);
  }

  @override
  Widget buildView() => Cube(controller: cube);

  @override
  void dispose() => cube.dispose();
}

// ── N×N (in-house engine) ──────────────────────────────────────────────────

class NxnScript implements PlayerScript {
  NxnScript({required this.initial, required this.steps});

  final NxnCubeState initial;
  final List<NxnMove> steps;

  @override
  List<String> get moves => [for (final m in steps) m.notation(initial.n)];

  @override
  PuzzleStepper createStepper() => _NxnStepper(this);
}

class _NxnStepper implements PuzzleStepper {
  _NxnStepper(this.script)
      : cube = NxnCubeController(script.initial.n, initial: script.initial);

  final NxnScript script;
  final NxnCubeController cube;

  @override
  Listenable get listenable => cube;
  @override
  bool get busy => cube.hasQueuedWork;

  @override
  void animate(int index, {required bool forward}) {
    final m = script.steps[index];
    cube.playSequence([forward ? m : m.inverse]);
  }

  @override
  void show(int count) => cube.replaceState(
      script.initial.copy()..applyAll(script.steps.take(count)));

  @override
  Widget buildView() => NxnCubeView(controller: cube);

  @override
  void dispose() => cube.dispose();
}

// ── Pyraminx ───────────────────────────────────────────────────────────────

class PyraminxScript implements PlayerScript {
  PyraminxScript({required this.initial, required this.steps});

  final PyraminxState initial;
  final List<PyraminxMove> steps;

  @override
  List<String> get moves => [for (final m in steps) m.notation];

  @override
  PuzzleStepper createStepper() => _PyraminxStepper(this);
}

class _PyraminxStepper implements PuzzleStepper {
  _PyraminxStepper(this.script)
      : puzzle = PyraminxController(initial: script.initial);

  final PyraminxScript script;
  final PyraminxController puzzle;

  @override
  Listenable get listenable => puzzle;
  @override
  bool get busy => puzzle.hasQueuedWork;

  @override
  void animate(int index, {required bool forward}) {
    final m = script.steps[index];
    puzzle.playSequence([forward ? m : m.inverse]);
  }

  @override
  void show(int count) => puzzle.replaceState(
      script.initial.copy()..applyAll(script.steps.take(count)));

  @override
  Widget buildView() =>
      PyraminxView(controller: puzzle, moveDuration: const Duration(milliseconds: 360));

  @override
  void dispose() => puzzle.dispose();
}
