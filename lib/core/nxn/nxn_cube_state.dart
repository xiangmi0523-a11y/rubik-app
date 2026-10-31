import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Integer vector. Positions use doubled coordinates so every cubie centre is
/// an integer: for order n they run -(n-1), -(n-3), ..., n-1.
typedef IVec = (int, int, int);

int axisOf(IVec v, int axis) => switch (axis) { 0 => v.$1, 1 => v.$2, _ => v.$3 };

/// +90° right-handed rotation about [axis], applied [quarters] times (mod 4).
IVec rotateIVec(IVec v, int axis, int quarters) {
  var r = v;
  for (var i = 0; i < ((quarters % 4) + 4) % 4; i++) {
    final (x, y, z) = r;
    r = switch (axis) {
      0 => (x, -z, y),
      1 => (z, y, -x),
      _ => (-y, x, z),
    };
  }
  return r;
}

/// A layer turn. [turns] is +1 / -1 (right-handed quarter turn about the
/// positive axis, or its inverse) or 2 (half turn).
class NxnMove {
  const NxnMove(this.axis, this.layer, this.turns);

  final int axis;

  /// Doubled coordinate of the layer along [axis].
  final int layer;
  final int turns;

  NxnMove get inverse => NxnMove(axis, layer, turns == 2 ? 2 : -turns);

  /// Parses SiGN notation for an order-[n] cube: R, U', F2, 2R, 3U2, ...
  factory NxnMove.parse(String text, int n) {
    final m = RegExp(r"^(\d?)([RLUDFB])(2|')?$").firstMatch(text.trim());
    if (m == null) throw ArgumentError('Invalid move: $text');
    final depth = m[1]!.isEmpty ? 1 : int.parse(m[1]!);
    final face = m[2]!;
    final positive = 'RUF'.contains(face);
    final axis = 'RL'.contains(face) ? 0 : ('UD'.contains(face) ? 1 : 2);
    final layer = positive ? (n - 1) - 2 * (depth - 1) : -(n - 1) + 2 * (depth - 1);
    final clockwise = positive ? -1 : 1;
    final turns = m[3] == '2' ? 2 : (m[3] == "'" ? -clockwise : clockwise);
    return NxnMove(axis, layer, turns);
  }

  static List<NxnMove> parseAll(String text, int n) => [
        for (final t in text.split(RegExp(r'\s+')))
          if (t.isNotEmpty) NxnMove.parse(t, n),
      ];

  /// Standard (SiGN) notation for an order-[n] cube, e.g. R, U', 2R, F2.
  String notation(int n) {
    final positive = layer >= 0;
    final face = const [['R', 'L'], ['U', 'D'], ['F', 'B']][axis][positive ? 0 : 1];
    final depth = positive ? (n - 1 - layer) ~/ 2 + 1 : (n - 1 + layer) ~/ 2 + 1;
    // Clockwise seen from that face = negative rotation about +axis for the
    // positive face, positive for the negative face.
    final clockwise = positive ? turns == -1 : turns == 1;
    final suffix = turns == 2 ? '2' : (clockwise ? '' : "'");
    return '${depth > 1 ? depth : ''}$face$suffix';
  }

  @override
  bool operator ==(Object other) =>
      other is NxnMove &&
      other.axis == axis &&
      other.layer == layer &&
      other.turns == turns;

  @override
  int get hashCode => Object.hash(axis, layer, turns);

  @override
  String toString() => 'NxnMove($axis, $layer, $turns)';
}

class NxnCubie {
  NxnCubie(this.pos, this.stickers);

  IVec pos;

  /// Outward normal (unit IVec in the cube frame) -> sticker colour.
  final Map<IVec, Color> stickers;

  NxnCubie copy() => NxnCubie(pos, Map.of(stickers));
}

/// An n×n×n cube (n >= 2). Frame: x right, y up, z towards the viewer.
/// Scheme: U white, D yellow, F green, B blue, R red, L orange.
class NxnCubeState {
  NxnCubeState._(this.n, this.cubies);

  final int n;
  final List<NxnCubie> cubies;

  static const Map<IVec, Color> faceColors = {
    (0, 1, 0): Color(0xFFFFFFFF), // U white
    (0, -1, 0): Color(0xFFFFEB3B), // D yellow
    (0, 0, 1): Color(0xFF4CAF50), // F green
    (0, 0, -1): Color(0xFF2196F3), // B blue
    (1, 0, 0): Color(0xFFF44336), // R red
    (-1, 0, 0): Color(0xFFFF9800), // L orange
  };

  int get max => n - 1;

  /// Doubled layer coordinates: -(n-1), -(n-3), ..., n-1.
  List<int> get layers => [for (var i = 0; i < n; i++) -max + 2 * i];

  factory NxnCubeState.solved(int n) {
    assert(n >= 2);
    final m = n - 1;
    final cubies = <NxnCubie>[];
    for (var x = -m; x <= m; x += 2) {
      for (var y = -m; y <= m; y += 2) {
        for (var z = -m; z <= m; z += 2) {
          if (x.abs() != m && y.abs() != m && z.abs() != m) continue; // hidden
          final stickers = <IVec, Color>{};
          if (x == m) stickers[(1, 0, 0)] = faceColors[(1, 0, 0)]!;
          if (x == -m) stickers[(-1, 0, 0)] = faceColors[(-1, 0, 0)]!;
          if (y == m) stickers[(0, 1, 0)] = faceColors[(0, 1, 0)]!;
          if (y == -m) stickers[(0, -1, 0)] = faceColors[(0, -1, 0)]!;
          if (z == m) stickers[(0, 0, 1)] = faceColors[(0, 0, 1)]!;
          if (z == -m) stickers[(0, 0, -1)] = faceColors[(0, 0, -1)]!;
          cubies.add(NxnCubie((x, y, z), stickers));
        }
      }
    }
    return NxnCubeState._(n, cubies);
  }

  NxnCubeState copy() =>
      NxnCubeState._(n, [for (final c in cubies) c.copy()]);

  bool inLayer(NxnCubie c, int axis, int layer) => axisOf(c.pos, axis) == layer;

  void apply(NxnMove move) {
    final q = move.turns == 2 ? 2 : move.turns;
    for (final c in cubies) {
      if (!inLayer(c, move.axis, move.layer)) continue;
      c.pos = rotateIVec(c.pos, move.axis, q);
      final rotated = {
        for (final e in c.stickers.entries)
          rotateIVec(e.key, move.axis, q): e.value,
      };
      c.stickers
        ..clear()
        ..addAll(rotated);
    }
  }

  void applyAll(Iterable<NxnMove> moves) => moves.forEach(apply);

  /// Every face shows a single colour (any orientation counts as solved).
  bool get isSolved {
    final seen = <IVec, int>{};
    for (final c in cubies) {
      for (final e in c.stickers.entries) {
        final argb = e.value.toARGB32();
        final prev = seen.putIfAbsent(e.key, () => argb);
        if (prev != argb) return false;
      }
    }
    return true;
  }

  /// Colour of the sticker on cubie [pos] facing [normal], or null.
  Color? stickerAt(IVec pos, IVec normal) {
    for (final c in cubies) {
      if (c.pos == pos) return c.stickers[normal];
    }
    return null;
  }

  /// Random scramble: no two consecutive moves on the same axis. A 2x2 only
  /// turns its U/R/F layers (other layers would just rotate the whole cube).
  static List<NxnMove> randomScramble(int n, {int? length, math.Random? rng}) {
    final random = rng ?? math.Random();
    final count = length ?? switch (n) { 2 => 11, 3 => 20, 4 => 40, _ => 60 };
    final m = n - 1;
    final allLayers = [for (var i = 0; i < n; i++) -m + 2 * i];
    final moves = <NxnMove>[];
    var lastAxis = -1;
    while (moves.length < count) {
      final axis = random.nextInt(3);
      if (axis == lastAxis) continue;
      final layers = n == 2 ? [m] : allLayers;
      final layer = layers[random.nextInt(layers.length)];
      final turns = const [1, -1, 2][random.nextInt(3)];
      moves.add(NxnMove(axis, layer, turns));
      lastAxis = axis;
    }
    return moves;
  }
}
