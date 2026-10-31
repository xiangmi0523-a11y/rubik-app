/// WCA average of the last [n] times: drop best and worst, mean of the rest.
/// [timesMs] is ordered oldest -> newest. Returns null if not enough solves.
int? averageOfLast(List<int> timesMs, int n) {
  if (n < 3 || timesMs.length < n) return null;
  return averageOf(timesMs.sublist(timesMs.length - n));
}

/// Trimmed mean of one window (drops one best and one worst).
int averageOf(List<int> window) {
  final sorted = [...window]..sort();
  final trimmed = sorted.sublist(1, sorted.length - 1);
  final sum = trimmed.fold<int>(0, (a, b) => a + b);
  return (sum / trimmed.length).round();
}

/// Best aoN over every window of the session.
int? bestAverage(List<int> timesMs, int n) {
  if (n < 3 || timesMs.length < n) return null;
  int? best;
  for (var i = 0; i + n <= timesMs.length; i++) {
    final avg = averageOf(timesMs.sublist(i, i + n));
    if (best == null || avg < best) best = avg;
  }
  return best;
}

class StatsSummary {
  const StatsSummary({
    required this.count,
    required this.best,
    required this.mean,
    required this.ao5,
    required this.ao12,
    required this.bestAo5,
    required this.bestAo12,
  });

  final int count;
  final int? best;
  final int? mean;
  final int? ao5;
  final int? ao12;
  final int? bestAo5;
  final int? bestAo12;

  factory StatsSummary.from(List<int> timesMs) {
    final count = timesMs.length;
    return StatsSummary(
      count: count,
      best: count == 0 ? null : timesMs.reduce((a, b) => a < b ? a : b),
      mean: count == 0
          ? null
          : (timesMs.fold<int>(0, (a, b) => a + b) / count).round(),
      ao5: averageOfLast(timesMs, 5),
      ao12: averageOfLast(timesMs, 12),
      bestAo5: bestAverage(timesMs, 5),
      bestAo12: bestAverage(timesMs, 12),
    );
  }
}
