import 'averages.dart';

/// WCA penalties.
enum Penalty {
  none('无罚时'),
  plus2('+2'),
  dnf('DNF');

  const Penalty(this.label);
  final String label;
}

class SolveRecord {
  const SolveRecord({
    required this.id,
    required this.durationMs,
    required this.createdAt,
    this.scramble = '',
    this.puzzle = 'cube3',
    this.penalty = Penalty.none,
  });

  final int id;

  /// Raw timer value.
  final int durationMs;
  final DateTime createdAt;
  final String scramble;

  /// PuzzleType.id; records saved before multi-puzzle support are 3x3.
  final String puzzle;
  final Penalty penalty;

  /// Time that counts: +2 adds 2 s, DNF is [kDnf].
  int get effectiveMs => switch (penalty) {
        Penalty.none => durationMs,
        Penalty.plus2 => durationMs + 2000,
        Penalty.dnf => kDnf,
      };

  SolveRecord copyWith({Penalty? penalty}) => SolveRecord(
        id: id,
        durationMs: durationMs,
        createdAt: createdAt,
        scramble: scramble,
        puzzle: puzzle,
        penalty: penalty ?? this.penalty,
      );

  factory SolveRecord.fromJson(Map<String, dynamic> json) => SolveRecord(
        id: json['id'] as int,
        durationMs: json['durationMs'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
        scramble: (json['scramble'] as String?) ?? '',
        puzzle: (json['puzzle'] as String?) ?? 'cube3',
        penalty: Penalty.values.asNameMap()[json['penalty']] ?? Penalty.none,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'durationMs': durationMs,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'scramble': scramble,
        'puzzle': puzzle,
        'penalty': penalty.name,
      };
}
