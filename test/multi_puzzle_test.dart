import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/app.dart';
import 'package:rubik_app/core/nxn/nxn_cube_state.dart';
import 'package:rubik_app/core/nxn/nxn_cube_view.dart';
import 'package:rubik_app/core/nxn/nxn_projection.dart';
import 'package:rubik_app/core/prefs/shared_prefs_provider.dart';
import 'package:rubik_app/features/free_play/application/free_play_controller.dart';
import 'package:rubik_app/features/puzzles/application/puzzle_type_controller.dart';
import 'package:rubik_app/features/puzzles/domain/puzzle_type.dart';
import 'package:rubik_app/core/pyraminx/pyraminx_solver.dart';
import 'package:rubik_app/core/pyraminx/pyraminx_view.dart';
import 'package:rubik_app/features/pyraminx/domain/pyraminx_scramble.dart';
import 'package:rubik_app/features/stats/application/stats_controller.dart';
import 'package:rubik_app/features/stats/domain/solve_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _app(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'hold_guide_seen_v1': true});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const RubikApp(),
  ));
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
}

void main() {
  testWidgets('4x4: finger turn starts timer, solving stops and records it',
      (tester) async {
    final c = await _app(tester);
    await tester.tap(find.text('四阶'));
    await tester.pumpAndSettle();
    expect(find.byType(NxnCubeView), findsOneWidget);
    expect(find.text('花式'), findsOneWidget); // every puzzle has patterns

    await tester.tap(find.text('打乱'));
    await tester.pump();
    expect(c.read(freePlayControllerProvider).status, TimerStatus.ready);

    // Real drag on a front sticker turns a layer and starts the timer.
    final cube = c.read(nxnCubeProvider(4));
    final view = find.byType(NxnCubeView);
    final proj = NxnProjection(
      size: tester.getSize(view),
      n: 4,
      rotationX: cube.rotationX,
      rotationY: cube.rotationY,
    );
    final p = proj.project(NxnProjection.cubieCenter((-1, 1, 3)) +
        NxnProjection.vec((0, 0, 1)) * 0.5);
    await tester.dragFrom(tester.getTopLeft(view) + p, const Offset(80, 0));
    // The running timer repaints every frame, so pump fixed time, not settle.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(c.read(freePlayControllerProvider).status, TimerStatus.running);

    // Put the cube one move from solved, then make that move.
    cube.reset();
    cube.apply(const NxnMove(1, 3, 1));
    c.read(freePlayControllerProvider.notifier).onCubeMove();
    cube.apply(const NxnMove(1, 3, -1));
    c.read(freePlayControllerProvider.notifier).onCubeMove();
    expect(c.read(freePlayControllerProvider).status, TimerStatus.stopped);

    final records = c.read(statsControllerProvider);
    expect(records.single.puzzle, 'cube4');

    // Stats tab follows the selected puzzle; 3x3 shows nothing.
    await tester.tap(find.text('成绩').last);
    await tester.pumpAndSettle();
    expect(c.read(filteredRecordsProvider), hasLength(1));
    c.read(statsFilterProvider.notifier).select(PuzzleType.cube3);
    expect(c.read(filteredRecordsProvider), isEmpty);
  });

  testWidgets('pyraminx: 3D puzzle, scramble, solve detection and timing',
      (tester) async {
    final c = await _app(tester);
    await tester.tap(find.text('金字塔'));
    await tester.pumpAndSettle();
    expect(find.byType(PyraminxView), findsOneWidget);
    await tester.tap(find.text('打乱'));
    await tester.pump();
    final puzzle = c.read(pyraminxProvider);
    expect(puzzle.isSolved, isFalse);
    expect(c.read(freePlayControllerProvider).status, TimerStatus.ready);

    // Solve it with the solver, as if by finger turns.
    final n = c.read(freePlayControllerProvider.notifier);
    final moves = PyraminxSolver.solve(puzzle.state.colors).moves;
    for (final m in moves) {
      puzzle.apply(m);
      n.onCubeMove();
    }
    expect(puzzle.isSolved, isTrue);
    expect(c.read(freePlayControllerProvider).status, TimerStatus.stopped);
    expect(c.read(statsControllerProvider).single.puzzle, 'pyraminx');
  });

  test('pyraminx scramble format', () {
    final s = pyraminxScramble(rng: math.Random(3)).split(' ');
    final faces = s.where((m) => 'ULRB'.contains(m[0])).toList();
    expect(faces, hasLength(11));
    for (var i = 1; i < faces.length; i++) {
      expect(faces[i][0], isNot(faces[i - 1][0]));
    }
    expect(s.skip(11).every((m) => 'ulrb'.contains(m[0])), isTrue);
  });

  test('records saved before multi-puzzle support count as 3x3', () {
    final r = SolveRecord.fromJson(
        {'id': 1, 'durationMs': 1000, 'createdAt': 0, 'scramble': ''});
    expect(r.puzzle, 'cube3');
  });
}
