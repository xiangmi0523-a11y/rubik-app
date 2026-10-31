import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_cube/puzzle_cube.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

const _turn = Duration(milliseconds: 400); // fade 100 ms, hold 280 ms
const _frame = Duration(milliseconds: 16);

/// Runs [frames] ticks of [_frame], returning the brightness of [keys] after
/// each tick.
List<List<double>> _run(TurnHighlight h, List<Object> keys, int frames) => [
      for (var i = 0; i < frames; i++)
        () {
          h.tick(_frame);
          return [for (final k in keys) h.brightnessOf(k)];
        }(),
    ];

void main() {
  group('TurnHighlight', () {
    test('idle: everything at full brightness', () {
      final h = TurnHighlight();
      expect(h.idle, isTrue);
      expect(h.brightnessOf('a'), 1);
      h.end(); // no turn: nothing happens
      expect(h.idle, isTrue);
      expect(h.tick(_frame), isFalse);
    });

    test('a turn: its pieces stay bright, the rest fade to dim, then back',
        () {
      final h = TurnHighlight(dim: 0.5);
      h.begin(['a', 'b'], _turn);
      expect(h.brightnessOf('a'), 1);
      expect(h.brightnessOf('x'), 1); // fades in, no jump
      final fadeIn = _run(h, ['a', 'x'], 8); // 128 ms > 100 ms fade
      for (var i = 1; i < fadeIn.length; i++) {
        expect(fadeIn[i][1], lessThanOrEqualTo(fadeIn[i - 1][1]));
      }
      expect(fadeIn.every((f) => f[0] == 1), isTrue);
      expect(h.brightnessOf('x'), 0.5);
      expect(h.brightnessOf('b'), 1);

      _run(h, [], 10); // rest of the turn
      h.end();
      // Held dimmed for 280 ms ...
      final held = _run(h, ['a', 'x'], 16); // 256 ms
      expect(held.every((f) => f[0] == 1 && f[1] == 0.5), isTrue);
      // ... then smoothly back to full brightness, and idle.
      final fadeOut = _run(h, ['a', 'x'], 12);
      for (var i = 1; i < fadeOut.length; i++) {
        expect(fadeOut[i][1], greaterThanOrEqualTo(fadeOut[i - 1][1]));
      }
      expect(h.brightnessOf('x'), 1);
      expect(h.brightnessOf('a'), 1);
      expect(h.idle, isTrue);
      expect(h.active, isEmpty);
    });

    test('back-to-back turns: no flash between them, smooth hand-over', () {
      final h = TurnHighlight(dim: 0.5);
      h.begin(['a', 'shared'], _turn);
      _run(h, [], 25); // the whole turn
      h.end();
      _run(h, [], 6); // a 96 ms gap, shorter than the hold
      expect(h.brightnessOf('x'), 0.5);
      h.begin(['b', 'shared'], _turn);
      final frames = _run(h, ['a', 'b', 'shared', 'x'], 10);
      for (var i = 0; i < frames.length; i++) {
        final [a, b, shared, x] = frames[i];
        expect(x, 0.5, reason: 'still pieces never brighten in between');
        expect(shared, 1, reason: 'a piece in both turns never dips');
        if (i > 0) {
          expect(a, lessThanOrEqualTo(frames[i - 1][0])); // old layer: darker
          expect(b, greaterThanOrEqualTo(frames[i - 1][1])); // new: brighter
        }
      }
      expect(h.brightnessOf('a'), 0.5);
      expect(h.brightnessOf('b'), 1);
    });

    test('the same layer twice in a row (e.g. U2 as two quarters) never dips',
        () {
      final h = TurnHighlight();
      h.begin(['u'], _turn);
      _run(h, [], 25);
      h.end();
      h.begin(['u'], _turn);
      expect(_run(h, ['u'], 20).every((f) => f[0] == 1), isTrue);
    });

    test('a turn starting while the dimming fades out only brightens its '
        'pieces', () {
      final h = TurnHighlight(dim: 0.4);
      h.begin(['a'], _turn);
      _run(h, [], 25);
      h.end();
      _run(h, [], 20); // hold over (320 ms), fading out
      final before = h.brightnessOf('b');
      expect(before, greaterThan(0.4));
      h.begin(['b'], _turn);
      final frames = _run(h, ['b'], 10);
      var prev = before;
      for (final [b] in frames) {
        expect(b, greaterThanOrEqualTo(prev - 1e-12));
        prev = b;
      }
      expect(h.brightnessOf('b'), 1);
    });

    test('reset: back to normal at once', () {
      final h = TurnHighlight();
      h.begin(['a'], _turn);
      _run(h, [], 10);
      expect(h.brightnessOf('x'), lessThan(1));
      h.reset();
      expect(h.idle, isTrue);
      expect(h.brightnessOf('x'), 1);
      expect(h.brightnessOf('a'), 1);
      h.end(); // a late "turn finished" after a reset changes nothing
      expect(h.idle, isTrue);
    });

    test('timing scales with the turn (1× / 2× / 4×)', () {
      for (final speed in [1, 2, 4]) {
        final h = TurnHighlight(dim: 0.5);
        final turn = const Duration(milliseconds: 480) * (1 / speed);
        h.begin(['a'], turn);
        // Fade-in takes a quarter of the turn.
        h.tick(turn * 0.24);
        expect(h.brightnessOf('x'), greaterThan(0.5));
        h.tick(turn * 0.02);
        expect(h.brightnessOf('x'), 0.5);
        h.tick(turn * 0.74);
        h.end();
        // Held for 0.7 of a turn, then fades back within another quarter.
        h.tick(turn * 0.69);
        expect(h.brightnessOf('x'), 0.5);
        h.tick(turn * 0.02);
        h.tick(turn * 0.26);
        expect(h.brightnessOf('x'), 1);
        expect(h.idle, isTrue);
      }
    });

    test('odd ticks (zero, negative, huge) are safe', () {
      final h = TurnHighlight();
      h.begin(['a'], _turn);
      h.tick(Duration.zero);
      h.tick(const Duration(milliseconds: -5));
      expect(h.brightnessOf('x'), 1);
      h.tick(const Duration(seconds: 10));
      expect(h.brightnessOf('x'), 0.5);
      h.end();
      h.tick(const Duration(seconds: 10));
      h.tick(const Duration(seconds: 10));
      expect(h.idle, isTrue);
    });
  });

  group('renderer brightness', () {
    Future<List<int>> centrePixel(WidgetTester tester, Color color, double b) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(80, 80);
      RealisticCubeRenderer(const CubeRenderStyle(shadow: false)).paint(
        canvas,
        size,
        [
          CubieDraw(
            depth: 0,
            brightness: b,
            faces: [
              CubieFaceDraw(
                at: (x, y) => Offset(40 + x * 36, 40 + y * 36),
                normal: Vector3(0, 0, 1),
                sticker: color,
              ),
            ],
          ),
        ],
      );
      final image = await recorder.endRecording().toImage(80, 80);
      final bytes = (await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
      const i = (40 * 80 + 40) * 4;
      return [bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2)];
    }

    testWidgets('dimmed stickers are darker but keep their colour', (tester) async {
      for (final color in const [
        Color(0xFFF44336), // red
        Color(0xFF4CAF50), // green
        Color(0xFFFFEB3B), // yellow
        Color(0xFFFFFFFF), // white
      ]) {
        final bright = await centrePixel(tester, color, 1);
        final dim = await centrePixel(tester, color, 0.5);
        final lb = bright.reduce((a, b) => a + b), ld = dim.reduce((a, b) => a + b);
        // Clearly darker, far from black.
        expect(ld / lb, inInclusiveRange(0.4, 0.65), reason: '$color');
        // Same hue: the brightest channel stays the brightest.
        final maxB = bright.indexOf(bright.reduce((a, b) => a > b ? a : b));
        expect(dim[maxB], dim.reduce((a, b) => a > b ? a : b), reason: '$color');
      }
      // Default brightness is unchanged (1).
      const d = CubieDraw(depth: 0, faces: []);
      expect(d.brightness, 1);
    });
  });
}
