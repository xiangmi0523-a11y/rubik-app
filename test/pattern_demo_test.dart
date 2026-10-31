import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/core/nxn/nxn_cube_view.dart';
import 'package:rubik_app/core/pyraminx/pyraminx_view.dart';
import 'package:rubik_app/features/patterns/presentation/pattern_picker_sheet.dart';
import 'package:rubik_app/features/player/application/player_controller.dart';
import 'package:rubik_app/features/player/presentation/player_page.dart';
import 'package:rubik_app/features/puzzles/domain/puzzle_type.dart';

Future<void> _open(WidgetTester tester, PuzzleType type, String name) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showPatternPicker(context, type),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

Future<void> _playToEnd(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.play_arrow));
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  for (final (type, name) in [
    (PuzzleType.cube3, '棋盘格'),
    (PuzzleType.cube4, '六面回字'),
    (PuzzleType.cube5, '棋盘格'),
    (PuzzleType.cube2, '六面条纹'),
    (PuzzleType.pyraminx, '花朵'),
  ]) {
    testWidgets('${type.label} pattern "$name" plays to the end',
        (tester) async {
      await _open(tester, type, name);
      expect(find.text('${type.label}花式：$name'), findsOneWidget);
      if (type.usesNxnEngine) expect(find.byType(NxnCubeView), findsWidgets);
      if (type.isPyraminx) expect(find.byType(PyraminxView), findsWidgets);

      final page = tester.widget<PlayerPage>(find.byType(PlayerPage));
      final container =
          ProviderScope.containerOf(tester.element(find.byType(PlayerPage)));
      await _playToEnd(tester);
      final state = container.read(playerControllerProvider(page.script));
      expect(state.index, page.script.moves.length);
      expect(state.playing, isFalse);
    });
  }
}
