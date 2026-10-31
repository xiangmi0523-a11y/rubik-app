import '../../../../core/nxn/nxn_cube_state.dart';

/// Phases of the big-cube reduction solve.
enum ReductionPhase {
  centers('拼中心'),
  edges('配对棱块'),
  parity('奇偶校正'),
  threeByThree('三阶求解');

  const ReductionPhase(this.label);
  final String label;
}

/// One formula applied during a solve, with what it was for.
class SolveStep {
  const SolveStep({
    required this.phase,
    required this.description,
    required this.moves,
  }) : _blocks = null;

  /// A step given as (possibly wide) turns; [moves] are their layers.
  SolveStep.turns({
    required this.phase,
    required this.description,
    required List<NxnBlockMove> blocks,
  })  : _blocks = blocks,
        moves = [for (final b in blocks) ...b.moves];

  final ReductionPhase phase;
  final String description;

  /// The step as single-layer moves (same effect as [blocks]).
  final List<NxnMove> moves;
  final List<NxnBlockMove>? _blocks;

  /// The step as turns, one per player step; a wide turn is one turn.
  List<NxnBlockMove> get blocks =>
      _blocks ?? [for (final m in moves) NxnBlockMove.single(m)];
}

/// Why a solve phase could not complete.
enum SolveFailureKind {
  /// The input isn't the right puzzle or isn't a legal colouring.
  invalidInput,

  /// The time budget ran out.
  timeout,

  /// An internal invariant was violated (a bug — never expected).
  internal,
}

class SolveFailure {
  const SolveFailure(this.kind, this.message);
  final SolveFailureKind kind;
  final String message;

  @override
  String toString() => 'SolveFailure(${kind.name}: $message)';
}
