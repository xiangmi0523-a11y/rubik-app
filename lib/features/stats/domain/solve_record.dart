class SolveRecord {
  const SolveRecord({
    required this.id,
    required this.durationMs,
    required this.createdAt,
    this.scramble = '',
    this.puzzle = 'cube3',
  });

  final int id;
  final int durationMs;
  final DateTime createdAt;
  final String scramble;

  /// PuzzleType.id; records saved before multi-puzzle support are 3x3.
  final String puzzle;

  factory SolveRecord.fromJson(Map<String, dynamic> json) => SolveRecord(
        id: json['id'] as int,
        durationMs: json['durationMs'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
        scramble: (json['scramble'] as String?) ?? '',
        puzzle: (json['puzzle'] as String?) ?? 'cube3',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'durationMs': durationMs,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'scramble': scramble,
        'puzzle': puzzle,
      };
}
