import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

import 'pyraminx_model.dart';

/// Camera + perspective for the Pyraminx (same conventions as the N×N cube:
/// view = Rx · Ry, camera on +z, screen y down).
class PyraminxProjection {
  PyraminxProjection({
    required this.size,
    required double rotationX,
    required double rotationY,
  })  : view = Matrix4.rotationX(rotationX)
          ..multiply(Matrix4.rotationY(rotationY)),
        scale = math.min(size.width, size.height) / 2 / 2.35;

  static const double cameraDistance = 12;

  final Size size;
  final Matrix4 view;
  final double scale;

  Vector3 toView(Vector3 world) => view.transform3(Vector3.copy(world));

  Offset toScreen(Vector3 v) {
    final f = cameraDistance / (cameraDistance - v.z);
    return Offset(
      size.width / 2 + v.x * f * scale,
      size.height / 2 - (v.y + 0.25) * f * scale,
    );
  }

  Offset project(Vector3 world) => toScreen(toView(world));

  bool facesCamera(Vector3 viewCenter, Vector3 viewNormal) =>
      viewNormal.dot(Vector3(0, 0, cameraDistance) - viewCenter) > 0;

  /// Camera position in model space.
  Vector3 get cameraInModel {
    final inv = Matrix4.copy(view)..invert();
    return inv.transform3(Vector3(0, 0, cameraDistance));
  }
}

/// Front-most sticker slot under [point]; within [tolerance] px of the
/// puzzle's edge the nearest visible slot counts too.
int? pyraminxHitTest(
  PyraminxProjection proj,
  Offset point, {
  double tolerance = 0,
}) {
  int? best;
  var bestDepth = double.negativeInfinity;
  int? nearest;
  var nearestDist = tolerance;
  final slots = PyraminxGeometry.slots;
  for (var i = 0; i < slots.length; i++) {
    final s = slots[i];
    final vc = proj.toView(s.centroid);
    final vn = proj.view.rotated3(Vector3.copy(s.normal));
    if (!proj.facesCamera(vc, vn)) continue;
    final tri = s.corners.map(proj.project).toList();
    if (_inside(point, tri)) {
      if (vc.z > bestDepth) {
        bestDepth = vc.z;
        best = i;
      }
    } else if (tolerance > 0) {
      final d = _distance(point, tri);
      if (d < nearestDist) {
        nearestDist = d;
        nearest = i;
      }
    }
  }
  return best ?? nearest;
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

double _distance(Offset p, List<Offset> poly) {
  var best = double.infinity;
  for (var i = 0; i < poly.length; i++) {
    final a = poly[i];
    final ab = poly[(i + 1) % poly.length] - a;
    final len2 = ab.distanceSquared;
    final t = len2 == 0
        ? 0.0
        : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
    final d = (p - (a + ab * t)).distance;
    if (d < best) best = d;
  }
  return best;
}
