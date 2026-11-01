import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/app.dart';
import 'package:rubik_app/core/nxn/nxn_cube_state.dart';
import 'package:rubik_app/core/prefs/shared_prefs_provider.dart';
import 'package:rubik_app/core/ui/app_background.dart';
import 'package:rubik_app/features/free_play/application/free_play_controller.dart';
import 'package:rubik_app/features/patterns/domain/cube_pattern.dart';
import 'package:rubik_app/features/patterns/presentation/pattern_picker_sheet.dart';
import 'package:rubik_app/features/player/presentation/player_page.dart';
import 'package:rubik_app/features/puzzles/application/puzzle_type_controller.dart';
import 'package:rubik_app/features/puzzles/domain/puzzle_type.dart';
import 'package:rubik_app/features/solver/application/puzzle_color_input.dart';
import 'package:rubik_app/features/stats/application/stats_controller.dart';
import 'package:rubik_app/features/stats/domain/solve_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// iPhone screens, portrait (logical points): SE, mini, standard, Plus/Max.
const _phones = {
  'SE 320': Size(320, 568),
  'SE 375': Size(375, 667),
  'standard': Size(390, 844),
  'Max': Size(430, 932),
};

Future<ProviderContainer> _open(WidgetTester tester, Size size, double text,
    {bool inspection = false}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(
      {'hold_guide_seen_v1': true, 'inspection_enabled_v1': inspection});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MediaQuery(
      data: MediaQueryData(
          size: size, devicePixelRatio: 3, textScaler: TextScaler.linear(text)),
      child: const RubikApp(),
    ),
  ));
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
}

/// Two frames: routes and sheets start animating on the frame after the tap.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 700));
}

SolveRecord _record(int id, int ms, PuzzleType puzzle, {String scramble = ''}) =>
    SolveRecord(
      id: id,
      durationMs: ms,
      createdAt: DateTime(2026, 11, 1, 12, id % 60),
      scramble: scramble,
      puzzle: puzzle.id,
      penalty: Penalty.none,
    );

void main() {
  for (final e in _phones.entries) {
    for (final text in [1.0, 1.5]) {
      testWidgets('no overflow or errors: ${e.key}, text ×$text', (tester) async {
        final c = await _open(tester, e.value, text);
        final rng = math.Random(3);

        // Free play with a long 5x5 scramble, then a recorded solve.
        for (final t in [PuzzleType.cube3, PuzzleType.cube5, PuzzleType.pyraminx]) {
          c.read(puzzleTypeProvider.notifier).select(t);
          await _settle(tester);
          c.read(freePlayControllerProvider.notifier).scramble();
          await _settle(tester);
        }
        for (var i = 0; i < 30; i++) {
          c.read(statsControllerProvider.notifier).restore(_record(
              i, 8000 + rng.nextInt(9000), PuzzleType.pyraminx,
              scramble: "R U R' U' " * 6));
        }
        c.read(puzzleTypeProvider.notifier).select(PuzzleType.pyraminx);

        // Pattern list sheet.
        await tester.tap(find.text('花式'));
        await _settle(tester);
        expect(find.textContaining('花式'), findsWidgets);
        await tester.tapAt(const Offset(5, 40));
        await _settle(tester);

        // Colouring tab: every puzzle, and the hold guide.
        await tester.tap(find.text('填色求解').last);
        await _settle(tester);
        for (final t in PuzzleType.values) {
          await tester.tap(find.text(t.label).last);
          await _settle(tester);
        }
        await tester.tap(find.byIcon(Icons.help_outline));
        await _settle(tester);
        expect(find.text('手持姿势'), findsOneWidget);
        await tester.tap(find.text('我知道了'));
        await _settle(tester);

        // Stats tab with data.
        await tester.tap(find.text('成绩').last);
        await _settle(tester);
        // Large text can fill the screen with the summary: scroll to rows.
        for (var i = 0;
            i < 20 && find.byType(ListTile).evaluate().isEmpty;
            i++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -150));
          await tester.pump();
        }
        expect(find.byType(ListTile), findsWidgets);

        // Player (4x4 solution with phases) and a pattern demo.
        final start = NxnCubeState.solved(4)
          ..applyAll(NxnCubeState.randomScramble(4, rng: math.Random(5)));
        final solved = (await tester.runAsync(() => solveBigCube(start)))!
            as PuzzleSolveOk;
        final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
        nav.push(MaterialPageRoute(
            builder: (_) => PlayerPage(script: solved.script)));
        await _settle(tester);
        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pump(const Duration(seconds: 2));
        await tester.tap(find.byIcon(Icons.pause));
        await _settle(tester);
        nav.pop();
        await _settle(tester);
        openPatternDemo(tester.element(find.byType(Scaffold).first),
            patternsFor(PuzzleType.cube5).first);
        await _settle(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('every page sits on the shared background', (tester) async {
    final c = await _open(tester, _phones['standard']!, 1);
    expect(find.byType(AppBackground), findsOneWidget);
    await tester.tap(find.text('填色求解').last);
    await _settle(tester);
    await tester.tap(find.text('成绩').last);
    await _settle(tester);
    // free play, colouring and stats each have one (IndexedStack keeps all).
    expect(find.byType(AppBackground, skipOffstage: false), findsNWidgets(3));
    expect(c, isNotNull);
  });

  group('stats page', () {
    testWidgets('empty state', (tester) async {
      await _open(tester, _phones['standard']!, 1);
      await tester.tap(find.text('成绩').last);
      await _settle(tester);
      expect(find.textContaining('还没有三阶成绩'), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    });

    testWidgets('summary tiles are three equal columns', (tester) async {
      await _open(tester, _phones['standard']!, 1);
      await tester.tap(find.text('成绩').last);
      await _settle(tester);
      final widths = {
        for (final label in ['次数', '最佳', '平均', '当前 ao5', '最佳 ao12'])
          tester.getSize(find.ancestor(
                  of: find.text(label), matching: find.byType(Container)).first).width,
      };
      expect(widths, hasLength(1));
      expect(widths.single, closeTo((390 - 24 - 16) / 3, 0.5));
    });

    testWidgets('deleting a solve (swipe or sheet) can be undone',
        (tester) async {
      final c = await _open(tester, _phones['standard']!, 1);
      final stats = c.read(statsControllerProvider.notifier);
      for (var i = 0; i < 3; i++) {
        stats.restore(_record(i + 1, 10000 + i * 1000, PuzzleType.cube3));
      }
      final before = c.read(statsControllerProvider).map((r) => r.id).toList();
      await tester.tap(find.text('成绩').last);
      await tester.pumpAndSettle();

      // Swipe the newest away, then undo.
      await tester.drag(find.byType(ListTile).first, const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(c.read(statsControllerProvider), hasLength(2));
      expect(find.textContaining('已删除成绩'), findsOneWidget);
      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();
      expect(c.read(statsControllerProvider).map((r) => r.id).toList(), before);

      // Delete from the edit sheet, undo again; order is kept.
      await tester.tap(find.byType(ListTile).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除这条成绩'));
      await tester.pumpAndSettle();
      expect(c.read(statsControllerProvider), hasLength(2));
      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();
      expect(c.read(statsControllerProvider).map((r) => r.id).toList(), before);
      // Undoing twice does not duplicate.
      final record = c.read(statsControllerProvider).first;
      stats.restore(record);
      expect(c.read(statsControllerProvider), hasLength(3));
    });
  });

  testWidgets('a long scramble scrolls instead of squeezing the puzzle',
      (tester) async {
    final c = await _open(tester, _phones['SE 375']!, 1);
    c.read(puzzleTypeProvider.notifier).select(PuzzleType.cube5);
    await tester.pumpAndSettle();
    c.read(freePlayControllerProvider.notifier).scramble();
    await tester.pumpAndSettle();
    final scramble = find.byType(SelectableText);
    expect(scramble, findsOneWidget);
    expect(tester.getSize(find.ancestor(
            of: scramble, matching: find.byType(ConstrainedBox)).first).height,
        lessThanOrEqualTo(62));
  });
}
