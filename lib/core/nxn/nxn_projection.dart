import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

import 'nxn_cube_state.dart';

/// A layer being turned by a finger or an animation.
class NxnTurn {
  const NxnTurn(this.axis, this.layer, this.angle);

  final int axis;
  final int layer;

  /// Radians, right-handed about +axis.
  final double angle;
}

/// Camera + perspective for an n×n cube. World units: one cubie = 1, so the
/// cube spans ±n/2. View = Rx(rotationX) · Ry(rotationY); the camera sits on
/// +z looking at the origin.
class NxnProjection {
  NxnProjection({
    required this.size,
    required this.n,
    required double rotationX,
    required double rotationY,
  })  : view = Matrix4.rotationX(rotationX)..multiply(Matrix4.rotationY(rotationY)),
        cameraDistance = n * 4.0,
        scale = math.min(size.width, size.height) / 2 / (n / 2 * math.sqrt(3)) * 0.82;

  final Size size;
  final int n;
  final Matrix4 view;
  final double cameraDistance;
  final double scale;

  /// World point -> view space.
  Vector3 toView(Vector3 world) => view.transform3(Vector3.copy(world));

  /// View-space point -> screen.
  Offset toScreen(Vector3 v) {
    final f = cameraDistance / (cameraDistance - v.z);
    return Offset(
      size.width / 2 + v.x * f * scale,
      size.height / 2 - v.y * f * scale,
    );
  }

  Offset project(Vector3 world) => toScreen(toView(world));

  /// Whether a face with view-space [normal] at view-space [center] faces the
  /// camera.
  bool facesCamera(Vector3 center, Vector3 normal) =>
      normal.dot(Vector3(0, 0, cameraDistance) - center) > 0;

  /// Rotation applied to cubies of the turning layer.
  static Matrix4 turnMatrix(NxnTurn turn) => switch (turn.axis) {
        0 => Matrix4.rotationX(turn.angle),
        1 => Matrix4.rotationY(turn.angle),
        _ => Matrix4.rotationZ(turn.angle),
      };

  static Vector3 vec(IVec v) =>
      Vector3(v.$1.toDouble(), v.$2.toDouble(), v.$3.toDouble());

  /// World centre of a cubie at doubled position [pos].
  static Vector3 cubieCenter(IVec pos) => vec(pos)..scale(0.5);

  /// Two unit vectors spanning the plane perpendicular to [normal].
  static (Vector3, Vector3) tangents(IVec normal) {
    if (normal.$1 != 0) return (Vector3(0, 1, 0), Vector3(0, 0, 1));
    if (normal.$2 != 0) return (Vector3(1, 0, 0), Vector3(0, 0, 1));
    return (Vector3(1, 0, 0), Vector3(0, 1, 0));
  }

  /// Corners of the square of half-size [half] centred at [center] on the
  /// plane perpendicular to [normal].
  static List<Vector3> square(Vector3 center, IVec normal, double half) {
    final (a, b) = tangents(normal);
    a.scale(half);
    b.scale(half);
    return [center + a + b, center + a - b, center - a - b, center - a + b];
  }
}

/// The sticker under a point: its cubie position and outward normal.
class NxnStickerHit {
  const NxnStickerHit(this.pos, this.normal);
  final IVec pos;
  final IVec normal;
}

/// Front-most outer sticker under [point], or null.
NxnStickerHit? nxnHitTest(NxnCubeState state, NxnProjection proj, Offset point) {
  NxnStickerHit? best;
  var bestDepth = double.negativeInfinity;
  for (final c in state.cubies) {
    final center = NxnProjection.cubieCenter(c.pos);
    for (final normal in c.stickers.keys) {
      final n = NxnProjection.vec(normal);
      final faceCenter = center + n * 0.5;
      final vc = proj.toView(faceCenter);
      final vn = proj.view.rotated3(Vector3.copy(n));
      if (!proj.facesCamera(vc, vn)) continue;
      final quad = NxnProjection.square(faceCenter, normal, 0.5)
          .map(proj.project)
          .toList();
      if (_inside(point, quad) && vc.z > bestDepth) {
        bestDepth = vc.z;
        best = NxnStickerHit(c.pos, normal);
      }
    }
  }
  return best;
}

bool _inside(Offset p, List<Offset> poly) {
  bool? positive;
  for (var i = 0; i < poly.length; i++) {
    final a = poly[i];
    final b = poly[(i + 1) % poly.length];
    final cross = (b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx);
    if (cross == 0) continue;
    final isPositive = cross > 0;
    positive ??= isPositive;
    if (positive != isPositive) return false;
  }
  return true;
}
