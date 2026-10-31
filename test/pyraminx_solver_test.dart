import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/core/pyraminx/pyraminx_model.dart';
import 'package:rubik_app/core/pyraminx/pyraminx_solver.dart';
import 'package:rubik_app/features/pyraminx/domain/pyraminx_scramble.dart';

void main() {
  test('every vertex has 3 tip and 3 centre stickers', () {
    for (var a = 0; a < 4; a++) {
      expect(PyraminxSolver.tips[a], hasLength(3));
      expect(PyraminxSolver.centers[a], hasLength(3));
    }
  });

  test('solves 30 random scrambles optimally-short', () {
    for (var seed = 0; seed < 30; seed++) {
      final scramble =
          PyraminxMove.parseAll(pyraminxScramble(rng: math.Random(seed)));
      final s = PyraminxState.solved()..applyAll(scramble);
      final result = PyraminxSolver.solve(s.colors);
      expect(result.ok, isTrue, reason: result.error);
      expect(result.moves.where((m) => !m.tip).length, lessThanOrEqualTo(11));
      s.applyAll(result.moves);
      expect(s.isSolved, isTrue, reason: 'seed $seed');
    }
  });

  test('works with any colour assignment (held differently)', () {
    // Recolour: swap colours 0<->3 and 1<->2 everywhere.
    const map = [3, 2, 1, 0];
    final s = PyraminxState.solved()..applyAll(PyraminxMove.parseAll("U R' B L u"));
    final recoloured = [for (final c in s.colors) map[c]];
    final result = PyraminxSolver.solve(recoloured);
    expect(result.ok, isTrue);
    final t = PyraminxState(recoloured)..applyAll(result.moves);
    expect(t.isSolved, isTrue);
  });

  test('rejects a single flipped edge', () {
    final s = PyraminxState.solved();
    // Find an edge (two stickers on the boundary of two faces) and swap them.
    final edges = [
      for (var i = 0; i < 36; i++)
        if (!PyraminxSolver.tips.any((t) => t.contains(i)) &&
            !PyraminxSolver.centers.any((c) => c.contains(i)))
          i,
    ];
    expect(edges, hasLength(12));
    final a = edges.first;
    final b = edges.firstWhere((j) =>
        j != a &&
        PyraminxGeometry.slots[j].centroid
                .distanceTo(PyraminxGeometry.slots[a].centroid) <
            0.8);
    final t = s.colors[a];
    s.colors[a] = s.colors[b];
    s.colors[b] = t;
    expect(PyraminxSolver.solve(s.colors).ok, isFalse);
  });
}
