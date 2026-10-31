import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/core/nxn/nxn_cube_state.dart';
import 'package:rubik_app/core/nxn/nxn_facelets.dart';
import 'package:rubik_app/features/solver/domain/big_cube/four_center_solver.dart';
import 'package:rubik_app/features/solver/domain/big_cube/solve_step.dart';
import 'package:rubik_app/features/solver/domain/big_cube/target_scheme.dart';

import 'helpers.dart';

final _f = NxnFacelets(4);
final _table = NxnMoveTable(4);

List<int> _nonCentres(List<int> colors) => [
      for (var i = 0; i < _f.count; i++)
        if (_f.kindOf[i] != SlotKind.centerX) colors[i],
    ];

/// Everything a successful centre solve must satisfy.
void _expectGoodSolve(NxnCubeState input, CenterSolveResult r, String why) {
  expect(r.ok, isTrue, reason: '$why: ${r.failure}');
  final target = r.target!;

  // 1. All 24 centres on their target face.
  expect(FourCenterSolver.centersSolved(r.state, target), isTrue, reason: why);

  // 2. Corners and edges exactly unchanged (only pure centre cycles used).
  expect(_nonCentres(_f.read(r.state)), _nonCentres(_f.read(input)),
      reason: '$why: non-centre stickers changed');

  // 3. Every move is a legal 4x4 move.
  for (final m in r.moves) {
    expect(_table.indexOf(m), isNonNegative);
  }

  // 4. Replaying the output on a fresh engine copy gives the same cube.
  final replay = input.copy()..applyAll(r.moves);
  expect(_f.read(replay), _f.read(r.state), reason: why);

  // 5. Steps are tagged and add up to the move list.
  expect(r.steps.every((s) => s.phase == ReductionPhase.centers), isTrue);
  expect(r.steps.expand((s) => s.moves).toList(), r.moves);
}

/// The target is an orientation of the scheme read from the down-back-left
/// corner, matches at least as many centres as any other orientation, and is
/// a real colour scheme (six colours, opposite pairs on opposite faces).
void _expectSchemeFromCorner(NxnCubeState s, TargetScheme t) {
  final colors = _f.read(s);
  final base = TargetScheme.fromCorner(s)!;
  const corner = (-3, -3, -3);
  expect(base.faceColors[3], colors[_f.slotAt(corner, (0, -1, 0))]); // D
  expect(base.faceColors[4], colors[_f.slotAt(corner, (-1, 0, 0))]); // L
  expect(base.faceColors[5], colors[_f.slotAt(corner, (0, 0, -1))]); // B
  final all = base.orientations();
  expect(all, hasLength(24));
  expect(all.map((o) => o.faceColors.join(',')),
      contains(t.faceColors.join(',')));
  final centres = _f.slotsOfKind(SlotKind.centerX);
  int score(TargetScheme o) =>
      centres.where((x) => colors[x] == o.faceColors[_f.faceOf[x]]).length;
  expect(all.every((o) => score(o) <= score(t)), isTrue);
  expect(t.faceColors.toSet(), hasLength(6));
  final solved = NxnCubeState.faceColors;
  int opp(int argb) {
    final n = solved.entries.firstWhere((e) => e.value.toARGB32() == argb).key;
    return solved[(-n.$1, -n.$2, -n.$3)]!.toARGB32();
  }
  for (var face = 0; face < 3; face++) {
    expect(t.faceColors[face], opp(t.faceColors[face + 3]));
  }
}

void main() {
  test('300 random legal 4x4 scrambles: all centres solved', () {
    final rng = math.Random(20261101);
    final formulas = <int>[], moves = <int>[], micros = <int>[];
    var solvedCount = 0;
    final failures = <String>[];
    FourCenterSolver.solve(NxnCubeState.solved(4)); // warm the library cache

    for (var i = 0; i < 300; i++) {
      final scramble = randomMoves(4, rng, 30 + rng.nextInt(51));
      final input = NxnCubeState.solved(4)..applyAll(scramble);
      final before = _f.read(input);
      final sw = Stopwatch()..start();
      final r = FourCenterSolver.solve(input);
      micros.add(sw.elapsedMicroseconds);
      if (!r.ok) {
        failures.add('#$i ${r.failure}: ${describe(scramble, 4)}');
        continue;
      }
      _expectGoodSolve(input, r, '#$i ${describe(scramble, 4)}');
      _expectSchemeFromCorner(input, r.target!);
      expect(_f.read(input), before, reason: 'input must not be modified');
      solvedCount++;
      formulas.add(r.steps.length);
      moves.add(r.moves.length);
    }

    double avg(List<int> xs) => xs.reduce((a, b) => a + b) / xs.length;
    int max(List<int> xs) => xs.reduce(math.max);
    // ignore: avoid_print
    print('CENTER_STATS solved=$solvedCount/300 failures=${failures.length} '
        'formulas avg=${avg(formulas).toStringAsFixed(1)} max=${max(formulas)} '
        'moves avg=${avg(moves).toStringAsFixed(1)} max=${max(moves)} '
        'time avg=${(avg(micros) / 1000).toStringAsFixed(2)}ms '
        'max=${(max(micros) / 1000).toStringAsFixed(2)}ms');
    expect(failures, isEmpty, reason: failures.join('\n'));
    expect(solvedCount, 300);
  });

  test('any holding orientation: whole-cube rotations before solving', () {
    final rng = math.Random(7);
    for (var i = 0; i < 24; i++) {
      final input = NxnCubeState.solved(4)..applyAll(randomMoves(4, rng, 40));
      // Rotate the whole cube (every layer) about random axes.
      for (var k = 0; k < 1 + rng.nextInt(3); k++) {
        final axis = rng.nextInt(3);
        final turns = const [1, -1, 2][rng.nextInt(3)];
        for (final layer in _f.layers) {
          input.apply(NxnMove(axis, layer, turns));
        }
      }
      final r = FourCenterSolver.solve(input);
      _expectGoodSolve(input, r, 'rotation case $i');
      _expectSchemeFromCorner(input, r.target!);
    }
  });

  test('the 24 orientations of a scheme are distinct and all valid', () {
    final base = TargetScheme.fromCorner(NxnCubeState.solved(4))!;
    final all = base.orientations();
    expect(all.map((o) => o.faceColors.join(',')).toSet(), hasLength(24));
    expect(all.first.faceColors, base.faceColors);
    // Each orientation is what a solved cube shows after whole-cube turns:
    // check by actually rotating a solved engine cube every possible way.
    final fromEngine = <String>{};
    for (final seq in [
      <NxnMove>[],
      for (var axis = 0; axis < 3; axis++)
        for (final turns in const [1, -1, 2]) [NxnMove(axis, 0, turns)],
    ]) {
      for (final axis2 in [0, 1, 2]) {
        for (final turns2 in const [0, 1, -1, 2]) {
          final cube = NxnCubeState.solved(4);
          for (final m in seq) {
            for (final l in _f.layers) {
              cube.apply(NxnMove(m.axis, l, m.turns));
            }
          }
          if (turns2 != 0) {
            for (final l in _f.layers) {
              cube.apply(NxnMove(axis2, l, turns2));
            }
          }
          final c = _f.read(cube);
          fromEngine.add([
            for (var face = 0; face < 6; face++) c[_f.slotsOfFace(face).first]
          ].join(','));
        }
      }
    }
    expect(fromEngine, all.map((o) => o.faceColors.join(',')).toSet());
  });

  test('already-solved centres need no steps (any orientation)', () {
    final input = NxnCubeState.solved(4)
      ..applyAll(NxnMove.parseAll("R U R' U' F2 D L' B", 4)); // outer only
    final r = FourCenterSolver.solve(input);
    expect(r.ok, isTrue);
    expect(r.steps, isEmpty);
  });

  test('two centres swapped (needs a solved third slot) is solved', () {
    // Swap one U centre with one F centre: a pure transposition, which
    // 3-cycles alone can only fix by borrowing a matching solved slot.
    final colors = _f.solvedColors();
    final u = _f.slotsOfFace(0).firstWhere((s) => _f.kindOf[s] == SlotKind.centerX);
    final fr = _f.slotsOfFace(2).firstWhere((s) => _f.kindOf[s] == SlotKind.centerX);
    final t = colors[u];
    colors[u] = colors[fr];
    colors[fr] = t;
    final input = _f.build(colors);
    final r = FourCenterSolver.solve(input);
    _expectGoodSolve(input, r, 'swap');
    expect(r.steps, hasLength(1));
  });

  test('every centre wrong: worst cases are still solved', () {
    // Cycle all centres one face along: U←R←F←D←L←B←U.
    final colors = _f.solvedColors();
    final out = [...colors];
    for (var face = 0; face < 6; face++) {
      final from = _f.slotsOfFace((face + 1) % 6)
          .where((s) => _f.kindOf[s] == SlotKind.centerX).toList();
      final to = _f.slotsOfFace(face)
          .where((s) => _f.kindOf[s] == SlotKind.centerX).toList();
      for (var k = 0; k < 4; k++) {
        out[to[k]] = colors[from[k]];
      }
    }
    final input = _f.build(out);
    final r = FourCenterSolver.solve(input);
    _expectGoodSolve(input, r, 'all wrong');
    expect(r.steps.length, lessThanOrEqualTo(24));
  });

  group('failures are reported, never faked', () {
    test('timeout', () {
      final input = NxnCubeState.solved(4)
        ..applyAll(randomMoves(4, math.Random(1), 50));
      final r = FourCenterSolver.solve(input, timeout: Duration.zero);
      expect(r.ok, isFalse);
      expect(r.failure!.kind, SolveFailureKind.timeout);
      // Whatever was done before the timeout is still a valid prefix.
      final replay = input.copy()..applyAll(r.moves);
      expect(_f.read(replay), _f.read(r.state));
    });

    test('wrong order', () {
      for (final n in [2, 3, 5]) {
        final r = FourCenterSolver.solve(NxnCubeState.solved(n));
        expect(r.failure!.kind, SolveFailureKind.invalidInput, reason: '$n');
      }
    });

    test('centre colour counts wrong (cannot be merged)', () {
      final colors = _f.solvedColors();
      final u = _f.slotsOfFace(0).firstWhere((s) => _f.kindOf[s] == SlotKind.centerX);
      colors[u] = colors[_f.slotsOfFace(2).first]; // a 5th green centre
      final r = FourCenterSolver.solve(_f.build(colors));
      expect(r.failure!.kind, SolveFailureKind.invalidInput);
      expect(r.failure!.message, contains('中心块颜色数量'));
      expect(r.steps, isEmpty);
    });

    test('unpainted (grey) centre', () {
      final colors = _f.solvedColors();
      final u = _f.slotsOfFace(0).firstWhere((s) => _f.kindOf[s] == SlotKind.centerX);
      colors[u] = 0xFF4D4D55;
      final r = FourCenterSolver.solve(_f.build(colors));
      expect(r.failure!.kind, SolveFailureKind.invalidInput);
    });

    test('illegal reference corner', () {
      final colors = _f.solvedColors();
      const corner = (-3, -3, -3);
      // Give the D-facing sticker the L-facing colour: duplicate colours.
      colors[_f.slotAt(corner, (0, -1, 0))] = colors[_f.slotAt(corner, (-1, 0, 0))];
      final r = FourCenterSolver.solve(_f.build(colors));
      expect(r.failure!.kind, SolveFailureKind.invalidInput);
      expect(r.failure!.message, contains('角块'));
    });
  });
}
