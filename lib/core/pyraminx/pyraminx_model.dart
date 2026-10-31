import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math_64.dart';

/// Geometry of a Pyraminx (edge length 3, one sticker row = 1), centred at the
/// origin with the U vertex on top and the green face towards the viewer.
///
/// Vertices: 0 U (top), 1 L (front-left), 2 R (front-right), 3 B (back).
/// Faces are numbered by the vertex they are opposite to:
/// face 0 = bottom (opposite U, yellow), 1 = right (opposite L, blue),
/// 2 = left (opposite R, red), 3 = front (opposite B, green).
abstract final class PyraminxGeometry {
  static final double height = math.sqrt(6); // tetrahedron height for edge 3

  static final List<Vector3> vertices = [
    Vector3(0, height * 3 / 4, 0),
    Vector3(-1.5, -height / 4, math.sqrt(3) / 2),
    Vector3(1.5, -height / 4, math.sqrt(3) / 2),
    Vector3(0, -height / 4, -math.sqrt(3)),
  ];

  /// Unit axis through each vertex.
  static final List<Vector3> axes = [
    for (final v in vertices) v.normalized(),
  ];

  /// Distance of the layer cut and the tip cut from the centre, along an axis.
  static final double layerCut = height / 12;
  static final double tipCut = height * 5 / 12;

  static const List<Color> faceColors = [
    Color(0xFFFFEB3B), // 0 bottom: yellow
    Color(0xFF2196F3), // 1 right: blue
    Color(0xFFF44336), // 2 left: red
    Color(0xFF4CAF50), // 3 front: green
  ];

  static const List<String> faceNames = ['底面', '右面', '左面', '前面'];

  /// The 36 sticker slots: 9 per face, face-major.
  static final List<PyraminxSlot> slots = _buildSlots();

  static List<PyraminxSlot> _buildSlots() {
    final out = <PyraminxSlot>[];
    for (var face = 0; face < 4; face++) {
      final corners = [
        for (var v = 0; v < 4; v++)
          if (v != face) vertices[v],
      ];
      // Orient corners so the normal points outwards.
      var a = corners[0], b = corners[1], c = corners[2];
      final centroid = (a + b + c) / 3;
      var normal = (b - a).cross(c - a)..normalize();
      if (normal.dot(centroid) < 0) {
        final t = b;
        b = c;
        c = t;
        normal = -normal;
      }
      Vector3 p(int i, int j) => a + (b - a) * (i / 3) + (c - a) * (j / 3);
      for (var i = 0; i < 3; i++) {
        for (var j = 0; i + j < 3; j++) {
          out.add(PyraminxSlot(face, [p(i, j), p(i + 1, j), p(i, j + 1)], normal));
          if (i + j < 2) {
            out.add(PyraminxSlot(
                face, [p(i + 1, j), p(i + 1, j + 1), p(i, j + 1)], normal));
          }
        }
      }
    }
    return out;
  }

  /// Rotation by [quarters] thirds of a turn (clockwise seen from outside the
  /// vertex = negative angle about the outward axis).
  static Matrix4 rotation(int axis, double angle) {
    final q = Quaternion.axisAngle(axes[axis], angle);
    return Matrix4.compose(Vector3.zero(), q, Vector3.all(1));
  }

  /// Whether [slot] moves with a turn of [axis] (tip-only or whole layer).
  static bool inRegion(PyraminxSlot slot, int axis, bool tip) =>
      slot.centroid.dot(axes[axis]) > (tip ? tipCut : layerCut);
}

class PyraminxSlot {
  PyraminxSlot(this.face, this.corners, this.normal)
      : centroid = (corners[0] + corners[1] + corners[2]) / 3;

  final int face;
  final List<Vector3> corners;
  final Vector3 normal;
  final Vector3 centroid;
}

/// A Pyraminx turn: [axis] 0..3 = U L R B, [tip] for lower-case tip turns,
/// [clockwise] as seen looking at that vertex from outside.
class PyraminxMove {
  const PyraminxMove(this.axis, {this.tip = false, this.clockwise = true});

  final int axis;
  final bool tip;
  final bool clockwise;

  PyraminxMove get inverse =>
      PyraminxMove(axis, tip: tip, clockwise: !clockwise);

  /// Rotation angle about the outward axis.
  double get angle => (clockwise ? -1 : 1) * 2 * math.pi / 3;

  String get notation {
    final letter = const ['U', 'L', 'R', 'B'][axis];
    return '${tip ? letter.toLowerCase() : letter}${clockwise ? '' : "'"}';
  }

  static PyraminxMove parse(String m) {
    final letter = m[0];
    final axis = 'ULRB'.indexOf(letter.toUpperCase());
    if (axis < 0) throw ArgumentError('Invalid Pyraminx move: $m');
    return PyraminxMove(
      axis,
      tip: letter == letter.toLowerCase(),
      clockwise: !m.endsWith("'"),
    );
  }

  static List<PyraminxMove> parseAll(String text) => text
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .map(parse)
      .toList();

  @override
  bool operator ==(Object other) =>
      other is PyraminxMove &&
      other.axis == axis &&
      other.tip == tip &&
      other.clockwise == clockwise;

  @override
  int get hashCode => Object.hash(axis, tip, clockwise);
}

/// Sticker colours of a Pyraminx: [colors][slot] is a face colour index.
class PyraminxState {
  PyraminxState(this.colors);

  factory PyraminxState.solved() => PyraminxState(
      [for (final s in PyraminxGeometry.slots) s.face]);

  /// Colour index per slot (0..3, see [PyraminxGeometry.faceColors]), or -1
  /// for an unpainted sticker.
  final List<int> colors;

  PyraminxState copy() => PyraminxState([...colors]);

  static final Map<PyraminxMove, List<int>> _perms = {};

  /// Slot permutation of [move]: the colour at slot i moves to perm[i].
  static List<int> permutation(PyraminxMove move) =>
      _perms.putIfAbsent(move, () {
        final slots = PyraminxGeometry.slots;
        final rot = PyraminxGeometry.rotation(move.axis, move.angle);
        return [
          for (final s in slots)
            if (!PyraminxGeometry.inRegion(s, move.axis, move.tip))
              slots.indexOf(s)
            else
              _nearest(rot.transform3(Vector3.copy(s.centroid))),
        ];
      });

  static int _nearest(Vector3 p) {
    var best = 0;
    var bestD = double.infinity;
    final slots = PyraminxGeometry.slots;
    for (var i = 0; i < slots.length; i++) {
      final d = slots[i].centroid.distanceToSquared(p);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  void apply(PyraminxMove move) {
    final perm = permutation(move);
    final out = List<int>.filled(colors.length, 0);
    for (var i = 0; i < colors.length; i++) {
      out[perm[i]] = colors[i];
    }
    colors.setAll(0, out);
  }

  void applyAll(Iterable<PyraminxMove> moves) => moves.forEach(apply);

  /// Every face shows one colour.
  bool get isSolved {
    final first = <int, int>{};
    for (var i = 0; i < colors.length; i++) {
      final face = PyraminxGeometry.slots[i].face;
      final c = first.putIfAbsent(face, () => colors[i]);
      if (c != colors[i]) return false;
    }
    return true;
  }
}
