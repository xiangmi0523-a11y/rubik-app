import 'package:puzzle_cube/puzzle_cube.dart';

import '../../../core/cube/cube_facelets.dart';
import '../../../core/nxn/nxn_cube_state.dart';
import '../../../core/pyraminx/pyraminx_model.dart';
import '../../player/domain/puzzle_stepper.dart';
import '../../puzzles/domain/puzzle_type.dart';
import 'cube_pattern.dart';

/// Player script that builds [pattern] from a solved puzzle.
PlayerScript patternScript(PuzzlePattern pattern) {
  final type = pattern.puzzle;
  if (type == PuzzleType.cube3) {
    return Cube3Script(
      colors: CubeFacelets.read(PuzzleCubeState.solved()),
      moves: pattern.moves,
    );
  }
  if (type == PuzzleType.pyraminx) {
    return PyraminxScript(
      initial: PyraminxState.solved(),
      steps: PyraminxMove.parseAll(pattern.algorithm),
    );
  }
  final n = type.order!;
  return NxnScript(
    initial: NxnCubeState.solved(n),
    steps: NxnMove.parseAll(pattern.algorithm, n),
  );
}

/// Cube state after the pattern (any order, via the N×N engine), for previews.
NxnCubeState cubePatternState(PuzzlePattern pattern) {
  final n = pattern.puzzle.order!;
  return NxnCubeState.solved(n)
    ..applyAll(NxnMove.parseAll(pattern.algorithm, n));
}

PyraminxState pyraminxPatternState(PuzzlePattern pattern) =>
    PyraminxState.solved()..applyAll(PyraminxMove.parseAll(pattern.algorithm));
