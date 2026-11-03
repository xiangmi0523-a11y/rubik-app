import 'package:flutter/material.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

import '../../../../core/cube/app_cube_controller.dart';
import '../../../../core/cube/sticker_hit_test.dart';

/// puzzle_cube's 3D cube where a tap reports the exact sticker (facelet index
/// in cuber order). Dragging does nothing: the colouring page moves the
/// camera itself, in fixed steps, so a swipe can't rotate the cube or turn a
/// layer under the finger.
class StickerPaintCube extends StatelessWidget {
  const StickerPaintCube({
    super.key,
    required this.controller,
    required this.onFaceletTap,
  });

  final AppCubeController controller;
  final ValueChanged<int> onFaceletTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final index = StickerHitTest.faceletAt(
              tap: details.localPosition,
              size: size,
              viewRotationX: controller.viewRotationX,
              viewRotationY: controller.viewRotationY,
            );
            if (index != null) onFaceletTap(index);
          },
          // Display-only cube: its own drag-to-orbit is off, taps come to us.
          child: Cube(controller: controller, enableGestures: false),
        );
      },
    );
  }
}
