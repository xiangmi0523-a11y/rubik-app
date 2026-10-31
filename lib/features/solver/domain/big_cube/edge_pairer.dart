import '../../../../core/nxn/nxn_cube_state.dart';
import '../../../../core/nxn/nxn_facelets.dart';
import 'cycle_library.dart';
import 'edge_layout.dart';
import 'parity_algorithms.dart';
import 'solve_step.dart';
import 'target_scheme.dart';

/// Pairs the wings of a 4x4 / 5x5 with pure wing 3-cycles
/// ([PieceCycleLibrary.wings]).
///
/// A wing piece is identified by its two colours (named sticker first); on a
/// legal cube all 24 are different, and a wing can never flip in place, so
/// the two wings of a dedge are always each other's mirror twin.
///
/// * 4x4: any arrangement of the 12 dedges will do. A minimum-cost assignment
///   of dedges to edge positions (the Hungarian method on "wings that must
///   move") picks the target; 3-cycles are even permutations, so if the wings
///   are an odd permutation away from it, one dedge is flipped in the target.
///   That flipped dedge is the OLL parity, fixed later on the reduced cube.
/// * 5x5: the middle edges fix the target of every wing. If it is an odd
///   permutation away, the two wings of UF are swapped in the target and
///   [ParityAlgorithms.edgeFive] swaps them back at the end (edge parity).
///
/// Each 3-cycle step solves at least one more wing and never breaks a solved
/// one, and only wing stickers move (centres, corners and middle edges are
/// exactly unchanged), all checked on the real engine after every step.
abstract final class EdgePairer {
  static SolveFailure _invalid(String m) =>
      SolveFailure(SolveFailureKind.invalidInput, m);
  static SolveFailure _internal(String m) =>
      SolveFailure(SolveFailureKind.internal, m);

  /// Wing piece keys (named colour × 6 + other colour) of every wing
  /// position, or null if a sticker isn't a scheme colour.
  static List<int>? _keys(List<int> colors, EdgeLayout layout, Map<int, int> ci) {
    final out = <int>[];
    for (final w in layout.wingSlots) {
      final a = ci[colors[w.named]], b = ci[colors[w.other]];
      if (a == null || b == null) return null;
      out.add(a * 6 + b);
    }
    return out;
  }

  static Map<int, int> _colorIndex(TargetScheme scheme) =>
      {for (var i = 0; i < 6; i++) scheme.faceColors[i]: i};

  /// Checks the 24 wings are the 24 different legal wing pieces.
  static SolveFailure? _checkWings(List<int>? keys) {
    if (keys == null) return _invalid('棱块上有无法识别的颜色');
    final set = keys.toSet();
    if (set.length != 24) return _invalid('棱块颜色不合法：有重复的小棱块');
    for (final k in keys) {
      final a = k ~/ 6, b = k % 6;
      if (a == b || (a + 3) % 6 == b) {
        return _invalid('棱块颜色不合法：出现了不可能的颜色组合');
      }
      if (!set.contains(b * 6 + a)) {
        return _invalid('棱块颜色不合法：小棱块缺少与之配对的另一半');
      }
    }
    return null;
  }

  /// Parity of the permutation taking [current] to [target] (both lists of
  /// distinct keys over the same set): 0 even, 1 odd.
  static int _parity(List<int> current, List<int> target) {
    final posInTarget = {for (var i = 0; i < target.length; i++) target[i]: i};
    final seen = List<bool>.filled(current.length, false);
    var cycles = 0;
    for (var i = 0; i < current.length; i++) {
      if (seen[i]) continue;
      cycles++;
      var j = i;
      while (!seen[j]) {
        seen[j] = true;
        j = posInTarget[current[j]]!;
      }
    }
    return (current.length - cycles) & 1;
  }

  // ── 4x4 ─────────────────────────────────────────────────────────────────

  /// Pairs the 12 dedges of a 4x4 in place, appending steps to [steps].
  static SolveFailure? pairFour(
    NxnCubeState state,
    TargetScheme scheme,
    List<SolveStep> steps, {
    required DateTime deadline,
  }) {
    final layout = EdgeLayout(4);
    final f = NxnFacelets(4);
    final ci = _colorIndex(scheme);
    final keys = _keys(f.read(state), layout, ci);
    final bad = _checkWings(keys);
    if (bad != null) return bad;
    final cur = keys!;

    // Dedges by colour pair (a < b); wing pieces (a,b) and (b,a).
    final dedges = <(int, int)>[
      for (final k in cur)
        if (k ~/ 6 < k % 6) (k ~/ 6, k % 6),
    ];
    // Required keys at (w0, w1) for dedge d at edge e, option o.
    (int, int) req((int, int) d, int o) {
      final ab = d.$1 * 6 + d.$2, ba = d.$2 * 6 + d.$1;
      return o == 0 ? (ab, ba) : (ba, ab);
    }

    int cost((int, int) d, int e, int o) {
      final (r0, r1) = req(d, o);
      return (cur[2 * e] == r0 ? 0 : 1) + (cur[2 * e + 1] == r1 ? 0 : 1);
    }

    final costs = [
      for (final d in dedges)
        [for (var e = 0; e < 12; e++) _min(cost(d, e, 0), cost(d, e, 1))],
    ];
    final assign = _hungarian(costs); // dedge → edge
    final option = List<int>.filled(12, 0); // per edge
    final dedgeAt = List<int>.filled(12, 0);
    for (var d = 0; d < 12; d++) {
      final e = assign[d];
      dedgeAt[e] = d;
      option[e] = cost(dedges[d], e, 0) <= cost(dedges[d], e, 1) ? 0 : 1;
    }
    List<int> buildTarget() => [
          for (var e = 0; e < 12; e++) ...() {
            final (r0, r1) = req(dedges[dedgeAt[e]], option[e]);
            return [r0, r1];
          }(),
        ];
    var target = buildTarget();
    if (_parity(cur, target) == 1) {
      // Flip the dedge that costs least to flip (OLL parity, fixed later).
      var bestE = 0, bestDelta = 1 << 30;
      for (var e = 0; e < 12; e++) {
        final d = dedges[dedgeAt[e]];
        final delta = cost(d, e, 1 - option[e]) - cost(d, e, option[e]);
        if (delta < bestDelta) {
          bestDelta = delta;
          bestE = e;
        }
      }
      option[bestE] = 1 - option[bestE];
      target = buildTarget();
    }

    final failure = _solveWings(state, target, layout, ci, steps, deadline);
    if (failure != null) return failure;
    if (!layout.allPaired(f.read(state))) return _internal('配对后仍有棱块未配好');
    return null;
  }

  // ── 5x5 ─────────────────────────────────────────────────────────────────

  /// Puts every 5x5 wing next to its middle edge, in place.
  static SolveFailure? pairFive(
    NxnCubeState state,
    TargetScheme scheme,
    List<SolveStep> steps, {
    required DateTime deadline,
  }) {
    final layout = EdgeLayout(5);
    final f = NxnFacelets(5);
    final ci = _colorIndex(scheme);
    final colors = f.read(state);
    final keys = _keys(colors, layout, ci);
    final bad = _checkWings(keys);
    if (bad != null) return bad;
    final cur = keys!;

    // Target of each wing position: the colours of its middle edge.
    final target = <int>[];
    for (final e in layout.edges) {
      final (ma, mb) = e.midge!;
      final onFace = {f.faceOf[ma]: colors[ma], f.faceOf[mb]: colors[mb]};
      for (final w in e.wings) {
        final a = ci[onFace[f.faceOf[w.named]]];
        final b = ci[onFace[f.faceOf[w.other]]];
        if (a == null || b == null) return _invalid('中棱上有无法识别的颜色');
        target.add(a * 6 + b);
      }
    }
    if (target.toSet().length != 24 ||
        !target.toSet().containsAll(cur) ||
        !cur.toSet().containsAll(target)) {
      return _invalid('小棱块与中棱的颜色对不上');
    }

    final uf = layout.edgeNamed('UF');
    final parity = _parity(cur, target) == 1;
    if (parity) {
      final i = 2 * uf.index;
      final t = target[i];
      target[i] = target[i + 1];
      target[i + 1] = t;
    }

    final failure = _solveWings(state, target, layout, ci, steps, deadline);
    if (failure != null) return failure;

    if (parity) {
      final before = f.read(state);
      final moves = ParityAlgorithms.moves(ParityAlgorithms.edgeFive, 5);
      state.applyAll(moves);
      final after = f.read(state);
      final ufSlots = {for (final w in uf.wings) ...[w.named, w.other]};
      for (var i = 0; i < f.count; i++) {
        if (!ufSlots.contains(i) && after[i] != before[i]) {
          return _internal('棱块奇偶公式改动了其他贴纸');
        }
      }
      steps.add(SolveStep(
        phase: ReductionPhase.parity,
        description: '棱块奇偶：${uf.name} 棱',
        moves: moves,
      ));
    }
    if (!layout.allPaired(f.read(state))) return _internal('配对后仍有棱块未配好');
    return null;
  }

  // ── Shared 3-cycle solve ────────────────────────────────────────────────

  /// Moves every wing piece to the position [target] gives it, with pure
  /// wing 3-cycles. [target] must be an even permutation of the current
  /// arrangement.
  static SolveFailure? _solveWings(
    NxnCubeState state,
    List<int> target,
    EdgeLayout layout,
    Map<int, int> ci,
    List<SolveStep> steps,
    DateTime deadline,
  ) {
    final f = NxnFacelets(state.n);
    final lib = PieceCycleLibrary.wings(state.n);
    final wings = layout.wingSlots;
    var colors = f.read(state);
    var cur = _keys(colors, layout, ci)!;
    if (_parity(cur, target) != 0) return _internal('棱块目标排列的奇偶性不对');

    while (true) {
      final wrong = [for (var w = 0; w < 24; w++) if (cur[w] != target[w]) w];
      if (wrong.isEmpty) return null;
      if (!DateTime.now().isBefore(deadline)) {
        return const SolveFailure(SolveFailureKind.timeout, '配对棱块超时');
      }
      final holder = {for (var w = 0; w < 24; w++) cur[w]: w};

      // Best (p, x): piece for p comes from q, p's piece goes to x, x's to q.
      List<int>? best;
      var bestGain = -1, bestP = -1;
      for (final p in wrong) {
        final q = holder[target[p]]!;
        for (final x in wrong) {
          if (x == p || x == q) continue;
          final gain = 1 +
              (target[x] == cur[p] ? 1 : 0) +
              (target[q] == cur[x] ? 1 : 0);
          final seq = lib.cycleIds(wings[q].named, wings[p].named, wings[x].named);
          if (gain > bestGain || (gain == bestGain && seq.length < best!.length)) {
            bestGain = gain;
            best = seq;
            bestP = p;
          }
        }
      }
      if (best == null) return _internal('只剩两个小棱块互换，无法用三循环完成');

      final before = colors;
      final beforeKeys = cur;
      final moves = [for (final m in best) lib.table.moves[m]];
      state.applyAll(moves);
      colors = f.read(state);
      cur = _keys(colors, layout, ci)!;
      for (var i = 0; i < f.count; i++) {
        if (f.kindOf[i] != SlotKind.wing && colors[i] != before[i]) {
          return _internal('配对公式改动了非棱块贴纸');
        }
      }
      for (var w = 0; w < 24; w++) {
        if (beforeKeys[w] == target[w] && cur[w] != target[w]) {
          return _internal('配对公式破坏了已放好的小棱块');
        }
      }
      if (cur[bestP] != target[bestP]) return _internal('配对公式没有放好目标小棱块');
      steps.add(SolveStep(
        phase: ReductionPhase.edges,
        description: '配对：${layout.edgeOfWing(bestP).name} 棱',
        moves: moves,
      ));
    }
  }

  static int _min(int a, int b) => a < b ? a : b;

  /// Minimum-cost perfect matching of a square cost matrix (Hungarian
  /// method, O(n³)). Returns the column assigned to each row.
  static List<int> _hungarian(List<List<int>> a) {
    final n = a.length;
    const inf = 1 << 40;
    final u = List<int>.filled(n + 1, 0), v = List<int>.filled(n + 1, 0);
    final p = List<int>.filled(n + 1, 0), way = List<int>.filled(n + 1, 0);
    for (var i = 1; i <= n; i++) {
      p[0] = i;
      var j0 = 0;
      final minv = List<int>.filled(n + 1, inf);
      final used = List<bool>.filled(n + 1, false);
      do {
        used[j0] = true;
        final i0 = p[j0];
        var delta = inf, j1 = 0;
        for (var j = 1; j <= n; j++) {
          if (used[j]) continue;
          final cur = a[i0 - 1][j - 1] - u[i0] - v[j];
          if (cur < minv[j]) {
            minv[j] = cur;
            way[j] = j0;
          }
          if (minv[j] < delta) {
            delta = minv[j];
            j1 = j;
          }
        }
        for (var j = 0; j <= n; j++) {
          if (used[j]) {
            u[p[j]] += delta;
            v[j] -= delta;
          } else {
            minv[j] -= delta;
          }
        }
        j0 = j1;
      } while (p[j0] != 0);
      do {
        final j1 = way[j0];
        p[j0] = p[j1];
        j0 = j1;
      } while (j0 != 0);
    }
    final result = List<int>.filled(n, 0);
    for (var j = 1; j <= n; j++) {
      result[p[j] - 1] = j - 1;
    }
    return result;
  }
}
