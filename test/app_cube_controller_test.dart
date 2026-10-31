import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_cube/puzzle_cube.dart';
import 'package:rubik_app/core/cube/app_cube_controller.dart';
import 'package:rubik_app/core/cube/cube_facelets.dart';

void main() {
  test('finger orbit is inverted, programmatic orbit is not', () {
    final c = AppCubeController();
    c.rotateView(dx: 0.1, dy: 0.2);
    expect(c.viewRotationY, closeTo(CubeNotation.viewRotationY - 0.1, 1e-9));
    expect(c.viewRotationX, closeTo(CubeNotation.viewRotationX - 0.2, 1e-9));
    c.setView(rotationX: 0.3, rotationY: 1.5);
    expect(c.viewRotationX, closeTo(0.3, 1e-9));
    expect(c.viewRotationY, closeTo(1.5, 1e-9));
  });

  testWidgets('dragging right turns the front of the cube to the right',
      (tester) async {
    final c = AppCubeController();
    await tester.pumpWidget(MaterialApp(
      home: SizedBox(width: 400, height: 400, child: Cube(controller: c)),
    ));
    final before = c.viewRotationY;
    // Start off the cube (corner) so the drag orbits instead of turning.
    await tester.dragFrom(const Offset(5, 5), const Offset(100, 0));
    await tester.pumpAndSettle();
    // With the y/z-flipped projection, a decreasing rotationY moves the
    // visible front face towards screen-right.
    expect(c.viewRotationY, lessThan(before));
  });
}
