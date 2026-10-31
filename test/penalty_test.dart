import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/core/prefs/shared_prefs_provider.dart';
import 'package:rubik_app/core/utils/time_format.dart';
import 'package:rubik_app/features/free_play/application/free_play_controller.dart';
import 'package:rubik_app/features/free_play/application/inspection_setting.dart';
import 'package:rubik_app/features/stats/application/stats_controller.dart';
import 'package:rubik_app/features/stats/domain/averages.dart';
import 'package:rubik_app/features/stats/domain/solve_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('inspection penalty boundaries (WCA)', () {
    expect(inspectionPenalty(const Duration(seconds: 15)), Penalty.none);
    expect(inspectionPenalty(const Duration(milliseconds: 15001)),
        Penalty.plus2);
    expect(inspectionPenalty(const Duration(seconds: 17)), Penalty.plus2);
    expect(inspectionPenalty(const Duration(milliseconds: 17001)), Penalty.dnf);
  });

  test('one DNF is dropped as the worst; two make the ao5 DNF', () {
    expect(averageOf([10000, 11000, 12000, 13000, kDnf]), 12000);
    expect(averageOf([10000, 11000, 12000, kDnf, kDnf]), kDnf);
    expect(formatMs(kDnf), 'DNF');
  });

  test('+2 counts in the time; DNF excluded from best and mean', () {
    final times = [
      SolveRecord(id: 1, durationMs: 10000, createdAt: _t, penalty: Penalty.plus2),
      SolveRecord(id: 2, durationMs: 9000, createdAt: _t, penalty: Penalty.dnf),
      SolveRecord(id: 3, durationMs: 11000, createdAt: _t),
    ].map((r) => r.effectiveMs).toList();
    final s = StatsSummary.from(times);
    expect(s.best, 11000);
    expect(s.mean, 11500);
    expect(s.count, 3);
  });

  test('old records without a penalty load as no penalty', () {
    final r = SolveRecord.fromJson(
        {'id': 1, 'durationMs': 1000, 'createdAt': 0, 'scramble': ''});
    expect(r.penalty, Penalty.none);
    final back = SolveRecord.fromJson(r.copyWith(penalty: Penalty.dnf).toJson());
    expect(back.penalty, Penalty.dnf);
  });

  test('changing the last solve to +2 updates the stats', () async {
    final c = await _container();
    final n = c.read(freePlayControllerProvider.notifier);
    n.scramble();
    expect(c.read(freePlayControllerProvider).status, TimerStatus.inspecting);
    n.toggleManual(); // start (within inspection: no penalty)
    expect(c.read(freePlayControllerProvider).penalty, Penalty.none);
    n.toggleManual(); // stop
    n.setLastPenalty(Penalty.plus2);
    final r = c.read(statsControllerProvider).single;
    expect(r.penalty, Penalty.plus2);
    expect(r.effectiveMs, r.durationMs + 2000);
    n.setLastPenalty(Penalty.dnf);
    expect(c.read(statsSummaryProvider).best, isNull);
  });

  test('inspection can be turned off (and is remembered)', () async {
    final c = await _container();
    c.read(inspectionEnabledProvider.notifier).toggle();
    c.read(freePlayControllerProvider.notifier).scramble();
    expect(c.read(freePlayControllerProvider).status, TimerStatus.ready);
    expect(
        c.read(sharedPreferencesProvider).getBool('inspection_enabled_v1'),
        isFalse);
  });
}

final _t = DateTime(2026);
