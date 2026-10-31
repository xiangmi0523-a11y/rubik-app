import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:puzzle_cube/puzzle_cube.dart';

void main() {
  const size = Size(280, 280);
  const center = Offset(140, 140);
  const scale = 20.0;
  // The example's default cube view.
  const rx = -0.5;
  const ry = 0.6;

  int faceAxis(CubieFace f) =>
      (f == CubieFace.xPos || f == CubieFace.xNeg)
          ? 0
          : (f == CubieFace.yPos || f == CubieFace.yNeg)
              ? 1
              : 2;

  group('cubeDragFor', () {
    test('returns null when the drag starts off the cube', () {
      final drag = cubeDragFor(
        start: const Offset(2, 2),
        delta: const Offset(30, 0),
        size: size,
        scale: scale,
        viewRotationX: rx,
        viewRotationY: ry,
      );
      expect(drag, isNull);
    });

    test('returns null for a non-positive scale', () {
      final drag = cubeDragFor(
        start: center,
        delta: const Offset(30, 0),
        size: size,
        scale: 0,
        viewRotationX: 0,
        viewRotationY: 0,
      );
      expect(drag, isNull);
    });

    test('a centre drag resolves to a valid, well-formed layer turn', () {
      final drag = cubeDragFor(
        start: center,
        delta: const Offset(30, 0),
        size: size,
        scale: scale,
        viewRotationX: rx,
        viewRotationY: ry,
      )!;
      expect(const [0, 1, 2], contains(drag.axis));
      expect(const [-1, 0, 1], contains(drag.layer));
      expect(drag.pixelsPerRadian, greaterThan(0));
      expect((drag.tangent.distance - 1).abs(), lessThan(1e-6)); // unit vector
    });

    test('the rotation axis is never the grabbed face\'s normal', () {
      for (var a = -3.0; a <= 3.0; a += 0.5) {
        final face = cubeFaceAtTap(
          tap: center,
          size: size,
          scale: scale,
          viewRotationX: rx,
          viewRotationY: a,
        );
        if (face == null) continue;
        for (final delta in const [
          Offset(30, 0),
          Offset(0, 30),
          Offset(-30, 0),
          Offset(0, -30),
        ]) {
          final drag = cubeDragFor(
            start: center,
            delta: delta,
            size: size,
            scale: scale,
            viewRotationX: rx,
            viewRotationY: a,
          );
          if (drag == null) continue;
          expect(
            drag.axis,
            isNot(faceAxis(face)),
            reason: 'ry=$a delta=$delta grabbed=$face',
          );
        }
      }
    });

    test('horizontal vs vertical swipes turn different layer axes', () {
      final horizontal = cubeDragFor(
        start: center,
        delta: const Offset(40, 0),
        size: size,
        scale: scale,
        viewRotationX: rx,
        viewRotationY: ry,
      )!;
      final vertical = cubeDragFor(
        start: center,
        delta: const Offset(0, 40),
        size: size,
        scale: scale,
        viewRotationX: rx,
        viewRotationY: ry,
      )!;
      expect(horizontal.axis, isNot(vertical.axis));
    });

    test('drags across the cube silhouette stay well-formed', () {
      for (var x = 90.0; x <= 190; x += 20) {
        for (var y = 90.0; y <= 190; y += 20) {
          final start = Offset(x, y);
          final face = cubeFaceAtTap(
            tap: start,
            size: size,
            scale: scale,
            viewRotationX: rx,
            viewRotationY: ry,
          );
          for (final delta in const [Offset(35, 0), Offset(0, 35)]) {
            final drag = cubeDragFor(
              start: start,
              delta: delta,
              size: size,
              scale: scale,
              viewRotationX: rx,
              viewRotationY: ry,
            );
            if (drag == null) continue;
            expect(const [0, 1, 2], contains(drag.axis));
            expect(const [-1, 0, 1], contains(drag.layer));
            expect(drag.pixelsPerRadian, greaterThan(0));
            if (face != null) {
              expect(
                drag.axis,
                isNot(faceAxis(face)),
                reason: 'start=$start delta=$delta face=$face',
              );
            }
          }
        }
      }
    });
  });
}
