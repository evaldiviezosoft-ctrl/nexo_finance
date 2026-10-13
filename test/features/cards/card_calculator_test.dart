import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_finance/core/money/money.dart';
import 'package:nexo_finance/features/accounts/domain/financial_account.dart';
import 'package:nexo_finance/features/cards/domain/card_calculator.dart';
import 'package:nexo_finance/features/cards/domain/card_statement.dart';
import 'package:nexo_finance/features/transactions/domain/financial_transaction.dart';

void main() {
  final now = DateTime.utc(2026, 9, 11);

  test('compra aumenta deuda y pago no duplica gasto', () {
    final card = FinancialAccount(
      id: 'bcp',
      userId: 'user',
      name: 'BCP',
      type: AccountType.creditCard,
      currency: Currency.pen,
      initialBalanceMinor: 125535,
      creditLimitMinor: 240000,
      createdAt: now,
      updatedAt: now,
    );
    final position = CardCalculator.position(card, [
      _transaction(TransactionKind.creditPurchase, 4741, now),
      _transaction(TransactionKind.creditPayment, 4741, now),
    ]);

    expect(position.debtMinor, 125535);
    expect(position.availableCreditMinor, 114465);
  });

  test('solo las reservas de ciclos no pagados comprometen dinero', () {
    CardStatement statement(
      String id,
      CardStatementStatus status,
      int amount,
    ) => CardStatement(
      id: id,
      userId: 'user',
      cardAccountId: 'bcp',
      cycleStart: now,
      cycleEnd: now,
      dueDate: now,
      amountDuePenMinor: amount,
      amountDueUsdMinor: 0,
      reservedPenMinor: amount,
      reservedUsdMinor: 0,
      status: status,
      createdAt: now,
      updatedAt: now,
    );

    expect(
      CardCalculator.reservedPen([
        statement('open', CardStatementStatus.open, 10000),
        statement('paid', CardStatementStatus.paid, 5000),
      ]),
      10000,
    );
  });
}

FinancialTransaction _transaction(
  TransactionKind kind,
  int amount,
  DateTime now,
) => FinancialTransaction(
  id: kind.name,
  userId: 'user',
  kind: kind,
  amountMinor: amount,
  currency: Currency.pen,
  sourceAccountId: kind == TransactionKind.creditPurchase ? 'bcp' : 'cash',
  destinationAccountId: kind == TransactionKind.creditPayment ? 'bcp' : null,
  occurredAt: now,
  createdAt: now,
  updatedAt: now,
);
