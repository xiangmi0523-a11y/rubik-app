import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/core/nxn/nxn_cube_state.dart';
import 'package:rubik_app/features/player/domain/puzzle_stepper.dart';
import 'package:rubik_app/features/solver/application/puzzle_color_input.dart';

/// Wall-clock time of a solve exactly as the app runs it: a fresh background
/// isolate per solve, so every run pays for building the formula libraries
/// and cuber's tables. Measured in the test VM (JIT), not on a phone.
void main() {
  test('cold solves in a fresh isolate (as in the app)', () async {
    for (final n in [4, 5]) {
      final times = <int>[];
      for (var i = 0; i < 5; i++) {
        final start = NxnCubeState.solved(n)
          ..applyAll(NxnCubeState.randomScramble(n, rng: math.Random(100 + i)));
        final sw = Stopwatch()..start();
        final outcome = await solveBigCube(start);
        times.add(sw.elapsedMilliseconds);
        expect(outcome, isA<PuzzleSolveOk>());
        final script = (outcome as PuzzleSolveOk).script as NxnScript;
        expect((script.initial.copy()..applyAll(script.steps)).isSolved, isTrue);
      }
      // ignore: avoid_print
      print('ISOLATE${n}_COLD_MS ${times.join(' ')} '
          'avg=${(times.reduce((a, b) => a + b) / times.length).round()}');
      expect(times.every((t) => t < bigCubeSolveTimeout.inMilliseconds), isTrue);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
