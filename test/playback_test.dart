import 'package:cuber/cuber.dart' as cuber;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_cube/puzzle_cube.dart';
import 'package:rubik_app/core/cube/cube_facelets.dart';
import 'package:rubik_app/features/solver/application/playback_controller.dart';
import 'package:rubik_app/features/solver/domain/solve_result.dart';
import 'package:rubik_app/features/solver/presentation/solution_page.dart';

void main() {
  testWidgets('auto play solves the cube', (tester) async {
    final cube = PuzzleCubeState.random(moves: 25, seed: 7);
    final colors = CubeFacelets.read(cube);
    final solution =
        cuber.Cube.from(CubeFacelets.toDefinition(colors)!).solve()!;
    final result = SolveResult(
      colors: colors,
      moves: solution.algorithm.moves.map((m) => m.toString()).toList(),
    );

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: SolutionPage(result: result)),
    ));
    final container = ProviderScope.containerOf(
        tester.element(find.byType(SolutionPage)));

    await tester.tap(find.byIcon(Icons.play_arrow));
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final state = container.read(playbackControllerProvider(result));
    expect(state.index, result.moves.length);
    expect(state.playing, isFalse);
    expect(container.read(playbackCubeProvider(result)).isSolved, isTrue);

    // Jump back to start and step forward once.
    container.read(playbackControllerProvider(result).notifier).jumpTo(0);
    await tester.pump();
    expect(container.read(playbackCubeProvider(result)).isSolved, isFalse);
  });
}
