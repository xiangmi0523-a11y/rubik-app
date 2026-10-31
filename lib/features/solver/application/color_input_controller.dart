import 'package:cuber/cuber.dart' as cuber;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

import '../../../core/cube/cube_facelets.dart';

class ColorInputState {
  const ColorInputState({required this.colors, required this.selected});

  /// 54 colours in cuber facelet order (U R F D L B).
  final List<Color> colors;
  final Color selected;

  ColorInputState copyWith({List<Color>? colors, Color? selected}) =>
      ColorInputState(
        colors: colors ?? this.colors,
        selected: selected ?? this.selected,
      );
}

class ColorInputController extends Notifier<ColorInputState> {
  @override
  ColorInputState build() => ColorInputState(
        colors: CubeFacelets.read(PuzzleCubeState.colorless()),
        selected: CubeColors.white,
      );

  void select(Color color) => state = state.copyWith(selected: color);

  void paint(int index) {
    if (index % 9 == 4) return; // centres are fixed
    final colors = [...state.colors];
    colors[index] = state.selected;
    state = state.copyWith(colors: colors);
  }

  void clear() => state = state.copyWith(
        colors: CubeFacelets.read(PuzzleCubeState.colorless()),
      );

  /// Fills a random scrambled cube (demo / testing).
  void randomExample() {
    final cube = PuzzleCubeState.solved();
    for (final m in cuber.Algorithm.scramble(n: 20).moves) {
      CubeNotation.toQuarterTurns(m).forEach(cube.applyMove);
    }
    state = state.copyWith(colors: CubeFacelets.read(cube));
  }
}

final colorInputProvider =
    NotifierProvider<ColorInputController, ColorInputState>(
  ColorInputController.new,
);

/// 3D preview that mirrors the 2D net.
final colorPreviewCubeProvider = Provider<CubeController>((ref) {
  final controller = CubeController(
    initialState: CubeFacelets.build(ref.read(colorInputProvider).colors),
    initialViewRotationX: CubeNotation.viewRotationX,
    initialViewRotationY: CubeNotation.viewRotationY,
  );
  ref.listen<List<Color>>(
    colorInputProvider.select((s) => s.colors),
    (_, next) => controller.replaceState(CubeFacelets.build(next)),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
