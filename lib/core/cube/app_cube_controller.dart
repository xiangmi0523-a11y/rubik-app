import 'package:puzzle_cube/puzzle_cube.dart';

import 'cube_facelets.dart';

/// [CubeController] whose orbit follows the finger.
///
/// puzzle_cube's `Cube` widget orbits by calling `rotateView` with the raw drag
/// delta, which after DiTreDi's y/z flip turns the cube *against* the finger.
/// Negating both axes here makes dragging feel natural, without forking the
/// package. Use [setView] / [orbit] for programmatic camera moves.
class AppCubeController extends CubeController {
  AppCubeController({
    super.moveDuration,
    super.initialState,
    super.initialViewRotationX = CubeNotation.viewRotationX,
    super.initialViewRotationY = CubeNotation.viewRotationY,
  });

  /// Called by the widget for finger drags: inverted so the cube follows.
  @override
  void rotateView({double dx = 0, double dy = 0}) =>
      super.rotateView(dx: -dx, dy: -dy);

  /// Programmatic orbit in camera angles (not inverted).
  void orbit({double dx = 0, double dy = 0}) =>
      super.rotateView(dx: dx, dy: dy);

  /// Moves the camera to absolute view angles.
  void setView({required double rotationX, required double rotationY}) {
    resetCamera();
    orbit(
      dx: rotationY - initialViewRotationY,
      dy: rotationX - initialViewRotationX,
    );
  }
}
