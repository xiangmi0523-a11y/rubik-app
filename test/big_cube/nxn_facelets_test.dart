import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/core/nxn/nxn_cube_state.dart';
import 'package:rubik_app/core/nxn/nxn_facelets.dart';

import 'helpers.dart';

/// Expected sticker counts per kind, written out by hand for each order so
/// that 4x4 and 5x5 are checked against their own rules, not a shared formula.
const _expectedKinds = <int, Map<SlotKind, int>>{
  4: {
    SlotKind.corner: 24, // 8 corners × 3
    SlotKind.wing: 48, // 12 edges × 2 wings × 2
    SlotKind.centerX: 24, // 6 faces × 4
  },
  5: {
    SlotKind.corner: 24,
    SlotKind.wing: 48, // 12 edges × 2 wings × 2
    SlotKind.midEdge: 24, // 12 edges × 2
    SlotKind.centerX: 24, // 6 faces × 4
    SlotKind.centerT: 24, // 6 faces × 4
    SlotKind.centerFixed: 6,
  },
};

const _expectedLayers = <int, List<int>>{
  4: [-3, -1, 1, 3],
  5: [-4, -2, 0, 2, 4],
};

void main() {
  for (final n in [4, 5]) {
    group('${n}x$n facelet map', () {
      final f = NxnFacelets(n);

      test('has 6·n² unique slots with no gaps or duplicates', () {
        expect(f.count, 6 * n * n);
        final seen = <(IVec, IVec)>{};
        for (var i = 0; i < f.count; i++) {
          expect(seen.add((f.posOf[i], f.normalOf[i])), isTrue,
              reason: 'duplicate slot $i');
          expect(f.slotAt(f.posOf[i], f.normalOf[i]), i);
        }
        // Every sticker the engine has is a slot, and vice versa.
        final engine = NxnCubeState.solved(n);
        final engineStickers = <(IVec, IVec)>{
          for (final c in engine.cubies)
            for (final normal in c.stickers.keys) (c.pos, normal),
        };
        expect(seen, engineStickers);
      });

      test('coordinates follow this order, not another', () {
        expect(f.layers, _expectedLayers[n]);
        final allowed = _expectedLayers[n]!.toSet();
        for (var i = 0; i < f.count; i++) {
          final p = f.posOf[i];
          expect({p.$1, p.$2, p.$3}.difference(allowed), isEmpty);
        }
        expect(f.pieceCount, n * n * n - (n - 2) * (n - 2) * (n - 2));
      });

      test('each face has n² slots and the face order is U R F D L B', () {
        for (var face = 0; face < 6; face++) {
          final slots = f.slotsOfFace(face);
          expect(slots, hasLength(n * n));
          for (final s in slots) {
            expect(f.normalOf[s], NxnFacelets.faceNormals[face]);
          }
        }
      });

      test('piece kinds have the expected sticker counts', () {
        final expected = _expectedKinds[n]!;
        for (final kind in SlotKind.values) {
          expect(f.slotsOfKind(kind), hasLength(expected[kind] ?? 0),
              reason: '$kind');
        }
        // Stickers per piece: corners 3, edges 2, centres 1.
        for (var p = 0; p < f.pieceCount; p++) {
          final slots = f.slotsOfPiece(p);
          final kinds = slots.map((s) => f.kindOf[s]).toSet();
          expect(kinds, hasLength(1), reason: 'piece $p mixes kinds');
          final expectedSize = switch (kinds.single) {
            SlotKind.corner => 3,
            SlotKind.wing || SlotKind.midEdge => 2,
            _ => 1,
          };
          expect(slots, hasLength(expectedSize));
        }
      });

      test('read/build round-trips solved and scrambled states', () {
        expect(f.build(f.solvedColors()).isSolved, isTrue);
        final solved = f.solvedColors();
        // Each face is a single colour, all six different.
        final faceColors = <int>{};
        for (var face = 0; face < 6; face++) {
          final colours = {for (final s in f.slotsOfFace(face)) solved[s]};
          expect(colours, hasLength(1));
          faceColors.addAll(colours);
        }
        expect(faceColors, hasLength(6));

        final rng = math.Random(n);
        for (var i = 0; i < 30; i++) {
          final state = NxnCubeState.solved(n)
            ..applyAll(randomMoves(n, rng, 1 + rng.nextInt(50)));
          final colours = f.read(state);
          final rebuilt = f.build(colours);
          expect(f.read(rebuilt), colours);
          // And the rebuilt engine state behaves identically afterwards.
          final move = randomMoves(n, rng, 1).single;
          state.apply(move);
          rebuilt.apply(move);
          expect(f.read(rebuilt), f.read(state));
        }
      });

      test('rejects a state of the wrong order', () {
        final other = n == 4 ? 5 : 4;
        expect(() => f.read(NxnCubeState.solved(other)), throwsArgumentError);
        expect(() => f.build(List.filled(5, 0)), throwsArgumentError);
      });
    });

    group('${n}x$n move table', () {
      final table = NxnMoveTable(n);
      final f = table.facelets;

      test('has 9n distinct moves with distinct, parseable notation', () {
        expect(table.moves, hasLength(9 * n));
        expect(table.moves.toSet(), hasLength(9 * n));
        final names = table.moves.map((m) => m.notation(n)).toList();
        expect(names.toSet(), hasLength(9 * n));
        for (final m in table.moves) {
          expect(NxnMove.parse(m.notation(n), n), m,
              reason: m.notation(n));
          expect(table.indexOf(m), table.moves.indexOf(m));
        }
      });

      test('rejects moves that belong to another order', () {
        // Layer 0 exists only on odd cubes; layer ±4 only on 5x5.
        final foreign = n == 4 ? const NxnMove(0, 0, 1) : const NxnMove(0, 5, 1);
        expect(() => table.indexOf(foreign), throwsArgumentError);
        if (n == 4) {
          expect(() => table.indexOf(const NxnMove(0, 4, 1)), throwsArgumentError);
        } else {
          expect(table.indexOf(const NxnMove(0, 4, 1)), isNonNegative);
        }
      });

      test('every move is a bijection and keeps each sticker\'s kind', () {
        for (var m = 0; m < table.moves.length; m++) {
          final perm = table.perms[m];
          expect({...perm}, hasLength(f.count), reason: 'move $m not a bijection');
          for (var i = 0; i < f.count; i++) {
            expect(f.kindOf[perm[i]], f.kindOf[i],
                reason: '${table.moves[m].notation(n)} changed kind of slot $i');
          }
        }
      });

      test('turns leave exactly the expected stickers in place', () {
        // An outer-layer quarter turn moves 4·n + n² - ... : count directly
        // from the engine layer rule instead of a formula.
        for (var m = 0; m < table.moves.length; m++) {
          final move = table.moves[m];
          final inLayer = [
            for (var i = 0; i < f.count; i++)
              if (axisOf(f.posOf[i], move.axis) == move.layer) i,
          ];
          for (var i = 0; i < f.count; i++) {
            final moves = table.perms[m][i] != i;
            if (!inLayer.contains(i)) expect(moves, isFalse);
          }
          // Quarter/half turns of the layer only permute within its stickers.
          for (final i in inLayer) {
            expect(inLayer.contains(table.perms[m][i]), isTrue);
          }
        }
      });

      test('inverse table undoes every move', () {
        for (var m = 0; m < table.moves.length; m++) {
          final inv = table.inverse[m];
          expect(table.moves[inv], table.moves[m].inverse);
          for (var i = 0; i < f.count; i++) {
            expect(table.perms[inv][table.perms[m][i]], i);
          }
        }
      });

      test('each single move matches the engine from a random state', () {
        final rng = math.Random(100 + n);
        final base = NxnCubeState.solved(n)..applyAll(randomMoves(n, rng, 40));
        final baseColours = f.read(base);
        for (var m = 0; m < table.moves.length; m++) {
          final engine = base.copy()..apply(table.moves[m]);
          expect(table.apply(baseColours, m), f.read(engine),
              reason: table.moves[m].notation(n));
        }
      });

      test('300 random sequences: table equals NxnCubeState.apply', () {
        final rng = math.Random(n * 7);
        for (var i = 0; i < 300; i++) {
          final seq = randomMoves(n, rng, 1 + rng.nextInt(60));
          final engine = NxnCubeState.solved(n)..applyAll(seq);
          final viaTable = table.applyMoves(f.solvedColors(), seq);
          expect(viaTable, f.read(engine), reason: describe(seq, n));

          // Same with every sticker unique, so no colour coincidence can
          // hide a wrong permutation.
          final labelled = f.build(f.identityLabels())..applyAll(seq);
          expect(table.applyMoves(f.identityLabels(), seq), f.read(labelled),
              reason: describe(seq, n));
        }
      });

      test('300 random sequences followed by their inverse restore the state',
          () {
        final rng = math.Random(n * 13);
        for (var i = 0; i < 300; i++) {
          final seq = randomMoves(n, rng, 1 + rng.nextInt(60));
          final start = f.read(
              NxnCubeState.solved(n)..applyAll(randomMoves(n, rng, 20)));

          final there = table.applyMoves(start, seq);
          final back = table.applyMoves(there, inverseOf(seq));
          expect(back, start, reason: describe(seq, n));

          // The engine agrees about the round trip too.
          final engine = f.build(start)
            ..applyAll(seq)
            ..applyAll(inverseOf(seq));
          expect(f.read(engine), start);
        }
      });

      test('a move applied 4 times (2 for half turns) is the identity', () {
        for (var m = 0; m < table.moves.length; m++) {
          final turns = table.moves[m].turns == 2 ? 2 : 4;
          var s = f.identityLabels();
          for (var k = 0; k < turns; k++) {
            s = table.apply(s, m);
          }
          expect(s, f.identityLabels(), reason: table.moves[m].notation(n));
        }
      });
    });
  }

  test('4x4 and 5x5 tables are independent objects with their own rules', () {
    final t4 = NxnMoveTable(4);
    final t5 = NxnMoveTable(5);
    expect(identical(t4, t5), isFalse);
    expect(t4.facelets.count, 96);
    expect(t5.facelets.count, 150);
    expect(t4.moves.length, 36);
    expect(t5.moves.length, 45);
    expect(identical(NxnMoveTable(4), t4), isTrue); // cached
    // Inner layers differ: a 4x4 inner layer (±1) is not a 5x5 layer, and the
    // 5x5 middle layer (0) is not a 4x4 layer. Neither table accepts the other's.
    expect(() => t5.indexOf(const NxnMove(0, 1, 1)), throwsArgumentError);
    expect(() => t4.indexOf(const NxnMove(0, 0, 1)), throwsArgumentError);
    expect(t4.indexOf(const NxnMove(0, 1, 1)), isNonNegative);
    expect(t5.indexOf(const NxnMove(0, 2, 1)), isNonNegative);
    expect(() => t4.indexOf(const NxnMove(0, 2, 1)), throwsArgumentError);
    // The same move id is a different turn on each cube.
    expect(t4.moves.map((m) => m.notation(4)).toSet(),
        isNot(t5.moves.map((m) => m.notation(5)).toSet()));
  });

  test('the facelet map is generic: 3x3 and 2x2 classify correctly too', () {
    final f3 = NxnFacelets(3);
    expect(f3.count, 54);
    expect(f3.slotsOfKind(SlotKind.corner), hasLength(24));
    expect(f3.slotsOfKind(SlotKind.midEdge), hasLength(24));
    expect(f3.slotsOfKind(SlotKind.centerFixed), hasLength(6));
    expect(f3.slotsOfKind(SlotKind.wing), isEmpty);
    expect(NxnFacelets(2).slotsOfKind(SlotKind.corner), hasLength(24));
  });
}
