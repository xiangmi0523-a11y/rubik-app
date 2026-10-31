import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/core/nxn/nxn_cube_state.dart';
import 'package:rubik_app/core/nxn/nxn_facelets.dart';
import 'package:rubik_app/features/solver/domain/big_cube/center_solver.dart';
import 'package:rubik_app/features/solver/domain/big_cube/cycle_library.dart';
import 'package:rubik_app/features/solver/domain/big_cube/edge_layout.dart';
import 'package:rubik_app/features/solver/domain/big_cube/edge_pairer.dart';
import 'package:rubik_app/features/solver/domain/big_cube/parity_algorithms.dart';
import 'package:rubik_app/features/solver/domain/big_cube/solve_step.dart';
import 'package:rubik_app/features/solver/domain/big_cube/target_scheme.dart';

import 'helpers.dart';

final _far = DateTime.now().add(const Duration(days: 1));

/// Scrambles with real turns, then solves the centres (the pairer's input).
(NxnCubeState, TargetScheme) _centresSolved(int n, List<NxnMove> scramble) {
  final s = NxnCubeState.solved(n)..applyAll(scramble);
  final scheme = n == 4
      ? TargetScheme.bestFor(s, SlotKind.centerX)!
      : TargetScheme.fromFixedCenters(s)!;
  final steps = <SolveStep>[];
  final kinds = n == 4 ? [SlotKind.centerX] : [SlotKind.centerX, SlotKind.centerT];
  for (final k in kinds) {
    expect(CenterOrbitSolver.solve(s, k, scheme, steps, deadline: _far, label: 'c'),
        isNull);
  }
  return (s, scheme);
}

List<int> _nonWing(NxnFacelets f, List<int> colors) => [
      for (var i = 0; i < f.count; i++)
        if (f.kindOf[i] != SlotKind.wing) colors[i],
    ];

/// Wing permutation parity of a 5x5 relative to its middle edges.
int _wingParity5(NxnCubeState s, TargetScheme scheme) {
  final f = NxnFacelets(5);
  final layout = EdgeLayout(5);
  final colors = f.read(s);
  final ci = {for (var i = 0; i < 6; i++) scheme.faceColors[i]: i};
  final cur = <int>[], target = <int>[];
  for (final e in layout.edges) {
    final (ma, mb) = e.midge!;
    final onFace = {f.faceOf[ma]: colors[ma], f.faceOf[mb]: colors[mb]};
    for (final w in e.wings) {
      cur.add(ci[colors[w.named]]! * 6 + ci[colors[w.other]]!);
      target.add(ci[onFace[f.faceOf[w.named]]]! * 6 + ci[onFace[f.faceOf[w.other]]]!);
    }
  }
  final pos = {for (var i = 0; i < 24; i++) target[i]: i};
  final seen = List.filled(24, false);
  var cycles = 0;
  for (var i = 0; i < 24; i++) {
    if (seen[i]) continue;
    cycles++;
    for (var j = i; !seen[j]; j = pos[cur[j]]!) {
      seen[j] = true;
    }
  }
  return (24 - cycles) & 1;
}

void main() {
  for (final n in [4, 5]) {
    group('${n}x$n edge layout', () {
      final f = NxnFacelets(n);
      final layout = EdgeLayout(n);
      final named = PieceCycleLibrary.wingOrbit(n).toSet();

      test('12 edges with standard names, two wings each', () {
        expect(layout.edges, hasLength(12));
        expect(layout.edges.map((e) => e.name).toSet(), {
          'UR', 'UF', 'UL', 'UB', 'RD', 'FD', 'DL', 'DB', 'RF', 'RB', 'FL', 'LB',
        });
        final all = <int>{};
        for (final e in layout.edges) {
          expect(e.wings, hasLength(2));
          for (final w in e.wings) {
            expect(f.kindOf[w.named], SlotKind.wing);
            expect(f.kindOf[w.other], SlotKind.wing);
            expect(named.contains(w.named), isTrue);
            expect(named.contains(w.other), isFalse);
            expect(f.pieceOf[w.named], f.pieceOf[w.other]);
            all.addAll([w.named, w.other]);
          }
          // Mirror twins: the two wings name stickers on different faces.
          expect(f.faceOf[e.wings[0].named], isNot(f.faceOf[e.wings[1].named]));
          final (a, b) = e.faceSlots;
          expect(a, hasLength(n == 4 ? 2 : 3));
          expect(b, hasLength(n == 4 ? 2 : 3));
          expect(a.every((s) => f.faceOf[s] == e.faces.$1), isTrue);
          expect(b.every((s) => f.faceOf[s] == e.faces.$2), isTrue);
          if (n == 5) {
            expect(f.kindOf[e.midge!.$1], SlotKind.midEdge);
            expect(f.faceOf[e.midge!.$1], e.faces.$1);
            expect(f.faceOf[e.midge!.$2], e.faces.$2);
          } else {
            expect(e.midge, isNull);
          }
        }
        expect(all, hasLength(48)); // every wing sticker exactly once
        expect(() => EdgeLayout(3), throwsArgumentError);
      });

      test('paired on a solved cube, after outer turns, not after a slice', () {
        expect(layout.allPairedState(NxnCubeState.solved(n)), isTrue);
        final outer = NxnCubeState.solved(n)
          ..applyAll(NxnMove.parseAll("R U F' D2 L B' R2 U'", n));
        expect(layout.allPairedState(outer), isTrue);
        final slice = NxnCubeState.solved(n)..apply(NxnMove.parse('2R', n));
        expect(layout.allPairedState(slice), isFalse);
      });
    });
  }

  test('4x4: 300 random scrambles — all 12 dedges paired, nothing else moved',
      () {
    final f = NxnFacelets(4);
    final layout = EdgeLayout(4);
    final rng = math.Random(4404);
    final formulas = <int>[], moves = <int>[];
    for (var i = 0; i < 300; i++) {
      final scramble = randomMoves(4, rng, 30 + rng.nextInt(51));
      final (s, scheme) = _centresSolved(4, scramble);
      final before = s.copy();
      final steps = <SolveStep>[];
      final failure = EdgePairer.pairFour(s, scheme, steps, deadline: _far);
      final why = describe(scramble, 4);
      expect(failure, isNull, reason: why);
      expect(layout.allPairedState(s), isTrue, reason: why);
      expect(_nonWing(f, f.read(s)), _nonWing(f, f.read(before)), reason: why);
      expect(steps.every((st) => st.phase == ReductionPhase.edges), isTrue);
      final all = [for (final st in steps) ...st.moves];
      for (final m in all) {
        expect(NxnMoveTable(4).indexOf(m), isNonNegative);
      }
      expect(f.read(before.copy()..applyAll(all)), f.read(s), reason: why);
      expect(steps.length, lessThanOrEqualTo(24));
      formulas.add(steps.length);
      moves.add(all.length);
    }
    double avg(List<int> l) => l.reduce((a, b) => a + b) / l.length;
    // ignore: avoid_print
    print('PAIR4_STATS formulas avg=${avg(formulas).toStringAsFixed(1)} '
        'max=${formulas.reduce(math.max)} moves avg=${avg(moves).toStringAsFixed(1)} '
        'max=${moves.reduce(math.max)}');
  });

  test('5x5: 300 random scrambles — wings next to their middle edges, '
      'edge parity exactly when the wing permutation is odd', () {
    final f = NxnFacelets(5);
    final layout = EdgeLayout(5);
    final rng = math.Random(5505);
    var parityCount = 0;
    for (var i = 0; i < 300; i++) {
      final scramble = randomMoves(5, rng, 30 + rng.nextInt(51));
      final (s, scheme) = _centresSolved(5, scramble);
      final odd = _wingParity5(s, scheme) == 1;
      final before = s.copy();
      final steps = <SolveStep>[];
      final failure = EdgePairer.pairFive(s, scheme, steps, deadline: _far);
      final why = describe(scramble, 5);
      expect(failure, isNull, reason: why);
      expect(layout.allPairedState(s), isTrue, reason: why);
      expect(_nonWing(f, f.read(s)), _nonWing(f, f.read(before)), reason: why);
      final parity = steps.where((st) => st.phase == ReductionPhase.parity).toList();
      expect(parity, hasLength(odd ? 1 : 0), reason: why);
      if (odd) {
        parityCount++;
        expect(steps.last.phase, ReductionPhase.parity);
        expect(steps.last.moves, ParityAlgorithms.moves(ParityAlgorithms.edgeFive, 5));
      }
      final all = [for (final st in steps) ...st.moves];
      expect(f.read(before.copy()..applyAll(all)), f.read(s), reason: why);
    }
    // Both cases really occur in a random sample.
    expect(parityCount, inInclusiveRange(60, 240));
  });

  group('last two edges', () {
    test('4x4: two edges with their wings crossed', () {
      final layout = EdgeLayout(4);
      final lib = PieceCycleLibrary.wings(4);
      final uf = layout.edgeNamed('UF'), ur = layout.edgeNamed('UR');
      // 3-cycle UF.w0 → UR.w0 → UF.w1: only UF and UR are broken.
      final s = NxnCubeState.solved(4)
        ..applyAll(lib.cycle(uf.wings[0].named, ur.wings[0].named, uf.wings[1].named));
      final f = NxnFacelets(4);
      final colors = f.read(s);
      final broken = [for (final e in layout.edges) if (!layout.paired(colors, e)) e.name];
      expect(broken.toSet(), {'UF', 'UR'});
      final scheme = TargetScheme.bestFor(s, SlotKind.centerX)!;
      final steps = <SolveStep>[];
      expect(EdgePairer.pairFour(s, scheme, steps, deadline: _far), isNull);
      expect(layout.allPairedState(s), isTrue);
      expect(steps, hasLength(1));
    });

    test('4x4: a single dedge flip is "paired" (left for OLL parity)', () {
      final s = NxnCubeState.solved(4)
        ..applyAll(ParityAlgorithms.moves(ParityAlgorithms.ollFour, 4));
      final layout = EdgeLayout(4);
      expect(layout.allPairedState(s), isTrue);
      final steps = <SolveStep>[];
      expect(
          EdgePairer.pairFour(s, TargetScheme.bestFor(s, SlotKind.centerX)!, steps,
              deadline: _far),
          isNull);
      expect(steps, isEmpty);
    });

    test('5x5: two tredges with crossed wings', () {
      final layout = EdgeLayout(5);
      final lib = PieceCycleLibrary.wings(5);
      final fl = layout.edgeNamed('FL'), db = layout.edgeNamed('DB');
      final s = NxnCubeState.solved(5)
        ..applyAll(lib.cycle(fl.wings[1].named, db.wings[0].named, db.wings[1].named));
      final scheme = TargetScheme.fromFixedCenters(s)!;
      final steps = <SolveStep>[];
      expect(EdgePairer.pairFive(s, scheme, steps, deadline: _far), isNull);
      expect(layout.allPairedState(s), isTrue);
      expect(s.isSolved, isTrue);
      expect(steps.where((st) => st.phase == ReductionPhase.parity), isEmpty);
    });

    test('5x5: one flipped wing pair (edge parity), anywhere on the cube', () {
      final layout = EdgeLayout(5);
      final alg = ParityAlgorithms.moves(ParityAlgorithms.edgeFive, 5);
      for (final setup in ['', 'R', "F' U2", 'L2 D', 'B R2 U']) {
        final pre = NxnMove.parseAll(setup, 5);
        final s = NxnCubeState.solved(5)
          ..applyAll(pre)
          ..applyAll(alg)
          ..applyAll(inverseOf(pre));
        final scheme = TargetScheme.fromFixedCenters(s)!;
        expect(_wingParity5(s, scheme), 1);
        final steps = <SolveStep>[];
        expect(EdgePairer.pairFive(s, scheme, steps, deadline: _far), isNull,
            reason: setup);
        expect(layout.allPairedState(s), isTrue, reason: setup);
        expect(s.isSolved, isTrue, reason: setup);
        expect(steps.last.phase, ReductionPhase.parity);
      }
    });
  });

  group('failures', () {
    test('timeout reports timeout, and the moves done so far still replay', () {
      final rng = math.Random(9);
      for (final n in [4, 5]) {
        final (s, scheme) = _centresSolved(n, randomMoves(n, rng, 60));
        final before = s.copy();
        final steps = <SolveStep>[];
        final past = DateTime.now().subtract(const Duration(seconds: 1));
        final failure = n == 4
            ? EdgePairer.pairFour(s, scheme, steps, deadline: past)
            : EdgePairer.pairFive(s, scheme, steps, deadline: past);
        expect(failure?.kind, SolveFailureKind.timeout);
        final f = NxnFacelets(n);
        expect(f.read(before..applyAll([for (final st in steps) ...st.moves])),
            f.read(s));
      }
    });

    test('illegal wings are rejected, not "solved"', () {
      final f = NxnFacelets(4);
      final layout = EdgeLayout(4);
      // Swap the two stickers of one wing (a flipped wing can't exist).
      final colors = f.solvedColors();
      final w = layout.edges.first.wings.first;
      final t = colors[w.named];
      colors[w.named] = colors[w.other];
      colors[w.other] = t;
      final s = f.build(colors);
      final scheme = TargetScheme.bestFor(s, SlotKind.centerX)!;
      final failure = EdgePairer.pairFour(s, scheme, [], deadline: _far);
      expect(failure?.kind, SolveFailureKind.invalidInput);

      // An unknown colour on a wing.
      final grey = f.solvedColors();
      grey[layout.edges[3].wings[1].other] = const Color(0xFF9E9E9E).toARGB32();
      final g = f.build(grey);
      expect(EdgePairer.pairFour(g, scheme, [], deadline: _far)?.kind,
          SolveFailureKind.invalidInput);
    });

    test('5x5: wings that do not match the middle edges are rejected', () {
      final f = NxnFacelets(5);
      final layout = EdgeLayout(5);
      final colors = f.solvedColors();
      // Give UR's middle edge the colours of UF's: two middle edges now ask
      // for the same wings, and UR's wings match no middle edge.
      final ur = layout.edgeNamed('UR'), uf = layout.edgeNamed('UF');
      colors[ur.midge!.$1] = colors[uf.midge!.$1];
      colors[ur.midge!.$2] = colors[uf.midge!.$2];
      final s = f.build(colors);
      final scheme = TargetScheme.fromFixedCenters(s)!;
      expect(EdgePairer.pairFive(s, scheme, [], deadline: _far)?.kind,
          SolveFailureKind.invalidInput);
    });
  });
}
