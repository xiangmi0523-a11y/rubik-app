import 'package:cuber/cuber.dart' as cuber;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_cube/puzzle_cube.dart';
import 'package:rubik_app/core/cube/cube_facelets.dart';
import 'package:rubik_app/features/player/application/player_controller.dart';
import 'package:rubik_app/features/player/domain/puzzle_stepper.dart';
import 'package:rubik_app/features/player/presentation/player_page.dart';

void main() {
  testWidgets('3x3 solution auto-plays to a solved cube', (tester) async {
    final cube = PuzzleCubeState.random(moves: 25, seed: 7);
    final colors = CubeFacelets.read(cube);
    final solution =
        cuber.Cube.from(CubeFacelets.toDefinition(colors)!).solve()!;
    final script = Cube3Script(
      colors: colors,
      moves: solution.algorithm.moves.map((m) => m.toString()).toList(),
    );

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: PlayerPage(script: script)),
    ));
    final container =
        ProviderScope.containerOf(tester.element(find.byType(PlayerPage)));

    await tester.tap(find.byIcon(Icons.play_arrow));
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final state = container.read(playerControllerProvider(script));
    expect(state.index, script.moves.length);
    expect(state.playing, isFalse);
    final stepper = container.read(playerStepperProvider(script));
    expect(stepper.busy, isFalse);

    // Jumping back to the start shows the scrambled cube again.
    container.read(playerControllerProvider(script).notifier).jumpTo(0);
    await tester.pump();
    expect(container.read(playerControllerProvider(script)).index, 0);
  });
}
