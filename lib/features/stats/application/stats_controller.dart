import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/stats_repository.dart';
import '../domain/averages.dart';
import '../domain/solve_record.dart';

/// All solves, oldest -> newest.
class StatsController extends Notifier<List<SolveRecord>> {
  @override
  List<SolveRecord> build() => ref.watch(statsRepositoryProvider).load();

  void add(Duration duration, {String scramble = ''}) {
    final now = DateTime.now();
    state = [
      ...state,
      SolveRecord(
        id: now.microsecondsSinceEpoch,
        durationMs: duration.inMilliseconds,
        createdAt: now,
        scramble: scramble,
      ),
    ];
    _persist();
  }

  void remove(int id) {
    state = state.where((r) => r.id != id).toList();
    _persist();
  }

  void clear() {
    state = [];
    _persist();
  }

  void _persist() => ref.read(statsRepositoryProvider).save(state);
}

final statsControllerProvider =
    NotifierProvider<StatsController, List<SolveRecord>>(StatsController.new);

final statsSummaryProvider = Provider<StatsSummary>((ref) {
  final records = ref.watch(statsControllerProvider);
  return StatsSummary.from(records.map((r) => r.durationMs).toList());
});
