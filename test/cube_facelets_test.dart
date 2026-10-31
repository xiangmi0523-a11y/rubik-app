import 'package:cuber/cuber.dart' as cuber;
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_cube/puzzle_cube.dart';
import 'package:rubik_app/core/cube/cube_facelets.dart';

void main() {
  test('solved cube maps to solved definition', () {
    expect(CubeFacelets.definitionOf(PuzzleCubeState.solved()),
        cuber.Cube.solved.definition);
  });

  test('every face turn matches cuber', () {
    for (final m in ['U', 'R', 'F', 'D', 'L', 'B', "U'", "R'", 'F2']) {
      final move = cuber.Move.parse(m);
      final state = PuzzleCubeState.solved();
      for (final q in CubeNotation.toQuarterTurns(move)) {
        state.applyMove(q);
      }
      expect(CubeFacelets.definitionOf(state),
          cuber.Cube.solved.move(move).definition,
          reason: m);
    }
  });

  test('round trip: scramble -> solve -> solved', () {
    for (var seed = 0; seed < 3; seed++) {
      final state = PuzzleCubeState.random(moves: 25, seed: seed);
      final rebuilt = CubeFacelets.build(CubeFacelets.read(state));
      expect(const CubeColorValidator().validate(rebuilt).isValid, isTrue);
      final def = CubeFacelets.definitionOf(rebuilt)!;
      final solution = cuber.Cube.from(def).solve()!;
      for (final m in solution.algorithm.moves) {
        CubeNotation.toQuarterTurns(m).forEach(rebuilt.applyMove);
      }
      expect(rebuilt.isSolved, isTrue);
    }
  });
}
