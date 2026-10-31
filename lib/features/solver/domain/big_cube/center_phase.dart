import '../../../../core/nxn/nxn_cube_state.dart';
import '../../../../core/nxn/nxn_facelets.dart';
import 'center_search.dart';
import 'center_solver.dart';
import 'edge_pairer.dart';
import 'parity_algorithms.dart';
import 'solve_step.dart';
import 'target_scheme.dart';

/// The centre phase of the reduction, in as few turns as it can:
///
/// 1. [CenterSearch.greedy]: short sequences of any legal turns, wide ones
///    included (edges and corners are free to move at this point).
/// 2. Pure 3-cycles ([CenterOrbitSolver]) for whatever the search leaves.
/// 3. Parity, decided early: a wing permutation's parity can only change
///    by a turn of an inner (wing) layer. Whether the cube will need a parity
///    formula after pairing (4x4 OLL parity, 5x5 edge parity) is therefore
///    fixed once the centres are done. If the first attempt leaves it odd,
///    the phase is retried with each of a few other good opening turns, and
///    the attempt with the fewest turns — counting the 15-turn parity formula
///    it would need later — wins.
///
/// Every sequence is applied to the real engine state and checked.
abstract final class CenterPhase {
  /// Alternative opening turns tried when parity comes out odd.
  static const alternatives = 3;

  /// [scheme]: 4x4 — the target colours per face; 5x5 — the fixed centres'
  /// colours at the start (the target follows the fixed centres).
  ///
  /// Solves the centres of [state] in place with the cheapest attempt by
  /// [CentreAttempt.cost].
  static SolveFailure? solve(
    NxnCubeState state,
    TargetScheme scheme,
    List<SolveStep> steps, {
    required DateTime deadline,
  }) {
    final all = attempts(state, scheme, deadline: deadline);
    final ok = [for (final a in all) if (a.failure == null) a];
    if (ok.isEmpty) return all.first.failure;
    ok.sort((a, b) => a.cost.compareTo(b.cost));
    return apply(state, scheme, ok.first, steps);
  }

  /// Candidate centre phases, each on its own copy of [state]: the search
  /// as is; with the 4x4 parity flip appended if its wings come out odd;
  /// and, while parity is odd, the search after each of a few other good
  /// opening turns. Callers compare them (e.g. by also pairing the edges).
  static List<CentreAttempt> attempts(
    NxnCubeState state,
    TargetScheme scheme, {
    required DateTime deadline,
  }) {
    final n = state.n;
    for (final (kind, label) in [
      (SlotKind.centerX, n == 4 ? '中心块' : '角中心块'),
      if (n == 5) (SlotKind.centerT, '棱中心块'),
    ]) {
      final counts = CenterOrbitSolver.checkCounts(state, kind, scheme, label);
      if (counts != null) return [CentreAttempt._fail(counts)];
    }
    final search = CenterSearch(n);
    final ci = {for (var k = 0; k < 6; k++) scheme.faceColors[k]: k};
    final start = search.read(state, ci);
    if (start == null) {
      return [
        CentreAttempt._fail(const SolveFailure(
            SolveFailureKind.invalidInput, '中心块上有无法识别的颜色')),
      ];
    }
    final target = n == 4 ? const [0, 1, 2, 3, 4, 5] : null;

    final out = <CentreAttempt>[];
    void add(CentreAttempt a) {
      out.add(a);
      if (n == 4 && a.failure == null && a.parity == 1) {
        out.add(a._withParityFlip(scheme));
      }
    }

    final first = _attempt(state, scheme, null, deadline);
    add(first);
    if (first.failure != null || first.parity == 0) return out;
    // Other good openings: the best single turns by centres gained.
    final gains = <(int, int)>[];
    final base = search.solved(start, target);
    for (var mi = 0; mi < search.moves.length; mi++) {
      final c = start.sublist(0);
      search.apply(c, mi);
      gains.add((search.solved(c, target) - base, mi));
    }
    gains.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (_, mi) in gains.take(alternatives)) {
      if (!DateTime.now().isBefore(deadline)) break;
      add(_attempt(state, scheme, mi, deadline));
    }
    return out;
  }

  /// Replays [attempt] on the real [state], checking every step.
  static SolveFailure? apply(NxnCubeState state, TargetScheme scheme,
      CentreAttempt attempt, List<SolveStep> steps) {
    final f = NxnFacelets(state.n);
    for (final step in attempt.steps) {
      final before = f.read(state);
      state.applyAll(step.moves);
      if (step.description.startsWith('拼中心：') &&
          _solvedCount(state, scheme) <= _solvedCount(f.build(before), scheme)) {
        return const SolveFailure(SolveFailureKind.internal, '拼中心的步骤没有增加已完成的中心');
      }
      steps.add(step);
    }
    if (!_allSolved(state, scheme)) {
      return const SolveFailure(SolveFailureKind.internal, '拼中心后中心没有全部完成');
    }
    return null;
  }

  /// One complete centre phase on a copy of [input], optionally opening
  /// with turn [opening].
  static CentreAttempt _attempt(
    NxnCubeState input,
    TargetScheme scheme,
    int? opening,
    DateTime deadline,
  ) {
    final n = input.n;
    final search = CenterSearch(n);
    final s = input.copy();
    final steps = <SolveStep>[];
    final ci = {for (var k = 0; k < 6; k++) scheme.faceColors[k]: k};
    final target = n == 4 ? const [0, 1, 2, 3, 4, 5] : null;
    if (opening != null) {
      final b = search.moves[opening];
      s.applyBlock(b);
      steps.add(SolveStep.turns(
          phase: ReductionPhase.centers, description: '拼中心（换一种开局）', blocks: [b]));
    }
    final colors = search.read(s, ci)!;
    var solved = search.solved(colors, target);
    for (final seq in search.greedy(colors, target, deadline: deadline)) {
      final blocks = [for (final mi in seq) search.moves[mi]];
      for (final b in blocks) {
        s.applyBlock(b);
      }
      final now = search.solved(search.read(s, ci)!, target);
      steps.add(SolveStep.turns(
        phase: ReductionPhase.centers,
        description: '拼中心：多放好 ${now - solved} 块',
        blocks: blocks,
      ));
      solved = now;
    }
    // Leftovers: pure 3-cycles, per orbit, against the current targets.
    final current = n == 4 ? scheme : TargetScheme.fromFixedCenters(s)!;
    for (final (kind, label) in [
      (SlotKind.centerX, n == 4 ? '中心块' : '角中心块'),
      if (n == 5) (SlotKind.centerT, '棱中心块'),
    ]) {
      final failure = CenterOrbitSolver.solve(s, kind, current, steps,
          deadline: deadline, label: label);
      if (failure != null) return CentreAttempt._fail(failure);
    }
    final parity = EdgePairer.wingParity(s, current);
    if (parity == null) {
      return CentreAttempt._fail(
          const SolveFailure(SolveFailureKind.invalidInput, '棱块颜色不合法'));
    }
    return CentreAttempt._(steps, s, parity);
  }

  static int _solvedCount(NxnCubeState s, TargetScheme scheme) {
    final search = CenterSearch(s.n);
    final ci = {for (var k = 0; k < 6; k++) scheme.faceColors[k]: k};
    final c = search.read(s, ci);
    if (c == null) return -1;
    return search.solved(c, s.n == 4 ? const [0, 1, 2, 3, 4, 5] : null);
  }

  static bool _allSolved(NxnCubeState s, TargetScheme scheme) =>
      _solvedCount(s, scheme) == CenterSearch(s.n).solvableCount;
}

/// One candidate centre phase (see [CenterPhase.attempts]).
class CentreAttempt {
  CentreAttempt._(this.steps, this.state, this.parity) : failure = null;
  CentreAttempt._fail(this.failure)
      : steps = const [],
        state = null,
        parity = 0;

  final List<SolveStep> steps;

  /// The cube after [steps] (a copy).
  final NxnCubeState? state;

  /// Wing parity left for after pairing (1: a parity formula will be needed).
  final int parity;
  final SolveFailure? failure;

  int get turns => steps.fold(0, (a, st) => a + st.blocks.length);

  /// Turns, plus the parity formula this attempt would need later.
  int get cost {
    if (failure != null) return 1 << 30;
    final n = state!.n;
    final formula = ParityAlgorithms.moves(
            n == 4 ? ParityAlgorithms.ollFour : ParityAlgorithms.edgeFive, n)
        .length;
    return turns + parity * formula;
  }

  /// 4x4: this attempt followed by the 7-turn centre-preserving parity flip.
  CentreAttempt _withParityFlip(TargetScheme scheme) {
    final s = state!.copy();
    for (final b in ParityAlgorithms.centreParityFour) {
      s.applyBlock(b);
    }
    final parity = EdgePairer.wingParity(s, scheme) ?? 1;
    return CentreAttempt._([
      ...steps,
      SolveStep.turns(
        phase: ReductionPhase.centers,
        description: '中心不变，预先消除 OLL 奇偶',
        blocks: ParityAlgorithms.centreParityFour,
      ),
    ], s, parity);
  }
}
