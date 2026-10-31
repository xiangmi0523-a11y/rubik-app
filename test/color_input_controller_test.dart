import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_cube/puzzle_cube.dart';
import 'package:rubik_app/features/solver/application/color_input_controller.dart';

void main() {
  late ProviderContainer container;
  ColorInputController notifier() => container.read(colorInputProvider.notifier);
  ColorInputState state() => container.read(colorInputProvider);

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('each colour starts with 8 left (centre already placed)', () {
    for (final c in CubeColors.palette) {
      expect(state().remaining(c), 8);
    }
  });

  test('painting decrements and same-colour tap erases', () {
    notifier().paint(0);
    expect(state().remaining(CubeColors.white), 7);
    notifier().paint(0);
    expect(state().remaining(CubeColors.white), 8);
  });

  test('centres cannot be painted', () {
    expect(notifier().paint(4), isFalse);
  });

  test('full colour is disabled and selection moves on', () {
    final targets = [0, 1, 2, 3, 5, 6, 7, 8]; // 8 whites on U
    for (final i in targets) {
      notifier().paint(i);
    }
    expect(state().remaining(CubeColors.white), 0);
    expect(state().selected, isNot(CubeColors.white));
    notifier().select(CubeColors.white);
    expect(state().selected, isNot(CubeColors.white));
  });
}
