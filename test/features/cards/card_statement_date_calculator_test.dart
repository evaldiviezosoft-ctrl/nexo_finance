import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_finance/core/money/money.dart';
import 'package:nexo_finance/features/accounts/domain/financial_account.dart';
import 'package:nexo_finance/features/cards/domain/card_statement_date_calculator.dart';

void main() {
  test('uses the latest closed cycle and its following payment date', () {
    final dates = CardStatementDateCalculator.defaultsFor(
      _card(closingDay: 25, paymentDay: 22),
      now: DateTime.utc(2026, 10, 13, 17),
    );

    expect(dates.cycleStart, DateTime.utc(2026, 8, 26, 5));
    expect(dates.cycleEnd, DateTime.utc(2026, 9, 25, 5));
    expect(dates.dueDate, DateTime.utc(2026, 10, 22, 5));
  });

  test('keeps a payment later than closing in the same month', () {
    final dates = CardStatementDateCalculator.defaultsFor(
      _card(closingDay: 5, paymentDay: 25),
      now: DateTime.utc(2026, 10, 13, 17),
    );

    expect(dates.cycleStart, DateTime.utc(2026, 9, 6, 5));
    expect(dates.cycleEnd, DateTime.utc(2026, 10, 5, 5));
    expect(dates.dueDate, DateTime.utc(2026, 10, 25, 5));
  });

  test('clamps closing and payment days in short months', () {
    final dates = CardStatementDateCalculator.defaultsFor(
      _card(closingDay: 31, paymentDay: 30),
      now: DateTime.utc(2027, 3, 15, 17),
    );

    expect(dates.cycleStart, DateTime.utc(2027, 2, 1, 5));
    expect(dates.cycleEnd, DateTime.utc(2027, 2, 28, 5));
    expect(dates.dueDate, DateTime.utc(2027, 3, 30, 5));
  });
}

FinancialAccount _card({required int closingDay, required int paymentDay}) {
  final now = DateTime.utc(2026, 1, 1);
  return FinancialAccount(
    id: 'card',
    userId: 'user',
    name: 'Tarjeta',
    type: AccountType.creditCard,
    currency: Currency.pen,
    initialBalanceMinor: 0,
    closingDay: closingDay,
    paymentDay: paymentDay,
    createdAt: now,
    updatedAt: now,
  );
}
