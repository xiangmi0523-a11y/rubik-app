import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/app.dart';
import 'package:rubik_app/core/prefs/shared_prefs_provider.dart';
import 'package:rubik_app/features/free_play/application/free_play_controller.dart';
import 'package:rubik_app/features/stats/application/stats_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('tabs render and scramble arms timer', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const RubikApp(),
    ));
    expect(find.text('自由玩'), findsWidgets);

    await tester.tap(find.text('打乱'));
    await tester.pump();
    final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first));
    expect(container.read(freePlayControllerProvider).status, TimerStatus.ready);

    // Manual start/stop records a solve.
    container.read(freePlayControllerProvider.notifier).toggleManual();
    container.read(freePlayControllerProvider.notifier).toggleManual();
    expect(container.read(statsControllerProvider).length, 1);

    await tester.tap(find.text('填色求解').last);
    await tester.pumpAndSettle();
    // First visit shows the hand-hold guide.
    expect(find.text('我知道了'), findsOneWidget);
    await tester.tap(find.text('我知道了'));
    await tester.pumpAndSettle();
    expect(find.text('开始求解'), findsOneWidget);

    await tester.tap(find.text('成绩').last);
    await tester.pumpAndSettle();
    expect(find.text('当前 ao5'), findsOneWidget);
  });
}
