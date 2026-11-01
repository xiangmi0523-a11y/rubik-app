import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../puzzles/application/puzzle_type_controller.dart';
import '../../puzzles/domain/puzzle_type.dart';
import '../data/stats_repository.dart';
import '../domain/averages.dart';
import '../domain/solve_record.dart';

/// All solves of every puzzle, oldest -> newest.
class StatsController extends Notifier<List<SolveRecord>> {
  @override
  List<SolveRecord> build() => ref.watch(statsRepositoryProvider).load();

  /// Records a solve and returns its id.
  int add(
    Duration duration, {
    String scramble = '',
    PuzzleType puzzle = PuzzleType.cube3,
    Penalty penalty = Penalty.none,
  }) {
    final now = DateTime.now();
    state = [
      ...state,
      SolveRecord(
        id: now.microsecondsSinceEpoch,
        durationMs: duration.inMilliseconds,
        createdAt: now,
        scramble: scramble,
        puzzle: puzzle.id,
        penalty: penalty,
      ),
    ];
    _persist();
    return state.last.id;
  }

  void setPenalty(int id, Penalty penalty) {
    state = [
      for (final r in state) r.id == id ? r.copyWith(penalty: penalty) : r,
    ];
    _persist();
  }

  void remove(int id) {
    state = state.where((r) => r.id != id).toList();
    _persist();
  }

  /// Puts a removed solve back (undo), in its original place by id.
  void restore(SolveRecord record) {
    if (state.any((r) => r.id == record.id)) return;
    state = [...state, record]..sort((a, b) => a.id.compareTo(b.id));
    _persist();
  }

  /// Clears the solves of one puzzle.
  void clear(PuzzleType puzzle) {
    state = state.where((r) => r.puzzle != puzzle.id).toList();
    _persist();
  }

  void _persist() => ref.read(statsRepositoryProvider).save(state);
}

final statsControllerProvider =
    NotifierProvider<StatsController, List<SolveRecord>>(StatsController.new);

/// Puzzle shown on the stats tab; follows the free-play selection until the
/// user picks another one there.
class StatsFilterController extends Notifier<PuzzleType> {
  @override
  PuzzleType build() => ref.watch(puzzleTypeProvider);

  void select(PuzzleType type) => state = type;
}

final statsFilterProvider =
    NotifierProvider<StatsFilterController, PuzzleType>(
  StatsFilterController.new,
);

/// Solves of the filtered puzzle, oldest -> newest.
final filteredRecordsProvider = Provider<List<SolveRecord>>((ref) {
  final puzzle = ref.watch(statsFilterProvider);
  return ref
      .watch(statsControllerProvider)
      .where((r) => r.puzzle == puzzle.id)
      .toList();
});

final statsSummaryProvider = Provider<StatsSummary>((ref) {
  final records = ref.watch(filteredRecordsProvider);
  return StatsSummary.from(records.map((r) => r.effectiveMs).toList());
});
