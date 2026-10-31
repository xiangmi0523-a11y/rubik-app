import '../solver/facelet_solver.dart';
import 'pyraminx_model.dart';

/// Result of checking / solving a Pyraminx colouring.
class PyraminxSolveResult {
  const PyraminxSolveResult.solved(this.moves) : error = null;
  const PyraminxSolveResult.invalid(this.error) : moves = const [];

  final List<PyraminxMove> moves;
  final String? error;

  bool get ok => error == null;
}

/// Solves any Pyraminx: optimal layer turns (≤ 11) by meet-in-the-middle,
/// then the four tips.
abstract final class PyraminxSolver {
  static final _slots = PyraminxGeometry.slots;

  static List<int> _region(int axis, {required bool tip}) => [
        for (var i = 0; i < _slots.length; i++)
          if (PyraminxGeometry.inRegion(_slots[i], axis, tip)) i,
      ];

  /// Tip stickers of each vertex.
  static final List<List<int>> tips = [
    for (var a = 0; a < 4; a++) _region(a, tip: true),
  ];

  /// Centre stickers of each vertex (in its layer, not its tip, and in no
  /// other vertex's layer).
  static final List<List<int>> centers = [
    for (var a = 0; a < 4; a++)
      [
        for (final i in _region(a, tip: false))
          if (!tips[a].contains(i) &&
              [for (var b = 0; b < 4; b++) if (b != a) b]
                  .every((b) => !PyraminxGeometry.inRegion(_slots[i], b, false)))
            i,
      ],
  ];

  static final FaceletPuzzle _puzzle = () {
    final moves = <PyraminxMove>[
      for (var a = 0; a < 4; a++) ...[
        PyraminxMove(a),
        PyraminxMove(a, clockwise: false),
      ],
    ];
    return FaceletPuzzle(
      moves: [for (final m in moves) PyraminxState.permutation(m)],
      names: [for (final m in moves) m.notation],
      axes: [for (final m in moves) m.axis],
      inverses: [for (var i = 0; i < moves.length; i++) i ^ 1],
    );
  }();

  static final List<PyraminxMove> _layerMoves = [
    for (var a = 0; a < 4; a++) ...[
      PyraminxMove(a),
      PyraminxMove(a, clockwise: false),
    ],
  ];

  /// Face colour of each face, inferred from the centre pieces, or null if
  /// the centres are inconsistent.
  static List<int>? inferFaceColors(List<int> colors) {
    final faceColor = List<int>.filled(4, -1);
    for (var a = 0; a < 4; a++) {
      final seen = {for (final i in centers[a]) colors[i]};
      if (seen.length != 3 || seen.contains(-1)) return null;
      final missing = {0, 1, 2, 3}.difference(seen);
      if (missing.length != 1) return null;
      faceColor[a] = missing.first; // face a is opposite vertex a
    }
    if (faceColor.toSet().length != 4) return null;
    return faceColor;
  }

  static PyraminxSolveResult solve(List<int> colors) {
    if (colors.contains(-1)) {
      final n = colors.where((c) => c == -1).length;
      return PyraminxSolveResult.invalid('还有 $n 个色块没有填色');
    }
    for (var c = 0; c < 4; c++) {
      final n = colors.where((x) => x == c).length;
      if (n != 9) {
        return PyraminxSolveResult.invalid('有一种颜色出现了 $n 次，应为 9 次');
      }
    }
    final faceColor = inferFaceColors(colors);
    if (faceColor == null) {
      return const PyraminxSolveResult.invalid('中心块颜色组合不可能，请检查三个面交汇处的颜色');
    }
    final target = [for (final s in _slots) faceColor[s.face]];
    final mask = [
      for (var i = 0; i < _slots.length; i++) !tips.any((t) => t.contains(i)),
    ];
    final layer = solveFacelets(_puzzle, colors, target, mask: mask);
    if (layer == null) {
      return const PyraminxSolveResult.invalid('棱块状态不可能（可能有棱块被翻转或填错）');
    }
    final moves = [for (final i in layer) _layerMoves[i]];
    final state = PyraminxState([...colors])..applyAll(moves);

    // Tips: 0, 1 or 2 clockwise turns each.
    for (var a = 0; a < 4; a++) {
      var ok = false;
      for (final turn in <PyraminxMove?>[
        null,
        PyraminxMove(a, tip: true),
        PyraminxMove(a, tip: true, clockwise: false),
      ]) {
        final trial = state.copy();
        if (turn != null) trial.apply(turn);
        if (tips[a].every((i) => trial.colors[i] == target[i])) {
          if (turn != null) {
            state.apply(turn);
            moves.add(turn);
          }
          ok = true;
          break;
        }
      }
      if (!ok) {
        return const PyraminxSolveResult.invalid('顶角颜色组合不可能，请检查小顶角的颜色');
      }
    }
    return PyraminxSolveResult.solved(moves);
  }
}
