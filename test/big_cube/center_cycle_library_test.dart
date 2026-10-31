import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/core/nxn/nxn_facelets.dart';
import 'package:rubik_app/features/solver/domain/big_cube/center_cycle_library.dart';

import 'helpers.dart';

void main() {
  final f = NxnFacelets(4);
  final table = NxnMoveTable(4);
  final lib = CenterCycleLibrary.forOrbit(4, SlotKind.centerX);
  final orbit = f.slotsOfKind(SlotKind.centerX);

  List<(int, int, int)> allCycles() => [
        for (final a in orbit)
          for (final b in orbit)
            for (final c in orbit)
              if (a != b && b != c && a != c) (a, b, c),
      ];

  test('covers every directed 3-cycle of the 24 4x4 centres', () {
    expect(orbit, hasLength(24));
    expect(lib.cycleCount, 24 * 23 * 22 ~/ 3); // 4048
    // Rotations of a cycle share one formula.
    for (final (a, b, c) in allCycles()) {
      expect(lib.cycleIds(a, b, c), same(lib.cycleIds(b, c, a)));
    }
  });

  test('every formula, run on the real engine, is exactly its 3-cycle', () {
    final labels = f.identityLabels();
    var checked = 0;
    final seen = <List<int>>{};
    for (final (a, b, c) in allCycles()) {
      final ids = lib.cycleIds(a, b, c);
      if (!seen.add(ids)) continue; // each formula once (3 rotations share it)
      final engine = f.build(labels)..applyAll(lib.cycle(a, b, c));
      final after = f.read(engine);
      final expected = [...labels];
      expected[b] = labels[a];
      expected[c] = labels[b];
      expected[a] = labels[c];
      expect(after, expected, reason: describe(lib.cycle(a, b, c), 4));
      checked++;
    }
    expect(checked, 4048);
  });

  test('every formula is undone by its inverse (engine)', () {
    final labels = f.identityLabels();
    final seen = <List<int>>{};
    for (final (a, b, c) in allCycles()) {
      final ids = lib.cycleIds(a, b, c);
      if (!seen.add(ids)) continue;
      final seq = lib.cycle(a, b, c);
      final engine = f.build(labels)
        ..applyAll(seq)
        ..applyAll(inverseOf(seq));
      expect(f.read(engine), labels);
      // ... and the inverse formula is the reverse cycle.
      final reverse = f.build(labels)..applyAll(inverseOf(seq));
      final after = f.read(reverse);
      expect(after[a], labels[b]);
      expect(after[b], labels[c]);
      expect(after[c], labels[a]);
    }
  });

  test('formulas only use legal 4x4 moves and are 8–12 moves long', () {
    for (final (a, b, c) in allCycles()) {
      final seq = lib.cycle(a, b, c);
      expect(seq.length, inInclusiveRange(8, 12));
      for (final m in seq) {
        expect(table.indexOf(m), isNonNegative); // throws if illegal
      }
    }
  });

  test('rejects orbits that do not exist on this order', () {
    expect(() => CenterCycleLibrary.build(4, SlotKind.centerFixed),
        throwsArgumentError);
    expect(() => lib.cycleIds(orbit[0], orbit[0], orbit[1]), throwsArgumentError);
  });
}
