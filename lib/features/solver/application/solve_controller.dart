import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cube/cube_facelets.dart';
import '../data/cube_solver_service.dart';
import '../domain/cube_input_validator.dart';
import '../domain/solve_result.dart';
import 'color_input_controller.dart';

enum SolveStatus { idle, solving, invalid, done }

class SolveState {
  const SolveState({
    this.status = SolveStatus.idle,
    this.errors = const [],
    this.result,
  });

  final SolveStatus status;
  final List<String> errors;
  final SolveResult? result;
}

class SolveController extends Notifier<SolveState> {
  @override
  SolveState build() => const SolveState();

  Future<void> solve() async {
    if (state.status == SolveStatus.solving) return;
    final colors = [...ref.read(colorInputProvider).colors];

    final errors = CubeInputValidator.validate(colors);
    if (errors.isNotEmpty) {
      state = SolveState(status: SolveStatus.invalid, errors: errors);
      return;
    }

    state = const SolveState(status: SolveStatus.solving);
    final definition = CubeFacelets.toDefinition(colors)!;
    try {
      final moves = await ref.read(cubeSolverServiceProvider).solve(definition);
      if (moves == null) {
        state = const SolveState(
          status: SolveStatus.invalid,
          errors: ['求解超时或无解，请检查颜色'],
        );
        return;
      }
      state = SolveState(
        status: SolveStatus.done,
        result: SolveResult(colors: colors, moves: moves),
      );
    } catch (e) {
      state = SolveState(status: SolveStatus.invalid, errors: ['求解出错：$e']);
    }
  }

  void acknowledge() => state = const SolveState();
}

final solveControllerProvider =
    NotifierProvider<SolveController, SolveState>(SolveController.new);
