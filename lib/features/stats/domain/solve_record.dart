class SolveRecord {
  const SolveRecord({
    required this.id,
    required this.durationMs,
    required this.createdAt,
    this.scramble = '',
  });

  final int id;
  final int durationMs;
  final DateTime createdAt;
  final String scramble;

  factory SolveRecord.fromJson(Map<String, dynamic> json) => SolveRecord(
        id: json['id'] as int,
        durationMs: json['durationMs'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
        scramble: (json['scramble'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'durationMs': durationMs,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'scramble': scramble,
      };
}
