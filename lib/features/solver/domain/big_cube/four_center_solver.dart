import '../../../../core/nxn/nxn_cube_state.dart';
import '../../../../core/nxn/nxn_facelets.dart';
import 'center_cycle_library.dart';
import 'solve_step.dart';
import 'target_scheme.dart';

/// Result of solving the 24 centre stickers of a 4x4.
class CenterSolveResult {
  CenterSolveResult._({
    required this.steps,
    required this.state,
    this.target,
    this.failure,
  });

  /// One entry per formula, in order.
  final List<SolveStep> steps;

  /// The cube after the steps (a copy; the input is never modified).
  final NxnCubeState state;

  /// Face colours the centres were solved to (null on early failure).
  final TargetScheme? target;
  final SolveFailure? failure;

  bool get ok => failure == null;

  /// All moves, in order.
  List<NxnMove> get moves => [for (final s in steps) ...s.moves];
}

/// Solves the 4x4 centres with pure centre 3-cycles.
///
/// Every step is one entry of [CenterCycleLibrary] — a setup, a pure centre
/// commutator, and the setup undone — so corners and edges are exactly the
/// same afterwards, and only centre stickers move.
///
/// Why it always finishes: pick an unsolved slot t on face F. F's colour
/// appears 4 times; the solved slots of F hold some of them, so at least one
/// more sits in an unsolved slot s ≠ t. Cycle s → t → x with a third slot x
/// that is unsolved, or solved but will receive the colour it needs. If only
/// s and t are unsolved, counting shows t holds the colour of s's face G and
/// G's other three slots are solved, so x can be one of them and the step
/// finishes the centres. The library has every 3-cycle, so each step exists
/// and solves at least one more slot without breaking any: at most 24 steps.
abstract final class FourCenterSolver {
  static const _faceNames = ['U', 'R', 'F', 'D', 'L', 'B'];

  /// Order in which faces are completed.
  static const _faceOrder = [0, 3, 4, 1, 2, 5]; // U D L R F B

  static CenterSolveResult solve(
    NxnCubeState input, {
    Duration timeout = const Duration(seconds: 10),
    TargetScheme? target,
  }) {
    final state = input.copy();
    CenterSolveResult fail(SolveFailureKind kind, String message,
            [List<SolveStep> steps = const [], TargetScheme? t]) =>
        CenterSolveResult._(
          steps: steps,
          state: state,
          target: t,
          failure: SolveFailure(kind, message),
        );

    if (input.n != 4) {
      return fail(SolveFailureKind.invalidInput, '只能求解四阶，收到 ${input.n} 阶');
    }
    final scheme = target ?? TargetScheme.bestFor(state, SlotKind.centerX);
    if (scheme == null) {
      return fail(SolveFailureKind.invalidInput, '左后下角块颜色不合法，无法确定配色');
    }

    final f = NxnFacelets(4);
    final centres = f.slotsOfKind(SlotKind.centerX);
    var colors = f.read(state);
    for (final c in scheme.faceColors) {
      final k = centres.where((s) => colors[s] == c).length;
      if (k != 4) {
        return fail(SolveFailureKind.invalidInput,
            '中心块颜色数量不对：有一种颜色出现 $k 次，应为 4 次', const [], scheme);
      }
    }

    final library = CenterCycleLibrary.forOrbit(4, SlotKind.centerX);
    final orderedCentres = [
      for (final face in _faceOrder)
        for (final s in centres)
          if (f.faceOf[s] == face) s,
    ];
    bool solved(List<int> col, int s) => col[s] == scheme.faceColors[f.faceOf[s]];

    final steps = <SolveStep>[];
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final unsolved = [for (final s in orderedCentres) if (!solved(colors, s)) s];
      if (unsolved.isEmpty) break;
      if (!DateTime.now().isBefore(deadline)) {
        return fail(SolveFailureKind.timeout, '拼中心超时', steps, scheme);
      }

      final t = unsolved.first;
      final need = scheme.faceColors[f.faceOf[t]];
      final sources = [for (final s in unsolved) if (s != t && colors[s] == need) s];
      if (sources.isEmpty) {
        return fail(SolveFailureKind.internal,
            '找不到 ${_faceNames[f.faceOf[t]]} 面需要的中心块', steps, scheme);
      }

      // Best (s, x): most stickers solved afterwards, then shortest formula.
      List<int>? best;
      var bestGain = -1 << 30;
      for (final s in sources) {
        for (final x in centres) {
          if (x == s || x == t) continue;
          final xSolved = solved(colors, x);
          final xAfter = colors[t] == scheme.faceColors[f.faceOf[x]];
          if (xSolved && !xAfter) continue; // would break a solved slot
          final sAfter = colors[x] == scheme.faceColors[f.faceOf[s]];
          final gain = 1 + (xAfter ? 1 : 0) + (sAfter ? 1 : 0) - (xSolved ? 1 : 0);
          final seq = library.cycleIds(s, t, x);
          if (gain > bestGain ||
              (gain == bestGain && seq.length < best!.length)) {
            bestGain = gain;
            best = seq;
          }
        }
      }
      if (best == null) {
        return fail(SolveFailureKind.internal, '找不到可用的中心循环', steps, scheme);
      }

      // Apply to the real engine, then check the step did what it should.
      final before = colors;
      final moves = [for (final m in best) library.table.moves[m]];
      state.applyAll(moves);
      colors = f.read(state);
      for (var i = 0; i < f.count; i++) {
        if (f.kindOf[i] != SlotKind.centerX && colors[i] != before[i]) {
          return fail(SolveFailureKind.internal, '中心公式改动了非中心贴纸', steps, scheme);
        }
        if (f.kindOf[i] == SlotKind.centerX && solved(before, i) && !solved(colors, i)) {
          return fail(SolveFailureKind.internal, '中心公式破坏了已完成的中心', steps, scheme);
        }
      }
      if (!solved(colors, t)) {
        return fail(SolveFailureKind.internal, '中心公式没有放好目标块', steps, scheme);
      }
      steps.add(SolveStep(
        phase: ReductionPhase.centers,
        description: '中心：${_faceNames[f.faceOf[t]]} 面',
        moves: moves,
      ));
    }
    return CenterSolveResult._(steps: steps, state: state, target: scheme);
  }

  /// Whether every 4x4 centre sticker matches [target].
  static bool centersSolved(NxnCubeState state, TargetScheme target) {
    final f = NxnFacelets(4);
    final colors = f.read(state);
    return f
        .slotsOfKind(SlotKind.centerX)
        .every((s) => colors[s] == target.faceColors[f.faceOf[s]]);
  }
}
