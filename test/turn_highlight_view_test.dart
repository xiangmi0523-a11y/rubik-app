import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_cube/puzzle_cube.dart';
import 'package:rubik_app/core/cube/cube_facelets.dart';
import 'package:rubik_app/core/nxn/nxn_cube_controller.dart';
import 'package:rubik_app/core/nxn/nxn_cube_painter.dart';
import 'package:rubik_app/core/nxn/nxn_cube_state.dart';
import 'package:rubik_app/core/nxn/nxn_cube_view.dart';
import 'package:rubik_app/core/nxn/nxn_facelets.dart';
import 'package:rubik_app/core/nxn/nxn_projection.dart';
import 'package:rubik_app/core/pyraminx/pyraminx_controller.dart';
import 'package:rubik_app/core/pyraminx/pyraminx_model.dart';
import 'package:rubik_app/core/pyraminx/pyraminx_painter.dart';
import 'package:rubik_app/core/pyraminx/pyraminx_view.dart';
import 'package:rubik_app/features/player/application/player_controller.dart';
import 'package:rubik_app/features/player/domain/puzzle_stepper.dart';
import 'package:rubik_app/features/player/presentation/player_page.dart';

final _dim = TurnHighlight().dim; // the default level the views use
const _frame = Duration(milliseconds: 16);

NxnCubePainter _nxnPainter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.descendant(
        of: find.byType(NxnCubeView), matching: find.byType(CustomPaint)))
    .painter! as NxnCubePainter;

CubePainter _cubePainter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.descendant(
        of: find.byType(Cube), matching: find.byType(CustomPaint)))
    .painter! as CubePainter;

PyraminxPainter _pyraPainter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.descendant(
        of: find.byType(PyraminxView), matching: find.byType(CustomPaint)))
    .painter! as PyraminxPainter;

Future<void> _pumpView(WidgetTester tester, Widget view) async {
  await tester.pumpWidget(MaterialApp(
    home: Center(child: SizedBox.square(dimension: 400, child: view)),
  ));
}

/// Every block of contiguous layers on one axis (turns -1, and a half turn
/// for the widest), for an order-[n] cube.
List<NxnBlockMove> _blocks(int n) {
  final layers = NxnFacelets(n).layers;
  return [
    for (var axis = 0; axis < 3; axis++)
      for (var a = 0; a < n; a++)
        for (var b = a; b < n; b++)
          NxnBlockMove(axis, layers[a], layers[b], b - a == n - 1 ? 2 : -1),
  ];
}

/// Mid-turn (after the fade-in): exactly the cubies in [block]'s layers are
/// rotated and bright; every other cubie is dimmed.
void _expectHighlight(NxnCubePainter p, NxnBlockMove block, String why) {
  final turn = p.turn;
  expect(turn, isNotNull, reason: why);
  expect((turn!.axis, turn.layer, turn.to), (block.axis, block.from, block.to),
      reason: why);
  for (final c in p.state.cubies) {
    final inBlock = block.layers.contains(axisOf(c.pos, block.axis));
    expect(turn.turns(c.pos), inBlock, reason: '$why ${c.pos}');
    expect(p.brightness!(c.pos), inBlock ? 1 : _dim, reason: '$why ${c.pos}');
  }
}

void _expectAllBright(NxnCubePainter p, String why) {
  for (final c in p.state.cubies) {
    expect(p.brightness!(c.pos), 1, reason: '$why ${c.pos}');
  }
}

void main() {
  for (final n in [2, 3, 4, 5]) {
    testWidgets('${n}x$n: the bright layers are exactly the turning layers, '
        'for every width', (tester) async {
      final cube = NxnCubeController(n);
      addTearDown(cube.dispose);
      await _pumpView(
        tester,
        NxnCubeView(
          controller: cube,
          highlightTurns: true,
          moveDuration: const Duration(milliseconds: 400),
        ),
      );
      final expected = NxnCubeState.solved(n);
      final f = NxnFacelets(n);
      for (final block in _blocks(n)) {
        final why = '${block.notation(n)} (width ${block.width})';
        cube.playBlocks([block]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150)); // fade-in done
        _expectHighlight(_nxnPainter(tester), block, why);
        await tester.pump(const Duration(milliseconds: 150));
        _expectHighlight(_nxnPainter(tester), block, '$why later');
        // Turn ends, the dimming is held, then everything is bright again.
        await tester.pumpAndSettle();
        final p = _nxnPainter(tester);
        expect(p.turn, isNull);
        _expectAllBright(p, '$why after');
        expected.applyBlock(block);
        expect(f.read(cube.state), f.read(expected), reason: why);
      }
    });
  }

  testWidgets('without highlightTurns nothing is dimmed (other screens)',
      (tester) async {
    final cube = NxnCubeController(4);
    addTearDown(cube.dispose);
    await _pumpView(tester, NxnCubeView(controller: cube));
    cube.playSequence(NxnMove.parseAll('R U', 4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(_nxnPainter(tester).turn, isNotNull);
    expect(_nxnPainter(tester).brightness, isNull);
    await tester.pumpAndSettle();

    final c3 = CubeController();
    addTearDown(c3.dispose);
    await _pumpView(tester, Cube(controller: c3));
    c3.play(CubeMove.u);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(_cubePainter(tester).brightness, isNull);
    await tester.pumpAndSettle();

    final py = PyraminxController();
    addTearDown(py.dispose);
    await _pumpView(tester, PyraminxView(controller: py));
    py.playSequence(PyraminxMove.parseAll('U'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(_pyraPainter(tester).brightness, isNull);
    await tester.pumpAndSettle();
  });

  group('interruptions', () {
    testWidgets('state replaced mid-turn: highlight cleared at once, no stale '
        'highlight when the old animation ends', (tester) async {
      final cube = NxnCubeController(4);
      addTearDown(cube.dispose);
      await _pumpView(tester, NxnCubeView(controller: cube, highlightTurns: true));
      cube.playBlocks([const NxnBlockMove(0, 1, 3, -1)]); // Rw
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_nxnPainter(tester).brightness!((3, 3, 3)), 1);
      expect(_nxnPainter(tester).brightness!((-3, 3, 3)), lessThan(1));
      cube.replaceState(NxnCubeState.solved(4)); // e.g. a jump
      await tester.pump();
      expect(_nxnPainter(tester).turn, isNull);
      _expectAllBright(_nxnPainter(tester), 'right after the jump');
      for (var i = 0; i < 60; i++) {
        await tester.pump(_frame);
        _expectAllBright(_nxnPainter(tester), 'frame $i');
      }
      await tester.pumpAndSettle();
      expect(cube.state.isSolved, isTrue);
    });

    testWidgets('page left mid-turn: no errors, ticker disposed',
        (tester) async {
      final cube = NxnCubeController(5);
      addTearDown(cube.dispose);
      await _pumpView(tester, NxnCubeView(controller: cube, highlightTurns: true));
      cube.playBlocks([const NxnBlockMove(1, 0, 4, -1)]); // 3Uw
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('highlight switched off mid-turn: back to normal',
        (tester) async {
      final cube = NxnCubeController(4);
      addTearDown(cube.dispose);
      await _pumpView(tester, NxnCubeView(controller: cube, highlightTurns: true));
      cube.playSequence(NxnMove.parseAll('U', 4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await _pumpView(tester, NxnCubeView(controller: cube));
      expect(_nxnPainter(tester).brightness, isNull);
      await tester.pumpAndSettle();
    });
  });

  group('player', () {
    Future<ProviderContainer> pumpPlayer(WidgetTester tester, PlayerScript s) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(theme: ThemeData.dark(), home: PlayerPage(script: s)),
      ));
      return ProviderScope.containerOf(tester.element(find.byType(PlayerPage)));
    }

    // Single, wide, inner-block and whole-cube turns on a 4x4 and a 5x5.
    final scripts = <int, List<NxnBlockMove>>{
      4: const [
        NxnBlockMove(0, 1, 3, -1), // Rw
        NxnBlockMove(1, 3, 3, -1), // U
        NxnBlockMove(1, 3, 3, 1), // U' (same layer again)
        NxnBlockMove(0, -1, 1, 2), // 2-3Rw2
        NxnBlockMove(2, 1, 3, -1), // Fw
        NxnBlockMove(1, 1, 1, -1), // 2U
        NxnBlockMove(0, -3, 3, -1), // x
        NxnBlockMove(2, -3, -1, 1), // Bw'
      ],
      5: const [
        NxnBlockMove(0, 0, 4, -1), // 3Rw
        NxnBlockMove(1, 2, 4, 2), // Uw2
        NxnBlockMove(2, 0, 0, -1), // 3F
        NxnBlockMove(0, -4, -2, 1), // Lw
        NxnBlockMove(1, -2, 2, -1), // 2-4Uw
        NxnBlockMove(2, 4, 4, 1), // F'
      ],
    };

    for (final n in [4, 5]) {
      for (final speed in playbackSpeeds) {
        testWidgets('${n}x$n continuous playback at ${speed.toInt()}×: '
            'highlight follows every turn, no flash, nothing left over',
            (tester) async {
          final blocks = scripts[n]!;
          final initial = NxnCubeState.solved(n);
          for (final b in blocks.reversed) {
            initial.applyBlock(b.inverse);
          }
          final script = NxnScript.blocks(initial: initial, blocks: blocks);
          final c = await pumpPlayer(tester, script);
          final ctrl = playerControllerProvider(script);
          c.read(ctrl.notifier).setSpeed(speed);
          await tester.pump();
          final cube = tester.widget<NxnCubeView>(find.byType(NxnCubeView)).controller;
          final turn = playerTurnDuration * (1 / speed);
          final fade = turn * 0.25;

          await tester.tap(find.byIcon(Icons.play_arrow));
          NxnBlockMove? current, last;
          var since = Duration.zero;
          var turnsSeen = 0;
          Map<IVec, double>? prev;
          for (var i = 0; i < 4000; i++) {
            await tester.pump(_frame);
            final p = _nxnPainter(tester);
            final pending = cube.pending;
            if (!identical(pending, current)) {
              if (pending != null) {
                turnsSeen++;
                last = current ?? last;
                since = Duration.zero;
              } else {
                last = current;
              }
              current = pending;
            } else {
              since += _frame;
            }
            final now = {for (final x in p.state.cubies) x.pos: p.brightness!(x.pos)};
            if (current != null) {
              final t = NxnTurn.of(current, 0);
              for (final x in p.state.cubies) {
                final b = now[x.pos]!;
                // Monotonic within a turn: its pieces brighten, others darken.
                if (prev != null && since > Duration.zero) {
                  if (t.turns(x.pos)) {
                    expect(b, greaterThanOrEqualTo(prev[x.pos]! - 1e-9));
                  } else {
                    expect(b, lessThanOrEqualTo(prev[x.pos]! + 1e-9));
                  }
                }
                // After the fade: bright ⇔ turning, exactly.
                if (since >= fade + _frame) {
                  expect(b, t.turns(x.pos) ? 1 : _dim,
                      reason: 'turn $turnsSeen ${current.notation(n)} ${x.pos}');
                }
              }
            } else if (c.read(ctrl).playing && turnsSeen > 0 && last != null) {
              // Between two turns: still pieces stay dim — no flash.
              final t = NxnTurn.of(last, 0);
              for (final x in p.state.cubies) {
                if (!t.turns(x.pos)) {
                  expect(now[x.pos], _dim, reason: 'gap after ${last.notation(n)}');
                }
              }
            }
            prev = now;
            if (!c.read(ctrl).playing && cube.pending == null) break;
          }
          expect(turnsSeen, blocks.length);
          await tester.pumpAndSettle();
          _expectAllBright(_nxnPainter(tester), 'after playback');
          expect(cube.state.isSolved, isTrue);
        });
      }
    }

    testWidgets('single step, pause and jump: highlight always cleared',
        (tester) async {
      final blocks = scripts[4]!;
      final script = NxnScript.blocks(initial: NxnCubeState.solved(4), blocks: blocks);
      final c = await pumpPlayer(tester, script);
      final ctrl = playerControllerProvider(script);

      // Single step: turn highlighted, then back to normal.
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      _expectHighlight(_nxnPainter(tester), blocks[0], 'step');
      await tester.pumpAndSettle();
      _expectAllBright(_nxnPainter(tester), 'after step');

      // Step back: the inverse turn is highlighted the same way.
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      _expectHighlight(_nxnPainter(tester), blocks[0].inverse, 'back');
      await tester.pumpAndSettle();
      _expectAllBright(_nxnPainter(tester), 'after back');

      // Play, then pause mid-turn: the turn finishes, then all bright.
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pumpAndSettle();
      expect(c.read(ctrl).playing, isFalse);
      _expectAllBright(_nxnPainter(tester), 'after pause');

      // Jump mid-turn (step chip): shown at once after the turn, all bright.
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      c.read(ctrl.notifier).jumpTo(5);
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.read(ctrl).index, 5);
      expect(_nxnPainter(tester).turn, isNull);
      _expectAllBright(_nxnPainter(tester), 'after jump');
      await tester.pumpAndSettle();
      _expectAllBright(_nxnPainter(tester), 'settled');
    });

    testWidgets('3x3: the turning layer is bright, the rest dimmed, also '
        'across the two quarters of a half turn', (tester) async {
      final script = Cube3Script(
        colors: CubeFacelets.read(PuzzleCubeState.solved()),
        moves: ['R', 'U2', "F'"],
      );
      await pumpPlayer(tester, script);
      await tester.tap(find.byIcon(Icons.play_arrow));
      final fade = playerTurnDuration * 0.25;
      Set<(int, int, int)>? layer;
      var frames = 0, checked = 0, uFrames = 0;
      Map<(int, int, int), double>? prev;
      for (var i = 0; i < 400; i++) {
        await tester.pump(_frame);
        final p = _cubePainter(tester);
        final turning = {for (final x in p.cubies) if (p.inSlice(x)) (x.x, x.y, x.z)};
        final now = {for (final x in p.cubies) (x.x, x.y, x.z): p.brightness!(x)};
        if (turning.isEmpty) {
          layer = null;
        } else if (layer != null && turning.length == layer.length &&
            turning.containsAll(layer)) {
          frames++;
          // The same layer keeps turning (U2 = two quarters): its pieces
          // never get darker, i.e. no dip between the quarters.
          for (final k in turning) {
            expect(now[k]!, greaterThanOrEqualTo(prev![k]! - 1e-9));
          }
          if (turning.every((k) => k.$2 == 1)) uFrames++;
          if (_frame * frames >= fade + _frame) {
            for (final e in now.entries) {
              expect(e.value, turning.contains(e.key) ? 1 : _dim, reason: '${e.key}');
            }
            checked++;
          }
        } else {
          layer = turning;
          frames = 0;
        }
        prev = now;
      }
      expect(checked, greaterThan(40));
      // U2 is two 480 ms quarters: one unbroken run of U-layer frames.
      expect(uFrames * _frame.inMilliseconds, greaterThan(800));
      await tester.pumpAndSettle();
      final p = _cubePainter(tester);
      expect(p.cubies.every((x) => p.brightness!(x) == 1), isTrue);
    });

    testWidgets('Pyraminx: the turning part is bright, the rest dimmed',
        (tester) async {
      final script = PyraminxScript(
        initial: PyraminxState.solved(),
        steps: PyraminxMove.parseAll("U R' l b"),
      );
      await pumpPlayer(tester, script);
      await tester.tap(find.byIcon(Icons.play_arrow));
      final fade = playerTurnDuration * 0.25;
      final slots = PyraminxGeometry.slots;
      final controller =
          tester.widget<PyraminxView>(find.byType(PyraminxView)).controller;
      PyraminxMove? current;
      var since = Duration.zero;
      var checked = 0, turns = 0;
      for (var i = 0; i < 400; i++) {
        await tester.pump(_frame);
        final pending = controller.pending;
        if (!identical(pending, current)) {
          current = pending;
          since = Duration.zero;
          if (pending != null) turns++;
        } else {
          since += _frame;
        }
        final p = _pyraPainter(tester);
        final t = p.turn;
        if (current == null || t == null || since < fade + _frame) continue;
        for (var s = 0; s < slots.length; s++) {
          expect(p.brightness!(s),
              PyraminxGeometry.inRegion(slots[s], t.axis, t.tip) ? 1 : _dim,
              reason: 'slot $s');
        }
        checked++;
      }
      expect(turns, 4);
      expect(checked, greaterThan(40));
      await tester.pumpAndSettle();
      final p = _pyraPainter(tester);
      for (var s = 0; s < slots.length; s++) {
        expect(p.brightness!(s), 1);
      }
    });
  });
}
