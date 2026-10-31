import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_cube/puzzle_cube.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;
import 'package:rubik_app/core/nxn/nxn_cube_controller.dart';
import 'package:rubik_app/core/nxn/nxn_cube_state.dart';
import 'package:rubik_app/core/nxn/nxn_cube_view.dart';
import 'package:rubik_app/core/nxn/nxn_projection.dart';

const _size = Size(360, 360);

Future<NxnMove?> _drag(
  WidgetTester t,
  NxnCubeController c,
  Offset from,
  Offset by,
) async {
  NxnMove? moved;
  await t.pumpWidget(MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(
        size: _size,
        child: NxnCubeView(controller: c, onMove: (m) => moved = m),
      ),
    ),
  ));
  await t.dragFrom(from, by);
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 30));
  }
  return moved;
}

Offset _sticker(NxnCubeController c, IVec pos, IVec normal) {
  final proj = NxnProjection(
      size: _size, n: c.n, rotationX: c.rotationX, rotationY: c.rotationY);
  return proj.project(
      NxnProjection.cubieCenter(pos) + NxnProjection.vec(normal) * 0.5);
}

void main() {
  for (final rotY in [-0.35, -0.6, -0.9]) {
    testWidgets('4x4: drag down on the right face turns that column '
        '(rotationY $rotY)', (t) async {
      for (final z in [-3, -1, 1, 3]) {
        final c = NxnCubeController(4)..orbit(dx: rotY - NxnCubeController.initialRotationY);
        final p = _sticker(c, (3, 1, z), (1, 0, 0));
        final move = await _drag(t, c, p, const Offset(0, 130));
        expect(move, isNotNull, reason: 'z=$z');
        expect(move!.axis, 2, reason: 'should turn about z, not the top; z=$z');
        expect(move.layer, z);
      }
    });
  }

  testWidgets('4x4: horizontal drag on the front face turns a row',
      (t) async {
    final c = NxnCubeController(4);
    final move = await _drag(t, c, _sticker(c, (-1, 1, 3), (0, 0, 1)),
        const Offset(130, 0));
    expect(move!.axis, 1);
    expect(move.layer, 1);
  });

  testWidgets('5x5: grabbing just outside the cube edge still turns a layer',
      (t) async {
    final c = NxnCubeController(5);
    final proj = NxnProjection(
        size: _size, n: 5, rotationX: c.rotationX, rotationY: c.rotationY);
    // Outer-left edge of the front face's left column, nudged 8px outward.
    final edge = proj.project(Vector3Like.leftEdge());
    final move = await _drag(t, c, edge - const Offset(8, 0),
        const Offset(0, 130));
    expect(move, isNotNull);
    expect(move!.axis, 0); // vertical drag on the left column turns about x
    expect(move.layer, -4);
  });

  testWidgets('starting far from the cube still orbits', (t) async {
    final c = NxnCubeController(4);
    final before = c.rotationY;
    final move = await _drag(t, c, const Offset(4, 4), const Offset(60, 0));
    expect(move, isNull);
    expect(c.rotationY, greaterThan(before));
  });

  test('3x3 (puzzle_cube): drag down on the steep right face turns a column',
      () {
    const size = Size(360, 360);
    final scale = cubeViewScale(size);
    for (final rotY in [0.35, 0.6, 0.9]) {
      // Base camera of puzzle_cube shows +x on the right with rotY > 0.
      for (final cq in [-1, 1]) {
        Offset? grab;
        // Find the screen point of the +x face cell (y=0, z=cq) centre.
        final full = Matrix4.identity()
          ..setEntry(3, 2, -0.001)
          ..scaleByDouble(scale, -scale, -scale, 1);
        final view = Matrix4.identity()
          ..rotateX(-0.5)
          ..rotateY(rotY);
        final m = full.multiplied(view);
        final v = m.perspectiveTransform(
            Vector3(kCubeHalfExtent, 0, cq * kCubeSpacing));
        grab = Offset(size.width / 2 + v.x, size.height / 2 + v.y);
        final drag = cubeDragFor(
          start: grab,
          delta: const Offset(0, 60),
          size: size,
          scale: scale,
          viewRotationX: -0.5,
          viewRotationY: rotY,
        );
        expect(drag, isNotNull);
        expect(drag!.axis, 2, reason: 'rotY=$rotY cq=$cq');
        expect(drag.layer, cq);
      }
    }
  });
}

/// Helper for the 5x5 edge test: the left edge of the front-left sticker.
abstract final class Vector3Like {
  static Vector3 leftEdge() => Vector3(-2.5, 0, 2.5);
}
