import 'package:flutter/material.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

import '../../../../core/cube/app_cube_controller.dart';
import '../../../../core/cube/sticker_hit_test.dart';

/// puzzle_cube's 3D cube where a tap reports the exact sticker (facelet index
/// in cuber order) and a drag orbits the view.
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
          // No onMove / onFaceTap: drags orbit the view, taps come to us.
          child: Cube(controller: controller),
        );
      },
    );
  }
}
