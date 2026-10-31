import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/core/nxn/nxn_cube_controller.dart';
import 'package:rubik_app/core/nxn/nxn_cube_state.dart';
import 'package:rubik_app/core/nxn/nxn_cube_view.dart';
import 'package:rubik_app/features/player/application/player_controller.dart';
import 'package:rubik_app/features/player/domain/puzzle_stepper.dart';
import 'package:rubik_app/features/player/presentation/player_page.dart';
import 'package:rubik_app/features/solver/application/puzzle_color_input.dart';

/// A real 4x4 / 5x5 solve as the colour-input flow builds it (in an isolate).
Future<NxnScript> _solved(WidgetTester tester, int n, int seed) async {
  final start = NxnCubeState.solved(n)
    ..applyAll(NxnCubeState.randomScramble(n, rng: math.Random(seed)));
  final outcome = (await tester.runAsync(() => solveBigCube(start)))!;
  expect(outcome, isA<PuzzleSolveOk>());
  return (outcome as PuzzleSolveOk).script as NxnScript;
}

Future<ProviderContainer> _pumpPlayer(WidgetTester tester, PlayerScript script) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(theme: ThemeData.dark(), home: PlayerPage(script: script)),
  ));
  return ProviderScope.containerOf(tester.element(find.byType(PlayerPage)));
}

/// The cube after the first [count] player steps (turns) of [script].
NxnCubeState _after(NxnScript script, int count) {
  final s = script.initial.copy();
  for (final b in script.blocks.take(count)) {
    s.applyBlock(b);
  }
  return s;
}

NxnCubeController _cubeOf(WidgetTester tester) =>
    tester.widget<NxnCubeView>(find.byType(NxnCubeView)).controller;

void main() {
  testWidgets('phases: chips per phase, jump to a phase, notes per formula',
      (tester) async {
    final script = await _solved(tester, 4, 11);
    final c = await _pumpPlayer(tester, script);
    final ctrl = playerControllerProvider(script);

    expect(script.phases.map((p) => p.label).toList(),
        containsAllInOrder(['拼中心', '配对棱块', '三阶求解']));
    // Phases tile the move list.
    expect(script.phases.first.start, 0);
    for (var i = 1; i < script.phases.length; i++) {
      expect(script.phases[i].start, script.phases[i - 1].end);
    }
    expect(script.phases.last.end, script.moves.length);
    expect(find.textContaining('拼中心 0/'), findsOneWidget);
    expect(find.textContaining('中心块：'), findsOneWidget);

    // Jump to each phase: the cube shows exactly the state at that point.
    for (var i = 0; i < script.phases.length; i++) {
      final p = script.phases[i];
      await tester.tap(find.byKey(ValueKey('phase$i')));
      await tester.pumpAndSettle();
      expect(c.read(ctrl).index, p.start);
      expect(c.read(ctrl).playing, isFalse);
      expect(find.textContaining('${p.label} 0/${p.length}'), findsOneWidget);
      final expected = _after(script, p.start);
      final shown = _cubeOf(tester).state;
      for (final cubie in expected.cubies) {
        for (final e in cubie.stickers.entries) {
          expect(shown.stickerAt(cubie.pos, e.key), e.value);
        }
      }
    }
    // The end of the last phase is the solved cube.
    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pumpAndSettle();
    expect(_cubeOf(tester).state.isSolved, isTrue);
  });

  testWidgets('single steps, play / pause and 1× / 2× / 4× speed',
      (tester) async {
    final script = await _solved(tester, 5, 12);
    final c = await _pumpPlayer(tester, script);
    final ctrl = playerControllerProvider(script);
    final cube = _cubeOf(tester);

    // Single step forward and back.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(c.read(ctrl).index, 1);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(c.read(ctrl).index, 2);
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(c.read(ctrl).index, 1);
    expect(find.textContaining('第 1 / ${script.moves.length} 步'), findsOneWidget);

    // Speed: default 1×, then 4× reaches the stepper's animation.
    expect(c.read(ctrl).speed, 1);
    expect(cube.speed, 1);
    await tester.tap(find.text('4×'));
    await tester.pump();
    expect(c.read(ctrl).speed, 4);
    expect(cube.speed, 4);
    expect(c.read(playbackSpeedProvider), 4);

    // Play for a while at 4×, then pause: the index stops moving.
    await tester.tap(find.byIcon(Icons.play_arrow));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final fast = c.read(ctrl).index;
    expect(fast, greaterThan(5)); // ~65 ms per turn plus a 30 ms gap
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pumpAndSettle();
    final paused = c.read(ctrl).index;
    expect(c.read(ctrl).playing, isFalse);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(c.read(ctrl).index, paused);

    // The shown cube matches the script at the paused index.
    final expected = _after(script, paused);
    expect(cube.state.isSolved, expected.isSolved);
    for (final cubie in expected.cubies) {
      for (final e in cubie.stickers.entries) {
        expect(cube.state.stickerAt(cubie.pos, e.key), e.value);
      }
    }

    // 1× is slower than 4×: over the same time, fewer moves play.
    await tester.tap(find.text('1×'));
    await tester.pump();
    expect(cube.speed, 1);
    await tester.tap(find.byIcon(Icons.play_arrow));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final slow = c.read(ctrl).index - paused;
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pumpAndSettle();
    expect(slow, greaterThan(0));
    expect(slow, lessThan(fast));
  });

  testWidgets('playing a whole 4x4 solution at 4× ends solved', (tester) async {
    final script = await _solved(tester, 4, 13);
    final c = await _pumpPlayer(tester, script);
    final ctrl = playerControllerProvider(script);
    await tester.tap(find.text('4×'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.play_arrow));
    for (var i = 0; i < 2000 && c.read(ctrl).playing; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(c.read(ctrl).index, script.moves.length);
    expect(_cubeOf(tester).state.isSolved, isTrue);
    final last = script.phases.last;
    expect(last.label, '三阶求解');
    expect(find.textContaining('三阶求解 ${last.length}/${last.length}'), findsOneWidget);
  });

  test('timeouts and failures become clear outcomes', () async {
    final start = NxnCubeState.solved(4)
      ..applyAll(NxnCubeState.randomScramble(4, rng: math.Random(1)));
    final timeout = await solveBigCube(start, timeout: Duration.zero);
    expect(timeout, isA<PuzzleSolveFailed>());
    expect((timeout as PuzzleSolveFailed).title, '求解超时');

    final s = NxnCubeState.solved(5);
    final fixed = s.cubies.firstWhere((x) => x.pos == (0, 4, 0));
    fixed.stickers[(0, 1, 0)] = const Color(0xFFFFEB3B); // two yellow centres
    final invalid = await solveBigCube(s);
    expect(invalid, isA<PuzzleSolveInvalid>());
  });

  test('phaseIndexAt follows the next move', () {
    const phases = [
      PlayerPhase(label: 'a', start: 0, end: 3),
      PlayerPhase(label: 'b', start: 3, end: 5),
    ];
    expect([for (var i = 0; i <= 5; i++) phaseIndexAt(phases, i)],
        [0, 0, 0, 1, 1, 1]);
    expect(phaseIndexAt(const [], 0), isNull);
  });
}
