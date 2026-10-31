import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'nxn_cube_state.dart';
import 'nxn_projection.dart';

/// Paints an n×n cube: black cubie bodies with coloured stickers, drawn back
/// to front (painter's algorithm, back faces culled).
class NxnCubePainter extends CustomPainter {
  NxnCubePainter({
    required this.state,
    required this.rotationX,
    required this.rotationY,
    this.turn,
    super.repaint,
  });

  final NxnCubeState state;
  final double rotationX;
  final double rotationY;
  final NxnTurn? turn;

  static const _bodyHalf = 0.5;
  static const _stickerHalf = 0.42;
  static const _bodyColor = Color(0xFF121212);

  static const _allNormals = <IVec>[
    (1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final proj = NxnProjection(
      size: size,
      n: state.n,
      rotationX: rotationX,
      rotationY: rotationY,
    );
    final turn = this.turn;
    final turnMatrix = turn == null ? null : NxnProjection.turnMatrix(turn);

    final items = <(double, NxnCubie, bool)>[];
    for (final c in state.cubies) {
      final turning = turn != null && state.inLayer(c, turn.axis, turn.layer);
      var center = NxnProjection.cubieCenter(c.pos);
      if (turning) center = turnMatrix!.transform3(center);
      items.add((proj.toView(center).z, c, turning));
    }
    items.sort((a, b) => a.$1.compareTo(b.$1)); // far first

    final body = Paint()..color = _bodyColor;
    final sticker = Paint();
    final edge = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final (_, c, turning) in items) {
      Vector3 world(Vector3 v) => turning ? turnMatrix!.transform3(v) : v;
      final center = NxnProjection.cubieCenter(c.pos);
      for (final normal in _allNormals) {
        final n = NxnProjection.vec(normal);
        final faceCenter = center + n * _bodyHalf;
        final vc = proj.toView(world(Vector3.copy(faceCenter)));
        var vn = Vector3.copy(n);
        if (turning) vn = turnMatrix!.rotated3(vn);
        vn = proj.view.rotated3(vn);
        if (!proj.facesCamera(vc, vn)) continue;

        canvas.drawPath(
          _path(NxnProjection.square(faceCenter, normal, _bodyHalf), world, proj),
          body,
        );
        final color = c.stickers[normal];
        if (color != null) {
          final path = _path(
            NxnProjection.square(faceCenter + n * 0.001, normal, _stickerHalf),
            world,
            proj,
          );
          canvas.drawPath(path, sticker..color = color);
          canvas.drawPath(path, edge);
        }
      }
    }
  }

  Path _path(List<Vector3> corners, Vector3 Function(Vector3) world,
      NxnProjection proj) {
    final pts = [for (final c in corners) proj.project(world(c))];
    return Path()..addPolygon(pts, true);
  }

  @override
  bool shouldRepaint(covariant NxnCubePainter old) => true;
}
