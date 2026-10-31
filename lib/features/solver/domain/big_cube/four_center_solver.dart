import '../../../../core/nxn/nxn_cube_state.dart';
import '../../../../core/nxn/nxn_facelets.dart';
import 'center_solver.dart';
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

/// Solves the 4x4 centres with pure centre 3-cycles ([CenterOrbitSolver]).
///
/// The target colours come from the corners ([TargetScheme.bestFor]), in the
/// orientation that already matches the most centres.
abstract final class FourCenterSolver {
  static CenterSolveResult solve(
    NxnCubeState input, {
    Duration timeout = const Duration(seconds: 10),
    TargetScheme? target,
  }) {
    final state = input.copy();
    final steps = <SolveStep>[];
    CenterSolveResult fail(SolveFailure failure, [TargetScheme? t]) =>
        CenterSolveResult._(steps: steps, state: state, target: t, failure: failure);

    if (input.n != 4) {
      return fail(SolveFailure(
          SolveFailureKind.invalidInput, '只能求解四阶，收到 ${input.n} 阶'));
    }
    final scheme = target ?? TargetScheme.bestFor(state, SlotKind.centerX);
    if (scheme == null) {
      return fail(const SolveFailure(
          SolveFailureKind.invalidInput, '左后下角块颜色不合法，无法确定配色'));
    }
    final failure = CenterOrbitSolver.solve(
      state,
      SlotKind.centerX,
      scheme,
      steps,
      deadline: DateTime.now().add(timeout),
      label: '中心块',
    );
    if (failure != null) return fail(failure, scheme);
    return CenterSolveResult._(steps: steps, state: state, target: scheme);
  }

  /// Whether every 4x4 centre sticker matches [target].
  static bool centersSolved(NxnCubeState state, TargetScheme target) =>
      CenterOrbitSolver.solved(state, SlotKind.centerX, target);
}
