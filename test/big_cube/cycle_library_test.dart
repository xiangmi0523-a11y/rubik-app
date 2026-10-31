import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/core/nxn/nxn_facelets.dart';
import 'package:rubik_app/features/solver/domain/big_cube/cycle_library.dart';

import 'helpers.dart';

/// Every library is checked exhaustively on the real engine, separately for
/// each order and orbit.
void main() {
  final libraries = <(int, SlotKind)>[
    (4, SlotKind.centerX),
    (4, SlotKind.wing),
    (5, SlotKind.centerX),
    (5, SlotKind.centerT),
    (5, SlotKind.wing),
  ];

  PieceCycleLibrary libOf(int n, SlotKind kind) => kind == SlotKind.wing
      ? PieceCycleLibrary.wings(n)
      : PieceCycleLibrary.centers(n, kind);

  test('sticker orbits: wings split into two orbits, one sticker per piece', () {
    for (final n in [4, 5]) {
      final f = NxnFacelets(n);
      final orbits = PieceCycleLibrary.stickerOrbits(n);
      final wingOrbits = [
        for (final o in orbits)
          if (f.kindOf[o.first] == SlotKind.wing) o,
      ];
      expect(wingOrbits, hasLength(2));
      for (final o in wingOrbits) {
        expect(o, hasLength(24));
        expect(o.map((s) => f.pieceOf[s]).toSet(), hasLength(24));
      }
      final mids = [
        for (final o in orbits)
          if (f.kindOf[o.first] == SlotKind.midEdge) o,
      ];
      expect(mids, hasLength(n == 5 ? 1 : 0));
      // Every orbit holds one kind only.
      for (final o in orbits) {
        expect(o.map((s) => f.kindOf[s]).toSet(), hasLength(1));
      }
    }
  });

  for (final (n, kind) in libraries) {
    group('${n}x$n ${kind.name}', () {
      final f = NxnFacelets(n);
      final table = NxnMoveTable(n);
      final lib = libOf(n, kind);
      final orbit = lib.orbit;
      // Named slot → all slots of that piece position, named slot first.
      List<int> stickersOf(int named) => [
            named,
            for (final s in f.slotsOfPiece(f.pieceOf[named]))
              if (s != named) s,
          ];

      List<(int, int, int)> allCycles() => [
            for (final a in orbit)
              for (final b in orbit)
                for (final c in orbit)
                  if (a != b && b != c && a != c) (a, b, c),
          ];

      test('covers every directed 3-cycle of its 24 pieces', () {
        expect(orbit, hasLength(24));
        expect(orbit.map((s) => f.kindOf[s]).toSet(), {kind});
        expect(orbit.map((s) => f.pieceOf[s]).toSet(), hasLength(24));
        expect(lib.cycleCount, 24 * 23 * 22 ~/ 3); // 4048
        for (final (a, b, c) in allCycles()) {
          expect(lib.cycleIds(a, b, c), same(lib.cycleIds(b, c, a)));
        }
      });

      test('every formula, run on the real engine, is exactly its 3-cycle', () {
        final labels = f.identityLabels();
        final seen = <List<int>>{};
        var checked = 0;
        for (final (a, b, c) in allCycles()) {
          if (!seen.add(lib.cycleIds(a, b, c))) continue;
          final seq = lib.cycle(a, b, c);
          final after = f.read(f.build(labels)..applyAll(seq));
          final expected = [...labels];
          for (final (from, to) in [(a, b), (b, c), (c, a)]) {
            final src = stickersOf(from), dst = stickersOf(to);
            for (var k = 0; k < src.length; k++) {
              expected[dst[k]] = labels[src[k]];
            }
          }
          expect(after, expected, reason: describe(seq, n));
          checked++;
        }
        expect(checked, 4048);
      });

      test('every formula is undone by its inverse, which is the reverse cycle',
          () {
        final labels = f.identityLabels();
        final seen = <List<int>>{};
        for (final (a, b, c) in allCycles()) {
          if (!seen.add(lib.cycleIds(a, b, c))) continue;
          final seq = lib.cycle(a, b, c);
          final back = f.build(labels)
            ..applyAll(seq)
            ..applyAll(inverseOf(seq));
          expect(f.read(back), labels);
          final reverse = f.read(f.build(labels)..applyAll(inverseOf(seq)));
          expect(reverse[a], labels[b]);
          expect(reverse[b], labels[c]);
          expect(reverse[c], labels[a]);
        }
      });

      test('formulas only use legal ${n}x$n moves and are 8–12 moves long', () {
        for (final (a, b, c) in allCycles()) {
          final seq = lib.cycle(a, b, c);
          expect(seq.length, inInclusiveRange(8, 12));
          for (final m in seq) {
            expect(table.indexOf(m), isNonNegative); // throws if illegal
          }
        }
      });
    });
  }

  test('rejects orbits that do not exist or mix piece sizes', () {
    expect(() => PieceCycleLibrary.centers(4, SlotKind.centerFixed),
        throwsArgumentError);
    expect(() => PieceCycleLibrary.centers(4, SlotKind.centerT),
        throwsArgumentError);
    final f = NxnFacelets(4);
    final mixed = [
      ...f.slotsOfKind(SlotKind.centerX).take(2),
      PieceCycleLibrary.wingOrbit(4).first,
    ];
    expect(() => PieceCycleLibrary.build(4, 'mixed', mixed), throwsArgumentError);
    final lib = PieceCycleLibrary.centers(4, SlotKind.centerX);
    expect(() => lib.cycleIds(lib.orbit[0], lib.orbit[0], lib.orbit[1]),
        throwsArgumentError);
  });

  test('4x4 and 5x5 libraries are independent', () {
    final w4 = PieceCycleLibrary.wings(4), w5 = PieceCycleLibrary.wings(5);
    expect(w4.n, 4);
    expect(w5.n, 5);
    // A 5x5 formula uses 5x5 layers that a 4x4 table rejects, and vice versa.
    final o5 = w5.orbit;
    final seq5 = w5.cycle(o5[0], o5[1], o5[2]);
    expect(seq5.any((m) => m.layer.isEven), isTrue);
    final o4 = w4.orbit;
    final seq4 = w4.cycle(o4[0], o4[1], o4[2]);
    expect(seq4.every((m) => m.layer.isOdd), isTrue);
    expect(() => NxnMoveTable(4).applyMoves(NxnFacelets(4).solvedColors(), seq5),
        throwsArgumentError);
  });
}
