/// An interactive 3D twisty-puzzle cube for Flutter: a pure-Dart 3x3 model with
/// layer turns, scrambling, validation and solved-state detection, plus a
/// gesture-driven [Cube] widget (orbit, tap-to-select and drag-to-turn) built
/// on the `ditredi` renderer.
library;

export 'src/models/cube_color_validator.dart';
export 'src/models/cube_colors.dart';
export 'src/models/cube_move.dart';
export 'src/models/cubie_model.dart';
export 'src/models/puzzle_cube_state.dart';
export 'src/rendering/cube_hit_test.dart';
export 'src/rendering/cubie_builder.dart';
export 'src/rendering/realistic_cube_renderer.dart';
export 'src/widgets/cube_controller.dart'
    show Cube, CubeController, cubeViewScale;
