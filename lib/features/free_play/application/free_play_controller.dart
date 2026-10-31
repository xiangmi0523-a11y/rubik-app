import 'package:cuber/cuber.dart' as cuber;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

import '../../../core/cube/app_cube_controller.dart';
import '../../../core/cube/cube_facelets.dart';
import '../../puzzles/application/puzzle_type_controller.dart';
import '../../puzzles/domain/puzzle_type.dart';
import '../../stats/application/stats_controller.dart';
import '../../stats/domain/solve_record.dart';
import 'inspection_setting.dart';

/// The 3x3 cube used on the free-play tab (puzzle_cube).
final freePlayCubeProvider = Provider<AppCubeController>((ref) {
  final controller = AppCubeController(
    moveDuration: const Duration(milliseconds: 200),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

enum TimerStatus { idle, ready, inspecting, running, stopped }

class TimerState {
  const TimerState({
    this.status = TimerStatus.idle,
    this.startedAt,
    this.elapsed = Duration.zero,
    this.scramble = '',
    this.inspectionStartedAt,
    this.penalty = Penalty.none,
    this.lastRecordId,
  });

  final TimerStatus status;
  final DateTime? startedAt;
  final Duration elapsed;
  final String scramble;

  /// Set while inspecting.
  final DateTime? inspectionStartedAt;

  /// Penalty of the current / last solve (from inspection or chosen after).
  final Penalty penalty;

  /// Stats id of the last recorded solve (for editing its penalty).
  final int? lastRecordId;

  Duration get inspectionElapsed => inspectionStartedAt == null
      ? Duration.zero
      : DateTime.now().difference(inspectionStartedAt!);

  Duration get current => status == TimerStatus.running && startedAt != null
      ? DateTime.now().difference(startedAt!)
      : elapsed;

  TimerState copyWith({
    TimerStatus? status,
    DateTime? startedAt,
    Duration? elapsed,
    String? scramble,
    Penalty? penalty,
    int? lastRecordId,
  }) =>
      TimerState(
        status: status ?? this.status,
        startedAt: startedAt ?? this.startedAt,
        elapsed: elapsed ?? this.elapsed,
        scramble: scramble ?? this.scramble,
        inspectionStartedAt: inspectionStartedAt,
        penalty: penalty ?? this.penalty,
        lastRecordId: lastRecordId ?? this.lastRecordId,
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
      text = ref.read(pyraminxProvider).scramble();
    }
    final inspect = ref.read(inspectionEnabledProvider);
    state = TimerState(
      status: inspect ? TimerStatus.inspecting : TimerStatus.ready,
      scramble: text,
      inspectionStartedAt: inspect ? DateTime.now() : null,
    );
  }

  void resetCube() {
    final type = _type;
    if (type == PuzzleType.cube3) {
      _cube3.reset();
    } else if (type.usesNxnEngine) {
      ref.read(nxnCubeProvider(type.order!)).reset();
    } else {
      ref.read(pyraminxProvider).reset();
    }
    state = const TimerState();
  }

  bool get _isSolved {
    final type = _type;
    if (type == PuzzleType.cube3) return _cube3.state.isSolved;
    if (type.usesNxnEngine) {
      return ref.read(nxnCubeProvider(type.order!)).isSolved;
    }
    return ref.read(pyraminxProvider).isSolved;
  }

  /// Called after every finger turn on the 3D cube.
  void onCubeMove() {
    if (state.status == TimerStatus.ready ||
        state.status == TimerStatus.inspecting) {
      _start();
    }
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
    final penalty = state.status == TimerStatus.inspecting
        ? inspectionPenalty(state.inspectionElapsed)
        : Penalty.none;
    state = TimerState(
      status: TimerStatus.running,
      startedAt: DateTime.now(),
      scramble: state.scramble,
      penalty: penalty,
    );
  }

  /// Changes the penalty of the solve that just finished.
  void setLastPenalty(Penalty penalty) {
    final id = state.lastRecordId;
    if (id == null) return;
    ref.read(statsControllerProvider.notifier).setPenalty(id, penalty);
    state = state.copyWith(penalty: penalty);
  }

  void _stop() {
    final elapsed = state.current;
    final id = ref.read(statsControllerProvider.notifier).add(
          elapsed,
          scramble: state.scramble,
          puzzle: _type,
          penalty: state.penalty,
        );
    state = state.copyWith(
      status: TimerStatus.stopped,
      elapsed: elapsed,
      lastRecordId: id,
    );
  }
}

final freePlayControllerProvider =
    NotifierProvider<FreePlayController, TimerState>(FreePlayController.new);
