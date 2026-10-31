import 'dart:math' as math;

import 'package:cuber/cuber.dart' as cuber;
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/core/nxn/nxn_cube_state.dart';
import 'package:rubik_app/core/nxn/nxn_facelets.dart';
import 'package:rubik_app/features/solver/domain/big_cube/edge_layout.dart';
import 'package:rubik_app/features/solver/domain/big_cube/move_optimizer.dart';
import 'package:rubik_app/features/solver/domain/big_cube/parity_algorithms.dart';
import 'package:rubik_app/features/solver/domain/big_cube/reduced_three.dart';
import 'package:rubik_app/features/solver/domain/big_cube/solve_step.dart';
import 'package:rubik_app/features/solver/domain/big_cube/target_scheme.dart';

import 'helpers.dart';

/// Random outer turns: keeps a solved cube reduced (centres solved, edges
/// paired) but scrambles it as a 3x3.
List<NxnMove> _outer(int n, math.Random rng, int length) {
  final outer = [
    for (final m in NxnMoveTable(n).moves)
      if (m.layer.abs() == n - 1) m,
  ];
  return [for (var i = 0; i < length; i++) outer[rng.nextInt(outer.length)]];
}

final _standard = TargetScheme.fromFixedCenters(NxnCubeState.solved(5))!;

/// Slots whose colour differs between [a] and [b].
Set<int> _diff(List<int> a, List<int> b) =>
    {for (var i = 0; i < a.length; i++) if (a[i] != b[i]) i};

Set<int> _wingSlots(EdgeLayout layout, List<String> names) => {
      for (final name in names)
        for (final w in layout.edgeNamed(name).wings) ...[w.named, w.other],
    };

void main() {
  group('parity formulas (real engine)', () {
    test('4x4 OLL parity flips exactly the UF dedge', () {
      final f = NxnFacelets(4);
      final layout = EdgeLayout(4);
      final alg = ParityAlgorithms.moves(ParityAlgorithms.ollFour, 4);
      expect(alg, hasLength(15));
      final s = NxnCubeState.solved(4)..applyAll(alg);
      final colors = f.read(s);
      final solved = f.solvedColors();
      expect(_diff(colors, solved), _wingSlots(layout, ['UF']));
      // Flipped: U shows green, F shows white on both wings.
      for (final w in layout.edgeNamed('UF').wings) {
        expect(colors[w.named], solved[w.other]);
        expect(colors[w.other], solved[w.named]);
      }
      expect(layout.allPaired(colors), isTrue);
      expect(f.read(s..applyAll(inverseOf(alg))), solved);
    });

    test('4x4 PLL parity swaps exactly the UF and UB dedges', () {
      final f = NxnFacelets(4);
      final layout = EdgeLayout(4);
      final alg = ParityAlgorithms.moves(ParityAlgorithms.pllFour, 4);
      final s = NxnCubeState.solved(4)..applyAll(alg);
      final colors = f.read(s);
      final solved = f.solvedColors();
      final uf = layout.edgeNamed('UF'), ub = layout.edgeNamed('UB');
      expect(_diff(colors, solved).every(_wingSlots(layout, ['UF', 'UB']).contains),
          isTrue);
      // UF now holds the UB dedge and vice versa, U colour still up.
      int faceColor(int face) => solved[f.slotsOfFace(face).first];
      for (final (e, other) in [(uf, ub), (ub, uf)]) {
        final (a, b) = e.faceSlots;
        expect(a.map((x) => colors[x]).toSet(), {faceColor(0)}); // U
        expect(b.map((x) => colors[x]).toSet(), {faceColor(other.faces.$2)});
      }
      expect(f.read(s..applyAll(inverseOf(alg))), solved);
    });

    test('5x5 edge parity swaps exactly the two UF wings', () {
      final f = NxnFacelets(5);
      final layout = EdgeLayout(5);
      final alg = ParityAlgorithms.moves(ParityAlgorithms.edgeFive, 5);
      final s = NxnCubeState.solved(5)..applyAll(alg);
      final colors = f.read(s);
      final solved = f.solvedColors();
      expect(_diff(colors, solved), _wingSlots(layout, ['UF']));
      final (ma, mb) = layout.edgeNamed('UF').midge!;
      expect(colors[ma], solved[ma]); // the middle edge stays
      expect(colors[mb], solved[mb]);
      expect(layout.allPaired(colors), isFalse);
      expect(f.read(s..applyAll(inverseOf(alg))), solved);
    });

    test('parity formulas only use legal moves of their own order', () {
      for (final (alg, n) in [
        (ParityAlgorithms.ollFour, 4),
        (ParityAlgorithms.pllFour, 4),
        (ParityAlgorithms.edgeFive, 5),
      ]) {
        for (final m in ParityAlgorithms.moves(alg, n)) {
          expect(NxnMoveTable(n).indexOf(m), isNonNegative);
        }
      }
    });

    test('on 200 random reduced 4x4s: OLL toggles edge flip, PLL toggles '
        'permutation parity, nothing else changes', () {
      final f = NxnFacelets(4);
      final layout = EdgeLayout(4);
      final rng = math.Random(4141);
      final scheme = TargetScheme.bestFor(NxnCubeState.solved(4), SlotKind.centerX)!;
      for (var i = 0; i < 200; i++) {
        final s = NxnCubeState.solved(4)..applyAll(_outer(4, rng, 25));
        expect(ReducedThree.status(ReducedThree.definition(s, scheme)!),
            cuber.CubeStatus.ok);
        final before = f.read(s);

        final oll = s.copy()
          ..applyAll(ParityAlgorithms.moves(ParityAlgorithms.ollFour, 4));
        expect(ReducedThree.status(ReducedThree.definition(oll, scheme)!),
            cuber.CubeStatus.twistedEdge);
        expect(_wingSlots(layout, ['UF']).containsAll(_diff(f.read(oll), before)),
            isTrue);
        expect(layout.allPairedState(oll), isTrue);

        final pll = s.copy()
          ..applyAll(ParityAlgorithms.moves(ParityAlgorithms.pllFour, 4));
        expect(ReducedThree.status(ReducedThree.definition(pll, scheme)!),
            cuber.CubeStatus.parityError);
        expect(
            _wingSlots(layout, ['UF', 'UB'])
                .containsAll(_diff(f.read(pll), before)),
            isTrue);
        expect(layout.allPairedState(pll), isTrue);
      }
    });
  });

  group('reduced 3x3', () {
    for (final n in [4, 5]) {
      test('${n}x$n: 54 distinct real stickers; solved reads as solved', () {
        final f = NxnFacelets(n);
        final sources = ReducedThree.sources(n);
        expect(sources, hasLength(54));
        expect(sources.toSet(), hasLength(54));
        for (final (pos, normal) in sources) {
          f.slotAt(pos, normal); // throws if no such sticker
        }
        final scheme = n == 4
            ? TargetScheme.bestFor(NxnCubeState.solved(4), SlotKind.centerX)!
            : _standard;
        expect(ReducedThree.definition(NxnCubeState.solved(n), scheme),
            cuber.Cube.solved.definition);
      });

      test('${n}x$n: every cuber move maps to the matching outer turn '
          '(200 random sequences)', () {
        final rng = math.Random(n * 31);
        final scheme = TargetScheme.fromCorner(NxnCubeState.solved(n))!;
        for (var i = 0; i < 200; i++) {
          var cube = cuber.Cube.solved;
          final s = NxnCubeState.solved(n);
          for (var k = 0; k < 1 + rng.nextInt(25); k++) {
            final m = cuber.Move.values[rng.nextInt(18)];
            cube = cube.move(m);
            final nm = ReducedThree.toNxn(m, n);
            expect(nm.layer.abs(), n - 1);
            s.apply(nm);
          }
          expect(ReducedThree.definition(s, scheme), cube.definition);
        }
      });
    }

    test('any held orientation: letters follow the target scheme', () {
      // Whole-cube rotation of a 4x4 (all layers of an axis).
      final s = NxnCubeState.solved(4)
        ..applyAll([for (final l in [-3, -1, 1, 3]) NxnMove(0, l, 1)]);
      final scheme = TargetScheme.bestFor(s, SlotKind.centerX)!;
      expect(ReducedThree.definition(s, scheme), cuber.Cube.solved.definition);
    });

    test('a sticker outside the scheme gives no definition', () {
      final f = NxnFacelets(4);
      final colors = f.solvedColors();
      colors[0] = 0xFF9E9E9E;
      final scheme = TargetScheme.bestFor(NxnCubeState.solved(4), SlotKind.centerX)!;
      final (pos, normal) = (f.posOf[0], f.normalOf[0]);
      final read = ReducedThree.sources(4).contains((pos, normal));
      expect(ReducedThree.definition(f.build(colors), scheme),
          read ? isNull : isNotNull);
    });
  });

  group('move optimizer', () {
    SolveStep step(ReductionPhase p, String alg, int n) =>
        SolveStep(phase: p, description: alg, moves: NxnMove.parseAll(alg, n));

    test('merges and cancels same-axis turns, cascading', () {
      final out = MoveOptimizer.optimize([
        step(ReductionPhase.centers, "R 2R R'", 4),
        step(ReductionPhase.centers, "U 2R' U' F", 4),
        step(ReductionPhase.centers, "F' F2 F2", 4),
      ]);
      // R 2R R' → 2R; then U … U' don't touch; 2R' stays apart from 2R.
      expect(out.expand((s) => s.moves).map((m) => m.notation(4)).join(' '),
          "2R U 2R' U'");
      expect(out, hasLength(2)); // the third step cancelled away
    });

    test('never merges across phases', () {
      final out = MoveOptimizer.optimize([
        step(ReductionPhase.centers, "R U", 4),
        step(ReductionPhase.edges, "U' R'", 4),
      ]);
      expect(out.expand((s) => s.moves), hasLength(4));
    });

    test('random sequences: same cube per phase, never longer, no '
        'adjacent same-layer turns', () {
      final rng = math.Random(77);
      for (final n in [4, 5]) {
        final f = NxnFacelets(n);
        for (var i = 0; i < 300; i++) {
          final steps = [
            for (var k = 0; k < 1 + rng.nextInt(6); k++)
              SolveStep(
                phase: ReductionPhase.values[k ~/ 2],
                description: '$k',
                moves: randomMoves(n, rng, rng.nextInt(12)),
              ),
          ];
          final out = MoveOptimizer.optimize(steps);
          for (final p in ReductionPhase.values) {
            final a = [for (final s in steps) if (s.phase == p) ...s.moves];
            final b = [for (final s in out) if (s.phase == p) ...s.moves];
            expect(b.length, lessThanOrEqualTo(a.length));
            expect(f.read(NxnCubeState.solved(n)..applyAll(b)),
                f.read(NxnCubeState.solved(n)..applyAll(a)));
            for (var k = 1; k < b.length; k++) {
              expect(b[k].axis == b[k - 1].axis && b[k].layer == b[k - 1].layer,
                  isFalse);
            }
          }
          expect(out.every((s) => s.moves.isNotEmpty), isTrue);
        }
      }
    });
  });
}
