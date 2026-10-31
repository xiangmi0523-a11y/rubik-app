import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'package:puzzle_cube/puzzle_cube.dart';

/// Outward model-space normal of each cube face.
const _normals = {
  CubieFace.xPos: [1.0, 0.0, 0.0],
  CubieFace.xNeg: [-1.0, 0.0, 0.0],
  CubieFace.yPos: [0.0, 1.0, 0.0],
  CubieFace.yNeg: [0.0, -1.0, 0.0],
  CubieFace.zPos: [0.0, 0.0, 1.0],
  CubieFace.zNeg: [0.0, 0.0, -1.0],
};

/// Independent check that [face] is the one pointing toward the viewer: under
/// DiTreDi's transform the camera sees the side whose rotated outward normal has
/// a negative z (this is what "front-most, not the opposite face" means).
bool _isFrontFacing(CubieFace face, double rx, double ry) {
  final n = _normals[face]!;
  final m = Matrix4.identity()
    ..rotateX(rx)
    ..rotateY(ry);
  final rotated = m.transform3(Vector3(n[0], n[1], n[2]));
  return rotated.z < 0;
}

void main() {
  const size = Size(280, 280);
  const center = Offset(140, 140);
  const scale = 20.0; // representative modelScale*viewScale

  group('cubeFaceAtTap', () {
    test('a centre tap picks a front face, never the opposite one', () {
      final face = cubeFaceAtTap(
        tap: center,
        size: size,
        scale: scale,
        viewRotationX: 0,
        viewRotationY: 0,
      );
      expect(face, anyOf(CubieFace.zPos, CubieFace.zNeg));
    });

    test('rotating 180° about Y flips which z-face is front-most', () {
      final front = cubeFaceAtTap(
        tap: center,
        size: size,
        scale: scale,
        viewRotationX: 0,
        viewRotationY: 0,
      );
      final flipped = cubeFaceAtTap(
        tap: center,
        size: size,
        scale: scale,
        viewRotationX: 0,
        viewRotationY: 3.14159265, // ~pi
      );
      expect(front, isNotNull);
      expect(flipped, isNotNull);
      expect(flipped, isNot(front));
      expect({front, flipped}, {CubieFace.zPos, CubieFace.zNeg});
    });

    test('centre tap always lands on a front-facing face (no fall-through)', () {
      // Sweep many orientations; the picked face must always face the viewer.
      for (var rx = -1.2; rx <= 1.2; rx += 0.3) {
        for (var ry = -3.0; ry <= 3.0; ry += 0.3) {
          final face = cubeFaceAtTap(
            tap: center,
            size: size,
            scale: scale,
            viewRotationX: rx,
            viewRotationY: ry,
          );
          expect(
            face,
            isNotNull,
            reason: 'centre should hit the cube at rx=$rx ry=$ry',
          );
          expect(
            _isFrontFacing(face!, rx, ry),
            isTrue,
            reason: 'picked $face is a back face at rx=$rx ry=$ry',
          );
        }
      }
    });

    test('a tap far outside the cube silhouette selects nothing', () {
      final face = cubeFaceAtTap(
        tap: const Offset(2, 2),
        size: size,
        scale: scale,
        viewRotationX: -0.5,
        viewRotationY: 0.6,
      );
      expect(face, isNull);
    });

    test('a non-positive scale is handled gracefully', () {
      final face = cubeFaceAtTap(
        tap: center,
        size: size,
        scale: 0,
        viewRotationX: 0,
        viewRotationY: 0,
      );
      expect(face, isNull);
    });
  });
}
