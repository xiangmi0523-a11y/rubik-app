import 'dart:isolate';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_cube/puzzle_cube.dart' show CubeColors;

import '../../../core/nxn/nxn_cube_controller.dart';
import '../../../core/nxn/nxn_cube_state.dart';
import '../../../core/nxn/nxn_projection.dart';
import '../../../core/pyraminx/pyraminx_controller.dart';
import '../../../core/pyraminx/pyraminx_model.dart';
import '../../../core/pyraminx/pyraminx_solver.dart';
import '../../player/domain/puzzle_stepper.dart';
import '../../puzzles/domain/puzzle_type.dart';
import '../domain/two_by_two_solver.dart';

/// Puzzle selected on the 填色求解 tab.
class SolverPuzzleController extends Notifier<PuzzleType> {
  @override
  PuzzleType build() => PuzzleType.cube3;

  void select(PuzzleType type) => state = type;
}

final solverPuzzleProvider =
    NotifierProvider<SolverPuzzleController, PuzzleType>(
  SolverPuzzleController.new,
);

/// Outcome of "开始求解" for the non-3x3 puzzles.
sealed class PuzzleSolveOutcome {
  const PuzzleSolveOutcome();
}

class PuzzleSolveOk extends PuzzleSolveOutcome {
  const PuzzleSolveOk(this.script);
  final PlayerScript script;
}

class PuzzleSolveIncomplete extends PuzzleSolveOutcome {
  const PuzzleSolveIncomplete(this.message);
  final String message;
}

class PuzzleSolveInvalid extends PuzzleSolveOutcome {
  const PuzzleSolveInvalid(this.reasons);
  final List<String> reasons;
}

class PuzzleSolveUnsupported extends PuzzleSolveOutcome {
  const PuzzleSolveUnsupported(this.message);
  final String message;
}

// ── N×N (2x2 / 4x4 / 5x5) ─────────────────────────────────────────────────

class NxnColorInputState {
  const NxnColorInputState({required this.selected, required this.version});
  final Color selected;

  /// Bumped on every paint so widgets rebuild counters.
  final int version;
}

/// Colouring an n×n cube on its 3D model.
class NxnColorInput extends Notifier<NxnColorInputState> {
  NxnColorInput(this.n);

  final int n;
  late NxnCubeController cube;

  @override
  NxnColorInputState build() {
    cube = NxnCubeController(n, initial: blank(n));
    ref.onDispose(cube.dispose);
    return const NxnColorInputState(selected: Color(0xFFFFFFFF), version: 0);
  }

  /// Every sticker grey, except the fixed centre of odd cubes.
  static NxnCubeState blank(int n) {
    final s = NxnCubeState.solved(n);
    for (final c in s.cubies) {
      for (final normal in [...c.stickers.keys]) {
        if (!isFixed(n, c.pos, normal)) {
          c.stickers[normal] = CubeColors.colorless;
        }
      }
    }
    return s;
  }

  static bool isFixed(int n, IVec pos, IVec normal) {
    if (n.isEven) return false;
    final zeros = [pos.$1, pos.$2, pos.$3].where((v) => v == 0).length;
    return zeros == 2;
  }

  int count(Color color) {
    var k = 0;
    for (final c in cube.state.cubies) {
      for (final v in c.stickers.values) {
        if (v.toARGB32() == color.toARGB32()) k++;
      }
    }
    return k;
  }

  int remaining(Color color) => n * n - count(color);
  int get blankCount => count(CubeColors.colorless);

  void select(Color color) {
    if (remaining(color) <= 0) return;
    state = NxnColorInputState(selected: color, version: state.version);
  }

  /// Paints the tapped sticker; tapping the same colour again erases it.
  bool paint(NxnStickerHit hit) {
    if (isFixed(n, hit.pos, hit.normal)) return false;
    final current = cube.state.stickerAt(hit.pos, hit.normal);
    final selected = state.selected;
    if (current?.toARGB32() == selected.toARGB32()) {
      cube.setSticker(hit.pos, hit.normal, CubeColors.colorless);
    } else {
      if (remaining(selected) <= 0) return false;
      cube.setSticker(hit.pos, hit.normal, selected);
    }
    var next = selected;
    if (remaining(selected) <= 0) {
      next = CubeColors.palette.firstWhere((c) => remaining(c) > 0,
          orElse: () => selected);
    }
    state = NxnColorInputState(selected: next, version: state.version + 1);
    return true;
  }

  void clear() {
    cube.replaceState(blank(n));
    state = NxnColorInputState(
        selected: const Color(0xFFFFFFFF), version: state.version + 1);
  }

  void randomExample() {
    cube.replaceState(
        NxnCubeState.solved(n)..applyAll(NxnCubeState.randomScramble(n)));
    state = NxnColorInputState(
        selected: state.selected, version: state.version + 1);
  }

  Future<PuzzleSolveOutcome> solve() async {
    final blank = blankCount;
    if (blank > 0) return PuzzleSolveIncomplete('还有 $blank 个色块没有填色');
    final counts = [
      for (final c in CubeColors.palette)
        if (count(c) != n * n) '有一种颜色出现了 ${count(c)} 次，应为 ${n * n} 次',
    ];
    if (counts.isNotEmpty) return PuzzleSolveInvalid(counts);
    if (n != 2) {
      return PuzzleSolveUnsupported(
        '颜色数量校验通过。$n 阶的自动求解需要“降阶法”（先拼中心、再配对棱块，'
        '最后按三阶解并处理奇偶），还在开发中。',
      );
    }
    final start = cube.state.copy();
    final result = await Isolate.run(() => TwoByTwoSolver.solve(start));
    if (!result.ok) return PuzzleSolveInvalid([result.error!]);
    return PuzzleSolveOk(NxnScript(initial: start, steps: result.moves));
  }
}

final nxnColorInputProvider =
    NotifierProvider.family<NxnColorInput, NxnColorInputState, int>(
  NxnColorInput.new,
);

// ── Pyraminx ───────────────────────────────────────────────────────────────

class PyraminxColorInputState {
  const PyraminxColorInputState({required this.selected, required this.version});

  /// Face-colour index 0..3.
  final int selected;
  final int version;
}

class PyraminxColorInput extends Notifier<PyraminxColorInputState> {
  late PyraminxController puzzle;

  @override
  PyraminxColorInputState build() {
    puzzle = PyraminxController(initial: PyraminxState(List.filled(36, -1)));
    ref.onDispose(puzzle.dispose);
    return const PyraminxColorInputState(selected: 3, version: 0);
  }

  int remaining(int color) =>
      9 - puzzle.state.colors.where((c) => c == color).length;
  int get blankCount => puzzle.state.colors.where((c) => c == -1).length;

  void select(int color) {
    if (remaining(color) <= 0) return;
    state = PyraminxColorInputState(selected: color, version: state.version);
  }

  bool paint(int slot) {
    final selected = state.selected;
    if (puzzle.state.colors[slot] == selected) {
      puzzle.setSticker(slot, -1);
    } else {
      if (remaining(selected) <= 0) return false;
      puzzle.setSticker(slot, selected);
    }
    var next = selected;
    if (remaining(selected) <= 0) {
      next = [0, 1, 2, 3].firstWhere((c) => remaining(c) > 0,
          orElse: () => selected);
    }
    state = PyraminxColorInputState(selected: next, version: state.version + 1);
    return true;
  }

  void clear() {
    puzzle.replaceState(PyraminxState(List.filled(36, -1)));
    state = PyraminxColorInputState(selected: 3, version: state.version + 1);
  }

  void randomExample() {
    puzzle.scramble();
    state = PyraminxColorInputState(
        selected: state.selected, version: state.version + 1);
  }

  Future<PuzzleSolveOutcome> solve() async {
    final blank = blankCount;
    if (blank > 0) return PuzzleSolveIncomplete('还有 $blank 个色块没有填色');
    final colors = [...puzzle.state.colors];
    final result = await Isolate.run(() => PyraminxSolver.solve(colors));
    if (!result.ok) return PuzzleSolveInvalid([result.error!]);
    return PuzzleSolveOk(PyraminxScript(
        initial: PyraminxState(colors), steps: result.moves));
  }
}

final pyraminxColorInputProvider =
    NotifierProvider<PyraminxColorInput, PyraminxColorInputState>(
  PyraminxColorInput.new,
);
