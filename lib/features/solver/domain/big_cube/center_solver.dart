import '../../../../core/nxn/nxn_cube_state.dart';
import '../../../../core/nxn/nxn_facelets.dart';
import 'cycle_library.dart';
import 'solve_step.dart';
import 'target_scheme.dart';

/// Solves one orbit of centre pieces (4x4 centres, 5x5 X- or T-centres) with
/// pure centre 3-cycles from [PieceCycleLibrary.centers].
///
/// Every step is a setup, a pure centre commutator and the setup undone, so
/// only stickers of that orbit move: corners, edges and the other centre
/// orbit are exactly the same afterwards.
///
/// Why it always finishes: pick an unsolved slot t on face F. F's colour
/// appears 4 times in the orbit; the solved slots of F hold some of them, so
/// at least one more sits in an unsolved slot s ≠ t. Cycle s → t → x with a
/// third slot x that is unsolved, or solved but will receive the colour it
/// needs. If only s and t are unsolved, counting shows t holds the colour of
/// s's face G and G's other three slots are solved, so x can be one of them
/// and the step finishes the orbit. The library has every 3-cycle, so each
/// step exists and solves at least one more slot without breaking any: at
/// most 24 steps.
abstract final class CenterOrbitSolver {
  static const faceNames = ['U', 'R', 'F', 'D', 'L', 'B'];

  /// Order in which faces are completed.
  static const _faceOrder = [0, 3, 4, 1, 2, 5]; // U D L R F B

  /// Checks that every target colour appears exactly 4 times in the orbit.
  static SolveFailure? checkCounts(
      NxnCubeState state, SlotKind kind, TargetScheme scheme, String label) {
    final f = NxnFacelets(state.n);
    final colors = f.read(state);
    final slots = f.slotsOfKind(kind);
    for (final c in scheme.faceColors) {
      final k = slots.where((s) => colors[s] == c).length;
      if (k != 4) {
        return SolveFailure(SolveFailureKind.invalidInput,
            '$label颜色数量不对：有一种颜色出现 $k 次，应为 4 次');
      }
    }
    return null;
  }

  /// Solves the [kind] centres of [state] in place to [scheme], appending one
  /// [SolveStep] per formula to [steps]. Returns null on success.
  static SolveFailure? solve(
    NxnCubeState state,
    SlotKind kind,
    TargetScheme scheme,
    List<SolveStep> steps, {
    required DateTime deadline,
    required String label,
  }) {
    final counts = checkCounts(state, kind, scheme, label);
    if (counts != null) return counts;

    final f = NxnFacelets(state.n);
    final library = PieceCycleLibrary.centers(state.n, kind);
    final centres = library.orbit;
    final ordered = [
      for (final face in _faceOrder)
        for (final s in centres)
          if (f.faceOf[s] == face) s,
    ];
    bool solved(List<int> col, int s) => col[s] == scheme.faceColors[f.faceOf[s]];
    SolveFailure internal(String m) => SolveFailure(SolveFailureKind.internal, m);

    var colors = f.read(state);
    while (true) {
      final unsolved = [for (final s in ordered) if (!solved(colors, s)) s];
      if (unsolved.isEmpty) return null;
      if (!DateTime.now().isBefore(deadline)) {
        return SolveFailure(SolveFailureKind.timeout, '$label超时');
      }

      // Best (s → t → x) over every unsolved t: most stickers solved
      // afterwards, then shortest formula. Each candidate solves t, so the
      // gain is at least 1 and no solved slot is broken.
      List<int>? best;
      var bestGain = -1 << 30;
      var bestT = -1;
      for (final t in unsolved) {
        final need = scheme.faceColors[f.faceOf[t]];
        for (final s in unsolved) {
          if (s == t || colors[s] != need) continue;
          for (final x in centres) {
            if (x == s || x == t) continue;
            final xSolved = solved(colors, x);
            final xAfter = colors[t] == scheme.faceColors[f.faceOf[x]];
            if (xSolved && !xAfter) continue; // would break a solved slot
            final sAfter = colors[x] == scheme.faceColors[f.faceOf[s]];
            final gain =
                1 + (xAfter ? 1 : 0) + (sAfter ? 1 : 0) - (xSolved ? 1 : 0);
            final seq = library.cycleIds(s, t, x);
            if (gain > bestGain ||
                (gain == bestGain && seq.length < best!.length)) {
              bestGain = gain;
              best = seq;
              bestT = t;
            }
          }
        }
      }
      if (best == null) {
        return internal('找不到 ${faceNames[f.faceOf[unsolved.first]]} 面可用的$label循环');
      }
      final t = bestT;

      // Apply to the real engine, then check the step did what it should.
      final before = colors;
      final moves = [for (final m in best) library.table.moves[m]];
      state.applyAll(moves);
      colors = f.read(state);
      for (var i = 0; i < f.count; i++) {
        if (f.kindOf[i] != kind && colors[i] != before[i]) {
          return internal('$label公式改动了其他贴纸');
        }
        if (f.kindOf[i] == kind && solved(before, i) && !solved(colors, i)) {
          return internal('$label公式破坏了已完成的块');
        }
      }
      if (!solved(colors, t)) return internal('$label公式没有放好目标块');
      steps.add(SolveStep(
        phase: ReductionPhase.centers,
        description: '$label：${faceNames[f.faceOf[t]]} 面',
        moves: moves,
      ));
    }
  }

  /// Whether every [kind] centre sticker of [state] matches [target].
  static bool solved(NxnCubeState state, SlotKind kind, TargetScheme target) {
    final f = NxnFacelets(state.n);
    final colors = f.read(state);
    return f
        .slotsOfKind(kind)
        .every((s) => colors[s] == target.faceColors[f.faceOf[s]]);
  }
}
