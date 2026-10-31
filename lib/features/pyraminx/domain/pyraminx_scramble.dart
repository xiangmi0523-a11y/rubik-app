import 'dart:math' as math;

/// WCA-style Pyraminx scramble text (no model needed): 11 turns of U L R B
/// with no face repeated twice in a row, then random tip turns u l r b.
String pyraminxScramble({math.Random? rng, int length = 11}) {
  final random = rng ?? math.Random();
  const faces = ['U', 'L', 'R', 'B'];
  final moves = <String>[];
  String? last;
  while (moves.length < length) {
    final f = faces[random.nextInt(4)];
    if (f == last) continue;
    moves.add(random.nextBool() ? f : "$f'");
    last = f;
  }
  for (final tip in ['u', 'l', 'r', 'b']) {
    switch (random.nextInt(3)) {
      case 1:
        moves.add(tip);
      case 2:
        moves.add("$tip'");
    }
  }
  return moves.join(' ');
}
