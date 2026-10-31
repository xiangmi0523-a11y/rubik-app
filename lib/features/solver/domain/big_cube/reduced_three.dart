import 'package:cuber/cuber.dart' as cuber;

import '../../../../core/nxn/nxn_cube_state.dart';
import 'solve_step.dart';
import 'target_scheme.dart';

/// The 3x3 a reduced 4x4 / 5x5 behaves as (centres solved, edges paired),
/// and solving it with cuber's two-phase solver using outer turns only.
abstract final class ReducedThree {
  /// cuber facelet frames, U R F D L B: (outward normal, row direction,
  /// column direction) as seen from outside, rows/columns read 1..9.
  static const frames = <(IVec, IVec, IVec)>[
    ((0, 1, 0), (0, 0, 1), (1, 0, 0)), // U
    ((1, 0, 0), (0, -1, 0), (0, 0, -1)), // R
    ((0, 0, 1), (0, -1, 0), (1, 0, 0)), // F
    ((0, -1, 0), (0, 0, -1), (1, 0, 0)), // D
    ((-1, 0, 0), (0, -1, 0), (0, 0, 1)), // L
    ((0, 0, -1), (0, -1, 0), (-1, 0, 0)), // B
  ];

  static const _letters = 'URFDLB';

  /// The n×n sticker each of the 54 facelets is read from: corners from the
  /// corners, edges from one wing (5x5: the middle edge), centres from one
  /// centre piece (5x5: the fixed centre).
  static List<(IVec, IVec)> sources(int n) {
    final m = n - 1;
    final inner = n.isOdd ? 0 : 1;
    int map(int u) => u == 0 ? inner : u * m;
    return [
      for (final (nv, r, c) in frames)
        for (var row = -1; row <= 1; row++)
          for (var col = -1; col <= 1; col++)
            (
              (
                map(nv.$1 + row * r.$1 + col * c.$1),
                map(nv.$2 + row * r.$2 + col * c.$2),
                map(nv.$3 + row * r.$3 + col * c.$3),
              ),
              nv,
            ),
    ];
  }

  /// cuber definition of the reduced cube: each facelet is the letter of the
  /// face whose target colour it shows. Null if a sticker isn't one of the
  /// scheme's colours.
  static String? definition(NxnCubeState state, TargetScheme scheme) {
    final letters = {
      for (var i = 0; i < 6; i++) scheme.faceColors[i]: _letters[i],
    };
    final b = StringBuffer();
    for (final (pos, normal) in sources(state.n)) {
      final letter = letters[state.stickerAt(pos, normal)?.toARGB32()];
      if (letter == null) return null;
      b.write(letter);
    }
    return b.toString();
  }

  static cuber.CubeStatus status(String definition) =>
      cuber.Cube.from(definition).verify();

  /// The n×n outer turn for a cuber move.
  static NxnMove toNxn(cuber.Move move, int n) => NxnMove.parse(
      '${move.color.letter}${move.inverted ? "'" : (move.double ? '2' : '')}', n);

  /// Solves the reduced cube in place with cuber, appending one step.
  static SolveFailure? solve(
    NxnCubeState state,
    TargetScheme scheme,
    List<SolveStep> steps, {
    required DateTime deadline,
  }) {
    final def = definition(state, scheme);
    if (def == null) {
      return const SolveFailure(SolveFailureKind.invalidInput, '有贴纸颜色不属于这套配色');
    }
    final cube = cuber.Cube.from(def);
    final status = cube.verify();
    if (status != cuber.CubeStatus.ok) {
      return SolveFailure(SolveFailureKind.invalidInput, statusMessage(status));
    }
    if (cube.isSolved) return null;
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      return const SolveFailure(SolveFailureKind.timeout, '三阶求解超时');
    }
    final solution = cube.solve(maxDepth: 25, timeout: remaining);
    if (solution == null) {
      return DateTime.now().isBefore(deadline)
          ? const SolveFailure(SolveFailureKind.internal, '三阶求解器没有找到解')
          : const SolveFailure(SolveFailureKind.timeout, '三阶求解超时');
    }
    final moves = [for (final m in solution.algorithm.moves) toNxn(m, state.n)];
    state.applyAll(moves);
    if (!state.isSolved) {
      return const SolveFailure(SolveFailureKind.internal, '三阶解法执行后魔方没有还原');
    }
    steps.add(SolveStep(
      phase: ReductionPhase.threeByThree,
      description: '三阶还原',
      moves: moves,
    ));
    return null;
  }

  static String statusMessage(cuber.CubeStatus status) => switch (status) {
        cuber.CubeStatus.ok => '正常',
        cuber.CubeStatus.twistedEdge => '有一个棱块被单独翻转了（单棱翻色）',
        cuber.CubeStatus.twistedCorner => '有角块被单独拧转了（单角翻转）',
        cuber.CubeStatus.parityError => '奇偶校验失败（两个块的位置被互换了）',
        cuber.CubeStatus.missingCorner => '角块颜色组合不可能，请检查八个角',
        cuber.CubeStatus.missingEdge => '棱块颜色组合不可能，请检查棱块',
      };
}
