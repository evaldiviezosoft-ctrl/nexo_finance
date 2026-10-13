import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_finance/core/time/lima_time.dart';

void main() {
  test('a selected Lima calendar day stays on that day', () {
    final stored = limaMidnightUtc(2026, 9, 13);

    expect(stored, DateTime.utc(2026, 9, 13, 5));
    expect(toLimaTime(stored), DateTime(2026, 9, 13));
    expect(toLimaTime(stored).isUtc, isFalse);
  });

  test('preserves sub-second Lima wall-clock fields', () {
    final stored = DateTime.utc(2026, 9, 13, 18, 42, 7, 123, 456);

    expect(toLimaTime(stored), DateTime(2026, 9, 13, 13, 42, 7, 123, 456));
  });
}
