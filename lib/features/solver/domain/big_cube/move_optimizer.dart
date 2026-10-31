import '../../../../core/nxn/nxn_cube_state.dart';
import 'solve_step.dart';

/// Removes redundant turns: consecutive turns on the same axis commute, so a
/// run of them is replaced by one net turn per layer (dropping layers that
/// cancel out), cascading when a run disappears.
///
/// Merging never crosses a phase boundary, so the cube after each phase is
/// exactly what it was before optimizing. Within a phase, a merged turn stays
/// in the step where its layer first appeared; steps left empty are dropped.
abstract final class MoveOptimizer {
  static List<SolveStep> optimize(List<SolveStep> steps) {
    final out = <SolveStep>[];
    var i = 0;
    while (i < steps.length) {
      var j = i;
      while (j < steps.length && steps[j].phase == steps[i].phase) {
        j++;
      }
      out.addAll(_optimizePhase(steps.sublist(i, j)));
      i = j;
    }
    return out;
  }

  static int _quarters(int turns) => turns == 2 ? 2 : (turns == 1 ? 1 : 3);
  static int _turns(int quarters) => quarters == 2 ? 2 : (quarters == 1 ? 1 : -1);

  static List<SolveStep> _optimizePhase(List<SolveStep> steps) {
    // Runs of same-axis turns: axis, then per layer (net quarters, step).
    final runs = <(int, List<(int, int, int)>)>[]; // (axis, [(layer, q, step)])
    for (var s = 0; s < steps.length; s++) {
      for (final m in steps[s].moves) {
        if (runs.isEmpty || runs.last.$1 != m.axis) {
          runs.add((m.axis, [(m.layer, _quarters(m.turns), s)]));
          continue;
        }
        final entries = runs.last.$2;
        final k = entries.indexWhere((e) => e.$1 == m.layer);
        if (k < 0) {
          entries.add((m.layer, _quarters(m.turns), s));
        } else {
          final (layer, q, step) = entries[k];
          final nq = (q + _quarters(m.turns)) % 4;
          if (nq == 0) {
            entries.removeAt(k);
          } else {
            entries[k] = (layer, nq, step);
          }
        }
        if (entries.isEmpty) runs.removeLast();
      }
    }
    final perStep = List.generate(steps.length, (_) => <NxnMove>[]);
    for (final (axis, entries) in runs) {
      for (final (layer, q, step) in entries) {
        perStep[step].add(NxnMove(axis, layer, _turns(q)));
      }
    }
    return [
      for (var s = 0; s < steps.length; s++)
        if (perStep[s].isNotEmpty)
          SolveStep(
            phase: steps[s].phase,
            description: steps[s].description,
            moves: perStep[s],
          ),
    ];
  }
}
