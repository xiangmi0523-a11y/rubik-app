import 'package:cuber/cuber.dart' as cuber;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

import '../../../core/cube/app_cube_controller.dart';
import '../../../core/cube/cube_facelets.dart';
import '../../puzzles/application/puzzle_type_controller.dart';
import '../../puzzles/domain/puzzle_type.dart';
import '../../pyraminx/domain/pyraminx_scramble.dart';
import '../../stats/application/stats_controller.dart';

/// The 3x3 cube used on the free-play tab (puzzle_cube).
final freePlayCubeProvider = Provider<AppCubeController>((ref) {
  final controller = AppCubeController(
    moveDuration: const Duration(milliseconds: 200),
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

/// Timer + free-play flow for whichever puzzle is selected:
/// scramble -> (ready) -> first turn starts timer -> solved stops & records.
/// Tapping the timer also starts/stops it manually (for a physical puzzle).
/// Switching puzzles resets the timer.
class FreePlayController extends Notifier<TimerState> {
  @override
  TimerState build() {
    ref.watch(puzzleTypeProvider);
    return const TimerState();
  }

  PuzzleType get _type => ref.read(puzzleTypeProvider);
  AppCubeController get _cube3 => ref.read(freePlayCubeProvider);

  void scramble() {
    final type = _type;
    final String text;
    if (type == PuzzleType.cube3) {
      final alg = cuber.Algorithm.scramble(n: 20);
      final cube = PuzzleCubeState.solved();
      for (final m in alg.moves) {
        CubeNotation.toQuarterTurns(m).forEach(cube.applyMove);
      }
      _cube3.replaceState(cube);
      text = alg.toString();
    } else if (type.usesNxnEngine) {
      text = ref.read(nxnCubeProvider(type.order!)).scramble();
    } else {
      text = pyraminxScramble();
    }
    state = TimerState(status: TimerStatus.ready, scramble: text);
  }

  void resetCube() {
    final type = _type;
    if (type == PuzzleType.cube3) {
      _cube3.reset();
    } else if (type.usesNxnEngine) {
      ref.read(nxnCubeProvider(type.order!)).reset();
    }
    state = const TimerState();
  }

  bool get _isSolved {
    final type = _type;
    if (type == PuzzleType.cube3) return _cube3.state.isSolved;
    if (type.usesNxnEngine) {
      return ref.read(nxnCubeProvider(type.order!)).isSolved;
    }
    return false;
  }

  /// Called after every finger turn on the 3D cube.
  void onCubeMove() {
    if (state.status == TimerStatus.ready) _start();
    if (state.status == TimerStatus.running && _isSolved) _stop();
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
        .add(elapsed, scramble: state.scramble, puzzle: _type);
  }
}

final freePlayControllerProvider =
    NotifierProvider<FreePlayController, TimerState>(FreePlayController.new);
