import 'dart:math' as math;

import 'package:cuber/cuber.dart' as cuber;
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/core/nxn/nxn_cube_state.dart';

/// Reads a 3x3 NxnCubeState as a cuber definition string.
String definitionOf(NxnCubeState s) {
  // (normal, row direction, column direction) per face in U R F D L B order.
  const frames = <(IVec, IVec, IVec)>[
    ((0, 1, 0), (0, 0, 1), (1, 0, 0)), // U: rows back->front, cols left->right
    ((1, 0, 0), (0, -1, 0), (0, 0, -1)), // R
    ((0, 0, 1), (0, -1, 0), (1, 0, 0)), // F
    ((0, -1, 0), (0, 0, -1), (1, 0, 0)), // D
    ((-1, 0, 0), (0, -1, 0), (0, 0, 1)), // L
    ((0, 0, -1), (0, -1, 0), (-1, 0, 0)), // B
  ];
  final letters = <int, String>{};
  for (final (i, (n, _, _)) in frames.indexed) {
    letters[NxnCubeState.faceColors[n]!.toARGB32()] = 'URFDLB'[i];
  }
  final b = StringBuffer();
  for (final (n, r, c) in frames) {
    for (var row = -1; row <= 1; row++) {
      for (var col = -1; col <= 1; col++) {
        final pos = (
          2 * n.$1 + 2 * row * r.$1 + 2 * col * c.$1,
          2 * n.$2 + 2 * row * r.$2 + 2 * col * c.$2,
          2 * n.$3 + 2 * row * r.$3 + 2 * col * c.$3,
        );
        b.write(letters[s.stickerAt(pos, n)!.toARGB32()]);
      }
    }
  }
  return b.toString();
}

NxnMove faceMove(String m) {
  final face = m[0];
  final suffix = m.length > 1 ? m[1] : '';
  final (axis, positive) = switch (face) {
    'R' => (0, true), 'L' => (0, false),
    'U' => (1, true), 'D' => (1, false),
    'F' => (2, true), _ => (2, false),
  };
  final cw = positive ? -1 : 1;
  final turns = suffix == '2' ? 2 : (suffix == "'" ? -cw : cw);
  return NxnMove(axis, positive ? 2 : -2, turns);
}

void main() {
  test('3x3 face turns match cuber exactly', () {
    for (final m in ['U', 'R', 'F', 'D', 'L', 'B', "U'", "R'", 'F2', "B'"]) {
      final s = NxnCubeState.solved(3)..apply(faceMove(m));
      expect(definitionOf(s),
          cuber.Cube.solved.move(cuber.Move.parse(m)).definition,
          reason: m);
      expect(faceMove(m).notation(3), m);
    }
  });

  test('3x3 random sequence matches cuber', () {
    final rng = math.Random(1);
    const faces = ['U', 'R', 'F', 'D', 'L', 'B'];
    const sufs = ['', "'", '2'];
    final alg = [
      for (var i = 0; i < 30; i++) faces[rng.nextInt(6)] + sufs[rng.nextInt(3)]
    ];
    final s = NxnCubeState.solved(3)..applyAll(alg.map(faceMove));
    expect(definitionOf(s),
        cuber.Algorithm.parse(alg.join(' ')).apply(cuber.Cube.solved).definition);
  });

  for (final n in [2, 4, 5]) {
    test('$n x $n: scramble then inverse returns to solved', () {
      final s = NxnCubeState.solved(n);
      expect(s.isSolved, isTrue);
      final moves = NxnCubeState.randomScramble(n, rng: math.Random(n));
      s.applyAll(moves);
      expect(s.isSolved, isFalse);
      s.applyAll(moves.reversed.map((m) => m.inverse));
      expect(s.isSolved, isTrue);
      // 6 faces * n*n stickers, all accounted for.
      expect(s.cubies.fold<int>(0, (a, c) => a + c.stickers.length), 6 * n * n);
    });
  }

  test('inner-layer notation', () {
    expect(const NxnMove(0, 1, -1).notation(4), '2R');
    expect(const NxnMove(0, -1, -1).notation(4), "2L'");
    expect(const NxnMove(1, 0, 2).notation(5), '3U2');
  });

  test('whole-cube rotation still counts as solved', () {
    final s = NxnCubeState.solved(4);
    for (final l in s.layers) {
      s.apply(NxnMove(1, l, 1));
    }
    expect(s.isSolved, isTrue);
  });
}
