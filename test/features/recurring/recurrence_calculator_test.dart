import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_finance/core/money/money.dart';
import 'package:nexo_finance/features/recurring/domain/recurring_transaction.dart';
import 'package:nexo_finance/features/transactions/domain/financial_transaction.dart';

void main() {
  test('una recurrencia mensual conserva el día cuando existe', () {
    final item = _item(DateTime.utc(2026, 9, 15, 5));
    expect(RecurrenceCalculator.next(item), DateTime.utc(2026, 10, 15, 5));
  });

  test('una recurrencia de fin de mes se ajusta al último día', () {
    final item = _item(DateTime.utc(2027, 1, 31, 5));
    expect(RecurrenceCalculator.next(item), DateTime.utc(2027, 2, 28, 5));
  });

  test(
    'el identificador de una ocurrencia es estable y cambia con la fecha',
    () {
      final item = _item(DateTime.utc(2026, 9, 15, 5));
      final sameOccurrence = _item(DateTime.utc(2026, 9, 15, 5));
      final nextOccurrence = _item(DateTime.utc(2026, 10, 15, 5));

      expect(
        RecurrenceCalculator.occurrenceTransactionId(item),
        RecurrenceCalculator.occurrenceTransactionId(sameOccurrence),
      );
      expect(
        RecurrenceCalculator.occurrenceTransactionId(item),
        isNot(RecurrenceCalculator.occurrenceTransactionId(nextOccurrence)),
      );
    },
  );
}

RecurringTransaction _item(DateTime due) => RecurringTransaction(
  id: 'recurring',
  userId: 'user',
  name: 'Internet',
  kind: TransactionKind.expense,
  amountMinor: 1000,
  currency: Currency.pen,
  frequency: RecurringFrequency.monthly,
  interval: 1,
  nextDueAt: due,
  createdAt: due,
  updatedAt: due,
);
