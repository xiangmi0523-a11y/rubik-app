import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/core/cube/cube_facelets.dart';
import 'package:rubik_app/features/patterns/domain/cube_pattern.dart';
import 'package:rubik_app/features/patterns/presentation/pattern_picker_sheet.dart';
import 'package:rubik_app/features/solver/application/playback_controller.dart';
import 'package:rubik_app/features/solver/presentation/solution_page.dart';

void main() {
  testWidgets('picking a pattern plays it to the pattern state',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showPatternPicker(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('棋盘格'));
    await tester.pumpAndSettle();
    expect(find.text('花式：棋盘格'), findsOneWidget);

    final page = tester.widget<SolutionPage>(find.byType(SolutionPage));
    final container =
        ProviderScope.containerOf(tester.element(find.byType(SolutionPage)));
    await tester.tap(find.byIcon(Icons.play_arrow));
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final cube = container.read(playbackCubeProvider(page.result));
    expect(CubeFacelets.definitionOf(cube.state),
        cubePatterns.first.definition);
  });
}
