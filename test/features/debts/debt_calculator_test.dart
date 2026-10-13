import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_finance/core/money/money.dart';
import 'package:nexo_finance/features/debts/domain/debt_calculator.dart';
import 'package:nexo_finance/features/debts/domain/debt_record.dart';
import 'package:nexo_finance/features/transactions/domain/financial_transaction.dart';

void main() {
  final date = DateTime.utc(2026, 9, 12);

  test('un pago vinculado reduce la deuda sin duplicar gasto', () {
    final debt = DebtRecord(
      id: 'debt-1',
      userId: 'user',
      name: 'Préstamo',
      direction: DebtDirection.owed,
      type: DebtType.bankLoan,
      party: 'Banco',
      initialPrincipalMinor: 100000,
      currency: Currency.pen,
      createdAt: date,
      updatedAt: date,
    );
    final payment = FinancialTransaction(
      id: 'pay',
      userId: 'user',
      kind: TransactionKind.debtPayment,
      amountMinor: 25000,
      currency: Currency.pen,
      sourceAccountId: 'bank',
      debtId: debt.id,
      occurredAt: date,
      createdAt: date,
      updatedAt: date,
    );
    final position = DebtCalculator.position(debt, [payment]);
    expect(position.paidMinor, 25000);
    expect(position.remainingMinor, 75000);
    expect(payment.kind.countsAsExpense, isFalse);
  });

  test('prepago reduce plazo e intereses', () {
    final result = DebtCalculator.simulate(
      principalMinor: 1000000,
      annualRateBasisPoints: 2400,
      monthlyPaymentMinor: 60000,
      extraMonthlyMinor: 10000,
      prepaymentMinor: 100000,
    );
    expect(result.accelerated.months, lessThan(result.normal.months));
    expect(result.interestSavedMinor, greaterThan(0));
  });

  test('aporte de tercero reduce deuda sin salir de la cuenta propia', () {
    final debt = DebtRecord(
      id: 'shared',
      userId: 'user',
      name: 'Préstamo compartido',
      direction: DebtDirection.owed,
      type: DebtType.shared,
      party: 'BCP',
      initialPrincipalMinor: 190079,
      currency: Currency.pen,
      createdAt: date,
      updatedAt: date,
    );
    final payment = FinancialTransaction(
      id: 'shared-pay',
      userId: 'user',
      kind: TransactionKind.debtPayment,
      amountMinor: 35039,
      thirdPartyAmountMinor: 35100,
      currency: Currency.pen,
      sourceAccountId: 'bank',
      debtId: debt.id,
      occurredAt: date,
      createdAt: date,
      updatedAt: date,
    );
    final position = DebtCalculator.position(debt, [payment]);
    expect(position.paidMinor, 70139);
    expect(position.remainingMinor, 119940);
  });

  test('deuda sin intereses mantiene prioridad financiera neutral', () {
    final result = DebtCalculator.simulate(
      principalMinor: 120000,
      annualRateBasisPoints: 0,
      monthlyPaymentMinor: 10000,
    );
    expect(result.normal.months, 12);
    expect(result.normal.totalInterestMinor, 0);
  });
}
