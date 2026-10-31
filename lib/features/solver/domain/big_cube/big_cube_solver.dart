import 'package:cuber/cuber.dart' as cuber;

import '../../../../core/nxn/nxn_cube_state.dart';
import '../../../../core/nxn/nxn_facelets.dart';
import 'center_phase.dart';
import 'center_solver.dart';
import 'edge_layout.dart';
import 'edge_pairer.dart';
import 'move_optimizer.dart';
import 'parity_algorithms.dart';
import 'reduced_three.dart';
import 'solve_step.dart';
import 'target_scheme.dart';

/// Moves [start, end) of one phase in [BigCubeSolution.moves].
class PhaseRange {
  const PhaseRange(this.phase, this.start, this.end);
  final ReductionPhase phase;
  final int start;
  final int end;

  int get length => end - start;
}

/// How [BigCubeSolver.solve] works.
enum SolveStrategy {
  /// Both strategies below; the solution with fewer turns wins.
  best,

  /// Pure commutators only (the earlier solver).
  classic,

  /// Block-turn centre search, early parity, cost-based choices.
  search,
}

/// One player turn of a solution (see [BigCubeSolution.blockSteps]).
class BlockStep {
  const BlockStep(this.phase, this.block, this.note);
  final ReductionPhase phase;
  final NxnBlockMove block;

  /// Description of the formula the turn belongs to.
  final String note;
}

/// Result of [BigCubeSolver.solve].
class BigCubeSolution {
  BigCubeSolution._({
    required this.n,
    required this.steps,
    required this.elapsed,
    this.failure,
  });

  final int n;

  /// One entry per formula, in order, tagged with its phase.
  final List<SolveStep> steps;
  final Duration elapsed;
  final SolveFailure? failure;

  bool get ok => failure == null;

  /// All moves, in order.
  List<NxnMove> get moves => [for (final s in steps) ...s.moves];

  /// The solution as player turns, one per step: each step's (possibly
  /// wide) turns, tagged with the step's phase and description. Same effect
  /// as [moves].
  List<BlockStep> get blockSteps => [
        for (final s in steps)
          for (final b in s.blocks) BlockStep(s.phase, b, s.description),
      ];

  /// Contiguous move ranges per phase, in solve order (phases with no moves
  /// are left out).
  List<PhaseRange> get phases {
    final out = <PhaseRange>[];
    var at = 0;
    for (final s in steps) {
      if (s.moves.isEmpty) continue;
      if (out.isNotEmpty && out.last.phase == s.phase) {
        out[out.length - 1] = PhaseRange(s.phase, out.last.start, at + s.moves.length);
      } else {
        out.add(PhaseRange(s.phase, at, at + s.moves.length));
      }
      at += s.moves.length;
    }
    return out;
  }
}

/// Reduction solver for 4x4 and 5x5:
///
/// 4x4: centres → 12 dedges → OLL parity → PLL parity → 3x3 (cuber).
/// 5x5: X-centres → T-centres → 12 tredges (+ edge parity) → 3x3 (cuber).
///
/// Every phase runs on the real [NxnCubeState] and checks its own result;
/// at the end the whole move list is replayed on a fresh copy of the input,
/// which must come out solved, or the solve is reported as an internal
/// failure. The input is never modified.
abstract final class BigCubeSolver {
  static BigCubeSolution solve(
    NxnCubeState input, {
    Duration timeout = const Duration(seconds: 30),
    bool optimize = true,
    SolveStrategy strategy = SolveStrategy.best,
  }) {
    final sw = Stopwatch()..start();
    final deadline = DateTime.now().add(timeout);
    BigCubeSolution done((List<SolveStep>, SolveFailure?) r) => BigCubeSolution._(
        n: input.n, steps: r.$1, elapsed: sw.elapsed, failure: r.$2);
    if (input.n != 4 && input.n != 5) {
      return done((
        const [],
        SolveFailure(SolveFailureKind.invalidInput, '只能求解四阶和五阶，收到 ${input.n} 阶'),
      ));
    }
    // Classic first: pure commutators, fast, the result is never worse than
    // the earlier solver. Then the block-turn search; the shorter one wins.
    if (strategy == SolveStrategy.search) {
      return done(_run(input, deadline, optimize, search: true));
    }
    final classic = _run(input, deadline, optimize, search: false);
    if (strategy == SolveStrategy.classic ||
        classic.$2?.kind == SolveFailureKind.invalidInput ||
        !DateTime.now().isBefore(deadline)) {
      return done(classic);
    }
    final searched = _run(input, deadline, optimize, search: true);
    if (searched.$2 != null) return done(classic.$2 == null ? classic : searched);
    if (classic.$2 != null) return done(searched);
    int turns(List<SolveStep> st) => st.fold(0, (a, s) => a + s.blocks.length);
    return done(turns(searched.$1) < turns(classic.$1) ? searched : classic);
  }

  /// One complete solve of a copy of [input]; the steps are optimized and
  /// replayed on another fresh copy, which must come out solved.
  static (List<SolveStep>, SolveFailure?) _run(
    NxnCubeState input,
    DateTime deadline,
    bool optimize, {
    required bool search,
  }) {
    final state = input.copy();
    final steps = <SolveStep>[];
    SolveFailure? failure;
    try {
      failure = input.n == 4
          ? _solveFour(state, steps, deadline, search)
          : _solveFive(state, steps, deadline, search);
    } on Object catch (e) {
      failure = SolveFailure(SolveFailureKind.internal, '求解出错：$e');
    }
    if (failure != null) return (steps, failure);

    final result = optimize ? MoveOptimizer.optimize(steps, input.n) : steps;
    final replay = input.copy();
    for (final s in result) {
      replay.applyAll(s.moves);
    }
    if (!replay.isSolved) {
      return (result, const SolveFailure(SolveFailureKind.internal, '解法重放后魔方没有还原'));
    }
    return (result, null);
  }

  /// The centre-phase candidate whose centres + edge pairing (+ parity)
  /// take the fewest turns, found by running [pairing] on a copy of each.
  static (CentreAttempt?, SolveFailure?) _bestAttempt(
    NxnCubeState state,
    TargetScheme scheme,
    DateTime deadline,
    SolveFailure? Function(NxnCubeState, TargetScheme, List<SolveStep>) pairing,
  ) {
    final options = CenterPhase.attempts(state, scheme, deadline: deadline);
    CentreAttempt? best;
    var bestCost = 1 << 30;
    SolveFailure? firstFailure;
    for (final a in options) {
      if (a.failure != null) {
        firstFailure ??= a.failure;
        continue;
      }
      final rest = <SolveStep>[];
      final failure = pairing(a.state!.copy(), scheme, rest);
      if (failure != null) {
        firstFailure ??= failure;
        continue;
      }
      final cost = a.turns + rest.fold<int>(0, (t, s) => t + s.blocks.length);
      if (cost < bestCost) {
        best = a;
        bestCost = cost;
      }
    }
    return best == null ? (null, firstFailure) : (best, null);
  }

  // ── 4x4 ─────────────────────────────────────────────────────────────────

  static SolveFailure? _solveFour(NxnCubeState state, List<SolveStep> steps,
      DateTime deadline, bool search) {
    final scheme = TargetScheme.bestFor(state, SlotKind.centerX);
    if (scheme == null) {
      return const SolveFailure(
          SolveFailureKind.invalidInput, '左后下角块颜色不合法，无法确定配色');
    }
    if (search) {
      final pick = _bestAttempt(state, scheme, deadline,
          (s, sc, rest) =>
              EdgePairer.pairFour(s, sc, rest, deadline: deadline) ??
              _fourParity(s, sc, rest));
      if (pick.$2 != null) return pick.$2;
      final failure = CenterPhase.apply(state, scheme, pick.$1!, steps);
      if (failure != null) return failure;
    }
    return (search
            ? null
            : CenterOrbitSolver.solve(state, SlotKind.centerX, scheme, steps,
                deadline: deadline, label: '中心块')) ??
        EdgePairer.pairFour(state, scheme, steps, deadline: deadline) ??
        _fourParity(state, scheme, steps) ??
        ReducedThree.solve(state, scheme, steps, deadline: deadline);
  }

  /// OLL parity (one flipped dedge), then PLL parity (two swapped dedges) of
  /// the reduced 4x4, each fixed with its formula and checked on the engine.
  static SolveFailure? _fourParity(
      NxnCubeState state, TargetScheme scheme, List<SolveStep> steps) {
    final layout = EdgeLayout(4);
    final uf = layout.edgeNamed('UF'), ub = layout.edgeNamed('UB');
    Set<int> wingSlotsOf(List<EdgePosition> edges) => {
          for (final e in edges)
            for (final w in e.wings) ...[w.named, w.other],
        };

    cuber.CubeStatus status() {
      final def = ReducedThree.definition(state, scheme);
      return def == null ? cuber.CubeStatus.missingEdge : ReducedThree.status(def);
    }

    SolveFailure? apply(String alg, Set<int> allowed, String description) {
      final f = NxnFacelets(4);
      final before = f.read(state);
      final moves = ParityAlgorithms.moves(alg, 4);
      state.applyAll(moves);
      final after = f.read(state);
      for (var i = 0; i < f.count; i++) {
        if (!allowed.contains(i) && after[i] != before[i]) {
          return const SolveFailure(SolveFailureKind.internal, '奇偶公式改动了其他贴纸');
        }
      }
      if (!layout.allPaired(after)) {
        return const SolveFailure(SolveFailureKind.internal, '奇偶公式拆散了棱块');
      }
      steps.add(SolveStep(
          phase: ReductionPhase.parity, description: description, moves: moves));
      return null;
    }

    var s = status();
    if (s == cuber.CubeStatus.twistedEdge) {
      final failure =
          apply(ParityAlgorithms.ollFour, wingSlotsOf([uf]), 'OLL 奇偶：翻转 UF 棱');
      if (failure != null) return failure;
      s = status();
    }
    if (s == cuber.CubeStatus.parityError) {
      final failure = apply(ParityAlgorithms.pllFour, wingSlotsOf([uf, ub]),
          'PLL 奇偶：交换 UF 和 UB 棱');
      if (failure != null) return failure;
      s = status();
    }
    if (s != cuber.CubeStatus.ok) {
      return SolveFailure(SolveFailureKind.invalidInput, ReducedThree.statusMessage(s));
    }
    return null;
  }

  // ── 5x5 ─────────────────────────────────────────────────────────────────

  static SolveFailure? _solveFive(NxnCubeState state, List<SolveStep> steps,
      DateTime deadline, bool search) {
    final scheme = TargetScheme.fromFixedCenters(state);
    if (scheme == null) {
      return const SolveFailure(SolveFailureKind.invalidInput, '正中心颜色不合法，无法确定配色');
    }
    // Check everything that can be checked up front, so an illegal cube is
    // reported before any work is done.
    final early = CenterOrbitSolver.checkCounts(
            state, SlotKind.centerX, scheme, '角中心块') ??
        CenterOrbitSolver.checkCounts(state, SlotKind.centerT, scheme, '棱中心块');
    if (early != null) return early;
    // Corners, middle edges and fixed centres already form the 3x3 that the
    // reduced cube will be; no turn of the reduction changes it.
    final def = ReducedThree.definition(state, scheme);
    if (def == null) {
      return const SolveFailure(SolveFailureKind.invalidInput, '有贴纸颜色不属于这套配色');
    }
    final status = ReducedThree.status(def);
    if (status != cuber.CubeStatus.ok) {
      return SolveFailure(
          SolveFailureKind.invalidInput, ReducedThree.statusMessage(status));
    }
    SolveFailure? pairFive(NxnCubeState s, TargetScheme _, List<SolveStep> rest) {
      final moved = TargetScheme.fromFixedCenters(s);
      if (moved == null) {
        return const SolveFailure(SolveFailureKind.internal, '拼中心后正中心配色不对');
      }
      return EdgePairer.pairFive(s, moved, rest, deadline: deadline);
    }

    CentreAttempt? pick;
    if (search) {
      final r = _bestAttempt(state, scheme, deadline, pairFive);
      if (r.$2 != null) return r.$2;
      pick = r.$1;
    }
    final centres = search
        ? CenterPhase.apply(state, scheme, pick!, steps)
        : CenterOrbitSolver.solve(state, SlotKind.centerX, scheme, steps,
                deadline: deadline, label: '角中心块') ??
            CenterOrbitSolver.solve(state, SlotKind.centerT, scheme, steps,
                deadline: deadline, label: '棱中心块');
    if (centres != null) return centres;
    // Turns of the middle layers move the fixed centres (never the scheme).
    final moved = TargetScheme.fromFixedCenters(state);
    if (moved == null) {
      return const SolveFailure(SolveFailureKind.internal, '拼中心后正中心配色不对');
    }
    return EdgePairer.pairFive(state, moved, steps, deadline: deadline) ??
        ReducedThree.solve(state, moved, steps, deadline: deadline);
  }
}
