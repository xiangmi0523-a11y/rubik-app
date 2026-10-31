import 'dart:math' as math;

import 'package:rubik_app/core/nxn/nxn_cube_state.dart';
import 'package:rubik_app/core/nxn/nxn_facelets.dart';

/// Random real turn sequences over the *full* move universe of order [n]
/// (every layer, all three turn types) — unlike `NxnCubeState.randomScramble`,
/// which avoids same-axis repeats and, for 2x2, inner layers.
List<NxnMove> randomMoves(int n, math.Random rng, int length) {
  final moves = NxnMoveTable(n).moves;
  return [for (var i = 0; i < length; i++) moves[rng.nextInt(moves.length)]];
}

List<NxnMove> inverseOf(List<NxnMove> seq) =>
    [for (final m in seq.reversed) m.inverse];

String describe(List<NxnMove> seq, int n) =>
    seq.map((m) => m.notation(n)).join(' ');
