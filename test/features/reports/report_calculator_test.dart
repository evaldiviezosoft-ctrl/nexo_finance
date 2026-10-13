import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_finance/core/money/money.dart';
import 'package:nexo_finance/features/reports/domain/report_calculator.dart';
import 'package:nexo_finance/features/transactions/domain/financial_transaction.dart';

void main() {
  FinancialTransaction tx(
    String id,
    TransactionKind kind,
    int amount,
    DateTime date, {
    String? category,
  }) => FinancialTransaction(
    id: id,
    userId: 'user',
    kind: kind,
    amountMinor: amount,
    currency: Currency.pen,
    sourceAccountId: kind.countsAsExpense ? 'bank' : null,
    destinationAccountId: kind.countsAsIncome ? 'bank' : null,
    categoryId: category,
    occurredAt: date,
    createdAt: date,
    updatedAt: date,
  );

  test('serie mensual separa ingresos, gastos y pagos neutrales', () {
    final data = [
      tx('income', TransactionKind.income, 100000, DateTime.utc(2026, 9, 5, 5)),
      tx(
        'expense',
        TransactionKind.expense,
        25000,
        DateTime.utc(2026, 9, 8, 5),
        category: 'food',
      ),
      tx(
        'payment',
        TransactionKind.debtPayment,
        30000,
        DateTime.utc(2026, 9, 9, 5),
      ),
    ];
    final series = ReportCalculator.monthlySeries(
      transactions: data,
      reference: DateTime.utc(2026, 9, 13),
      months: 1,
      currency: Currency.pen,
    );
    expect(series.single.incomeMinor, 100000);
    expect(series.single.expenseMinor, 25000);
    expect(series.single.savingsMinor, 75000);
  });

  test('distribución agrupa solo gastos por categoría', () {
    final data = [
      tx(
        'one',
        TransactionKind.expense,
        1200,
        DateTime.utc(2026, 9, 2, 5),
        category: 'food',
      ),
      tx(
        'two',
        TransactionKind.creditPurchase,
        800,
        DateTime.utc(2026, 9, 3, 5),
        category: 'food',
      ),
      tx(
        'income',
        TransactionKind.income,
        5000,
        DateTime.utc(2026, 9, 4, 5),
        category: 'salary',
      ),
    ];
    final totals = ReportCalculator.categoryTotals(
      transactions: data,
      start: DateTime.utc(2026, 9, 1, 5),
      end: DateTime.utc(2026, 10, 1, 5),
      currency: Currency.pen,
    );
    expect(totals, {'food': 2000});
  });

  test('reembolsos por categoria no dependen del orden', () {
    final expense = tx(
      'expense',
      TransactionKind.expense,
      2000,
      DateTime.utc(2026, 9, 3, 5),
      category: 'food',
    );
    final refund = tx(
      'refund',
      TransactionKind.refund,
      800,
      DateTime.utc(2026, 9, 2, 5),
      category: 'food',
    );

    Map<String, int> calculate(List<FinancialTransaction> transactions) =>
        ReportCalculator.categoryTotals(
          transactions: transactions,
          start: DateTime.utc(2026, 9, 1, 5),
          end: DateTime.utc(2026, 10, 1, 5),
          currency: Currency.pen,
        );

    expect(calculate([refund, expense]), {'food': 1200});
    expect(calculate([expense, refund]), {'food': 1200});
  });

  test('un reembolso superior al gasto no produce un total negativo', () {
    final totals = ReportCalculator.categoryTotals(
      transactions: [
        tx(
          'refund',
          TransactionKind.refund,
          2500,
          DateTime.utc(2026, 9, 2, 5),
          category: 'food',
        ),
        tx(
          'expense',
          TransactionKind.expense,
          1000,
          DateTime.utc(2026, 9, 3, 5),
          category: 'food',
        ),
      ],
      start: DateTime.utc(2026, 9, 1, 5),
      end: DateTime.utc(2026, 10, 1, 5),
      currency: Currency.pen,
    );

    expect(totals, {'food': 0});
  });

  test('ritmo diario compara acumulado contra presupuesto', () {
    final data = [
      tx(
        'one',
        TransactionKind.expense,
        3100,
        DateTime.utc(2026, 9, 1, 5),
        category: 'food',
      ),
    ];
    final points = ReportCalculator.dailyCumulative(
      transactions: data,
      month: DateTime.utc(2026, 9, 13),
      currency: Currency.pen,
      budgetMinor: 30000,
      now: DateTime.utc(2026, 9, 13),
    );
    expect(points.first.actualMinor, 3100);
    expect(points.first.allowedMinor, 1000);
    expect(points, hasLength(30));
  });

  test('el cambio de mes respeta la hora de Lima', () {
    final data = [
      tx(
        'last-day',
        TransactionKind.expense,
        4200,
        DateTime.utc(2026, 10, 1, 2),
        category: 'food',
      ),
    ];
    final series = ReportCalculator.monthlySeries(
      transactions: data,
      reference: DateTime.utc(2026, 10, 1, 2),
      months: 1,
      currency: Currency.pen,
    );
    expect(series.single.month, DateTime.utc(2026, 9, 1, 5));
    expect(series.single.expenseMinor, 4200);
  });
}
