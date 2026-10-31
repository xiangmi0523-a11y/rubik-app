/// A classic 3x3 pattern and the algorithm that makes it from a solved cube
/// (white up, green front). Every algorithm is checked against cuber in tests.
class CubePattern {
  const CubePattern({
    required this.id,
    required this.name,
    required this.description,
    required this.algorithm,
    required this.definition,
  });

  final String id;
  final String name;
  final String description;

  /// Moves in standard notation, e.g. "R2 L2 U2".
  final String algorithm;

  /// Expected cuber facelet string after applying [algorithm] to solved.
  final String definition;

  List<String> get moves => algorithm.split(' ');
}

const cubePatterns = <CubePattern>[
  CubePattern(
    id: 'checkerboard',
    name: '棋盘格',
    description: '六个面都变成两色相间的棋盘',
    algorithm: 'R2 L2 U2 D2 F2 B2',
    definition: 'UDUDUDUDURLRLRLRLRFBFBFBFBFDUDUDUDUDLRLRLRLRLBFBFBFBFB',
  ),
  CubePattern(
    id: 'six_spots',
    name: '六面回字',
    description: '每个面中心换成另一种颜色，像“回”字',
    algorithm: "U D' R L' F B' U D'",
    definition: 'FFFFUFFFFUUUURUUUURRRRFRRRRBBBBDBBBBDDDDLDDDDLLLLBLLLL',
  ),
  CubePattern(
    id: 'four_spots',
    name: '四面回字',
    description: '前后左右四个面的中心互换',
    algorithm: "D B2 F2 D U' L2 R2 U'",
    definition: 'UUUUUUUUULLLLRLLLLBBBBFBBBBDDDDDDDDDRRRRLRRRRFFFFBFFFF',
  ),
  CubePattern(
    id: 'cross',
    name: '十字',
    description: '每个面都出现一个十字',
    algorithm: "D2 U' B2 L2 R2 D2 U2 F2 L2 R2 U'",
    definition: 'DUDUUUDUDFRFRRRFRFRFRFFFRFRUDUDDDUDUBLBLLLBLBLBLBBBLBL',
  ),
  CubePattern(
    id: 'six_ts',
    name: '六面 T 字',
    description: '每个面上都有一个 T 字',
    algorithm: "D2 B2 L2 D U' R2 F2 D' U'",
    definition: 'DDUUUUDDURLLRRRRLLFFFBFBBFBDUUDDDDUULRRLLLLRRFBFFBFBBB',
  ),
  CubePattern(
    id: 'cube_in_cube',
    name: '魔中魔',
    description: '一个角上“嵌”着一个小魔方',
    algorithm: "F L F U' R U F2 L2 U' L' B D' B' L2 U",
    definition: 'FFFFUUFUURRURRUUUURFFRFFRRRBBBDDBDDBDDDLLDLLDLLLLBBLBB',
  ),
  CubePattern(
    id: 'tetris',
    name: '俄罗斯方块',
    description: '每个面出现俄罗斯方块般的图案',
    algorithm: "L R B F D' U' L' R'",
    definition: 'FFBFUBFBBUDDURDUUDRLLRFLRRLBBFBDFBFFUDDULDUUDLRRLBRLLR',
  ),
];
