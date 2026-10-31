/// Puzzles the app knows about, in display order.
enum PuzzleType {
  cube2('cube2', '二阶', 2),
  cube3('cube3', '三阶', 3),
  cube4('cube4', '四阶', 4),
  cube5('cube5', '五阶', 5),
  pyraminx('pyraminx', '金字塔', null);

  const PuzzleType(this.id, this.label, this.order);

  /// Stable id used in storage.
  final String id;
  final String label;

  /// Cube order, or null for non-cube puzzles.
  final int? order;

  /// 3x3 uses puzzle_cube + cuber; 2x2/4x4/5x5 use the in-house N×N engine.
  bool get usesNxnEngine => order != null && this != PuzzleType.cube3;

  bool get isPyraminx => this == PuzzleType.pyraminx;

  static PuzzleType fromId(String? id) => PuzzleType.values.firstWhere(
        (t) => t.id == id,
        orElse: () => PuzzleType.cube3,
      );
}
