import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/puzzle_stepper.dart';

class PlaybackState {
  const PlaybackState({this.index = 0, this.playing = false});

  /// Number of steps already applied.
  final int index;
  final bool playing;

  PlaybackState copyWith({int? index, bool? playing}) => PlaybackState(
        index: index ?? this.index,
        playing: playing ?? this.playing,
      );
}

/// The animated puzzle for one script.
final playerStepperProvider =
    Provider.autoDispose.family<PuzzleStepper, PlayerScript>((ref, script) {
  final stepper = script.createStepper();
  ref.onDispose(stepper.dispose);
  return stepper;
});

/// Steps through a script with animated turns (any puzzle).
class PlayerController extends Notifier<PlaybackState> {
  PlayerController(this.script);

  final PlayerScript script;
  late PuzzleStepper _stepper;
  int? _pendingJump;
  Timer? _timer;

  int get total => script.moves.length;

  @override
  PlaybackState build() {
    _stepper = ref.watch(playerStepperProvider(script));
    _stepper.listenable.addListener(_onChanged);
    ref.onDispose(() {
      _timer?.cancel();
      _stepper.listenable.removeListener(_onChanged);
    });
    return const PlaybackState();
  }

  void _onChanged() {
    if (_stepper.busy) return;
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
    if (!state.playing || _stepper.busy) return;
    if (state.index >= total) {
      state = state.copyWith(playing: false);
      return;
    }
    next();
  }

  void next() {
    if (_stepper.busy || state.index >= total) return;
    final i = state.index;
    state = state.copyWith(index: i + 1);
    _stepper.animate(i, forward: true);
  }

  void prev() {
    if (_stepper.busy || state.index == 0) return;
    final step = state.index - 1;
    state = state.copyWith(index: step, playing: false);
    _stepper.animate(step, forward: false);
  }

  void togglePlay() {
    if (state.playing) {
      state = state.copyWith(playing: false);
      return;
    }
    if (state.index >= total) jumpTo(0);
    state = state.copyWith(playing: true);
    if (_pendingJump == null) _pump();
  }

  /// Instantly shows the puzzle after [step] steps.
  void jumpTo(int step) {
    state = state.copyWith(playing: false);
    if (_stepper.busy) {
      _pendingJump = step;
      return;
    }
    _applyJump(step);
  }

  void _applyJump(int step) {
    _stepper.show(step);
    state = state.copyWith(index: step);
    if (state.playing) _pump();
  }
}

final playerControllerProvider = NotifierProvider.autoDispose
    .family<PlayerController, PlaybackState, PlayerScript>(
  PlayerController.new,
);
