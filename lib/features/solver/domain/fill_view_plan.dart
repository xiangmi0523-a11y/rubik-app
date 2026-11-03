import 'dart:math' as math;

import '../../../core/cube/cube_facelets.dart';
import '../../../core/nxn/nxn_cube_controller.dart';
import '../../../core/pyraminx/pyraminx_controller.dart';
import '../../puzzles/domain/puzzle_type.dart';

/// One fixed camera position of the colouring page.
class FillViewStop {
  const FillViewStop(this.rotationX, this.rotationY);

  /// Camera angles in the puzzle's own camera convention (the values its
  /// controller's `setView` takes).
  final double rotationX;
  final double rotationY;
}

/// The fixed order in which the colouring page shows a puzzle.
///
/// The user no longer orbits the model by hand. Instead the camera steps
/// through [stops]:
///
/// * the first stop is the controller's default camera (top + two side
///   faces), unchanged;
/// * the following stops turn the puzzle about the vertical axis by one
///   [sideStep] each, so every side face becomes the main face once while
///   the composition stays exactly that of the default view;
/// * the last stop looks at the puzzle from below: the bottom face, which is
///   therefore always filled last.
///
/// Only the camera moves; the puzzle's stickers are untouched.
class FillViewPlan {
  const FillViewPlan._({
    required this.stops,
    required this.backIndex,
    required this.sideStep,
  });

  /// Side views: [sideCount] stops [step] radians of yaw apart, starting at
  /// ([pitch], [yaw]); then the bottom view at [bottomPitch], which is the
  /// next side view tipped under the puzzle and turned [extraYaw] further.
  factory FillViewPlan._build({
    required double pitch,
    required double yaw,
    required double step,
    required int sideCount,
    required double bottomPitch,
    required int backIndex,
    double extraYaw = 0.4,
  }) {
    return FillViewPlan._(
      stops: [
        for (var k = 0; k < sideCount; k++) FillViewStop(pitch, yaw + k * step),
        FillViewStop(
          bottomPitch,
          yaw + sideCount * step + step.sign * extraYaw,
        ),
      ],
      backIndex: backIndex,
      sideStep: step,
    );
  }

  /// 3×3 (puzzle_cube camera: white up, green front, red right). Turning the
  /// view by +90° brings the right face to the front.
  static final FillViewPlan cube3 = FillViewPlan._build(
    pitch: CubeNotation.viewRotationX,
    yaw: CubeNotation.viewRotationY,
    step: math.pi / 2,
    sideCount: 4,
    bottomPitch: -2.2 * CubeNotation.viewRotationX,
    backIndex: 2,
  );

  /// 2×2 / 4×4 / 5×5 (own engine; its camera turns the other way, so −90°
  /// brings the right face to the front).
  static final FillViewPlan nxn = FillViewPlan._build(
    pitch: NxnCubeController.initialRotationX,
    yaw: NxnCubeController.initialRotationY,
    step: -math.pi / 2,
    sideCount: 4,
    bottomPitch: -2.2 * NxnCubeController.initialRotationX,
    backIndex: 2,
  );

  /// Pyraminx: three side faces, 120° apart, then the bottom face seen almost
  /// face-on (a plain flip: same yaw as the default view, no extra turn).
  static final FillViewPlan pyraminx = FillViewPlan._build(
    pitch: PyraminxController.initialRotationX,
    yaw: PyraminxController.initialRotationY,
    step: -2 * math.pi / 3,
    sideCount: 3,
    bottomPitch: -1.1,
    backIndex: 2,
    extraYaw: 0,
  );

  static FillViewPlan of(PuzzleType type) => switch (type) {
        PuzzleType.cube3 => cube3,
        PuzzleType.pyraminx => pyraminx,
        _ => nxn,
      };

  final List<FillViewStop> stops;

  /// The stop the 「背面」 shortcut jumps to: the side view whose main face is
  /// opposite to the default one (for the Pyraminx, the side that is hidden
  /// by default).
  final int backIndex;

  /// Yaw between two consecutive side views (signed, radians).
  final double sideStep;

  /// The default view, shown on entering the page; 「正面」 returns to it.
  int get frontIndex => 0;

  int get lastIndex => stops.length - 1;

  /// Index of the stop closest to a camera at ([rotationX], [rotationY]).
  /// Yaw is compared modulo a full turn.
  int nearestIndex(double rotationX, double rotationY) {
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < stops.length; i++) {
      final dx = stops[i].rotationX - rotationX;
      final dy = wrapAngle(stops[i].rotationY - rotationY);
      final d = dx * dx + dy * dy;
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return best;
  }

  /// Whether the camera sits exactly on a stop (not mid-animation).
  bool isOnStop(double rotationX, double rotationY, {double tolerance = 1e-6}) {
    final s = stops[nearestIndex(rotationX, rotationY)];
    return (s.rotationX - rotationX).abs() < tolerance &&
        wrapAngle(s.rotationY - rotationY).abs() < tolerance;
  }

  /// The yaw to animate to so that a camera at [current] reaches stop
  /// [index] by the shortest way round (the result is equivalent to the
  /// stop's own yaw, modulo a full turn).
  double yawToward(int index, double current) =>
      current + wrapAngle(stops[index].rotationY - current);

  /// Largest angle the camera has to travel to get from ([rotationX],
  /// [rotationY]) to stop [index].
  double travel(int index, double rotationX, double rotationY) => math.max(
        (stops[index].rotationX - rotationX).abs(),
        wrapAngle(stops[index].rotationY - rotationY).abs(),
      );
}

/// [angle] wrapped into [-π, π].
double wrapAngle(double angle) {
  const full = 2 * math.pi;
  return angle - full * (angle / full).roundToDouble();
}
