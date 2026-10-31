import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_cube/puzzle_cube.dart';
import 'package:rubik_app/core/cube/cube_facelets.dart';
import 'package:rubik_app/features/solver/domain/cube_input_validator.dart';

void main() {
  test('solved cube is valid', () {
    expect(CubeInputValidator.validate(
        CubeFacelets.read(PuzzleCubeState.solved())), isEmpty);
  });

  test('blank stickers are reported', () {
    final errors = CubeInputValidator.validate(
        CubeFacelets.read(PuzzleCubeState.colorless()));
    expect(errors.single, contains('48'));
  });

  test('wrong colour count is reported', () {
    final colors = CubeFacelets.read(PuzzleCubeState.solved());
    colors[0] = CubeColors.yellow;
    expect(CubeInputValidator.validate(colors), isNotEmpty);
  });

  test('twisted corner is rejected', () {
    final colors = CubeFacelets.read(PuzzleCubeState.solved());
    // Corner U9 / R1 / F3: rotate its three stickers.
    final a = CubeFacelets.indexOf(CubeSide.u, 8);
    final b = CubeFacelets.indexOf(CubeSide.r, 0);
    final c = CubeFacelets.indexOf(CubeSide.f, 2);
    final t = colors[a];
    colors[a] = colors[b];
    colors[b] = colors[c];
    colors[c] = t;
    expect(CubeInputValidator.validate(colors), isNotEmpty);
  });

  test('swapped edges (parity) is rejected', () {
    final colors = CubeFacelets.read(PuzzleCubeState.solved());
    // Swap UF and UR edges.
    void swap(int i, int j) {
      final t = colors[i];
      colors[i] = colors[j];
      colors[j] = t;
    }
    swap(CubeFacelets.indexOf(CubeSide.u, 7), CubeFacelets.indexOf(CubeSide.u, 5));
    swap(CubeFacelets.indexOf(CubeSide.f, 1), CubeFacelets.indexOf(CubeSide.r, 1));
    expect(CubeInputValidator.validate(colors), isNotEmpty);
  });
}
