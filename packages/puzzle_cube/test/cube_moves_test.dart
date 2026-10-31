import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

void main() {
  group('PuzzleCubeState basics', () {
    test('a fresh cube is solved', () {
      expect(PuzzleCubeState.solved().isSolved, isTrue);
    });

    test('a single turn unsolves it; the inverse re-solves it', () {
      final cube = PuzzleCubeState.solved()..applyMove(CubeMove.r);
      expect(cube.isSolved, isFalse);
      cube.applyMove(CubeMove.ri);
      expect(cube.isSolved, isTrue);
    });

    test('every move has order 4', () {
      for (final move in CubeMove.values) {
        final cube = PuzzleCubeState.solved();
        for (var i = 0; i < 4; i++) {
          cube.applyMove(move);
        }
        expect(cube.isSolved, isTrue, reason: '$move');
      }
    });

    test('every move round-trips with its inverse', () {
      for (final move in CubeMove.values) {
        final cube = PuzzleCubeState.solved()
          ..applyMove(move)
          ..applyMove(move.inverse);
        expect(cube.isSolved, isTrue, reason: '$move');
      }
    });

    test('a seeded random scramble is reproducible', () {
      final a = PuzzleCubeState.random(moves: 30, seed: 7);
      final b = PuzzleCubeState.random(moves: 30, seed: 7);
      for (var i = 0; i < a.cubies.length; i++) {
        expect(a.cubies[i].faces, b.cubies[i].faces);
      }
    });

    test('a JSON-restored solved cube still reports isSolved', () {
      // fromJson rebuilds stickers as plain Colors; isSolved must compare by
      // ARGB value, not Color identity (the reference uses MaterialColors).
      final restored =
          PuzzleCubeState.fromJson(PuzzleCubeState.solved().toJson());
      expect(restored.isSolved, isTrue);

      final scrambled = PuzzleCubeState.fromJson(
        PuzzleCubeState.random(moves: 10, seed: 5).toJson(),
      );
      expect(scrambled.isSolved, isFalse);
    });

    test('toJson/fromJson round-trips a scrambled cube', () {
      final cube = PuzzleCubeState.random(moves: 20, seed: 3);
      final restored = PuzzleCubeState.fromJson(cube.toJson());
      for (var i = 0; i < cube.cubies.length; i++) {
        final a = cube.cubies[i];
        final b = restored.cubieAt(a.x, a.y, a.z)!;
        for (final entry in a.faces.entries) {
          expect(b.faces[entry.key]!.toARGB32(), entry.value.toARGB32());
        }
      }
    });

    test('centre stickers cannot be painted; others can', () {
      final cube = PuzzleCubeState.solved();
      expect(
        cube.setStickerColor(
          x: 1,
          y: 0,
          z: 0,
          face: CubieFace.xPos,
          color: CubeColors.red,
        ),
        isFalse,
        reason: 'centre is fixed',
      );
      expect(
        cube.setStickerColor(
          x: 1,
          y: 1,
          z: 1,
          face: CubieFace.xPos,
          color: CubeColors.red,
        ),
        isTrue,
        reason: 'corner sticker is editable',
      );
    });
  });
}
