import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

void main() {
  const slices = [
    CubeMove.m,
    CubeMove.mi,
    CubeMove.e,
    CubeMove.ei,
    CubeMove.s,
    CubeMove.si,
  ];

  group('slice moves', () {
    for (final move in slices) {
      test('$move has order 4 (four turns return to solved)', () {
        final cube = PuzzleCubeState.solved();
        for (var i = 0; i < 4; i++) {
          cube.applyMove(move);
        }
        expect(cube.isSolved, isTrue);
      });

      test('$move followed by its inverse is the identity', () {
        final cube = PuzzleCubeState.solved()
          ..applyMove(move)
          ..applyMove(move.inverse);
        expect(cube.isSolved, isTrue);
      });
    }

    test('M only disturbs the middle x-slice (x = ±1 layers untouched)', () {
      final solved = PuzzleCubeState.solved();
      final cube = PuzzleCubeState.solved()..applyMove(CubeMove.m);
      for (final cubie in cube.cubies.where((c) => c.x != 0)) {
        final ref = solved.cubieAt(cubie.x, cubie.y, cubie.z)!;
        for (final entry in cubie.faces.entries) {
          expect(
            ref.faces[entry.key]!.toARGB32(),
            entry.value.toARGB32(),
            reason: 'outer cubie ${cubie.x},${cubie.y},${cubie.z} changed',
          );
        }
      }
    });

    test('a mixed scramble undoes via reversed inverses', () {
      const moves = [
        CubeMove.m,
        CubeMove.r,
        CubeMove.e,
        CubeMove.ui,
        CubeMove.s,
        CubeMove.mi,
      ];
      final cube = PuzzleCubeState.solved();
      for (final m in moves) {
        cube.applyMove(m);
      }
      expect(cube.isSolved, isFalse);
      for (final m in moves.reversed) {
        cube.applyMove(m.inverse);
      }
      expect(cube.isSolved, isTrue);
    });

    test('M follows L: front-centre sticker lands on the down face', () {
      final cube = PuzzleCubeState.solved()..applyMove(CubeMove.m);
      // The old front-centre (0,0,1) carried its red zPos sticker; after M
      // (which follows L, front -> down on the middle column) it should now
      // show red on the yPos (down) face at (0,1,0).
      final cubie = cube.cubieAt(0, 1, 0)!;
      expect(cubie.faces[CubieFace.yPos]!.toARGB32(), CubeColors.red.toARGB32());
    });
  });
}
