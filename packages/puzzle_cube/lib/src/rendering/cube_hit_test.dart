import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../models/cube_move.dart';
import '../models/cubie_model.dart';

/// Outer half-extent of the cube in model space (cubie centre 2.2 + body 1).
const double _half = 3.2;

/// The six outer faces as (cube face, 4 model-space corners in cyclic order).
final List<(CubieFace, List<Vector3>)> _faces = [
  (CubieFace.xPos, [
    Vector3(_half, -_half, -_half),
    Vector3(_half, _half, -_half),
    Vector3(_half, _half, _half),
    Vector3(_half, -_half, _half),
  ]),
  (CubieFace.xNeg, [
    Vector3(-_half, -_half, -_half),
    Vector3(-_half, _half, -_half),
    Vector3(-_half, _half, _half),
    Vector3(-_half, -_half, _half),
  ]),
  (CubieFace.yPos, [
    Vector3(-_half, _half, -_half),
    Vector3(_half, _half, -_half),
    Vector3(_half, _half, _half),
    Vector3(-_half, _half, _half),
  ]),
  (CubieFace.yNeg, [
    Vector3(-_half, -_half, -_half),
    Vector3(_half, -_half, -_half),
    Vector3(_half, -_half, _half),
    Vector3(-_half, -_half, _half),
  ]),
  (CubieFace.zPos, [
    Vector3(-_half, -_half, _half),
    Vector3(_half, -_half, _half),
    Vector3(_half, _half, _half),
    Vector3(-_half, _half, _half),
  ]),
  (CubieFace.zNeg, [
    Vector3(-_half, -_half, -_half),
    Vector3(_half, -_half, -_half),
    Vector3(_half, _half, -_half),
    Vector3(-_half, _half, -_half),
  ]),
];

/// Returns the front-most cube face under [tap] (widget-local coordinates), or
/// null if the tap missed the cube.
///
/// It projects all six outer faces with the exact transform DiTreDi uses
/// (perspective + the y/z-flipping [scale]; the cube is centred at the origin
/// with no pan/zoom, so its orientation lives entirely in the view rotation),
/// finds which projected quads cover the tap, and keeps the one with the
/// greatest transformed depth — i.e. the face DiTreDi draws on top. That last
/// step is what stops a tap from "passing through" to the opposite (hidden)
/// face: both are hit by the ray, but only the front one is returned.
CubieFace? cubeFaceAtTap({
  required Offset tap,
  required Size size,
  required double scale,
  required double viewRotationX,
  required double viewRotationY,
}) {
  if (scale <= 0 || !scale.isFinite) return null;

  final projection = Matrix4.identity()
    ..setEntry(3, 2, -0.001) // perspective (DiTreDiConfig.perspective == true)
    ..scaleByDouble(scale, -scale, -scale, 1);
  final viewMatrix = Matrix4.identity()
    ..rotateX(viewRotationX)
    ..rotateY(viewRotationY);
  final full = projection.multiplied(viewMatrix);

  final cx = size.width / 2;
  final cy = size.height / 2;

  CubieFace? best;
  var bestDepth = double.negativeInfinity;
  for (final (face, corners) in _faces) {
    final points = <Offset>[];
    var depthSum = 0.0;
    for (final corner in corners) {
      final v = Vector3.copy(corner);
      full.perspectiveTransform(v);
      points.add(Offset(cx + v.x, cy + v.y));
      depthSum += v.z;
    }
    if (_pointInPolygon(tap, points)) {
      final depth = depthSum / corners.length;
      if (depth > bestDepth) {
        bestDepth = depth;
        best = face;
      }
    }
  }
  return best;
}

bool _pointInPolygon(Offset p, List<Offset> poly) {
  // Convex polygon test: the point is inside if it sits on the same side of
  // every edge (all edge cross-products share a sign).
  bool? positive;
  for (var i = 0; i < poly.length; i++) {
    final a = poly[i];
    final b = poly[(i + 1) % poly.length];
    final cross = (b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx);
    if (cross == 0) continue; // exactly on the edge — ignore
    final isPositive = cross > 0;
    positive ??= isPositive;
    if (positive != isPositive) return false;
  }
  return true;
}

/// Cubie-cell spacing / half-size along a face's two in-plane axes.
const double _cellSpan = 2 * _half / 3;
const double _cellHalf = _half / 3;

/// The +90°-about-+axis move for each (rotation axis, layer). Axis 0=x,1=y,2=z.
const Map<int, Map<int, CubeMove>> _posMove = {
  0: {-1: CubeMove.li, 0: CubeMove.mi, 1: CubeMove.r},
  1: {-1: CubeMove.u, 0: CubeMove.ei, 1: CubeMove.di},
  2: {-1: CubeMove.bi, 0: CubeMove.s, 1: CubeMove.f},
};

/// The layer turn a drag-on-the-cube resolves to.
class CubeDrag {
  /// Creates a resolved drag turn.
  const CubeDrag({
    required this.posMove,
    required this.axis,
    required this.layer,
    required this.tangent,
    required this.pixelsPerRadian,
  });

  /// Move applied when the layer is rotated +90° (i.e. a drag along [tangent]);
  /// the opposite drag commits [posMove]`.inverse`.
  final CubeMove posMove;

  /// Rotation axis: 0=x, 1=y, 2=z.
  final int axis;

  /// Which layer along [axis] turns: -1, 0 or 1.
  final int layer;

  /// Unit screen direction the grabbed point moves under +rotation.
  final Offset tangent;

  /// Screen pixels travelled per radian of rotation at the grab point.
  final double pixelsPerRadian;
}

/// Resolves a drag starting at [start] (widget-local) moving by [delta] into the
/// layer turn it should perform, or null if it started off the cube.
///
/// Finds the front-most sticker under [start], picks the swipe's dominant
/// in-plane axis, and turns the perpendicular layer through the grabbed cubie.
/// Direction is derived numerically from the same projection the renderer uses,
/// so it stays correct under any view rotation.
CubeDrag? cubeDragFor({
  required Offset start,
  required Offset delta,
  required Size size,
  required double scale,
  required double viewRotationX,
  required double viewRotationY,
}) {
  if (scale <= 0 || !scale.isFinite) return null;

  final full = (Matrix4.identity()
        ..setEntry(3, 2, -0.001)
        ..scaleByDouble(scale, -scale, -scale, 1))
      .multiplied(
    Matrix4.identity()
      ..rotateX(viewRotationX)
      ..rotateY(viewRotationY),
  );

  final cx = size.width / 2;
  final cy = size.height / 2;

  Offset project(Vector3 p) {
    final v = Vector3.copy(p);
    full.perspectiveTransform(v);
    return Offset(cx + v.x, cy + v.y);
  }

  double depthOf(Vector3 p) {
    final v = Vector3.copy(p);
    full.perspectiveTransform(v);
    return v.z;
  }

  // Front-most 3x3 sticker cell under `start`.
  ({int normal, int sign, int cp, int cq, int p, int q})? best;
  var bestDepth = double.negativeInfinity;

  for (final (normal, sign) in const [
    (0, 1), (0, -1), (1, 1), (1, -1), (2, 1), (2, -1),
  ]) {
    final inPlane = [0, 1, 2]..remove(normal);
    final p = inPlane[0];
    final q = inPlane[1];
    for (final cp in const [-1, 0, 1]) {
      for (final cq in const [-1, 0, 1]) {
        final corners = <Vector3>[];
        for (final (dp, dq) in const [(-1, -1), (1, -1), (1, 1), (-1, 1)]) {
          final v = Vector3.zero();
          _setAxis(v, normal, sign * _half);
          _setAxis(v, p, cp * _cellSpan + dp * _cellHalf);
          _setAxis(v, q, cq * _cellSpan + dq * _cellHalf);
          corners.add(v);
        }
        if (_pointInPolygon(start, corners.map(project).toList())) {
          final depth =
              corners.map(depthOf).reduce((a, b) => a + b) / corners.length;
          if (depth > bestDepth) {
            bestDepth = depth;
            best = (normal: normal, sign: sign, cp: cp, cq: cq, p: p, q: q);
          }
        }
      }
    }
  }
  final cell = best;
  if (cell == null) return null;

  // Grab point = the cell centre on the cube surface.
  final grab = Vector3.zero();
  _setAxis(grab, cell.normal, cell.sign * _half);
  _setAxis(grab, cell.p, cell.cp * _cellSpan);
  _setAxis(grab, cell.q, cell.cq * _cellSpan);
  final grabScreen = project(grab);

  Offset axisScreenDir(int axis) {
    final p2 = Vector3.copy(grab);
    _addAxis(p2, axis, 1);
    return project(p2) - grabScreen;
  }

  final alongP = _dot(delta, _normalize(axisScreenDir(cell.p)));
  final alongQ = _dot(delta, _normalize(axisScreenDir(cell.q)));

  // Swipe runs along the dominant in-plane axis; the layer turns about the
  // other in-plane axis, at the grabbed cubie's coordinate.
  final rotAxis = alongP.abs() >= alongQ.abs() ? cell.q : cell.p;
  final layer = rotAxis == cell.p ? cell.cp : cell.cq;
  final posMove = _posMove[rotAxis]![layer]!;

  // Numeric tangent: where +rotation about +rotAxis carries the grab point.
  final motionScreen =
      project(grab + _axisVec(rotAxis).cross(grab)) - grabScreen;
  final ppr = motionScreen.distance;
  if (ppr < 1e-3) return null;

  return CubeDrag(
    posMove: posMove,
    axis: rotAxis,
    layer: layer,
    tangent: Offset(motionScreen.dx / ppr, motionScreen.dy / ppr),
    pixelsPerRadian: ppr,
  );
}

void _setAxis(Vector3 v, int axis, double value) {
  if (axis == 0) {
    v.x = value;
  } else if (axis == 1) {
    v.y = value;
  } else {
    v.z = value;
  }
}

void _addAxis(Vector3 v, int axis, double d) {
  if (axis == 0) {
    v.x += d;
  } else if (axis == 1) {
    v.y += d;
  } else {
    v.z += d;
  }
}

Vector3 _axisVec(int axis) => axis == 0
    ? Vector3(1, 0, 0)
    : axis == 1
        ? Vector3(0, 1, 0)
        : Vector3(0, 0, 1);

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

Offset _normalize(Offset o) {
  final d = o.distance;
  return d == 0 ? Offset.zero : Offset(o.dx / d, o.dy / d);
}
