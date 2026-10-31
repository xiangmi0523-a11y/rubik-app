import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/core/nxn/nxn_cube_state.dart';
import 'package:rubik_app/features/solver/domain/big_cube_validator.dart';

NxnCubie _at(NxnCubeState s, IVec pos) => s.cubies.firstWhere((c) => c.pos == pos);

void _swapStickers(NxnCubie c) {
  final k = c.stickers.keys.toList();
  final t = c.stickers[k[0]]!;
  c.stickers[k[0]] = c.stickers[k[1]]!;
  c.stickers[k[1]] = t;
}

void main() {
  for (final n in [4, 5]) {
    test('$n x $n: random scrambles are valid', () {
      for (var seed = 0; seed < 10; seed++) {
        final s = NxnCubeState.solved(n)
          ..applyAll(NxnCubeState.randomScramble(n, rng: math.Random(seed)));
        expect(BigCubeValidator.validate(s), isEmpty, reason: 'seed $seed');
      }
    });

    test('$n x $n: a flipped wing is rejected', () {
      final s = NxnCubeState.solved(n)
        ..applyAll(NxnCubeState.randomScramble(n, rng: math.Random(1)));
      _swapStickers(_at(s, (s.max, s.max, n == 4 ? 1 : 2)));
      expect(BigCubeValidator.validate(s).join(), contains('翻转'));
    });

    test('$n x $n: a twisted corner is rejected', () {
      final s = NxnCubeState.solved(n)
        ..applyAll(NxnCubeState.randomScramble(n, rng: math.Random(2)));
      final c = _at(s, (s.max, s.max, s.max));
      final k = c.stickers.keys.toList();
      final first = c.stickers[k[0]]!;
      c.stickers[k[0]] = c.stickers[k[1]]!;
      c.stickers[k[1]] = c.stickers[k[2]]!;
      c.stickers[k[2]] = first;
      expect(BigCubeValidator.validate(s).join(), contains('拧转'));
    });

    test('$n x $n: two swapped centre stickers of different colours', () {
      final s = NxnCubeState.solved(n);
      // Swap one centre sticker between U and F: counts stay 4 per colour
      // only if done twice, so a single paint change is a count error.
      final k = n == 4 ? 1 : 2;
      final u = _at(s, (k, s.max, k));
      u.stickers[(0, 1, 0)] = const Color(0xFF4CAF50); // green on U
      expect(BigCubeValidator.validate(s), isNotEmpty);
    });
  }

  test('5x5: a flipped middle edge is rejected', () {
    final s = NxnCubeState.solved(5)
      ..applyAll(NxnCubeState.randomScramble(5, rng: math.Random(3)));
    _swapStickers(_at(s, (4, 4, 0)));
    expect(BigCubeValidator.validate(s).join(), contains('翻'));
  });

  test('4x4: whole-cube rotation is still valid', () {
    final s = NxnCubeState.solved(4);
    for (final l in s.layers) {
      s.apply(NxnMove(0, l, 1));
    }
    expect(BigCubeValidator.validate(s), isEmpty);
  });
}
