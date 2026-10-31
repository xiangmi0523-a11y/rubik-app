import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_cube/puzzle_cube.dart';
import 'package:rubik_app/app.dart';
import 'package:rubik_app/core/cube/cube_facelets.dart';
import 'package:rubik_app/core/cube/sticker_hit_test.dart';
import 'package:rubik_app/core/prefs/shared_prefs_provider.dart';
import 'package:rubik_app/features/solver/application/color_input_controller.dart';
import 'package:rubik_app/features/solver/presentation/widgets/sticker_paint_cube.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _openSolverTab(WidgetTester tester,
    {bool seen = false}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(
      seen ? {'hold_guide_seen_v1': true} : {});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const RubikApp(),
  ));
  await tester.tap(find.text('填色求解').last);
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
}

void main() {
  testWidgets('first visit shows hold guide once', (tester) async {
    final container = await _openSolverTab(tester);
    expect(find.text('手持姿势'), findsOneWidget);
    await tester.tap(find.text('我知道了'));
    await tester.pumpAndSettle();
    expect(find.text('我知道了'), findsNothing);

    await tester.tap(find.text('自由玩').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('填色求解').last);
    await tester.pumpAndSettle();
    expect(find.text('我知道了'), findsNothing);
    expect(container.read(colorInputProvider).blankCount, 48);
  });

  testWidgets('tapping a 3D sticker paints that sticker', (tester) async {
    final container = await _openSolverTab(tester, seen: true);
    final cubeFinder = find.byType(StickerPaintCube);
    final size = tester.getSize(cubeFinder);
    final origin = tester.getTopLeft(cubeFinder);

    final f1 = CubeFacelets.indexOf(CubeSide.f, 0);
    final p = StickerHitTest.centerOf(
      index: f1,
      size: size,
      viewRotationX: CubeNotation.viewRotationX,
      viewRotationY: CubeNotation.viewRotationY,
    )!;
    await tester.tapAt(origin + p);
    await tester.pump();

    final colors = container.read(colorInputProvider).colors;
    expect(colors[f1].toARGB32(), CubeColors.white.toARGB32());
    expect(colors.where((c) => c.toARGB32() == CubeColors.white.toARGB32()),
        hasLength(2)); // centre + the painted one
  });

  testWidgets('unsolvable state shows dedicated dialog', (tester) async {
    final container = await _openSolverTab(tester, seen: true);
    // Solved cube with one twisted corner.
    final colors = CubeFacelets.read(PuzzleCubeState.solved());
    final a = CubeFacelets.indexOf(CubeSide.u, 8);
    final b = CubeFacelets.indexOf(CubeSide.r, 0);
    final c = CubeFacelets.indexOf(CubeSide.f, 2);
    final t = colors[a];
    colors[a] = colors[b];
    colors[b] = colors[c];
    colors[c] = t;
    final n = container.read(colorInputProvider.notifier);
    n.state = n.state.copyWith(colors: colors);
    await tester.pump();

    await tester.tap(find.text('开始求解'));
    await tester.pumpAndSettle();
    expect(find.text('填色状态不可解'), findsOneWidget);
    expect(find.textContaining('暴力拆装'), findsOneWidget);
  });

  testWidgets('incomplete state shows a snackbar, not the dialog',
      (tester) async {
    await _openSolverTab(tester, seen: true);
    await tester.tap(find.text('开始求解'));
    await tester.pump();
    expect(find.textContaining('48 个色块没有填色'), findsOneWidget);
    expect(find.text('填色状态不可解'), findsNothing);
  });
}
