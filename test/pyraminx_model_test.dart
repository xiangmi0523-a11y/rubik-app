import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/core/pyraminx/pyraminx_model.dart';

void main() {
  test('36 slots, 9 per face', () {
    expect(PyraminxGeometry.slots, hasLength(36));
    for (var f = 0; f < 4; f++) {
      expect(PyraminxGeometry.slots.where((s) => s.face == f), hasLength(9));
    }
  });

  test('every move is a permutation and has order 3', () {
    for (var axis = 0; axis < 4; axis++) {
      for (final tip in [true, false]) {
        final m = PyraminxMove(axis, tip: tip);
        expect(PyraminxState.permutation(m).toSet(), hasLength(36));
        final s = PyraminxState.solved()..applyAll([m, m]);
        expect(s.isSolved, isFalse);
        s.apply(m);
        expect(s.isSolved, isTrue);
      }
    }
  });

  test('a tip turn moves 3 stickers, a layer turn moves 3 + 9', () {
    for (var axis = 0; axis < 4; axis++) {
      int moved(bool tip) {
        final p = PyraminxState.permutation(PyraminxMove(axis, tip: tip));
        return [for (var i = 0; i < 36; i++) if (p[i] != i) i].length;
      }
      expect(moved(true), 3);
      expect(moved(false), 12);
    }
  });

  test('notation round trip and inverse', () {
    final moves = PyraminxMove.parseAll("U L' r b' B");
    expect(moves.map((m) => m.notation).join(' '), "U L' r b' B");
    final s = PyraminxState.solved()..applyAll(moves);
    s.applyAll(moves.reversed.map((m) => m.inverse));
    expect(s.isSolved, isTrue);
  });
}
