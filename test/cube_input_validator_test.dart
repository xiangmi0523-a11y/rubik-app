import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_cube/puzzle_cube.dart';
import 'package:rubik_app/core/cube/cube_facelets.dart';
import 'package:rubik_app/features/solver/domain/cube_input_validator.dart';

void main() {
  test('solved cube is valid', () {
    expect(CubeInputValidator.validate(
            CubeFacelets.read(PuzzleCubeState.solved()))
        .isValid, isTrue);
  });

  test('blank stickers are reported as incomplete', () {
    final check = CubeInputValidator.validate(
        CubeFacelets.read(PuzzleCubeState.colorless()));
    expect(check.issue, CubeInputIssue.incomplete);
    expect(check.messages.single, contains('48'));
  });

  test('wrong colour count is reported', () {
    final colors = CubeFacelets.read(PuzzleCubeState.solved());
    colors[0] = CubeColors.yellow;
    expect(CubeInputValidator.validate(colors).issue, CubeInputIssue.colorCount);
  });

  test('twisted corner is unsolvable', () {
    final colors = CubeFacelets.read(PuzzleCubeState.solved());
    // Corner U9 / R1 / F3: rotate its three stickers.
    final a = CubeFacelets.indexOf(CubeSide.u, 8);
    final b = CubeFacelets.indexOf(CubeSide.r, 0);
    final c = CubeFacelets.indexOf(CubeSide.f, 2);
    final t = colors[a];
    colors[a] = colors[b];
    colors[b] = colors[c];
    colors[c] = t;
    final check = CubeInputValidator.validate(colors);
    expect(check.issue, CubeInputIssue.unsolvable);
    expect(check.messages.single, contains('单角翻转'));
  });

  test('flipped edge is unsolvable', () {
    final colors = CubeFacelets.read(PuzzleCubeState.solved());
    final a = CubeFacelets.indexOf(CubeSide.u, 7);
    final b = CubeFacelets.indexOf(CubeSide.f, 1);
    final t = colors[a];
    colors[a] = colors[b];
    colors[b] = t;
    final check = CubeInputValidator.validate(colors);
    expect(check.issue, CubeInputIssue.unsolvable);
    expect(check.messages.single, contains('单棱翻色'));
  });

  test('swapped edges (parity) is unsolvable', () {
    final colors = CubeFacelets.read(PuzzleCubeState.solved());
    void swap(int i, int j) {
      final t = colors[i];
      colors[i] = colors[j];
      colors[j] = t;
    }
    swap(CubeFacelets.indexOf(CubeSide.u, 7), CubeFacelets.indexOf(CubeSide.u, 5));
    swap(CubeFacelets.indexOf(CubeSide.f, 1), CubeFacelets.indexOf(CubeSide.r, 1));
    expect(CubeInputValidator.validate(colors).issue, CubeInputIssue.unsolvable);
  });
}
