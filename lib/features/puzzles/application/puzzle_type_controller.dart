import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nxn/nxn_cube_controller.dart';
import '../../../core/pyraminx/pyraminx_controller.dart';
import '../../../core/prefs/shared_prefs_provider.dart';
import '../domain/puzzle_type.dart';

/// The puzzle selected on the free-play tab (persisted).
class PuzzleTypeController extends Notifier<PuzzleType> {
  static const _key = 'puzzle_type_v1';

  @override
  PuzzleType build() =>
      PuzzleType.fromId(ref.watch(sharedPreferencesProvider).getString(_key));

  void select(PuzzleType type) {
    if (type == state) return;
    state = type;
    ref.read(sharedPreferencesProvider).setString(_key, type.id);
  }
}

final puzzleTypeProvider =
    NotifierProvider<PuzzleTypeController, PuzzleType>(PuzzleTypeController.new);

/// One N×N cube per order, kept alive so switching puzzles keeps their state.
final nxnCubeProvider = Provider.family<NxnCubeController, int>((ref, n) {
  final controller = NxnCubeController(n);
  ref.onDispose(controller.dispose);
  return controller;
});

/// The free-play Pyraminx.
final pyraminxProvider = Provider<PyraminxController>((ref) {
  final controller = PyraminxController();
  ref.onDispose(controller.dispose);
  return controller;
});
