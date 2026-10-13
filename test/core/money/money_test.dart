import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_finance/core/money/money.dart';

void main() {
  group('Money', () {
    test('stores and formats PEN exclusively from minor units', () {
      const money = Money(125050, Currency.pen);

      expect(money.minorUnits, 125050);
      expect(money.format(), 'S/ 1,250.50');
    });

    test('formats USD and negative values', () {
      expect(const Money(2446, Currency.usd).format(), r'US$ 24.46');
      expect(const Money(-1050, Currency.pen).format(), '-S/ 10.50');
    });

    test('adds values in the same currency', () {
      expect(
        const Money(1000, Currency.pen) + const Money(50, Currency.pen),
        const Money(1050, Currency.pen),
      );
    });

    test('rejects operations between different currencies', () {
      expect(
        () => const Money(100, Currency.pen) + const Money(100, Currency.usd),
        throwsArgumentError,
      );
    });
  });

  test('parses decimal input without using floating point', () {
    expect(Money.parseMinorUnits('10.50'), 1050);
    expect(Money.parseMinorUnits('24,46'), 2446);
    expect(Money.parseMinorUnits('10.999'), isNull);
  });
}
