import 'dart:math' as math;

import 'package:cuber/cuber.dart' as cuber;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/core/nxn/nxn_cube_state.dart';
import 'package:rubik_app/core/nxn/nxn_facelets.dart';
import 'package:rubik_app/features/player/domain/puzzle_stepper.dart'
    show playerStepGap, playerTurnDuration;
import 'package:rubik_app/features/solver/domain/big_cube/big_cube_solver.dart';
import 'package:rubik_app/features/solver/domain/big_cube/cycle_library.dart';
import 'package:rubik_app/features/solver/domain/big_cube/edge_layout.dart';
import 'package:rubik_app/features/solver/domain/big_cube/edge_pairer.dart';
import 'package:rubik_app/features/solver/domain/big_cube/parity_algorithms.dart';
import 'package:rubik_app/features/solver/domain/big_cube/reduced_three.dart';
import 'package:rubik_app/features/solver/domain/big_cube/solve_step.dart';
import 'package:rubik_app/features/solver/domain/big_cube/target_scheme.dart';

import 'helpers.dart';

const _order = ReductionPhase.values; // centers, edges, parity, threeByThree

/// Slots of [kinds].
List<int> _slots(NxnFacelets f, Set<SlotKind> kinds) => [
      for (var i = 0; i < f.count; i++)
        if (kinds.contains(f.kindOf[i])) i,
    ];

List<int> _pick(List<int> colors, List<int> slots) => [for (final s in slots) colors[s]];

/// The physical pieces of a colouring (corners, wings, middle edges): each
/// as its sorted colours, as a sorted list — equal for any two states that
/// differ only by turns.
List<String> _pieces(NxnFacelets f, List<int> colors) {
  final byPiece = <int, List<int>>{};
  for (var i = 0; i < f.count; i++) {
    final k = f.kindOf[i];
    if (k == SlotKind.corner || k == SlotKind.wing || k == SlotKind.midEdge) {
      byPiece.putIfAbsent(f.pieceOf[i], () => []).add(colors[i]);
    }
  }
  return [for (final p in byPiece.values) (p..sort()).join('-')]..sort();
}

/// Every centre sticker of each face shows one colour (and, on 5x5, the
/// colour of the fixed centre).
bool _centresUniform(NxnFacelets f, List<int> colors) {
  for (var face = 0; face < 6; face++) {
    final c = {
      for (final s in f.slotsOfFace(face))
        if (const {SlotKind.centerX, SlotKind.centerT, SlotKind.centerFixed}
            .contains(f.kindOf[s]))
          colors[s],
    };
    if (c.length != 1) return false;
  }
  return true;
}

/// The scheme orientation matching the cube's (solved) centres.
TargetScheme _schemeOf(NxnCubeState input, List<int> colors, NxnFacelets f) {
  final centre = SlotKind.centerX;
  return TargetScheme.fromCorner(input)!.orientations().firstWhere((t) => f
      .slotsOfKind(centre)
      .every((s) => colors[s] == t.faceColors[f.faceOf[s]]));
}

/// Everything a successful solve must satisfy; returns parity steps seen.
List<String> _expectGoodSolve(NxnCubeState input, BigCubeSolution r, String why) {
  final n = input.n;
  final f = NxnFacelets(n);
  final table = NxnMoveTable(n);
  final layout = EdgeLayout(n);
  expect(r.ok, isTrue, reason: '$why: ${r.failure}');

  // Legal moves, steps add up, phases in order and each at most once.
  for (final m in r.moves) {
    expect(table.indexOf(m), isNonNegative, reason: why);
  }
  expect(r.steps.expand((s) => s.moves).toList(), r.moves);
  // The turns shown by the player are exactly these layers.
  expect([for (final t in r.blockSteps) ...t.block.moves], r.moves);
  final phases = r.phases.map((p) => p.phase).toList();
  expect(phases.toSet().length, phases.length, reason: why);
  for (var i = 1; i < phases.length; i++) {
    expect(_order.indexOf(phases[i]), greaterThan(_order.indexOf(phases[i - 1])));
  }
  expect(r.phases.fold(0, (a, p) => a + p.length), r.moves.length);

  // Replay on a fresh copy of the input, checking each phase's result.
  final start = f.read(input);
  final corners = _slots(f, {SlotKind.corner});
  final mids = _slots(f, {SlotKind.midEdge});
  final s = input.copy();
  // State after the centre phase (the input if there is none): edge
  // pairing and parity work from here and must leave corners (and 5x5
  // middle edges) exactly as they are.
  var afterCentres = start;
  final hasParity = phases.contains(ReductionPhase.parity);
  for (final p in r.phases) {
    s.applyAll(r.moves.sublist(p.start, p.end));
    final c = f.read(s);
    switch (p.phase) {
      case ReductionPhase.centers:
        expect(_centresUniform(f, c), isTrue, reason: '$why: centres');
        // Edges and corners may move while the centres are solved (wide
        // turns), but they are still exactly the input's pieces.
        expect(_pieces(f, c), _pieces(f, start), reason: '$why: same pieces');
        // Parity is settled here: no parity formula later ⇔ even wings.
        final scheme = n == 4
            ? _schemeOf(input, c, f)
            : TargetScheme.fromFixedCenters(s)!;
        if (!hasParity) {
          expect(EdgePairer.wingParity(s, scheme), 0, reason: '$why: parity');
        }
        afterCentres = c;
      case ReductionPhase.edges:
        expect(_centresUniform(f, c), isTrue, reason: '$why: edges/centres');
        if (n == 4 || !hasParity) {
          expect(layout.allPaired(c), isTrue, reason: '$why: edges');
        }
        expect(_pick(c, corners), _pick(afterCentres, corners),
            reason: '$why: corners');
        expect(_pick(c, mids), _pick(afterCentres, mids),
            reason: '$why: middle edges');
      case ReductionPhase.parity:
        expect(_centresUniform(f, c), isTrue, reason: '$why: parity/centres');
        expect(layout.allPaired(c), isTrue, reason: '$why: parity/edges');
        expect(_pick(c, corners), _pick(afterCentres, corners),
            reason: '$why: corners');
        final scheme = n == 4
            ? _schemeOf(input, c, f)
            : TargetScheme.fromFixedCenters(s)!;
        expect(ReducedThree.status(ReducedThree.definition(s, scheme)!),
            cuber.CubeStatus.ok, reason: '$why: reduced 3x3');
      case ReductionPhase.threeByThree:
        expect(s.isSolved, isTrue, reason: '$why: 3x3');
        expect(r.moves.sublist(p.start, p.end).every((m) => m.layer.abs() == n - 1),
            isTrue, reason: '$why: 3x3 phase uses outer turns only');
    }
  }
  expect(s.isSolved, isTrue, reason: '$why: replay');
  expect(f.read(input), start, reason: 'input must not be modified');
  return [
    for (final st in r.steps)
      if (st.phase == ReductionPhase.parity) st.description,
  ];
}

/// [count] random real scrambles of order [n]; prints the statistics.
void _randomRun(int n, int count, int seed) {
  final rng = math.Random(seed);
  final times = <int>[], moves = <int>[];
  final turns = <int>[], singles = <int>[], wides = <int>[], playMs = <int>[];
  final phaseMoves = {for (final p in _order) p: <int>[]};
  final phaseTurns = {for (final p in _order) p: <int>[]};
  final parities = <String, int>{};
  var solved = 0;
  final failures = <String>[];
  // Cold start: builds the tables and cuber's pruning tables.
  final cold = BigCubeSolver.solve(NxnCubeState.solved(n)
    ..applyAll(randomMoves(n, math.Random(seed + 1), 50)));
  expect(cold.ok, isTrue);
  for (var i = 0; i < count; i++) {
    final scramble = randomMoves(n, rng, 30 + rng.nextInt(51));
    final input = NxnCubeState.solved(n)..applyAll(scramble);
    final r = BigCubeSolver.solve(input);
    final why = '#$i ${describe(scramble, n)}';
    if (!r.ok) {
      failures.add('$why → ${r.failure}');
      continue;
    }
    for (final p in _expectGoodSolve(input, r, why)) {
      final key = p.split('：').first;
      parities[key] = (parities[key] ?? 0) + 1;
    }
    solved++;
    times.add(r.elapsed.inMicroseconds);
    moves.add(r.moves.length);
    for (final p in r.phases) {
      phaseMoves[p.phase]!.add(p.length);
    }
    // Player turns (a wide turn is one step).
    final steps = r.blockSteps;
    final t = steps.length;
    turns.add(t);
    final w = steps.where((s) => s.block.width > 1).length;
    wides.add(w);
    singles.add(t - w);
    // Playback at 1×: every turn animates, with a pause between turns.
    playMs.add(t == 0
        ? 0
        : t * playerTurnDuration.inMilliseconds +
            (t - 1) * playerStepGap.inMilliseconds);
    for (final p in _order) {
      final k = steps.where((s) => s.phase == p).length;
      if (k > 0) phaseTurns[p]!.add(k);
    }
  }
  String avg(List<int> l, [int div = 1]) => l.isEmpty
      ? '-'
      : (l.reduce((a, b) => a + b) / l.length / div).toStringAsFixed(1);
  String mx(List<int> l, [int div = 1]) =>
      l.isEmpty ? '-' : (l.reduce(math.max) / div).toStringAsFixed(1);
  // ignore: avoid_print
  print('SOLVE${n}_STATS solved=$solved/$count failures=${failures.length} '
      'cold=${cold.elapsed.inMilliseconds}ms '
      'time avg=${avg(times, 1000)}ms max=${mx(times, 1000)}ms '
      'moves avg=${avg(moves)} max=${mx(moves)} '
      '${[for (final p in _order) '${p.name}=${avg(phaseMoves[p]!)}(${phaseMoves[p]!.length})'].join(' ')} '
      'parity=$parities');
  // ignore: avoid_print
  print('TURNS${n}_STATS turns avg=${avg(turns)} max=${mx(turns)} '
      'single avg=${avg(singles)} wide avg=${avg(wides)} '
      'wideShare=${(wides.fold(0, (a, b) => a + b) * 100 / turns.fold(0, (a, b) => a + b)).toStringAsFixed(1)}% '
      'play1x avg=${avg(playMs, 1000)}s max=${mx(playMs, 1000)}s '
      '${[for (final p in _order) '${p.name}=${avg(phaseTurns[p]!)}(${phaseTurns[p]!.length})'].join(' ')}');
  for (final x in failures) {
    // ignore: avoid_print
    print('FAIL $x');
  }
  expect(failures, isEmpty);
  expect(solved, count);
  // Parity formulas are mostly avoided now (decided during centres and
  // pairing); their own paths are covered by the parity special cases.
}

NxnCubeState _from(int n, String alg) =>
    NxnCubeState.solved(n)..applyAll(NxnMove.parseAll(alg, n));

List<NxnMove> _wholeCube(int n, int axis, int turns) => [
      for (final l in NxnFacelets(n).layers) NxnMove(axis, l, turns),
    ];

void main() {
  test('4x4: 500 random legal scrambles solve completely', () {
    _randomRun(4, 500, 20261031);
  }, timeout: const Timeout(Duration(minutes: 20)));

  test('5x5: 500 random legal scrambles solve completely', () {
    _randomRun(5, 500, 20261131);
  }, timeout: const Timeout(Duration(minutes: 20)));

  group('4x4 special cases', () {
    List<ReductionPhase> phasesOf(BigCubeSolution r) =>
        r.phases.map((p) => p.phase).toList();

    test('solved (in any orientation) needs no moves', () {
      for (final axis in [0, 1, 2]) {
        final s = NxnCubeState.solved(4)..applyAll(_wholeCube(4, axis, 1));
        final r = BigCubeSolver.solve(s);
        expect(r.ok, isTrue);
        expect(r.moves, isEmpty);
      }
    });

    test('OLL parity only', () {
      final s = _from(4, ParityAlgorithms.ollFour);
      final r = BigCubeSolver.solve(s);
      _expectGoodSolve(s, r, 'oll');
      expect(phasesOf(r), [ReductionPhase.parity]);
      expect(r.steps.single.description, contains('OLL'));
    });

    test('PLL parity only', () {
      final s = _from(4, ParityAlgorithms.pllFour);
      final r = BigCubeSolver.solve(s);
      _expectGoodSolve(s, r, 'pll');
      expect(phasesOf(r), [ReductionPhase.parity]);
      expect(r.steps.single.description, contains('PLL'));
    });

    test('OLL and PLL parity together, under a 3x3 scramble', () {
      final s = _from(4, "${ParityAlgorithms.ollFour} ${ParityAlgorithms.pllFour} "
          "R U2 F' L D B2 U' R2");
      final r = BigCubeSolver.solve(s);
      final parity = _expectGoodSolve(s, r, 'oll+pll');
      expect(parity, hasLength(2));
      expect(parity[0], contains('OLL'));
      expect(parity[1], contains('PLL'));
    });

    test('last two edges crossed', () {
      final layout = EdgeLayout(4);
      final lib = PieceCycleLibrary.wings(4);
      for (final (a, b) in [('UF', 'UR'), ('DB', 'FL'), ('RB', 'LB')]) {
        final ea = layout.edgeNamed(a), eb = layout.edgeNamed(b);
        final s = NxnCubeState.solved(4)
          ..applyAll(lib.cycle(ea.wings[0].named, eb.wings[1].named, ea.wings[1].named))
          ..applyAll(NxnMove.parseAll("U R' F2", 4));
        final colors = NxnFacelets(4).read(s);
        expect([for (final e in layout.edges) if (!layout.paired(colors, e)) e].length,
            2);
        final r = BigCubeSolver.solve(s);
        _expectGoodSolve(s, r, '$a+$b');
        expect(phasesOf(r).first, ReductionPhase.edges);
      }
    });

    test('a pure 3x3 scramble only needs the 3x3 phase', () {
      final s = _from(4, "R U F' D2 L B' R2 U' F L2 D' B");
      final r = BigCubeSolver.solve(s);
      _expectGoodSolve(s, r, '3x3');
      expect(phasesOf(r), [ReductionPhase.threeByThree]);
    });

    test('only centres scrambled', () {
      final lib = PieceCycleLibrary.centers(4, SlotKind.centerX);
      final o = lib.orbit;
      final s = NxnCubeState.solved(4)..applyAll(lib.cycle(o[0], o[9], o[17]));
      final r = BigCubeSolver.solve(s);
      _expectGoodSolve(s, r, 'centres');
      expect(phasesOf(r), [ReductionPhase.centers]);
    });
  });

  group('5x5 special cases', () {
    List<ReductionPhase> phasesOf(BigCubeSolution r) =>
        r.phases.map((p) => p.phase).toList();

    test('solved (in any orientation) needs no moves', () {
      for (final axis in [0, 1, 2]) {
        final s = NxnCubeState.solved(5)..applyAll(_wholeCube(5, axis, -1));
        final r = BigCubeSolver.solve(s);
        expect(r.ok, isTrue);
        expect(r.moves, isEmpty);
      }
    });

    test('edge parity only (one flipped wing pair)', () {
      final s = _from(5, ParityAlgorithms.edgeFive);
      final r = BigCubeSolver.solve(s);
      _expectGoodSolve(s, r, 'edge parity');
      expect(phasesOf(r), [ReductionPhase.parity]);
    });

    test('edge parity on another edge, under a 3x3 scramble', () {
      final s = _from(5, "F2 L ${ParityAlgorithms.edgeFive} L' F2 R U B' D2");
      final r = BigCubeSolver.solve(s);
      final parity = _expectGoodSolve(s, r, 'edge parity 2');
      expect(parity, hasLength(1));
    });

    test('last two tredges crossed', () {
      final layout = EdgeLayout(5);
      final lib = PieceCycleLibrary.wings(5);
      final a = layout.edgeNamed('UL'), b = layout.edgeNamed('RF');
      final s = NxnCubeState.solved(5)
        ..applyAll(lib.cycle(a.wings[0].named, b.wings[0].named, b.wings[1].named));
      final r = BigCubeSolver.solve(s);
      _expectGoodSolve(s, r, 'last two');
      expect(phasesOf(r), [ReductionPhase.edges]);
    });

    test('middle-slice turns (fixed centres move) and a 3x3 scramble', () {
      final s = _from(5, "3R U 3F' R2 3U2 D L'");
      final r = BigCubeSolver.solve(s);
      _expectGoodSolve(s, r, 'middle slices');
    });

    test('a pure 3x3 scramble only needs the 3x3 phase', () {
      final s = _from(5, "R U F' D2 L B' R2 U' F L2 D' B");
      final r = BigCubeSolver.solve(s);
      _expectGoodSolve(s, r, '3x3');
      expect(phasesOf(r), [ReductionPhase.threeByThree]);
    });
  });

  group('failures are reported, never "solved"', () {
    test('timeout', () {
      for (final n in [4, 5]) {
        final s = NxnCubeState.solved(n)
          ..applyAll(randomMoves(n, math.Random(3), 60));
        final r = BigCubeSolver.solve(s, timeout: Duration.zero);
        expect(r.ok, isFalse);
        expect(r.failure!.kind, SolveFailureKind.timeout);
        // Whatever was done before the timeout is legal and replays.
        for (final m in r.moves) {
          expect(NxnMoveTable(n).indexOf(m), isNonNegative);
        }
        s.copy().applyAll(r.moves);
      }
    });

    test('wrong order', () {
      for (final n in [2, 3, 6]) {
        final r = BigCubeSolver.solve(NxnCubeState.solved(n));
        expect(r.failure?.kind, SolveFailureKind.invalidInput, reason: '$n');
      }
    });

    List<int> solvedColors(int n) => NxnFacelets(n).solvedColors();
    NxnCubeState build(int n, List<int> c) => NxnFacelets(n).build(c);

    void twistCorner(int n, List<int> c) {
      final f = NxnFacelets(n);
      final m = n - 1;
      final pos = (m, m, m);
      final a = f.slotAt(pos, (1, 0, 0)), b = f.slotAt(pos, (0, 1, 0)),
          d = f.slotAt(pos, (0, 0, 1));
      final t = c[a];
      c[a] = c[b];
      c[b] = c[d];
      c[d] = t;
    }

    test('4x4 and 5x5: a twisted corner', () {
      for (final n in [4, 5]) {
        final c = solvedColors(n);
        twistCorner(n, c);
        final s = build(n, c)..applyAll(randomMoves(n, math.Random(n), 40));
        final r = BigCubeSolver.solve(s);
        expect(r.failure?.kind, SolveFailureKind.invalidInput, reason: '$n');
        expect(r.failure!.message, contains('角'));
      }
    });

    test('4x4: a flipped single wing', () {
      final layout = EdgeLayout(4);
      final c = solvedColors(4);
      final w = layout.edgeNamed('FL').wings[0];
      final t = c[w.named];
      c[w.named] = c[w.other];
      c[w.other] = t;
      final r = BigCubeSolver.solve(build(4, c));
      expect(r.failure?.kind, SolveFailureKind.invalidInput);
      expect(r.failure!.message, contains('棱'));
    });

    test('5x5: a flipped middle edge, and two swapped middle edges', () {
      final layout = EdgeLayout(5);
      final flip = solvedColors(5);
      final (a, b) = layout.edgeNamed('UF').midge!;
      final t = flip[a];
      flip[a] = flip[b];
      flip[b] = t;
      final r1 = BigCubeSolver.solve(build(5, flip));
      expect(r1.failure?.kind, SolveFailureKind.invalidInput);
      expect(r1.moves, isEmpty); // rejected before doing any work

      final swap = solvedColors(5);
      final uf = layout.edgeNamed('UF').midge!, ur = layout.edgeNamed('UR').midge!;
      // UF (white, green) ↔ UR (white, red): white stays up.
      final g = swap[uf.$2];
      swap[uf.$2] = swap[ur.$2];
      swap[ur.$2] = g;
      final r2 = BigCubeSolver.solve(build(5, swap));
      expect(r2.failure?.kind, SolveFailureKind.invalidInput);
    });

    test('wrong centre counts and unpainted stickers', () {
      for (final n in [4, 5]) {
        final f = NxnFacelets(n);
        final c = solvedColors(n);
        final x = f.slotsOfKind(SlotKind.centerX);
        c[x.first] = c[x.last]; // one colour 5 times, another 3 times
        expect(BigCubeSolver.solve(build(n, c)).failure?.kind,
            SolveFailureKind.invalidInput);

        final g = solvedColors(n);
        g[f.slotsOfKind(SlotKind.wing)[5]] = const Color(0xFF9E9E9E).toARGB32();
        expect(BigCubeSolver.solve(build(n, g)).failure?.kind,
            SolveFailureKind.invalidInput);
      }
    });

    test('illegal reference corner / fixed centres', () {
      final f4 = NxnFacelets(4);
      final c4 = solvedColors(4);
      final corner = (-3, -3, -3);
      c4[f4.slotAt(corner, (0, -1, 0))] = c4[f4.slotAt(corner, (0, 0, -1))];
      expect(BigCubeSolver.solve(build(4, c4)).failure?.kind,
          SolveFailureKind.invalidInput);

      final f5 = NxnFacelets(5);
      final c5 = solvedColors(5);
      c5[f5.slotAt((0, 4, 0), (0, 1, 0))] = c5[f5.slotAt((0, -4, 0), (0, -1, 0))];
      expect(BigCubeSolver.solve(build(5, c5)).failure?.kind,
          SolveFailureKind.invalidInput);
    });
  });
}
