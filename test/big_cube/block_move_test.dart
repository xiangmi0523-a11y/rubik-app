import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/core/nxn/nxn_cube_state.dart';
import 'package:rubik_app/core/nxn/nxn_facelets.dart';
import 'package:rubik_app/core/nxn/nxn_projection.dart';
import 'package:rubik_app/features/solver/domain/big_cube/big_cube_solver.dart';

import 'helpers.dart';

/// Every block of contiguous layers on every axis of an order-[n] cube.
List<NxnBlockMove> allBlocks(int n) {
  final layers = NxnFacelets(n).layers;
  return [
    for (var axis = 0; axis < 3; axis++)
      for (var a = 0; a < n; a++)
        for (var b = a; b < n; b++)
          for (final turns in const [1, -1, 2])
            NxnBlockMove(axis, layers[a], layers[b], turns),
  ];
}

void main() {
  test('every block of every width, orders 2–6: layers, effect, inverse', () {
    for (var n = 2; n <= 6; n++) {
      final f = NxnFacelets(n);
      final labels = f.identityLabels();
      for (final b in allBlocks(n)) {
        expect(b.layers, hasLength(b.width));
        expect(b.layers.first, b.from);
        expect(b.layers.last, b.to);
        for (final l in f.layers) {
          expect(b.containsLayer(l), b.layers.contains(l));
          expect(NxnTurn.of(b, 0).containsLayer(l), b.layers.contains(l));
        }
        // The block is exactly its single-layer moves (engine).
        final s = f.build(labels)..applyBlock(b);
        final t = f.build(labels);
        for (final l in b.layers) {
          t.apply(NxnMove(b.axis, l, b.turns));
        }
        final after = f.read(s);
        expect(after, f.read(t));
        // Exactly the cubies in its layers move.
        final moved = <IVec>{
          for (var i = 0; i < f.count; i++)
            if (after[i] != labels[i]) f.posOf[i],
        };
        for (final pos in moved) {
          expect(b.containsLayer(axisOf(pos, b.axis)), isTrue);
        }
        expect(f.read(s..applyBlock(b.inverse)), labels);
      }
    }
  });

  test('notation: single layers as before, wide, inner blocks, rotations', () {
    String nt(int n, int axis, int from, int to, int turns) =>
        NxnBlockMove(axis, from, to, turns).notation(n);
    // Width 1 is the existing single-layer notation.
    for (final n in [2, 3, 4, 5]) {
      for (final m in NxnMoveTable(n).moves) {
        expect(NxnBlockMove.single(m).notation(n), m.notation(n));
      }
    }
    expect(nt(4, 0, 1, 3, -1), 'Rw');
    expect(nt(4, 0, 1, 3, 1), "Rw'");
    expect(nt(4, 1, 1, 3, 2), 'Uw2');
    expect(nt(4, 0, -3, -1, 1), 'Lw');
    expect(nt(4, 2, -3, -1, -1), "Bw'");
    expect(nt(5, 0, 0, 4, -1), '3Rw');
    expect(nt(5, 1, -4, 0, 1), '3Dw');
    expect(nt(5, 0, 0, 2, -1), '2-3Rw');
    expect(nt(4, 0, -1, 1, -1), '2-3Rw');
    expect(nt(4, 0, -3, 3, -1), 'x');
    expect(nt(5, 1, -4, 4, 1), "y'");
    expect(nt(3, 2, -2, 2, 2), 'z2');
    expect(nt(2, 0, -1, 1, -1), 'x');
  });

  test('grouping keeps the effect and only merges commuting neighbours', () {
    for (final n in [4, 5]) {
      final f = NxnFacelets(n);
      final rng = math.Random(n);
      for (var i = 0; i < 400; i++) {
        final moves = randomMoves(n, rng, rng.nextInt(30));
        final grouped = NxnBlockMove.groupWithSource(moves);
        final s = NxnCubeState.solved(n);
        for (final (b, _) in grouped) {
          s.applyBlock(b);
        }
        expect(f.read(s), f.read(NxnCubeState.solved(n)..applyAll(moves)));
        // Same moves, regrouped: total layers turned is unchanged.
        expect(grouped.fold(0, (a, e) => a + e.$1.width), moves.length);
        for (final (b, src) in grouped) {
          expect(moves[src].axis, b.axis);
          expect(b.containsLayer(moves[src].layer), isTrue);
        }
      }
    }
    List<String> g(String alg, int n) => [
          for (final b in NxnBlockMove.group(NxnMove.parseAll(alg, n)))
            b.notation(n),
        ];
    expect(g('U2 2U2 R', 4), ['Uw2', 'R']);
    expect(g('R 2R', 4), ['Rw']);
    expect(g("R 2R'", 4), ['R', "2R'"]); // different turns
    expect(g('U 3U 2U', 5), ['3Uw']); // commute within the run, adjacent
    expect(g('U F 2U', 4), ['U', 'F', '2U']); // F in between: no merge
    expect(g('R R', 4), ['R', 'R']); // same layer twice: untouched
    expect(g("U D'", 4), ['U', "D'"]); // not adjacent layers
    expect(g('2R2 U2 2R2 U2 2U2 2R2 2U2', 4), ['2R2', 'U2', '2R2', 'Uw2', '2R2', '2U2']);
  });

  test('solutions as wide turns: same result, never across phases', () {
    final rng = math.Random(31);
    for (final n in [4, 5]) {
      var moves = 0, turns = 0;
      for (var i = 0; i < 30; i++) {
        final input = NxnCubeState.solved(n)..applyAll(randomMoves(n, rng, 60));
        final r = BigCubeSolver.solve(input);
        expect(r.ok, isTrue);
        final steps = r.blockSteps;
        final s = input.copy();
        for (final t in steps) {
          s.applyBlock(t.block);
        }
        expect(s.isSolved, isTrue);
        // Phases appear in the same order and sizes as the moves say.
        final layersPerPhase = <Object, int>{};
        for (final t in steps) {
          layersPerPhase[t.phase] = (layersPerPhase[t.phase] ?? 0) + t.block.width;
        }
        for (final p in r.phases) {
          expect(layersPerPhase[p.phase], p.length);
        }
        final notes = {for (final st in r.steps) st.description};
        expect(steps.every((t) => notes.contains(t.note)), isTrue);
        moves += r.moves.length;
        turns += steps.length;
      }
      expect(turns, lessThanOrEqualTo(moves));
      // ignore: avoid_print
      print('WIDE${n}_STATS layers=$moves turns=$turns '
          'saved=${((moves - turns) * 100 / moves).toStringAsFixed(1)}%');
    }
  });
}
