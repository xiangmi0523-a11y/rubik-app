import 'dart:async';

import 'package:cuber/cuber.dart' as cuber;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

import '../../../core/cube/app_cube_controller.dart';
import '../../../core/cube/cube_facelets.dart';
import '../domain/solve_result.dart';

class PlaybackState {
  const PlaybackState({this.index = 0, this.playing = false});

  /// Number of solution steps already applied.
  final int index;
  final bool playing;

  PlaybackState copyWith({int? index, bool? playing}) => PlaybackState(
        index: index ?? this.index,
        playing: playing ?? this.playing,
      );
}

/// The 3D cube for one solution, starting from the user's colouring.
final playbackCubeProvider =
    Provider.autoDispose.family<AppCubeController, SolveResult>((ref, result) {
  final controller = AppCubeController(
    initialState: CubeFacelets.build(result.colors),
    moveDuration: const Duration(milliseconds: 320),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// Steps through the solution with animated turns.
class PlaybackController extends Notifier<PlaybackState> {
  PlaybackController(this.result);

  final SolveResult result;
  late AppCubeController _cube;
  int? _pendingJump;
  Timer? _timer;

  int get total => result.moves.length;

  List<CubeMove> _turns(int step) =>
      CubeNotation.toQuarterTurns(cuber.Move.parse(result.moves[step]));

  @override
  PlaybackState build() {
    _cube = ref.watch(playbackCubeProvider(result));
    _cube.addListener(_onCubeChanged);
    ref.onDispose(() {
      _timer?.cancel();
      _cube.removeListener(_onCubeChanged);
    });
    return const PlaybackState();
  }

  void _onCubeChanged() {
    if (_cube.hasQueuedWork) return;
    final jump = _pendingJump;
    if (jump != null) {
      _pendingJump = null;
      _applyJump(jump);
      return;
    }
    if (state.playing) {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 120), _pump);
    }
  }

  void _pump() {
    if (!state.playing || _cube.hasQueuedWork) return;
    if (state.index >= total) {
      state = state.copyWith(playing: false);
      return;
    }
    next();
  }

  void next() {
    if (_cube.hasQueuedWork || state.index >= total) return;
    _cube.playSequence(_turns(state.index));
    state = state.copyWith(index: state.index + 1);
  }

  void prev() {
    if (_cube.hasQueuedWork || state.index == 0) return;
    final step = state.index - 1;
    _cube.playSequence(_turns(step).reversed.map((m) => m.inverse));
    state = state.copyWith(index: step, playing: false);
  }

  void togglePlay() {
    if (state.playing) {
      state = state.copyWith(playing: false);
      return;
    }
    if (state.index >= total) {
      jumpTo(0);
    }
    state = state.copyWith(playing: true);
    if (_pendingJump == null) _pump();
  }

  /// Instantly shows the cube after [step] solution steps.
  void jumpTo(int step) {
    state = state.copyWith(playing: false);
    if (_cube.hasQueuedWork) {
      _pendingJump = step; // applied once the current turn finishes
      return;
    }
    _applyJump(step);
  }

  void _applyJump(int step) {
    final cube = CubeFacelets.build(result.colors);
    for (var i = 0; i < step; i++) {
      _turns(i).forEach(cube.applyMove);
    }
    _cube.replaceState(cube);
    state = state.copyWith(index: step);
    if (state.playing) _pump();
  }
}

final playbackControllerProvider = NotifierProvider.autoDispose
    .family<PlaybackController, PlaybackState, SolveResult>(
  PlaybackController.new,
);
