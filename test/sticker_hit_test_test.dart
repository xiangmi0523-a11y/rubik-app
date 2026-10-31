import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/core/cube/cube_facelets.dart';
import 'package:rubik_app/core/cube/sticker_hit_test.dart';

Set<String> _hittable(Size size, double rx, double ry) {
  final out = <String>{};
  for (var i = 0; i < 54; i++) {
    final p = StickerHitTest.centerOf(
        index: i, size: size, viewRotationX: rx, viewRotationY: ry)!;
    final hit = StickerHitTest.faceletAt(
        tap: p, size: size, viewRotationX: rx, viewRotationY: ry);
    if (hit == i) out.add(CubeSide.values[i ~/ 9].letter);
  }
  return out;
}

void main() {
  const rx = CubeNotation.viewRotationX;
  const ry = CubeNotation.viewRotationY;

  test('front view: exactly U, R, F stickers are tappable', () {
    for (final size in const [Size(360, 420), Size(390, 600), Size(600, 300)]) {
      var count = 0;
      for (var i = 0; i < 54; i++) {
        final p = StickerHitTest.centerOf(
            index: i, size: size, viewRotationX: rx, viewRotationY: ry)!;
        if (StickerHitTest.faceletAt(
                tap: p, size: size, viewRotationX: rx, viewRotationY: ry) ==
            i) {
          count++;
        }
      }
      expect(count, 27, reason: '$size');
      expect(_hittable(size, rx, ry), {'U', 'R', 'F'});
    }
  });

  test('back view: exactly D, L, B stickers are tappable', () {
    expect(_hittable(const Size(390, 600), rx + 1.0, ry + math.pi),
        {'D', 'L', 'B'});
  });

  test('tap outside the cube misses', () {
    expect(
        StickerHitTest.faceletAt(
            tap: const Offset(2, 2),
            size: const Size(390, 600),
            viewRotationX: rx,
            viewRotationY: ry),
        isNull);
  });
}
