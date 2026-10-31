import '../../puzzles/domain/puzzle_type.dart';

/// A classic pattern and the algorithm that makes it from a solved puzzle
/// (cubes: white up, green front). Every algorithm is verified in tests.
class PuzzlePattern {
  const PuzzlePattern({
    required this.puzzle,
    required this.id,
    required this.name,
    required this.description,
    required this.algorithm,
    this.definition,
  });

  final PuzzleType puzzle;
  final String id;
  final String name;
  final String description;

  /// Moves in standard notation, e.g. "R2 L2 U2" or "U u' L l'".
  final String algorithm;

  /// 3x3 only: expected cuber facelet string after the algorithm.
  final String? definition;

  List<String> get moves => algorithm.split(' ');
}

List<PuzzlePattern> patternsFor(PuzzleType type) =>
    [for (final p in puzzlePatterns) if (p.puzzle == type) p];

const puzzlePatterns = <PuzzlePattern>[
  // ── 3x3 ──
  PuzzlePattern(
    puzzle: PuzzleType.cube3,
    id: 'checkerboard',
    name: '棋盘格',
    description: '六个面都变成两色相间的棋盘',
    algorithm: 'R2 L2 U2 D2 F2 B2',
    definition: 'UDUDUDUDURLRLRLRLRFBFBFBFBFDUDUDUDUDLRLRLRLRLBFBFBFBFB',
  ),
  PuzzlePattern(
    puzzle: PuzzleType.cube3,
    id: 'six_spots',
    name: '六面回字',
    description: '每个面中心换成另一种颜色，像“回”字',
    algorithm: "U D' R L' F B' U D'",
    definition: 'FFFFUFFFFUUUURUUUURRRRFRRRRBBBBDBBBBDDDDLDDDDLLLLBLLLL',
  ),
  PuzzlePattern(
    puzzle: PuzzleType.cube3,
    id: 'four_spots',
    name: '四面回字',
    description: '前后左右四个面的中心互换',
    algorithm: "D B2 F2 D U' L2 R2 U'",
    definition: 'UUUUUUUUULLLLRLLLLBBBBFBBBBDDDDDDDDDRRRRLRRRRFFFFBFFFF',
  ),
  PuzzlePattern(
    puzzle: PuzzleType.cube3,
    id: 'cross',
    name: '十字',
    description: '每个面都出现一个十字',
    algorithm: "D2 U' B2 L2 R2 D2 U2 F2 L2 R2 U'",
    definition: 'DUDUUUDUDFRFRRRFRFRFRFFFRFRUDUDDDUDUBLBLLLBLBLBLBBBLBL',
  ),
  PuzzlePattern(
    puzzle: PuzzleType.cube3,
    id: 'six_ts',
    name: '六面 T 字',
    description: '每个面上都有一个 T 字',
    algorithm: "D2 B2 L2 D U' R2 F2 D' U'",
    definition: 'DDUUUUDDURLLRRRRLLFFFBFBBFBDUUDDDDUULRRLLLLRRFBFFBFBBB',
  ),
  PuzzlePattern(
    puzzle: PuzzleType.cube3,
    id: 'cube_in_cube',
    name: '魔中魔',
    description: '一个角上“嵌”着一个小魔方',
    algorithm: "F L F U' R U F2 L2 U' L' B D' B' L2 U",
    definition: 'FFFFUUFUURRURRUUUURFFRFFRRRBBBDDBDDBDDDLLDLLDLLLLBBLBB',
  ),
  PuzzlePattern(
    puzzle: PuzzleType.cube3,
    id: 'tetris',
    name: '俄罗斯方块',
    description: '每个面出现俄罗斯方块般的图案',
    algorithm: "L R B F D' U' L' R'",
    definition: 'FFBFUBFBBUDDURDUUDRLLRFLRRLBBFBDFBFFUDDULDUUDLRRLBRLLR',
  ),
  // ── 2x2 ──
  PuzzlePattern(
    puzzle: PuzzleType.cube2,
    id: 'stripes2',
    name: '六面条纹',
    description: '每个面都变成两色条纹（二阶没有中心块，图案较少）',
    algorithm: 'U2 R2',
  ),
  // ── 4x4 ──
  PuzzlePattern(
    puzzle: PuzzleType.cube4,
    id: 'six_spots4',
    name: '六面回字',
    description: '每个面中间 2×2 换成对面颜色',
    algorithm: "U D' R L' F B' U D'",
  ),
  PuzzlePattern(
    puzzle: PuzzleType.cube4,
    id: 'four_spots4',
    name: '四面回字',
    description: '前后左右四个面的中间 2×2 互换',
    algorithm: "D B2 F2 D U' L2 R2 U'",
  ),
  PuzzlePattern(
    puzzle: PuzzleType.cube4,
    id: 'cube_in_cube4',
    name: '魔中魔',
    description: '一个角上“嵌”着一个 3×3 的小魔方',
    algorithm: "F L F U' R U F2 L2 U' L' B D' B' L2 U",
  ),
  // ── 5x5 ──
  PuzzlePattern(
    puzzle: PuzzleType.cube5,
    id: 'checkerboard5',
    name: '棋盘格',
    description: '六个面都变成 5×5 的两色棋盘',
    algorithm: '2R2 2L2 2U2 2D2 2F2 2B2',
  ),
  PuzzlePattern(
    puzzle: PuzzleType.cube5,
    id: 'six_spots5',
    name: '六面回字',
    description: '每个面中间 3×3 换成另一种颜色',
    algorithm: "U D' R L' F B' U D'",
  ),
  PuzzlePattern(
    puzzle: PuzzleType.cube5,
    id: 'checkerboard5b',
    name: '大棋盘',
    description: '外层与中层交替翻转出的棋盘',
    algorithm: 'R2 L2 U2 D2 F2 B2 3R2 3U2 3F2',
  ),
  // ── Pyraminx ──
  PuzzlePattern(
    puzzle: PuzzleType.pyraminx,
    id: 'tips',
    name: '顶角旋转',
    description: '四个小顶角各转一下，顶角颜色与面不同',
    algorithm: 'u l r b',
  ),
  PuzzlePattern(
    puzzle: PuzzleType.pyraminx,
    id: 'flower',
    name: '花朵',
    description: '只转中心层：每个面中间开出一朵三色花',
    algorithm: "U u' L l' R r' B b'",
  ),
  PuzzlePattern(
    puzzle: PuzzleType.pyraminx,
    id: 'two_tone',
    name: '双色面',
    description: '每个面都只剩两种颜色',
    algorithm: "U L' U L' U L'",
  ),
];
