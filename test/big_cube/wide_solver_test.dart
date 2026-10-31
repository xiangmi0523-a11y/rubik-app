import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/core/nxn/nxn_cube_state.dart';
import 'package:rubik_app/core/nxn/nxn_facelets.dart';
import 'package:rubik_app/features/solver/domain/big_cube/big_cube_solver.dart';
import 'package:rubik_app/features/solver/domain/big_cube/center_phase.dart';
import 'package:rubik_app/features/solver/domain/big_cube/center_search.dart';
import 'package:rubik_app/features/solver/domain/big_cube/cycle_library.dart';
import 'package:rubik_app/features/solver/domain/big_cube/edge_pairer.dart';
import 'package:rubik_app/features/solver/domain/big_cube/parity_algorithms.dart';
import 'package:rubik_app/features/solver/domain/big_cube/solve_step.dart';
import 'package:rubik_app/features/solver/domain/big_cube/target_scheme.dart';

import 'helpers.dart';

final _far = DateTime.now().add(const Duration(days: 1));

TargetScheme _scheme(NxnCubeState s) => s.n == 4
    ? TargetScheme.bestFor(s, SlotKind.centerX)!
    : TargetScheme.fromFixedCenters(s)!;

int _turns(BigCubeSolution r) => r.steps.fold(0, (a, s) => a + s.blocks.length);

void main() {
  group('centre search moves (engine)', () {
    for (final n in [4, 5]) {
      test('${n}x$n: every candidate turn is legal and acts as the engine says',
          () {
        final cs = CenterSearch(n);
        final f = NxnFacelets(n);
        final layers = f.layers;
        final labels = f.identityLabels();
        expect(cs.moves.toSet(), hasLength(cs.moves.length));
        for (var mi = 0; mi < cs.moves.length; mi++) {
          final b = cs.moves[mi];
          // Never a whole-cube rotation; on 5x5 never a block through the
          // middle that also reaches a face (a rotation in disguise).
          expect(b.width, lessThan(n));
          if (n == 5 && b.containsLayer(0)) {
            expect(b.from != layers.first && b.to != layers.last, isTrue);
          }
          for (final m in b.moves) {
            expect(NxnMoveTable(n).indexOf(m), isNonNegative);
          }
          final after = f.read(f.build(labels)..applyBlock(b));
          for (var i = 0; i < cs.slots.length; i++) {
            // The sticker in tracked slot i lands in tracked slot perm[i].
            expect(after[cs.slots[cs.perms[mi][i]]], labels[cs.slots[i]]);
          }
          // Wing parity flag = parity of the turn's wing permutation.
          final wings = PieceCycleLibrary.wingOrbit(n);
          final pos = {for (var k = 0; k < wings.length; k++) wings[k]: k};
          final img = [
            for (final w in wings) pos[after.indexOf(labels[w])]!,
          ];
          var parity = 0;
          final seen = List.filled(24, false);
          for (var k = 0; k < 24; k++) {
            if (seen[k]) continue;
            var len = 0;
            for (var j = k; !seen[j]; j = img[j]) {
              seen[j] = true;
              len++;
            }
            parity ^= (len - 1) & 1;
          }
          expect(cs.wingOdd[mi], parity == 1, reason: b.notation(n));
        }
      });

      test('${n}x$n: each greedy step solves more centres (100 scrambles)', () {
        final cs = CenterSearch(n);
        final rng = math.Random(n * 101);
        for (var i = 0; i < 100; i++) {
          final s = NxnCubeState.solved(n)..applyAll(randomMoves(n, rng, 60));
          final scheme = _scheme(s);
          final ci = {for (var k = 0; k < 6; k++) scheme.faceColors[k]: k};
          final target = n == 4 ? const [0, 1, 2, 3, 4, 5] : null;
          final colors = cs.read(s, ci)!;
          var solved = cs.solved(colors, target);
          final engine = s.copy();
          for (final seq in cs.greedy(cs.read(s, ci)!, target, deadline: _far)) {
            expect(seq.length, inInclusiveRange(1, 6));
            for (final mi in seq) {
              engine.applyBlock(cs.moves[mi]);
            }
            final now = cs.solved(cs.read(engine, ci)!, target);
            expect(now, greaterThan(solved));
            solved = now;
          }
        }
      });
    }
  });

  group('early parity', () {
    test('4x4 parity flip: 7 turns, keeps every centre, odd wings', () {
      expect(
          ParityAlgorithms.centreParityFour.map((b) => b.notation(4)).join(' '),
          "Lw2 2D' 2-3Rw2 Uw 2-3Rw2 Dw' Lw2");
      final f = NxnFacelets(4);
      final rng = math.Random(7);
      final centres = f.slotsOfKind(SlotKind.centerX);
      for (var i = 0; i < 100; i++) {
        // Centres solved, edges and corners scrambled by outer turns and
        // wing 3-cycles.
        final s = NxnCubeState.solved(4);
        final lib = PieceCycleLibrary.wings(4);
        for (var k = 0; k < 4; k++) {
          final o = [...lib.orbit]..shuffle(rng);
          s.applyAll(lib.cycle(o[0], o[1], o[2]));
          s.applyAll(NxnMove.parseAll('R U F2', 4));
        }
        final scheme = _scheme(s);
        final before = EdgePairer.wingParity(s, scheme)!;
        final colours = f.read(s);
        for (final b in ParityAlgorithms.centreParityFour) {
          s.applyBlock(b);
        }
        final after = f.read(s);
        for (final c in centres) {
          expect(after[c], colours[c]);
        }
        expect(EdgePairer.wingParity(s, scheme), 1 - before);
      }
    });

    test('centre attempts: replay reproduces each, parity is what it says',
        () {
      for (final n in [4, 5]) {
        final f = NxnFacelets(n);
        final rng = math.Random(n * 3);
        for (var i = 0; i < 40; i++) {
          final s = NxnCubeState.solved(n)..applyAll(randomMoves(n, rng, 60));
          final scheme = _scheme(s);
          final attempts = CenterPhase.attempts(s, scheme, deadline: _far);
          expect(attempts, isNotEmpty);
          for (final a in attempts) {
            expect(a.failure, isNull);
            final replay = s.copy();
            for (final st in a.steps) {
              expect(st.phase, ReductionPhase.centers);
              replay.applyAll(st.moves);
            }
            expect(f.read(replay), f.read(a.state!));
            final now = n == 4 ? scheme : TargetScheme.fromFixedCenters(replay)!;
            expect(EdgePairer.wingParity(replay, now), a.parity);
          }
          // An odd first attempt always comes with alternatives.
          if (attempts.first.parity == 1) expect(attempts.length, greaterThan(1));
        }
      }
    });
  });

  test('strategies: the result is the shorter of classic and search, and '
      'both are correct (60 scrambles per order)', () {
    for (final n in [4, 5]) {
      final rng = math.Random(n * 17);
      var classicTotal = 0, bestTotal = 0, pll = 0;
      for (var i = 0; i < 60; i++) {
        final s = NxnCubeState.solved(n)..applyAll(randomMoves(n, rng, 60));
        final classic = BigCubeSolver.solve(s, strategy: SolveStrategy.classic);
        final search = BigCubeSolver.solve(s, strategy: SolveStrategy.search);
        final best = BigCubeSolver.solve(s);
        for (final r in [classic, search, best]) {
          expect(r.ok, isTrue, reason: '${r.failure}');
          expect((s.copy()..applyAll(r.moves)).isSolved, isTrue);
        }
        expect(_turns(best), math.min(_turns(classic), _turns(search)));
        classicTotal += _turns(classic);
        bestTotal += _turns(best);
        pll += best.steps.where((st) => st.description.contains('PLL')).length;
      }
      expect(bestTotal, lessThan(classicTotal));
      // PLL parity is decided while pairing; the formula is rarely needed.
      if (n == 4) expect(pll, lessThanOrEqualTo(3));
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
