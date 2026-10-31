import 'package:cuber/cuber.dart' as cuber;
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_cube/puzzle_cube.dart';
import 'package:rubik_app/core/cube/cube_facelets.dart';
import 'package:rubik_app/features/patterns/domain/cube_pattern.dart';

void main() {
  for (final p in cubePatterns) {
    test('${p.name} builds its pattern in cuber and on the 3D model', () {
      final alg = cuber.Algorithm.parse(p.algorithm);
      expect(alg.apply(cuber.Cube.solved).definition, p.definition);

      final state = PuzzleCubeState.solved();
      for (final m in alg.moves) {
        CubeNotation.toQuarterTurns(m).forEach(state.applyMove);
      }
      expect(CubeFacelets.definitionOf(state), p.definition);
    });
  }
}
