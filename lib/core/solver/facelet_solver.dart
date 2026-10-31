/// Optimal-ish solver for small permutation puzzles (2x2, Pyraminx) by
/// meet-in-the-middle over facelet permutations.
///
/// A table of every state within [tableDepth] moves of the target is built
/// first; then an iterative-deepening search from the start state, up to
/// [searchDepth] moves, stops at the first state found in the table. With
/// 5 + 6 this covers any 2x2 (`<U,R,F>`, God's number 11) or Pyraminx without
/// tips (11) in milliseconds.
class FaceletPuzzle {
  FaceletPuzzle({
    required this.moves,
    required this.names,
    required this.axes,
    required this.inverses,
  });

  /// Facelet permutations: after the move, facelet i's colour is at perm[i].
  final List<List<int>> moves;
  final List<String> names;

  /// Moves on the same axis are never chained back to back.
  final List<int> axes;

  /// Index of each move's inverse.
  final List<int> inverses;

  List<int> apply(List<int> state, int move) {
    final perm = moves[move];
    final out = List<int>.filled(state.length, 0);
    for (var i = 0; i < state.length; i++) {
      out[perm[i]] = state[i];
    }
    return out;
  }
}

/// Returns move indices turning [start] into [target], or null if none exists
/// within tableDepth + searchDepth moves. Facelets whose [mask] entry is false
/// are ignored (e.g. Pyraminx tips, fixed separately).
List<int>? solveFacelets(
  FaceletPuzzle puzzle,
  List<int> start,
  List<int> target, {
  List<bool>? mask,
  int tableDepth = 5,
  int searchDepth = 6,
}) {
  String key(List<int> s) {
    final codes = <int>[];
    for (var i = 0; i < s.length; i++) {
      if (mask == null || mask[i]) codes.add(65 + s[i]);
    }
    return String.fromCharCodes(codes);
  }

  // Table: key -> move that produced it from its BFS parent (-1 for target).
  final table = <String, int>{key(target): -1};
  var frontier = <(List<int>, int)>[(target, -1)];
  for (var d = 0; d < tableDepth; d++) {
    final next = <(List<int>, int)>[];
    for (final (state, last) in frontier) {
      for (var m = 0; m < puzzle.moves.length; m++) {
        if (last >= 0 && puzzle.axes[m] == puzzle.axes[last]) continue;
        final s = puzzle.apply(state, m);
        final k = key(s);
        if (table.containsKey(k)) continue;
        table[k] = m;
        next.add((s, m));
      }
    }
    frontier = next;
  }

  List<int> finish(List<int> state, List<int> path) {
    final result = [...path];
    var s = state;
    var k = key(s);
    while (table[k] != -1) {
      final undo = puzzle.inverses[table[k]!];
      result.add(undo);
      s = puzzle.apply(s, undo);
      k = key(s);
    }
    return result;
  }

  final path = <int>[];
  List<int>? dfs(List<int> state, int depth, int last) {
    if (table.containsKey(key(state))) return finish(state, path);
    if (depth == 0) return null;
    for (var m = 0; m < puzzle.moves.length; m++) {
      if (last >= 0 && puzzle.axes[m] == puzzle.axes[last]) continue;
      path.add(m);
      final found = dfs(puzzle.apply(state, m), depth - 1, m);
      if (found != null) return found;
      path.removeLast();
    }
    return null;
  }

  for (var d = 0; d <= searchDepth; d++) {
    final found = dfs(start, d, -1);
    if (found != null) return found;
  }
  return null;
}
