/// 12.34 / 1:02.34
String formatDuration(Duration d) {
  final cs = (d.inMilliseconds ~/ 10) % 100;
  final s = d.inSeconds % 60;
  final m = d.inMinutes;
  final cc = cs.toString().padLeft(2, '0');
  if (m == 0) return '$s.$cc';
  return '$m:${s.toString().padLeft(2, '0')}.$cc';
}

String formatMs(int? ms) =>
    ms == null ? '-' : formatDuration(Duration(milliseconds: ms));
