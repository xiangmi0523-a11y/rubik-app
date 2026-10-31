import 'dart:isolate';

import 'package:cuber/cuber.dart' as cuber;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runs cuber's Kociemba two-phase solver off the UI thread.
class CubeSolverService {
  const CubeSolverService();

  /// Returns the solution in cuber notation, or null if none was found.
  Future<List<String>?> solve(String definition) =>
      Isolate.run(() => _solveSync(definition));
}

List<String>? _solveSync(String definition) {
  final solution = cuber.Cube.from(definition).solve(
    maxDepth: 25,
    timeout: const Duration(seconds: 20),
  );
  return solution?.algorithm.moves.map((m) => m.toString()).toList();
}

final cubeSolverServiceProvider =
    Provider<CubeSolverService>((ref) => const CubeSolverService());
