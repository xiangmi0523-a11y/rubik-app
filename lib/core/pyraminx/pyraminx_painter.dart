import 'package:flutter/material.dart';
import 'package:puzzle_cube/puzzle_cube.dart'
    show CubeColors, RealisticCubeRenderer;
import 'package:vector_math/vector_math_64.dart';

import 'pyraminx_controller.dart';
import 'pyraminx_model.dart';
import 'pyraminx_projection.dart';

/// Paints the Pyraminx with the shared lit renderer: black plastic triangles,
/// rounded glossy stickers, a contact shadow, and the inner cut faces that a
/// turning tip/layer exposes.
class PyraminxPainter extends CustomPainter {
  PyraminxPainter({
    required this.colors,
    required this.rotationX,
    required this.rotationY,
    this.turn,
  });

  final List<int> colors;
  final double rotationX;
  final double rotationY;
  final PyraminxTurn? turn;

  static final _renderer = RealisticCubeRenderer();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final proj = PyraminxProjection(
      size: size,
      rotationX: rotationX,
      rotationY: rotationY,
    );
    _renderer.paintShadow(canvas, size, proj.scale * 1.55);

    final turn = this.turn;
    final slots = PyraminxGeometry.slots;
    if (turn == null) {
      _paintPart(canvas, proj, [for (var i = 0; i < slots.length; i++) i],
          null, null);
      return;
    }

    final moving = <int>[];
    final still = <int>[];
    for (var i = 0; i < slots.length; i++) {
      (PyraminxGeometry.inRegion(slots[i], turn.axis, turn.tip)
              ? moving
              : still)
          .add(i);
    }
    final rot = PyraminxGeometry.rotation(turn.axis, turn.angle);
    final axis = PyraminxGeometry.axes[turn.axis];
    final cut = turn.tip ? PyraminxGeometry.tipCut : PyraminxGeometry.layerCut;
    final cap = _capTriangle(turn.axis, turn.tip);

    // Both parts are convex and separated by the cut plane: draw the one on
    // the far side of the plane first.
    final cameraOnVertexSide = proj.cameraInModel.dot(axis) > cut;
    void drawStill() => _paintPart(canvas, proj, still, null, (cap, axis));
    void drawMoving() => _paintPart(canvas, proj, moving, rot, (cap, -axis));
    if (cameraOnVertexSide) {
      drawStill();
      drawMoving();
    } else {
      drawMoving();
      drawStill();
    }
  }

  /// Cross-section of the tetrahedron at the cut of [axis].
  static List<Vector3> _capTriangle(int axis, bool tip) {
    final v = PyraminxGeometry.vertices[axis];
    final t = tip ? 1 / 3 : 2 / 3;
    return [
      for (var w = 0; w < 4; w++)
        if (w != axis) v + (PyraminxGeometry.vertices[w] - v) * t,
    ];
  }

  void _paintPart(
    Canvas canvas,
    PyraminxProjection proj,
    List<int> indices,
    Matrix4? rot,
    (List<Vector3>, Vector3)? cap,
  ) {
    Vector3 world(Vector3 p) => rot == null ? p : rot.transform3(Vector3.copy(p));
    Vector3 dir(Vector3 n) => rot == null ? n : rot.rotated3(Vector3.copy(n));

    final panels = <(double, VoidCallback)>[];
    void addPanel(List<Vector3> corners, Vector3 normal, int? color) {
      final w = corners.map(world).toList();
      final centroid = (w[0] + w[1] + w[2]) / 3;
      final vc = proj.toView(centroid);
      final vn = proj.view.rotated3(dir(Vector3.copy(normal)));
      if (!proj.facesCamera(vc, vn)) return;
      final screenNormal = Vector3(vn.x, -vn.y, vn.z)..normalize();
      panels.add((
        vc.z,
        () {
          final pts = w.map(proj.project).toList();
          final center = proj.project(centroid);
          final body = _rounded(pts, center, 1.0, 0.08);
          Path? sticker;
          Color? fill;
          if (color != null) {
            sticker = _rounded(pts, center, 0.78, 0.32);
            fill = color < 0
                ? CubeColors.colorless
                : PyraminxGeometry.faceColors[color];
          }
          _renderer.paintPanel(
            canvas,
            body: body,
            sticker: sticker,
            color: fill,
            normal: screenNormal,
            center: center,
            reach: (pts[0] - center).distance,
          );
        },
      ));
    }

    for (final i in indices) {
      final s = PyraminxGeometry.slots[i];
      addPanel(s.corners, s.normal, colors[i]);
    }
    if (cap != null) addPanel(cap.$1, cap.$2, null);

    panels.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, draw) in panels) {
      draw();
    }
  }

  /// Triangle shrunk towards [center] by [scale], corners rounded by
  /// [round] (fraction of each edge).
  static Path _rounded(
      List<Offset> tri, Offset center, double scale, double round) {
    final p = [for (final q in tri) center + (q - center) * scale];
    final path = Path();
    for (var i = 0; i < 3; i++) {
      final corner = p[i];
      final prev = p[(i + 2) % 3];
      final next = p[(i + 1) % 3];
      final a = Offset.lerp(corner, prev, round)!;
      final b = Offset.lerp(corner, next, round)!;
      if (i == 0) {
        path.moveTo(a.dx, a.dy);
      } else {
        path.lineTo(a.dx, a.dy);
      }
      path.quadraticBezierTo(corner.dx, corner.dy, b.dx, b.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant PyraminxPainter old) => true;
}
