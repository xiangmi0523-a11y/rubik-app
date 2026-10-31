import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/app.dart';
import 'package:rubik_app/core/nxn/nxn_cube_state.dart';
import 'package:rubik_app/core/nxn/nxn_cube_view.dart';
import 'package:rubik_app/core/nxn/nxn_projection.dart';
import 'package:rubik_app/core/prefs/shared_prefs_provider.dart';
import 'package:rubik_app/core/pyraminx/pyraminx_model.dart';
import 'package:rubik_app/core/pyraminx/pyraminx_projection.dart';
import 'package:rubik_app/core/pyraminx/pyraminx_view.dart';
import 'package:rubik_app/features/player/application/player_controller.dart';
import 'package:rubik_app/features/player/domain/puzzle_stepper.dart';
import 'package:rubik_app/features/player/presentation/player_page.dart';
import 'package:rubik_app/features/solver/application/puzzle_color_input.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _open(WidgetTester tester, String puzzle) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'hold_guide_seen_v1': true});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const RubikApp(),
  ));
  await tester.tap(find.text('填色求解').last);
  await tester.pumpAndSettle();
  // The second selector row (on the 填色 tab) is the visible one.
  await tester.tap(find.text(puzzle).last);
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
}

Future<void> _randomAndSolve(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('随机示例'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('开始求解'));
  await tester.pump();
  // The solver runs in a background isolate; wait (in real time) until the
  // player opens or a dialog shows, up to 60 s.
  for (var i = 0; i < 120; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
    if (find.byType(PlayerPage).evaluate().isNotEmpty ||
        find.byType(AlertDialog).evaluate().isNotEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

/// The solve opened the player with a phased script that really solves the
/// colouring on a fresh engine copy.
void _expectBigCubeSolution(WidgetTester tester, int n) {
  expect(find.byType(PlayerPage), findsOneWidget);
  final page = tester.widget<PlayerPage>(find.byType(PlayerPage));
  final script = page.script as NxnScript;
  expect(script.initial.n, n);
  expect(script.initial.isSolved, isFalse);
  expect((script.initial.copy()..applyAll(script.steps)).isSolved, isTrue);
  final labels = script.phases.map((p) => p.label).toList();
  expect(labels.first, '拼中心');
  expect(labels.last, '三阶求解');
  expect(labels, contains('配对棱块'));
  expect(script.phases.last.end, script.steps.length);
  for (var i = 0; i < script.phases.length; i++) {
    final tile = find.byKey(ValueKey('phase$i'));
    expect(find.descendant(of: tile, matching: find.text(script.phases[i].label)),
        findsOneWidget);
    expect(
        find.descendant(
            of: tile, matching: find.text('${script.phases[i].length} 步')),
        findsOneWidget);
  }
  expect(find.text('1×'), findsOneWidget);
  expect(find.text('4×'), findsOneWidget);
}

void main() {
  testWidgets('2x2: tap paints a sticker; random example solves and plays',
      (tester) async {
    final c = await _open(tester, '二阶');
    final view = find.byType(NxnCubeView).last;
    final input = c.read(nxnColorInputProvider(2).notifier);
    final proj = NxnProjection(
      size: tester.getSize(view),
      n: 2,
      rotationX: input.cube.rotationX,
      rotationY: input.cube.rotationY,
    );
    final p = proj.project(NxnProjection.cubieCenter((-1, 1, 1)) +
        NxnProjection.vec((0, 0, 1)) * 0.5);
    await tester.tapAt(tester.getTopLeft(view) + p);
    await tester.pump();
    expect(input.blankCount, 23);
    expect(input.cube.state.stickerAt((-1, 1, 1), (0, 0, 1))!.toARGB32(),
        0xFFFFFFFF);

    await _randomAndSolve(tester);
    expect(find.byType(PlayerPage), findsOneWidget);
    final page = tester.widget<PlayerPage>(find.byType(PlayerPage));
    expect(page.script.moves.length, lessThanOrEqualTo(11));
    expect(c.read(playerControllerProvider(page.script)).index, 0);
  });

  testWidgets('Pyraminx: tap paints; random example solves and plays',
      (tester) async {
    final c = await _open(tester, '金字塔');
    final view = find.byType(PyraminxView).last;
    final input = c.read(pyraminxColorInputProvider.notifier);
    final proj = PyraminxProjection(
      size: tester.getSize(view),
      rotationX: input.puzzle.rotationX,
      rotationY: input.puzzle.rotationY,
    );
    // Centre of a visible front-face slot.
    final slot = PyraminxGeometry.slots.indexWhere((s) => s.face == 3);
    await tester.tapAt(tester.getTopLeft(view) +
        proj.project(PyraminxGeometry.slots[slot].centroid));
    await tester.pump();
    expect(input.blankCount, 35);

    await _randomAndSolve(tester);
    expect(find.byType(PlayerPage), findsOneWidget);
  });

  testWidgets('4x4: random example is solved by reduction and plays by phase',
      (tester) async {
    await _open(tester, '四阶');
    await _randomAndSolve(tester);
    _expectBigCubeSolution(tester, 4);
  });

  testWidgets('5x5: random example is solved by reduction and plays by phase',
      (tester) async {
    await _open(tester, '五阶');
    await _randomAndSolve(tester);
    _expectBigCubeSolution(tester, 5);
  });

  testWidgets('4x4: an illegal colouring is still caught by the colour check',
      (tester) async {
    final c = await _open(tester, '四阶');
    final input = c.read(nxnColorInputProvider(4).notifier);
    // Solved cube with one corner twisted in place.
    final s = NxnCubeState.solved(4);
    final corner = s.cubies.firstWhere((x) => x.pos == (3, 3, 3));
    final colours = [
      corner.stickers[(1, 0, 0)]!,
      corner.stickers[(0, 1, 0)]!,
      corner.stickers[(0, 0, 1)]!,
    ];
    corner.stickers[(1, 0, 0)] = colours[1];
    corner.stickers[(0, 1, 0)] = colours[2];
    corner.stickers[(0, 0, 1)] = colours[0];
    input.cube.replaceState(s);
    await tester.pump();
    await tester.tap(find.text('开始求解'));
    await tester.pumpAndSettle();
    expect(find.text('填色状态不可解'), findsOneWidget);
    expect(find.textContaining('有角块被单独拧转'), findsOneWidget);
    expect(find.byType(PlayerPage), findsNothing);
  });
}
