import 'package:cuber/cuber.dart' as cuber;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

import '../../../core/cube/cube_facelets.dart';
import '../../stats/application/stats_controller.dart';

/// The 3D cube used on the free-play tab.
final freePlayCubeProvider = Provider<CubeController>((ref) {
  final controller = CubeController(
    moveDuration: const Duration(milliseconds: 200),
    initialViewRotationX: CubeNotation.viewRotationX,
    initialViewRotationY: CubeNotation.viewRotationY,
  );
  ref.onDispose(controller.dispose);
  return controller;
});

enum TimerStatus { idle, ready, running, stopped }

class TimerState {
  const TimerState({
    this.status = TimerStatus.idle,
    this.startedAt,
    this.elapsed = Duration.zero,
    this.scramble = '',
  });

  final TimerStatus status;
  final DateTime? startedAt;
  final Duration elapsed;
  final String scramble;

  Duration get current => status == TimerStatus.running && startedAt != null
      ? DateTime.now().difference(startedAt!)
      : elapsed;

  TimerState copyWith({
    TimerStatus? status,
    DateTime? startedAt,
    Duration? elapsed,
    String? scramble,
  }) =>
      TimerState(
        status: status ?? this.status,
        startedAt: startedAt ?? this.startedAt,
        elapsed: elapsed ?? this.elapsed,
        scramble: scramble ?? this.scramble,
      );
}

/// Timer + free-play cube flow:
/// scramble -> (ready) -> first turn starts timer -> solved stops & records.
/// Tapping the timer also starts/stops it manually (for a physical cube).
class FreePlayController extends Notifier<TimerState> {
  @override
  TimerState build() => const TimerState();

  CubeController get _cube => ref.read(freePlayCubeProvider);

  void scramble() {
    final alg = cuber.Algorithm.scramble(n: 20);
    final state = PuzzleCubeState.solved();
    for (final m in alg.moves) {
      CubeNotation.toQuarterTurns(m).forEach(state.applyMove);
    }
    _cube.replaceState(state);
    this.state = TimerState(status: TimerStatus.ready, scramble: alg.toString());
  }

  void resetCube() {
    _cube.reset();
    state = const TimerState();
  }

  /// Called after every finger turn on the 3D cube.
  void onCubeMove() {
    if (state.status == TimerStatus.ready) _start();
    if (state.status == TimerStatus.running && _cube.state.isSolved) _stop();
  }

  /// Tap on the timer.
  void toggleManual() {
    if (state.status == TimerStatus.running) {
      _stop();
    } else {
      _start();
    }
  }

  void _start() {
    state = state.copyWith(
      status: TimerStatus.running,
      startedAt: DateTime.now(),
      elapsed: Duration.zero,
    );
  }

  void _stop() {
    final elapsed = state.current;
    state = state.copyWith(status: TimerStatus.stopped, elapsed: elapsed);
    ref
        .read(statsControllerProvider.notifier)
        .add(elapsed, scramble: state.scramble);
  }
}

final freePlayControllerProvider =
    NotifierProvider<FreePlayController, TimerState>(FreePlayController.new);
