import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/core/cube/cube_facelets.dart';
import 'package:rubik_app/core/cube/sticker_hit_test.dart';
import 'package:rubik_app/core/nxn/nxn_cube_controller.dart';
import 'package:rubik_app/core/nxn/nxn_cube_state.dart';
import 'package:rubik_app/core/nxn/nxn_projection.dart';
import 'package:rubik_app/core/pyraminx/pyraminx_controller.dart';
import 'package:rubik_app/core/pyraminx/pyraminx_model.dart';
import 'package:rubik_app/core/pyraminx/pyraminx_projection.dart';
import 'package:rubik_app/features/puzzles/domain/puzzle_type.dart';
import 'package:rubik_app/features/solver/domain/fill_view_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

const _size = Size(360, 360);

/// Face (by the face's own centre sticker) that points most at the camera.
double _facing(Matrix4 view, Vector3 normal, {required bool towardsNegZ}) {
  final z = view.rotated3(Vector3.copy(normal)).z;
  return towardsNegZ ? -z : z;
}

void main() {
  group('FillViewPlan basics', () {
    test('first stop is each puzzle\'s unchanged default camera', () {
      expect(FillViewPlan.cube3.stops.first.rotationX, CubeNotation.viewRotationX);
      expect(FillViewPlan.cube3.stops.first.rotationY, CubeNotation.viewRotationY);
      expect(FillViewPlan.nxn.stops.first.rotationX,
          NxnCubeController.initialRotationX);
      expect(FillViewPlan.nxn.stops.first.rotationY,
          NxnCubeController.initialRotationY);
      expect(FillViewPlan.pyraminx.stops.first.rotationX,
          PyraminxController.initialRotationX);
      expect(FillViewPlan.pyraminx.stops.first.rotationY,
          PyraminxController.initialRotationY);
    });

    test('plans per puzzle type', () {
      expect(FillViewPlan.of(PuzzleType.cube3), same(FillViewPlan.cube3));
      for (final t in [PuzzleType.cube2, PuzzleType.cube4, PuzzleType.cube5]) {
        expect(FillViewPlan.of(t), same(FillViewPlan.nxn));
      }
      expect(FillViewPlan.of(PuzzleType.pyraminx), same(FillViewPlan.pyraminx));
      expect(FillViewPlan.cube3.stops, hasLength(5));
      expect(FillViewPlan.nxn.stops, hasLength(5));
      expect(FillViewPlan.pyraminx.stops, hasLength(4));
    });

    test('side views are exactly one step of yaw apart, same pitch', () {
      for (final plan in [
        FillViewPlan.cube3,
        FillViewPlan.nxn,
        FillViewPlan.pyraminx
      ]) {
        final sides = plan.stops.length - 1;
        for (var k = 1; k < sides; k++) {
          expect(plan.stops[k].rotationX, plan.stops[0].rotationX);
          expect(plan.stops[k].rotationY - plan.stops[k - 1].rotationY,
              closeTo(plan.sideStep, 1e-12));
        }
        // The bottom view looks from the other side of the equator.
        expect(plan.stops.last.rotationX.sign,
            -plan.stops.first.rotationX.sign);
      }
      expect(FillViewPlan.cube3.sideStep, closeTo(math.pi / 2, 1e-12));
      expect(FillViewPlan.nxn.sideStep.abs(), closeTo(math.pi / 2, 1e-12));
      expect(FillViewPlan.pyraminx.sideStep.abs(), closeTo(2 * math.pi / 3, 1e-12));
    });

    test('nearestIndex ignores full turns of yaw; isOnStop is exact', () {
      final plan = FillViewPlan.cube3;
      for (var i = 0; i < plan.stops.length; i++) {
        final s = plan.stops[i];
        expect(plan.nearestIndex(s.rotationX, s.rotationY), i);
        expect(plan.nearestIndex(s.rotationX, s.rotationY + 2 * math.pi), i);
        expect(plan.nearestIndex(s.rotationX, s.rotationY - 4 * math.pi), i);
        expect(plan.isOnStop(s.rotationX, s.rotationY + 2 * math.pi), isTrue);
        expect(plan.isOnStop(s.rotationX + 0.05, s.rotationY), isFalse);
      }
    });

    test('yawToward takes the short way round', () {
      final plan = FillViewPlan.cube3;
      final s0 = plan.stops[0].rotationY;
      // From the last side view back to the default: a quarter turn forward.
      final from = plan.stops[3].rotationY;
      expect(plan.yawToward(0, from) - from, closeTo(math.pi / 2, 1e-9));
      // The result is the stop's own yaw, up to full turns.
      expect(wrapAngle(plan.yawToward(0, from) - s0), closeTo(0, 1e-9));
      expect(plan.yawToward(1, s0) - s0, closeTo(math.pi / 2, 1e-9));
      expect(wrapAngle(-7 * math.pi).abs(), closeTo(math.pi, 1e-9));
    });
  });

  group('3x3 views', () {
    final plan = FillViewPlan.cube3;

    Set<int> visible(int stop) {
      final s = plan.stops[stop];
      final out = <int>{};
      for (var i = 0; i < 54; i++) {
        final c = StickerHitTest.centerOf(
            index: i,
            size: _size,
            viewRotationX: s.rotationX,
            viewRotationY: s.rotationY);
        final hit = c == null
            ? null
            : StickerHitTest.faceletAt(
                tap: c,
                size: _size,
                viewRotationX: s.rotationX,
                viewRotationY: s.rotationY);
        if (hit == i) out.add(i);
      }
      return out;
    }

    Set<CubeSide> faces(Set<int> idx) => {
          for (final i in idx) CubeSide.values[i ~/ 9],
        };

    test('top + front + right first; each side face becomes main in turn', () {
      const U = CubeSide.u, R = CubeSide.r, F = CubeSide.f;
      const D = CubeSide.d, L = CubeSide.l, B = CubeSide.b;
      final expected = [
        {U, F, R},
        {U, R, B},
        {U, B, L},
        {U, L, F},
      ];
      for (var k = 0; k < 4; k++) {
        expect(faces(visible(k)), expected[k], reason: 'stop $k');
        // all 27 stickers of those three faces can be tapped
        expect(visible(k), hasLength(27), reason: 'stop $k');
      }
      // The bottom view shows D, never U.
      final last = visible(4);
      expect(faces(last), contains(D));
      expect(faces(last), isNot(contains(U)));
      expect(last.where((i) => i ~/ 9 == D.index), hasLength(9));
    });

    test('the main face of each side view is F, R, B, L; D for the last', () {
      final mainOf = <CubeSide>[];
      for (final s in plan.stops) {
        final view = Matrix4.identity()
          ..rotateX(s.rotationX)
          ..rotateY(s.rotationY);
        CubeSide? best;
        var bestFacing = -2.0;
        for (final side in CubeSide.values) {
          final n = StickerRefNormal.of(side);
          final f = _facing(view, n, towardsNegZ: true);
          if (f > bestFacing) {
            bestFacing = f;
            best = side;
          }
        }
        mainOf.add(best!);
      }
      expect(mainOf, [
        CubeSide.f,
        CubeSide.r,
        CubeSide.b,
        CubeSide.l,
        CubeSide.d,
      ]);
    });

    test('bottom face appears only in the last view; every sticker is '
        'reachable; centres hit-test back to themselves', () {
      final union = <int>{};
      for (var k = 0; k < plan.stops.length; k++) {
        final v = visible(k);
        union.addAll(v);
        final hasD = v.any((i) => i ~/ 9 == CubeSide.d.index);
        expect(hasD, k == plan.lastIndex, reason: 'stop $k');
      }
      expect(union, hasLength(54));
    });

    test('shortcut targets: front = default view, back = the B-main view', () {
      expect(plan.frontIndex, 0);
      expect(plan.backIndex, 2);
      expect(faces(visible(plan.backIndex)),
          {CubeSide.u, CubeSide.b, CubeSide.l});
    });
  });

  group('N×N views', () {
    for (final n in [2, 4, 5]) {
      test('${n}x$n: faces per view, bottom last, all stickers reachable', () {
        final plan = FillViewPlan.nxn;
        final state = NxnCubeState.solved(n);
        final all = <(IVec, IVec)>{};
        final per = <Set<IVec>>[];
        for (final s in plan.stops) {
          final proj = NxnProjection(
              size: _size,
              n: n,
              rotationX: s.rotationX,
              rotationY: s.rotationY);
          final faces = <IVec>{};
          for (final c in state.cubies) {
            for (final normal in c.stickers.keys) {
              final p = proj.project(NxnProjection.cubieCenter(c.pos) +
                  NxnProjection.vec(normal) * 0.5);
              final hit = nxnHitTest(state, proj, p);
              if (hit != null && hit.pos == c.pos && hit.normal == normal) {
                faces.add(normal);
                all.add((c.pos, normal));
              }
            }
          }
          per.add(faces);
        }
        const up = (0, 1, 0), down = (0, -1, 0);
        const front = (0, 0, 1), right = (1, 0, 0);
        const back = (0, 0, -1), left = (-1, 0, 0);
        expect(per[0], {up, front, right});
        expect(per[1], {up, right, back});
        expect(per[2], {up, back, left});
        expect(per[3], {up, left, front});
        expect(per.last, contains(down));
        expect(per.last, isNot(contains(up)));
        for (var k = 0; k < plan.lastIndex; k++) {
          expect(per[k], isNot(contains(down)), reason: 'bottom only last');
        }
        final outerStickers =
            state.cubies.fold<int>(0, (a, c) => a + c.stickers.length);
        expect(all, hasLength(outerStickers));
      });
    }
  });

  group('Pyraminx views', () {
    test('three side views then the bottom; all 36 stickers reachable', () {
      final plan = FillViewPlan.pyraminx;
      final slots = PyraminxGeometry.slots;
      final facesPer = <Set<int>>[];
      final seen = <int>{};
      for (final s in plan.stops) {
        final proj = PyraminxProjection(
            size: _size, rotationX: s.rotationX, rotationY: s.rotationY);
        final visible = <int>{};
        for (var i = 0; i < slots.length; i++) {
          final p = proj.project(slots[i].centroid);
          if (pyraminxHitTest(proj, p) == i) visible.add(i);
        }
        seen.addAll(visible);
        facesPer.add({
          for (var f = 0; f < 4; f++)
            if (visible.where((i) => slots[i].face == f).length == 9) f,
        });
      }
      // face 0 = bottom, 1 = right, 2 = left, 3 = front
      expect(facesPer[0], {1, 3});
      expect(facesPer[1], {1, 2});
      expect(facesPer[2], {2, 3});
      expect(facesPer[3], {0});
      for (var k = 0; k < plan.lastIndex; k++) {
        expect(facesPer[k], isNot(contains(0)));
      }
      expect(seen, hasLength(36));
    });
  });
}

/// Outward model-space normal of a cuber face on the puzzle_cube model
/// (U = +y, F = +x, R = +z, D = -y, B = -x, L = -z).
abstract final class StickerRefNormal {
  static Vector3 of(CubeSide side) => switch (side) {
        CubeSide.u => Vector3(0, 1, 0),
        CubeSide.d => Vector3(0, -1, 0),
        CubeSide.f => Vector3(1, 0, 0),
        CubeSide.b => Vector3(-1, 0, 0),
        CubeSide.r => Vector3(0, 0, 1),
        CubeSide.l => Vector3(0, 0, -1),
      };
}
