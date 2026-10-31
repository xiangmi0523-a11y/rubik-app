import 'package:cuber/cuber.dart' as cuber;
import 'package:flutter/material.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

/// Six faces in Kociemba / cuber order: U R F D L B.
enum CubeSide { u, r, f, d, l, b }

extension CubeSideX on CubeSide {
  String get letter => const ['U', 'R', 'F', 'D', 'L', 'B'][index];

  String get label => const ['上 U', '右 R', '前 F', '下 D', '左 L', '后 B'][index];
}

typedef _Vec = (int, int, int);

/// One sticker position on the puzzle_cube model.
class StickerRef {
  const StickerRef(this.x, this.y, this.z, this.face);
  final int x;
  final int y;
  final int z;
  final CubieFace face;
}

/// Maps the 54 facelets (cuber string order U1..U9 R1..R9 F1..F9 D1..D9 L1..L9
/// B1..B9, each face read row by row as seen from outside) onto puzzle_cube's
/// cubie coordinates, matching what puzzle_cube actually renders with the app
/// camera: U = +y (white), F = +x (green), R = +z (red), D = -y, B = -x, L = -z.
abstract final class CubeFacelets {
  static const _Vec _up = (0, 1, 0);
  static const _Vec _down = (0, -1, 0);
  static const _Vec _front = (1, 0, 0);
  static const _Vec _back = (-1, 0, 0);
  static const _Vec _right = (0, 0, 1);
  static const _Vec _left = (0, 0, -1);

  // (outward normal, row direction, column direction, sticker face)
  static const Map<CubeSide, (_Vec, _Vec, _Vec, CubieFace)> _frames = {
    CubeSide.u: (_up, _front, _right, CubieFace.yPos),
    CubeSide.r: (_right, _down, _back, CubieFace.zPos),
    CubeSide.f: (_front, _down, _right, CubieFace.xPos),
    CubeSide.d: (_down, _back, _right, CubieFace.yNeg),
    CubeSide.l: (_left, _down, _front, CubieFace.zNeg),
    CubeSide.b: (_back, _down, _left, CubieFace.xNeg),
  };

  /// All 54 sticker references in cuber facelet order.
  static final List<StickerRef> refs = [
    for (final side in CubeSide.values)
      for (var i = 0; i < 9; i++) _ref(side, i ~/ 3, i % 3),
  ];

  static StickerRef _ref(CubeSide side, int row, int col) {
    final (n, rd, cd, face) = _frames[side]!;
    final dr = row - 1;
    final dc = col - 1;
    return StickerRef(
      n.$1 + rd.$1 * dr + cd.$1 * dc,
      n.$2 + rd.$2 * dr + cd.$2 * dc,
      n.$3 + rd.$3 * dr + cd.$3 * dc,
      face,
    );
  }

  /// Index (0..53) of facelet [index] (0..8) on [side].
  static int indexOf(CubeSide side, int index) => side.index * 9 + index;

  /// Fixed centre colours, as defined by puzzle_cube's solved state.
  static Map<CubeSide, Color> get centerColors {
    final solved = PuzzleCubeState.solved();
    return {
      for (final side in CubeSide.values)
        side: colorAt(solved, refs[indexOf(side, 4)]),
    };
  }

  static Color colorAt(PuzzleCubeState state, StickerRef ref) =>
      state.cubieAt(ref.x, ref.y, ref.z)!.faces[ref.face]!;

  /// Reads the 54 sticker colours of [state].
  static List<Color> read(PuzzleCubeState state) =>
      [for (final ref in refs) colorAt(state, ref)];

  /// Builds a puzzle_cube state from 54 colours (cuber facelet order).
  static PuzzleCubeState build(List<Color> colors) {
    assert(colors.length == 54);
    final state = PuzzleCubeState.colorless();
    for (var i = 0; i < 54; i++) {
      if (i % 9 == 4) continue; // centres are fixed
      final ref = refs[i];
      state.setStickerColor(
        x: ref.x,
        y: ref.y,
        z: ref.z,
        face: ref.face,
        color: colors[i],
      );
    }
    return state;
  }

  /// Converts 54 colours to a cuber definition string, or null if a colour
  /// doesn't match any centre.
  static String? toDefinition(List<Color> colors) {
    final byArgb = {
      for (final e in centerColors.entries) e.value.toARGB32(): e.key.letter,
    };
    final buffer = StringBuffer();
    for (final c in colors) {
      final letter = byArgb[c.toARGB32()];
      if (letter == null) return null;
      buffer.write(letter);
    }
    return buffer.toString();
  }

  static String? definitionOf(PuzzleCubeState state) =>
      toDefinition(read(state));
}

/// Conversions between cuber moves and puzzle_cube quarter-turns.
abstract final class CubeNotation {
  static const Map<String, (CubeMove, CubeMove)> _byLetter = {
    'U': (CubeMove.di, CubeMove.d),
    'R': (CubeMove.f, CubeMove.fi),
    'F': (CubeMove.r, CubeMove.ri),
    'D': (CubeMove.ui, CubeMove.u),
    'L': (CubeMove.b, CubeMove.bi),
    'B': (CubeMove.l, CubeMove.li),
  };

  /// Expands a cuber move into 1 or 2 puzzle_cube quarter turns.
  static List<CubeMove> toQuarterTurns(cuber.Move move) {
    final (cw, ccw) = _byLetter[move.color.letter]!;
    if (move.double) return [cw, cw];
    return [move.inverted ? ccw : cw];
  }

  /// Standard notation of a puzzle_cube move, as seen with the app's camera
  /// (white up, green front). puzzle_cube's own enum names don't match what is
  /// rendered, so this table was derived from the rendered cube.
  static String label(CubeMove move) => switch (move) {
        CubeMove.di => 'U',
        CubeMove.d => "U'",
        CubeMove.f => 'R',
        CubeMove.fi => "R'",
        CubeMove.r => 'F',
        CubeMove.ri => "F'",
        CubeMove.ui => 'D',
        CubeMove.u => "D'",
        CubeMove.b => 'L',
        CubeMove.bi => "L'",
        CubeMove.l => 'B',
        CubeMove.li => "B'",
        CubeMove.si => 'M',
        CubeMove.s => "M'",
        CubeMove.e => 'E',
        CubeMove.ei => "E'",
        CubeMove.mi => 'S',
        CubeMove.m => "S'",
      };

  /// Camera angles that show white on top, green in front, red on the right.
  static const double viewRotationX = -0.5;
  static const double viewRotationY = 2.17;

  static const List<CubeMove> outerMoves = [
    CubeMove.r, CubeMove.ri, CubeMove.l, CubeMove.li,
    CubeMove.u, CubeMove.ui, CubeMove.d, CubeMove.di,
    CubeMove.f, CubeMove.fi, CubeMove.b, CubeMove.bi,
  ];
}
