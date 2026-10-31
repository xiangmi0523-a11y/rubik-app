import 'package:flutter/painting.dart';

import '../../../core/nxn/nxn_cube_state.dart';
import '../../../core/solver/facelet_solver.dart';

/// Result of solving a 2x2 colouring.
class TwoByTwoResult {
  const TwoByTwoResult.solved(this.moves) : error = null;
  const TwoByTwoResult.invalid(this.error) : moves = const [];

  final List<NxnMove> moves;
  final String? error;
  bool get ok => error == null;
}

/// Optimal 2x2 solver (≤ 11 moves) using only U, R and F, so the
/// down-back-left corner never moves: the solved colours are read off that
/// corner, and the cube can be held in any orientation.
abstract final class TwoByTwoSolver {
  /// Sticker slots in a fixed order: (cubie position, outward normal).
  static final List<(IVec, IVec)> slots = [
    for (final c in NxnCubeState.solved(2).cubies)
      for (final n in c.stickers.keys) (c.pos, n),
  ];

  static const _palette = [
    Color(0xFFFFFFFF), Color(0xFFFFEB3B), Color(0xFF4CAF50),
    Color(0xFF2196F3), Color(0xFFF44336), Color(0xFFFF9800),
  ];

  /// Opposite colours of the standard scheme (index into [_palette]).
  static const _opposite = [1, 0, 3, 2, 5, 4];

  static final List<NxnMove> _moves = [
    for (final axis in [1, 0, 2]) // U, R, F
      for (final turns in [-1, 1, 2]) NxnMove(axis, 1, turns),
  ];

  static final FaceletPuzzle _puzzle = FaceletPuzzle(
    moves: [for (final m in _moves) _permutation(m)],
    names: [for (final m in _moves) m.notation(2)],
    axes: [for (final m in _moves) m.axis],
    inverses: [
      for (final m in _moves) _moves.indexOf(m.inverse),
    ],
  );

  static List<int> _permutation(NxnMove move) {
    // Label every slot with its own index as a colour, apply, read back.
    final s = NxnCubeState.solved(2);
    for (final c in s.cubies) {
      for (final n in [...c.stickers.keys]) {
        c.stickers[n] = Color(slots.indexOf((c.pos, n)));
      }
    }
    s.apply(move);
    final perm = List<int>.filled(slots.length, 0);
    for (var i = 0; i < slots.length; i++) {
      final (pos, n) = slots[i];
      final label = s.stickerAt(pos, n)!.toARGB32();
      perm[label] = i;
    }
    return perm;
  }

  static int _colorIndex(Color c) =>
      _palette.indexWhere((p) => p.toARGB32() == c.toARGB32());

  /// Colours of [state] as palette indices in [slots] order (-1 = blank).
  static List<int> read(NxnCubeState state) => [
        for (final (pos, n) in slots) _colorIndex(state.stickerAt(pos, n)!),
      ];

  static TwoByTwoResult solve(NxnCubeState state) {
    final colors = read(state);
    final blank = colors.where((c) => c < 0).length;
    if (blank > 0) return TwoByTwoResult.invalid('还有 $blank 个色块没有填色');
    for (var c = 0; c < 6; c++) {
      final n = colors.where((x) => x == c).length;
      if (n != 4) return TwoByTwoResult.invalid('有一种颜色出现了 $n 次，应为 4 次');
    }
    // Fixed corner: down-back-left.
    int at(IVec normal) => colors[slots.indexOf(((-1, -1, -1), normal))];
    final d = at((0, -1, 0)), l = at((-1, 0, 0)), b = at((0, 0, -1));
    if ({d, l, b}.length != 3 ||
        _opposite[d] == l || _opposite[d] == b || _opposite[l] == b) {
      return const TwoByTwoResult.invalid('左后下角块的颜色组合不可能，请检查');
    }
    final faceColor = <IVec, int>{
      (0, -1, 0): d, (0, 1, 0): _opposite[d],
      (-1, 0, 0): l, (1, 0, 0): _opposite[l],
      (0, 0, -1): b, (0, 0, 1): _opposite[b],
    };
    final target = [for (final (_, n) in slots) faceColor[n]!];
    final path = solveFacelets(_puzzle, colors, target);
    if (path == null) {
      return const TwoByTwoResult.invalid('这个状态无法还原（可能有角块被单独拧转或填错）');
    }
    return TwoByTwoResult.solved([for (final i in path) _moves[i]]);
  }
}
