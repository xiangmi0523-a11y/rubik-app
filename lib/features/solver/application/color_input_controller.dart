import 'package:cuber/cuber.dart' as cuber;
import '../../../core/cube/app_cube_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

import '../../../core/cube/cube_facelets.dart';
import '../domain/cube_input_validator.dart';

class ColorInputState {
  const ColorInputState({required this.colors, required this.selected});

  /// 54 colours in cuber facelet order (U R F D L B).
  final List<Color> colors;

  /// The colour that a tap paints.
  final Color selected;

  /// How many more stickers of [color] can still be painted (9 per colour,
  /// centres included).
  int remaining(Color color) =>
      9 - colors.where((c) => c.toARGB32() == color.toARGB32()).length;

  int get blankCount => colors.where(CubeInputValidator.isBlank).length;

  bool get isComplete => blankCount == 0;

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

  /// Selects a colour; colours already used 9 times can't be selected.
  void select(Color color) {
    if (state.remaining(color) <= 0) return;
    state = state.copyWith(selected: color);
  }

  /// Paints facelet [index] with the selected colour. Tapping a sticker that
  /// already has that colour erases it. Returns whether anything changed.
  bool paint(int index) {
    if (index % 9 == 4) return false; // centres are fixed
    final colors = [...state.colors];
    final current = colors[index];
    final selected = state.selected;

    if (current.toARGB32() == selected.toARGB32()) {
      colors[index] = CubeColors.colorless;
    } else {
      if (state.remaining(selected) <= 0) return false;
      colors[index] = selected;
    }

    var next = state.copyWith(colors: colors);
    // Selected colour used up -> jump to the next colour still available.
    if (next.remaining(selected) <= 0) {
      final available =
          CubeColors.palette.where((c) => next.remaining(c) > 0).toList();
      if (available.isNotEmpty) {
        final start = CubeColors.palette.indexOf(selected);
        final ordered = [
          ...CubeColors.palette.skip(start + 1),
          ...CubeColors.palette.take(start + 1),
        ];
        next = next.copyWith(
          selected: ordered.firstWhere((c) => next.remaining(c) > 0),
        );
      }
    }
    state = next;
    return true;
  }

  void clear() => state = ColorInputState(
        colors: CubeFacelets.read(PuzzleCubeState.colorless()),
        selected: CubeColors.white,
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

/// The 3D cube the user paints on; mirrors [colorInputProvider].
final colorInputCubeProvider = Provider<AppCubeController>((ref) {
  final controller = AppCubeController(
    initialState: CubeFacelets.build(ref.read(colorInputProvider).colors),
  );
  ref.listen<List<Color>>(
    colorInputProvider.select((s) => s.colors),
    (_, next) => controller.replaceState(CubeFacelets.build(next)),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
