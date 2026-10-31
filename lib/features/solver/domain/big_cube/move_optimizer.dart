import '../../../../core/nxn/nxn_cube_state.dart';
import 'solve_step.dart';

/// Rewrites each phase with the fewest turns: consecutive same-axis turns
/// commute, so every run of them is replaced by its net per-layer effect,
/// written as the fewest (possibly wide) block turns
/// ([NxnBlockMove.decompose]). A run that cancels out disappears, which lets
/// the runs around it merge (cascading).
///
/// Merging never crosses a phase boundary, so the cube after each phase is
/// exactly what it was before optimizing. A run's turns go to the step where
/// the run started; steps left empty are dropped.
abstract final class MoveOptimizer {
  static List<SolveStep> optimize(List<SolveStep> steps, int n) {
    final out = <SolveStep>[];
    var i = 0;
    while (i < steps.length) {
      var j = i;
      while (j < steps.length && steps[j].phase == steps[i].phase) {
        j++;
      }
      out.addAll(_optimizePhase(steps.sublist(i, j), n));
      i = j;
    }
    return out;
  }

  static int _quarters(int turns) => turns == 2 ? 2 : (turns == 1 ? 1 : 3);

  static List<SolveStep> _optimizePhase(List<SolveStep> steps, int n) {
    // Runs of same-axis turns: axis, net quarters per layer, first step.
    final runs = <(int, List<int>, int)>[];
    bool zero(List<int> q) => q.every((x) => x == 0);
    for (var s = 0; s < steps.length; s++) {
      for (final m in steps[s].moves) {
        final layer = (m.layer + n - 1) ~/ 2;
        if (runs.isEmpty || runs.last.$1 != m.axis) {
          runs.add((m.axis, List<int>.filled(n, 0), s));
        }
        final q = runs.last.$2;
        q[layer] = (q[layer] + _quarters(m.turns)) % 4;
        if (zero(q)) runs.removeLast();
      }
    }
    final perStep = List.generate(steps.length, (_) => <NxnBlockMove>[]);
    for (final (axis, q, step) in runs) {
      perStep[step].addAll(NxnBlockMove.decompose(n, axis, q));
    }
    return [
      for (var s = 0; s < steps.length; s++)
        if (perStep[s].isNotEmpty)
          SolveStep.turns(
            phase: steps[s].phase,
            description: steps[s].description,
            blocks: perStep[s],
          ),
    ];
  }
}
