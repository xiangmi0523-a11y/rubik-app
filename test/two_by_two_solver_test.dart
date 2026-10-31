import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/core/nxn/nxn_cube_state.dart';
import 'package:rubik_app/features/solver/domain/two_by_two_solver.dart';

void main() {
  test('solves 30 random 2x2 scrambles in ≤ 11 moves', () {
    for (var seed = 0; seed < 30; seed++) {
      final s = NxnCubeState.solved(2)
        ..applyAll(NxnCubeState.randomScramble(2, rng: math.Random(seed)));
      final r = TwoByTwoSolver.solve(s);
      expect(r.ok, isTrue, reason: r.error);
      expect(r.moves.length, lessThanOrEqualTo(11));
      s.applyAll(r.moves);
      expect(s.isSolved, isTrue, reason: 'seed $seed');
    }
  });

  test('works when the whole cube is held differently', () {
    final s = NxnCubeState.solved(2)
      ..applyAll(NxnCubeState.randomScramble(2, rng: math.Random(99)));
    // Rotate the whole cube (all layers) – D/L/B moves included.
    for (final l in [-1, 1]) {
      s.apply(NxnMove(0, l, 1));
      s.apply(NxnMove(1, l, 2));
    }
    s.apply(const NxnMove(1, -1, 1)); // a D turn
    final r = TwoByTwoSolver.solve(s);
    expect(r.ok, isTrue);
    s.applyAll(r.moves);
    expect(s.isSolved, isTrue);
  });

  test('rejects a single twisted corner', () {
    final s = NxnCubeState.solved(2);
    final corner = s.cubies.firstWhere((c) => c.pos == (1, 1, 1));
    final keys = corner.stickers.keys.toList();
    final first = corner.stickers[keys[0]]!;
    corner.stickers[keys[0]] = corner.stickers[keys[1]]!;
    corner.stickers[keys[1]] = corner.stickers[keys[2]]!;
    corner.stickers[keys[2]] = first;
    expect(TwoByTwoSolver.solve(s).ok, isFalse);
  });
}
