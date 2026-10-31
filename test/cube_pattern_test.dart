import 'package:cuber/cuber.dart' as cuber;
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_cube/puzzle_cube.dart';
import 'package:rubik_app/core/cube/cube_facelets.dart';
import 'package:rubik_app/core/nxn/nxn_cube_state.dart';
import 'package:rubik_app/core/pyraminx/pyraminx_model.dart';
import 'package:rubik_app/core/pyraminx/pyraminx_solver.dart';
import 'package:rubik_app/features/patterns/domain/cube_pattern.dart';
import 'package:rubik_app/features/patterns/domain/pattern_scripts.dart';
import 'package:rubik_app/features/puzzles/domain/puzzle_type.dart';

/// Colours on the face with normal [n], keyed by in-plane coordinates.
Map<(int, int), int> faceCells(NxnCubeState s, IVec n) {
  final ax = n.$1 != 0 ? 0 : (n.$2 != 0 ? 1 : 2);
  final o = [0, 1, 2]..remove(ax);
  return {
    for (final c in s.cubies)
      if (c.stickers[n] != null)
        (axisOf(c.pos, o[0]), axisOf(c.pos, o[1])): c.stickers[n]!.toARGB32(),
  };
}

bool isCheckerboard(NxnCubeState s) =>
    NxnCubeState.faceColors.keys.every((n) {
      final byParity = <int, Set<int>>{};
      faceCells(s, n).forEach((k, v) {
        final parity = ((k.$1 + s.max) ~/ 2 + (k.$2 + s.max) ~/ 2) % 2;
        byParity.putIfAbsent(parity, () => {}).add(v);
      });
      return byParity[0]!.length == 1 &&
          byParity[1]!.length == 1 &&
          byParity[0]!.first != byParity[1]!.first;
    });

/// Every face: uniform centre block, uniform border, different colours.
bool isSpots(NxnCubeState s, {required int faces}) {
  var count = 0;
  for (final n in NxnCubeState.faceColors.keys) {
    final inner = <int>{}, border = <int>{};
    faceCells(s, n).forEach((k, v) =>
        (k.$1.abs() == s.max || k.$2.abs() == s.max ? border : inner).add(v));
    if (inner.length == 1 && border.length == 1 && inner.first != border.first) {
      count++;
    } else if (inner.length != 1 || border.length != 1) {
      return false;
    }
  }
  return count == faces;
}

void main() {
  for (final p in patternsFor(PuzzleType.cube3)) {
    test('3x3 ${p.name}: cuber, 3D model and N×N engine agree', () {
      final alg = cuber.Algorithm.parse(p.algorithm);
      expect(alg.apply(cuber.Cube.solved).definition, p.definition);
      final state = PuzzleCubeState.solved();
      for (final m in alg.moves) {
        CubeNotation.toQuarterTurns(m).forEach(state.applyMove);
      }
      expect(CubeFacelets.definitionOf(state), p.definition);
    });
  }

  test('2x2 六面条纹: every face is two stripes', () {
    final s = cubePatternState(patternsFor(PuzzleType.cube2).single);
    for (final n in NxnCubeState.faceColors.keys) {
      expect(faceCells(s, n).values.toSet(), hasLength(2));
    }
  });

  test('4x4 patterns', () {
    final p = {for (final x in patternsFor(PuzzleType.cube4)) x.id: x};
    expect(isSpots(cubePatternState(p['six_spots4']!), faces: 6), isTrue);
    expect(isSpots(cubePatternState(p['four_spots4']!), faces: 4), isTrue);
    expect(cubePatternState(p['cube_in_cube4']!).isSolved, isFalse);
  });

  test('5x5 patterns', () {
    final p = {for (final x in patternsFor(PuzzleType.cube5)) x.id: x};
    expect(isCheckerboard(cubePatternState(p['checkerboard5']!)), isTrue);
    expect(isCheckerboard(cubePatternState(p['checkerboard5b']!)), isTrue);
    expect(isSpots(cubePatternState(p['six_spots5']!), faces: 6), isTrue);
  });

  test('Pyraminx patterns', () {
    final p = {for (final x in patternsFor(PuzzleType.pyraminx)) x.id: x};
    final slots = PyraminxGeometry.slots;
    final tips = {for (final t in PyraminxSolver.tips) ...t};

    final tipState = pyraminxPatternState(p['tips']!);
    for (var i = 0; i < 36; i++) {
      // Only the tips differ from their face.
      expect(tipState.colors[i] == slots[i].face, !tips.contains(i));
    }

    final flower = pyraminxPatternState(p['flower']!);
    for (var i = 0; i < 36; i++) {
      if (tips.contains(i)) expect(flower.colors[i], slots[i].face);
    }
    expect(flower.isSolved, isFalse);

    final twoTone = pyraminxPatternState(p['two_tone']!);
    for (var f = 0; f < 4; f++) {
      final colours = {
        for (var i = 0; i < 36; i++)
          if (slots[i].face == f) twoTone.colors[i],
      };
      expect(colours, hasLength(2));
    }
  });
}
