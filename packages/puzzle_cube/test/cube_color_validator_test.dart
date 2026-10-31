import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

void main() {
  const validator = CubeColorValidator();

  group('CubeColorValidator', () {
    test('a solved cube is valid', () {
      final result = validator.validate(PuzzleCubeState.solved());
      expect(result.isValid, isTrue);
      expect(result.issues, isEmpty);
    });

    test('a scrambled (but real) cube is still valid', () {
      final result = validator.validate(
        PuzzleCubeState.random(moves: 30, seed: 11),
      );
      expect(result.isValid, isTrue);
    });

    test('a blank "colour my cube" start is invalid', () {
      final result = validator.validate(PuzzleCubeState.colorless());
      expect(result.isValid, isFalse);
      // The grey stickers throw off the per-colour counts.
      expect(
        result.issues.any((i) => i.type == CubeValidationIssueType.global),
        isTrue,
      );
    });
  });
}
