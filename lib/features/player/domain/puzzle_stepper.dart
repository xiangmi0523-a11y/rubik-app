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

/// Duration of one animated turn in the player at 1× (2× / 4× divide it).
const playerTurnDuration = Duration(milliseconds: 480);

/// Pause between turns during playback at 1×.
const playerStepGap = Duration(milliseconds: 200);

/// A named section of a script's moves, [start, end) — e.g. one phase of a
/// big-cube solve (拼中心, 配对棱块, ...).
class PlayerPhase {
  const PlayerPhase({required this.label, required this.start, required this.end});

  final String label;
  final int start;
  final int end;

  int get length => end - start;
  bool contains(int move) => move >= start && move < end;
}

/// Index of the current phase after [applied] moves: the phase of the next
/// move, or the last phase once every move is applied. Null without phases.
int? phaseIndexAt(List<PlayerPhase> phases, int applied) {
  if (phases.isEmpty) return null;
  final move = applied < phases.last.end ? applied : phases.last.end - 1;
  final i = phases.indexWhere((p) => p.contains(move));
  return i < 0 ? null : i;
}

/// A move list to play on some puzzle, starting from a given state.
abstract class PlayerScript {
  /// Moves in display notation, one per step.
  List<String> get moves;

  /// Named sections of [moves], in order; empty if the script has none.
  List<PlayerPhase> get phases => const [];

  /// What move [index] is part of (e.g. "配对：UF 棱"), or null.
  String? noteAt(int index) => null;

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

  /// Animation speed factor (1 = normal, 2 = twice as fast, ...).
  set speed(double value);

  Widget buildView();

  void dispose();
}

// ── 3x3 (puzzle_cube) ──────────────────────────────────────────────────────

class Cube3Script extends PlayerScript {
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
          moveDuration: playerTurnDuration,
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
  set speed(double value) =>
      cube.moveDuration = playerTurnDuration * (1 / value);

  @override
  Widget buildView() => Cube(controller: cube, highlightTurns: true);

  @override
  void dispose() => cube.dispose();
}

// ── N×N (in-house engine) ──────────────────────────────────────────────────

class NxnScript extends PlayerScript {
  /// One player step per single-layer move.
  NxnScript({
    required this.initial,
    required List<NxnMove> steps,
    this.phases = const [],
    this.notes,
  })  : blocks = [for (final m in steps) NxnBlockMove.single(m)],
        assert(notes == null || notes.length == steps.length);

  /// One player step per turn; a wide turn animates its layers together.
  NxnScript.blocks({
    required this.initial,
    required this.blocks,
    this.phases = const [],
    this.notes,
  }) : assert(notes == null || notes.length == blocks.length);

  final NxnCubeState initial;

  /// The turns, one per step.
  final List<NxnBlockMove> blocks;

  @override
  final List<PlayerPhase> phases;

  /// Optional note per step (same length as [blocks]).
  final List<String>? notes;

  /// The same solution as single-layer moves.
  List<NxnMove> get steps => [for (final b in blocks) ...b.moves];

  @override
  late final List<String> moves = [for (final b in blocks) b.notation(initial.n)];

  @override
  String? noteAt(int index) => notes?[index];

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
    final b = script.blocks[index];
    cube.playBlocks([forward ? b : b.inverse]);
  }

  @override
  void show(int count) {
    final s = script.initial.copy();
    for (final b in script.blocks.take(count)) {
      s.applyBlock(b);
    }
    cube.replaceState(s);
  }

  @override
  set speed(double value) => cube.speed = value;

  @override
  Widget buildView() => NxnCubeView(
        controller: cube,
        moveDuration: playerTurnDuration,
        highlightTurns: true,
      );

  @override
  void dispose() => cube.dispose();
}

// ── Pyraminx ───────────────────────────────────────────────────────────────

class PyraminxScript extends PlayerScript {
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
  set speed(double value) => puzzle.speed = value;

  @override
  Widget buildView() =>
      PyraminxView(
        controller: puzzle,
        moveDuration: playerTurnDuration,
        highlightTurns: true,
      );

  @override
  void dispose() => puzzle.dispose();
}
