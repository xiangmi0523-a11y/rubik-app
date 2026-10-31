import 'package:flutter/material.dart';
import 'package:puzzle_cube/puzzle_cube.dart'
    show CubieDraw, CubieFaceDraw, RealisticCubeRenderer;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'nxn_cube_state.dart';
import 'nxn_projection.dart';

/// Paints an n×n cube with the shared [RealisticCubeRenderer] (lighting,
/// rounded glossy stickers, contact shadow), so it matches the 3x3.
class NxnCubePainter extends CustomPainter {
  NxnCubePainter({
    required this.state,
    required this.rotationX,
    required this.rotationY,
    this.turn,
    this.brightness,
    super.repaint,
  });

  final NxnCubeState state;
  final double rotationX;
  final double rotationY;
  final NxnTurn? turn;

  /// Light multiplier per cubie position (the turn highlight); null = 1.
  final double Function(IVec pos)? brightness;

  static final _renderer = RealisticCubeRenderer();

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

    final draws = <CubieDraw>[];
    for (final c in state.cubies) {
      final turning = turn != null && turn.turns(c.pos);
      Vector3 world(Vector3 v) => turning ? turnMatrix!.transform3(v) : v;
      final center = NxnProjection.cubieCenter(c.pos);

      final faces = <CubieFaceDraw>[];
      for (final normal in _allNormals) {
        final n = NxnProjection.vec(normal);
        final faceCenter = center + n * 0.5;
        final viewCenter = proj.toView(world(Vector3.copy(faceCenter)));
        var vn = Vector3.copy(n);
        if (turning) vn = turnMatrix!.rotated3(vn);
        vn = proj.view.rotated3(vn);
        if (!proj.facesCamera(viewCenter, vn)) continue;

        final (u, v) = NxnProjection.tangents(normal);
        u.scale(0.5);
        v.scale(0.5);
        faces.add(CubieFaceDraw(
          at: (a, b) => proj.project(world(faceCenter + u * a + v * b)),
          // View space is y-up; the renderer wants screen space (y down).
          normal: Vector3(vn.x, -vn.y, vn.z)..normalize(),
          sticker: c.stickers[normal],
        ));
      }
      if (faces.isEmpty) continue;
      draws.add(CubieDraw(
        depth: proj.toView(world(Vector3.copy(center))).z,
        // Slabs along the turn axis are drawn as rigid blocks, back to front.
        group: turn == null ? 0 : turn.sideOf(c.pos),
        brightness: brightness?.call(c.pos) ?? 1,
        faces: faces,
      ));
    }
    _renderer.paint(canvas, size, draws,
        extent: state.n / 2 * proj.scale * 1.15);
  }

  @override
  bool shouldRepaint(covariant NxnCubePainter old) => true;
}
