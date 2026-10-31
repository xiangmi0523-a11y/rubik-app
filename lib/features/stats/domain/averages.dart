/// A DNF time (counts as slower than anything).
const int kDnf = -1;

int _rank(int t) => t == kDnf ? 1 << 62 : t;

/// WCA average of the last [n] times: drop best and worst, mean of the rest.
/// [timesMs] is ordered oldest -> newest; [kDnf] marks a DNF. Returns null if
/// not enough solves, [kDnf] if the average is DNF (2+ DNFs in the window).
int? averageOfLast(List<int> timesMs, int n) {
  if (n < 3 || timesMs.length < n) return null;
  return averageOf(timesMs.sublist(timesMs.length - n));
}

/// Trimmed mean of one window (drops one best and one worst). One DNF is
/// dropped as the worst; two or more make the average a DNF.
int averageOf(List<int> window) {
  if (window.where((t) => t == kDnf).length >= 2) return kDnf;
  final sorted = [...window]..sort((a, b) => _rank(a).compareTo(_rank(b)));
  final trimmed = sorted.sublist(1, sorted.length - 1);
  final sum = trimmed.fold<int>(0, (a, b) => a + b);
  return (sum / trimmed.length).round();
}

/// Best aoN over every window of the session (null if too few solves).
int? bestAverage(List<int> timesMs, int n) {
  if (n < 3 || timesMs.length < n) return null;
  int? best;
  for (var i = 0; i + n <= timesMs.length; i++) {
    final avg = averageOf(timesMs.sublist(i, i + n));
    if (best == null || _rank(avg) < _rank(best)) best = avg;
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
    final ok = timesMs.where((t) => t != kDnf).toList();
    return StatsSummary(
      count: timesMs.length,
      best: ok.isEmpty ? null : ok.reduce((a, b) => a < b ? a : b),
      mean: ok.isEmpty
          ? null
          : (ok.fold<int>(0, (a, b) => a + b) / ok.length).round(),
      ao5: averageOfLast(timesMs, 5),
      ao12: averageOfLast(timesMs, 12),
      bestAo5: bestAverage(timesMs, 5),
      bestAo12: bestAverage(timesMs, 12),
    );
  }
}
