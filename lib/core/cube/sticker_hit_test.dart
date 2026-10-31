import 'dart:math' as math;
import 'dart:ui';

import 'package:puzzle_cube/puzzle_cube.dart';
import 'package:vector_math/vector_math_64.dart';

import 'cube_facelets.dart';

/// Sticker-level hit testing for puzzle_cube's `Cube` widget.
///
/// puzzle_cube only reports which *face* was tapped, so this reproduces the
/// projection DiTreDi uses (perspective, y/z flip, fit-to-viewport scale) to
/// find the exact facelet under a tap.
abstract final class StickerHitTest {
  static const double _spacing = 2.2; // cubie centre spacing
  static const double _half = 3.2; // outer half-extent (2.2 + 1)
  static const double _cellHalf = 1.0; // half size of a cubie face

  /// Index (0..53, cuber facelet order) of the front-most sticker under [tap],
  /// or null if the tap misses the cube.
  static int? faceletAt({
    required Offset tap,
    required Size size,
    required double viewRotationX,
    required double viewRotationY,
  }) {
    final full = _transform(size, viewRotationX, viewRotationY);
    if (full == null) return null;
    final view = Matrix4.identity()
      ..rotateX(viewRotationX)
      ..rotateY(viewRotationY);
    final cx = size.width / 2;
    final cy = size.height / 2;

    int? best;
    var bestDepth = double.negativeInfinity;
    for (var i = 0; i < 54; i++) {
      final ref = CubeFacelets.refs[i];
      // Back-face culling: skip stickers turned away from the camera, so a tap
      // near the silhouette never lands on a hidden face.
      if (view.rotated3(_normal(ref.face)).z >= 0) continue;
      final quad = _quad(ref);
      final points = <Offset>[];
      var depth = 0.0;
      for (final corner in quad) {
        final v = Vector3.copy(corner);
        full.perspectiveTransform(v);
        points.add(Offset(cx + v.x, cy + v.y));
        depth += v.z;
      }
      if (_inside(tap, points) && depth > bestDepth) {
        bestDepth = depth;
        best = i;
      }
    }
    return best;
  }

  /// Screen position of the centre of facelet [index] (used by tests).
  static Offset? centerOf({
    required int index,
    required Size size,
    required double viewRotationX,
    required double viewRotationY,
  }) {
    final full = _transform(size, viewRotationX, viewRotationY);
    if (full == null) return null;
    final quad = _quad(CubeFacelets.refs[index]);
    final c = (quad[0] + quad[2])..scale(0.5);
    full.perspectiveTransform(c);
    return Offset(size.width / 2 + c.x, size.height / 2 + c.y);
  }

  static Matrix4? _transform(Size size, double rotX, double rotY) {
    if (size.isEmpty) return null;
    final view = Matrix4.identity()
      ..rotateX(rotX)
      ..rotateY(rotY);

    // DiTreDi fits the *unrotated* model's bounding box to the viewport.
    // The box spans the cubie bodies (±3.2) plus the sticker planes, which sit
    // 0.01 proud of the bodies: spread = 2 * 3.21.
    const spread = 2 * (_half + 0.01);
    final scale = math.min(size.width, size.height) / 2 / spread;

    final projection = Matrix4.identity()
      ..setEntry(3, 2, -0.001)
      ..scaleByDouble(scale, -scale, -scale, 1);
    return projection.multiplied(view);
  }

  static Vector3 _normal(CubieFace face) => switch (face) {
        CubieFace.xPos => Vector3(1, 0, 0),
        CubieFace.xNeg => Vector3(-1, 0, 0),
        CubieFace.yPos => Vector3(0, 1, 0),
        CubieFace.yNeg => Vector3(0, -1, 0),
        CubieFace.zPos => Vector3(0, 0, 1),
        CubieFace.zNeg => Vector3(0, 0, -1),
      };

  /// The four model-space corners of a sticker's cubie face (cyclic order).
  static List<Vector3> _quad(StickerRef ref) {
    final center = Vector3(
      ref.x * _spacing,
      ref.y * _spacing,
      ref.z * _spacing,
    );
    final n = _normal(ref.face);
    // Two unit vectors spanning the face plane.
    final a = n.x != 0 ? Vector3(0, 1, 0) : Vector3(1, 0, 0);
    final b = n.z != 0 ? Vector3(0, 1, 0) : Vector3(0, 0, 1);
    final c = center + n * _cellHalf;
    a.scale(_cellHalf);
    b.scale(_cellHalf);
    return [c + a + b, c + a - b, c - a - b, c - a + b];
  }

  static bool _inside(Offset p, List<Offset> poly) {
    bool? positive;
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      final cross =
          (b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx);
      if (cross == 0) continue;
      final isPositive = cross > 0;
      positive ??= isPositive;
      if (positive != isPositive) return false;
    }
    return true;
  }
}
