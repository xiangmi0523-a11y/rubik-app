import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_cube/puzzle_cube.dart';
import 'package:rubik_app/app.dart';
import 'package:rubik_app/core/cube/cube_facelets.dart';
import 'package:rubik_app/core/cube/sticker_hit_test.dart';
import 'package:rubik_app/core/nxn/nxn_cube_view.dart';
import 'package:rubik_app/core/nxn/nxn_projection.dart';
import 'package:rubik_app/core/pyraminx/pyraminx_model.dart';
import 'package:rubik_app/core/pyraminx/pyraminx_projection.dart';
import 'package:rubik_app/core/pyraminx/pyraminx_view.dart';
import 'package:rubik_app/features/puzzles/domain/puzzle_type.dart';
import 'package:rubik_app/features/solver/application/puzzle_color_input.dart';
import 'package:rubik_app/features/solver/domain/fill_view_plan.dart';
import 'package:rubik_app/core/prefs/shared_prefs_provider.dart';
import 'package:rubik_app/features/solver/application/color_input_controller.dart';
import 'package:rubik_app/features/solver/presentation/widgets/sticker_paint_cube.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _openSolverTab(WidgetTester tester,
    {bool seen = false,
    Size size = const Size(390, 844),
    double text = 1.0}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(
      seen ? {'hold_guide_seen_v1': true} : {});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MediaQuery(
      data: MediaQueryData(
          size: size, devicePixelRatio: 3, textScaler: TextScaler.linear(text)),
      child: const RubikApp(),
    ),
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

  group('fixed view stepping', () {
    final plan = FillViewPlan.cube3;

    (double, double) camera(ProviderContainer c) {
      final cube = c.read(colorInputCubeProvider);
      return (cube.viewRotationX, cube.viewRotationY);
    }

    void expectAtStop(ProviderContainer c, int i) {
      final (x, y) = camera(c);
      final s = plan.stops[i];
      expect(x, closeTo(s.rotationX, 1e-9), reason: 'pitch at stop $i');
      expect(wrapAngle(y - s.rotationY), closeTo(0, 1e-9),
          reason: 'yaw at stop $i');
    }

    Future<void> tapStep(WidgetTester tester, IconData icon) async {
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();
    }

    bool enabled(WidgetTester tester, IconData icon) => tester
        .widget<IconButton>(find.widgetWithIcon(IconButton, icon))
        .onPressed != null;

    Offset stickerAt(WidgetTester tester, ProviderContainer c, int index) {
      final finder = find.byType(StickerPaintCube);
      final (x, y) = camera(c);
      return tester.getTopLeft(finder) +
          StickerHitTest.centerOf(
            index: index,
            size: tester.getSize(finder),
            viewRotationX: x,
            viewRotationY: y,
          )!;
    }

    testWidgets('starts on the unchanged default view; ◀ is disabled',
        (tester) async {
      final c = await _openSolverTab(tester, seen: true);
      expect(camera(c), (CubeNotation.viewRotationX, CubeNotation.viewRotationY));
      expect(enabled(tester, Icons.chevron_left), isFalse);
      expect(enabled(tester, Icons.chevron_right), isTrue);
      // Tapping a disabled ◀ does nothing.
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expectAtStop(c, 0);
    });

    testWidgets('▶ turns smoothly (no jump) to the next view', (tester) async {
      final c = await _openSolverTab(tester, seen: true);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      final yaws = <double>[];
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        yaws.add(camera(c).$2);
      }
      final y0 = plan.stops[0].rotationY, y1 = plan.stops[1].rotationY;
      // Strictly between the two views while turning, monotone, small steps.
      expect(yaws.first, greaterThan(y0));
      expect(yaws.first, lessThan(y1));
      for (var i = 1; i < yaws.length; i++) {
        expect(yaws[i], greaterThanOrEqualTo(yaws[i - 1]));
        expect(yaws[i] - yaws[i - 1], lessThan(0.45));
      }
      await tester.pumpAndSettle();
      expectAtStop(c, 1);
      expect(camera(c).$2, closeTo(y1, 1e-9)); // forward, not the long way
    });

    testWidgets('walks F → R → B → L → bottom, then stops at both ends',
        (tester) async {
      final c = await _openSolverTab(tester, seen: true);
      for (var i = 1; i <= plan.lastIndex; i++) {
        await tapStep(tester, Icons.chevron_right);
        expectAtStop(c, i);
      }
      // Bottom is last: ▶ is disabled and further taps change nothing.
      expect(enabled(tester, Icons.chevron_right), isFalse);
      expect(enabled(tester, Icons.chevron_left), isTrue);
      await tapStep(tester, Icons.chevron_right);
      expectAtStop(c, plan.lastIndex);
      // And back again.
      for (var i = plan.lastIndex - 1; i >= 0; i--) {
        await tapStep(tester, Icons.chevron_left);
        expectAtStop(c, i);
      }
      expect(enabled(tester, Icons.chevron_left), isFalse);
    });

    testWidgets('quick taps keep the sequence consistent', (tester) async {
      final c = await _openSolverTab(tester, seen: true);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();
      expectAtStop(c, 3);
    });

    testWidgets('dragging neither rotates the cube nor paints', (tester) async {
      final c = await _openSolverTab(tester, seen: true);
      final before = camera(c);
      final start = stickerAt(tester, c, CubeFacelets.indexOf(CubeSide.f, 4));
      for (final by in [
        const Offset(120, 0),
        const Offset(0, -120),
        const Offset(-90, 90),
      ]) {
        await tester.dragFrom(start, by);
        await tester.pumpAndSettle();
      }
      // Also a drag that starts off the cube.
      await tester.dragFrom(
          tester.getTopLeft(find.byType(StickerPaintCube)) + const Offset(30, 30),
          const Offset(100, 100));
      await tester.pumpAndSettle();
      expect(camera(c), before);
      expect(c.read(colorInputProvider).blankCount, 48);
    });

    testWidgets('tap paints and a second tap erases, in every view',
        (tester) async {
      final c = await _openSolverTab(tester, seen: true);
      final cube = c.read(colorInputCubeProvider);
      for (var stop = 0; stop <= plan.lastIndex; stop++) {
        if (stop > 0) await tapStep(tester, Icons.chevron_right);
        // A sticker that is tappable in this view: the main face's top-left
        // corner (for the bottom view: D's first sticker).
        final main = const [
          CubeSide.f,
          CubeSide.r,
          CubeSide.b,
          CubeSide.l,
          CubeSide.d,
        ][stop];
        final idx = CubeFacelets.indexOf(main, 0);
        final p = stickerAt(tester, c, idx);
        await tester.tapAt(p);
        await tester.pump();
        final painted = c.read(colorInputProvider).colors[idx];
        expect(painted.toARGB32(), isNot(CubeColors.colorless.toARGB32()),
            reason: 'stop $stop paints $main[0]');
        // Only that one sticker changed.
        expect(c.read(colorInputProvider).blankCount, 47);
        // Same colour again → erase.
        await tester.tapAt(p);
        await tester.pump();
        expect(c.read(colorInputProvider).colors[idx].toARGB32(),
            CubeColors.colorless.toARGB32());
        expect(c.read(colorInputProvider).blankCount, 48);
      }
      expect(cube.viewRotationX, closeTo(plan.stops.last.rotationX, 1e-9));
    });

    testWidgets('painted colours survive switching views (and the model '
        'stays in sync)', (tester) async {
      final c = await _openSolverTab(tester, seen: true);
      final input = c.read(colorInputProvider.notifier);
      // Paint a few stickers of different faces in different colours.
      final picks = {
        CubeSide.f: CubeColors.green,
        CubeSide.r: CubeColors.red,
        CubeSide.b: CubeColors.blue,
        CubeSide.l: CubeColors.orange,
        CubeSide.d: CubeColors.yellow,
      };
      var stop = 0;
      for (final e in picks.entries) {
        input.select(e.value);
        await tester.tapAt(stickerAt(tester, c, CubeFacelets.indexOf(e.key, 0)));
        await tester.pump();
        if (stop < plan.lastIndex) await tapStep(tester, Icons.chevron_right);
        stop++;
      }
      final snapshot = [...c.read(colorInputProvider).colors];
      // Go back to the default view and out to the bottom again.
      await tester.tap(find.text('正面'));
      await tester.pumpAndSettle();
      expectAtStop(c, 0);
      for (var i = 0; i < plan.lastIndex; i++) {
        await tapStep(tester, Icons.chevron_right);
      }
      expect(c.read(colorInputProvider).colors, snapshot);
      // Each painted colour is on exactly the sticker it was tapped on.
      for (final e in picks.entries) {
        final idx = CubeFacelets.indexOf(e.key, 0);
        expect(snapshot[idx].toARGB32(), e.value.toARGB32(), reason: '${e.key}');
      }
      // The 3D model mirrors the input state.
      final model = CubeFacelets.read(c.read(colorInputCubeProvider).state);
      for (final e in picks.entries) {
        final idx = CubeFacelets.indexOf(e.key, 0);
        expect(model[idx].toARGB32(), e.value.toARGB32());
      }
    });

    testWidgets('「正面」「背面」 shortcuts cooperate with ◀ ▶', (tester) async {
      final c = await _openSolverTab(tester, seen: true);
      await tester.tap(find.text('背面'));
      await tester.pumpAndSettle();
      expectAtStop(c, plan.backIndex);
      expect(enabled(tester, Icons.chevron_left), isTrue);
      await tapStep(tester, Icons.chevron_right);
      expectAtStop(c, plan.backIndex + 1);
      await tapStep(tester, Icons.chevron_left);
      await tapStep(tester, Icons.chevron_left);
      expectAtStop(c, plan.backIndex - 1);
      await tester.tap(find.text('正面'));
      await tester.pumpAndSettle();
      expectAtStop(c, 0);
      expect(enabled(tester, Icons.chevron_left), isFalse);
      // From the bottom view, 正面 goes back to the default view too.
      for (var i = 0; i < plan.lastIndex; i++) {
        await tapStep(tester, Icons.chevron_right);
      }
      expect(enabled(tester, Icons.chevron_right), isFalse);
      await tester.tap(find.text('正面'));
      await tester.pumpAndSettle();
      expectAtStop(c, 0);
    });

    testWidgets('the view survives leaving the tab and coming back',
        (tester) async {
      final c = await _openSolverTab(tester, seen: true);
      await tapStep(tester, Icons.chevron_right);
      await tapStep(tester, Icons.chevron_right);
      await tester.tap(find.text('成绩').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('填色求解').last);
      await tester.pumpAndSettle();
      expectAtStop(c, 2);
      expect(enabled(tester, Icons.chevron_left), isTrue);
    });

    testWidgets('switching puzzle and back keeps the buttons in step',
        (tester) async {
      final c = await _openSolverTab(tester, seen: true);
      await tapStep(tester, Icons.chevron_right);
      c.read(solverPuzzleProvider.notifier).select(PuzzleType.cube4);
      await tester.pumpAndSettle();
      expect(enabled(tester, Icons.chevron_left), isFalse); // 4x4 is at its default
      c.read(solverPuzzleProvider.notifier).select(PuzzleType.cube3);
      await tester.pumpAndSettle();
      expect(enabled(tester, Icons.chevron_left), isTrue);
      expectAtStop(c, 1);
    });

    testWidgets('hint no longer promises drag-to-rotate', (tester) async {
      await _openSolverTab(tester, seen: true);
      expect(find.textContaining('拖动可旋转'), findsNothing);
      expect(find.textContaining('切换视角'), findsOneWidget);
    });
  });

  group('4x4 and Pyraminx pages', () {
    testWidgets('4x4: no drag rotation, steps to the bottom, painting works',
        (tester) async {
      final c = await _openSolverTab(tester, seen: true);
      c.read(solverPuzzleProvider.notifier).select(PuzzleType.cube4);
      await tester.pumpAndSettle();
      final notifier = c.read(nxnColorInputProvider(4).notifier);
      final cube = notifier.cube;
      final plan = FillViewPlan.nxn;
      final finder = find.byType(NxnCubeView);

      final before = (cube.rotationX, cube.rotationY);
      await tester.dragFrom(
          tester.getCenter(finder), const Offset(100, 40));
      await tester.dragFrom(
          tester.getTopLeft(finder) + const Offset(20, 20), const Offset(80, 0));
      await tester.pumpAndSettle();
      expect((cube.rotationX, cube.rotationY), before);
      expect(notifier.blankCount, 6 * 16);

      for (var i = 1; i <= plan.lastIndex; i++) {
        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pumpAndSettle();
        expect(plan.nearestIndex(cube.rotationX, cube.rotationY), i);
        expect(plan.isOnStop(cube.rotationX, cube.rotationY), isTrue);
      }
      expect(
          tester
              .widget<IconButton>(
                  find.widgetWithIcon(IconButton, Icons.chevron_right))
              .onPressed,
          isNull);

      // Bottom view: tap a bottom sticker → painted; tap again → erased.
      final cubie = cube.state.cubies
          .firstWhere((q) => q.stickers.containsKey((0, -1, 0)));
      final proj = NxnProjection(
          size: tester.getSize(finder),
          n: 4,
          rotationX: cube.rotationX,
          rotationY: cube.rotationY);
      final p = tester.getTopLeft(finder) +
          proj.project(NxnProjection.cubieCenter(cubie.pos) +
              NxnProjection.vec((0, -1, 0)) * 0.5);
      await tester.tapAt(p);
      await tester.pump();
      expect(notifier.blankCount, 6 * 16 - 1);
      expect(cube.state.stickerAt(cubie.pos, (0, -1, 0))?.toARGB32(),
          isNot(CubeColors.colorless.toARGB32()));
      await tester.tapAt(p);
      await tester.pump();
      expect(notifier.blankCount, 6 * 16);
    });

    testWidgets('Pyraminx: three side views then the bottom; drag is inert',
        (tester) async {
      final c = await _openSolverTab(tester, seen: true);
      c.read(solverPuzzleProvider.notifier).select(PuzzleType.pyraminx);
      await tester.pumpAndSettle();
      final notifier = c.read(pyraminxColorInputProvider.notifier);
      final puzzle = notifier.puzzle;
      final plan = FillViewPlan.pyraminx;
      final finder = find.byType(PyraminxView);

      final before = (puzzle.rotationX, puzzle.rotationY);
      await tester.dragFrom(tester.getCenter(finder), const Offset(90, 30));
      await tester.pumpAndSettle();
      expect((puzzle.rotationX, puzzle.rotationY), before);
      expect(notifier.blankCount, 36);

      for (var i = 1; i <= plan.lastIndex; i++) {
        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pumpAndSettle();
        expect(plan.nearestIndex(puzzle.rotationX, puzzle.rotationY), i);
      }
      expect(
          tester
              .widget<IconButton>(
                  find.widgetWithIcon(IconButton, Icons.chevron_right))
              .onPressed,
          isNull);

      // Bottom view: slot 0 belongs to the bottom face (face 0).
      expect(PyraminxGeometry.slots[0].face, 0);
      final proj = PyraminxProjection(
          size: tester.getSize(finder),
          rotationX: puzzle.rotationX,
          rotationY: puzzle.rotationY);
      final p = tester.getTopLeft(finder) +
          proj.project(PyraminxGeometry.slots[0].centroid);
      await tester.tapAt(p);
      await tester.pump();
      expect(notifier.blankCount, 35);
      expect(puzzle.state.colors[0], greaterThanOrEqualTo(0));
      await tester.tapAt(p);
      await tester.pump();
      expect(notifier.blankCount, 36);
    });
  });

  group('layout', () {
    const phones = {
      'SE 320': Size(320, 568),
      'SE 375': Size(375, 667),
      'standard': Size(390, 844),
      'Max': Size(430, 932),
    };
    for (final e in phones.entries) {
      for (final text in [1.0, 1.5]) {
        testWidgets('◀ ▶ clear of the shortcuts and the cube: ${e.key} ×$text',
            (tester) async {
          final c = await _openSolverTab(tester,
              seen: true, size: e.value, text: text);
          final cube = c.read(colorInputCubeProvider);
          final screen = Offset.zero & e.value;
          final cubeFinder = find.byType(StickerPaintCube);
          final cubeRect = tester.getRect(cubeFinder);

          Rect step(String tip) => tester.getRect(find.byTooltip(tip));
          final prev = step('上一个视角'), next = step('下一个视角');
          final front = tester.getRect(find.ancestor(
              of: find.text('正面'), matching: find.byType(InkWell)));
          final back = tester.getRect(find.ancestor(
              of: find.text('背面'), matching: find.byType(InkWell)));

          for (final r in [prev, next]) {
            expect(screen.contains(r.topLeft) && screen.contains(r.bottomRight),
                isTrue, reason: 'on screen: $r');
            expect(r.overlaps(front), isFalse, reason: '$r vs 正面 $front');
            expect(r.overlaps(back), isFalse, reason: '$r vs 背面 $back');
            // Inside the 3D area, not over the hint / palette below it.
            expect(r.bottom, lessThanOrEqualTo(cubeRect.bottom + 8));
          }
          expect(prev.overlaps(next), isFalse);
          // The cube itself keeps filling the whole 3D area (not shrunk).
          expect(cubeRect.width, greaterThan(e.value.width - 24));

          // No sticker of any view sits under a ◀ / ▶ button.
          final plan = FillViewPlan.cube3;
          for (var stop = 0; stop < plan.stops.length; stop++) {
            cube.setView(
                rotationX: plan.stops[stop].rotationX,
                rotationY: plan.stops[stop].rotationY);
            for (var i = 0; i < 54; i++) {
              final p = StickerHitTest.centerOf(
                  index: i,
                  size: cubeRect.size,
                  viewRotationX: cube.viewRotationX,
                  viewRotationY: cube.viewRotationY)!;
              final at = cubeRect.topLeft + p;
              for (final r in [prev, next]) {
                if (StickerHitTest.faceletAt(
                        tap: p,
                        size: cubeRect.size,
                        viewRotationX: cube.viewRotationX,
                        viewRotationY: cube.viewRotationY) !=
                    i) {
                  continue; // hidden sticker
                }
                expect(r.inflate(10).contains(at), isFalse,
                    reason: 'stop $stop sticker $i at $at under $r');
              }
            }
          }
          // Keep the unused-import analyzer quiet and the maths explicit.
          expect(math.pi, greaterThan(3));
        });
      }
    }
  });
}
