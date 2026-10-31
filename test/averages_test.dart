import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_app/features/stats/domain/averages.dart';

void main() {
  test('ao5 drops best and worst', () {
    expect(averageOfLast([10000, 12000, 11000, 9000, 20000], 5), 11000);
  });

  test('not enough solves -> null', () {
    expect(averageOfLast([1, 2, 3, 4], 5), isNull);
    expect(averageOfLast(List.filled(11, 1000), 12), isNull);
  });

  test('ao12 uses last 12 solves', () {
    final times = [99999, ...List.generate(12, (i) => 10000 + i * 100)];
    // last 12: 10000..11100, drop 10000 & 11100 -> mean of 10100..11000
    expect(averageOfLast(times, 12), 10550);
  });

  test('best ao5 over session', () {
    final times = [20000, 10000, 10000, 10000, 10000, 10000, 30000];
    expect(bestAverage(times, 5), 10000);
  });
}
