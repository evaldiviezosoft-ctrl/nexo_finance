import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_finance/core/money/money.dart';
import 'package:nexo_finance/features/budgets/domain/budget.dart';
import 'package:nexo_finance/features/budgets/domain/budget_calculator.dart';
import 'package:nexo_finance/features/transactions/domain/financial_transaction.dart';

void main() {
  final now = DateTime.utc(2026, 9, 12, 2);
  final budget = Budget(
    id: 'budget',
    userId: 'user',
    name: 'Moto',
    period: BudgetPeriod.monthly,
    amountMinor: 20000,
    currency: Currency.pen,
    categoryId: 'moto',
    createdAt: now,
    updatedAt: now,
  );

  test('calcula el mes usando medianoche de Lima y categorías hijas', () {
    final progress = BudgetCalculator.calculate(
      budget: budget,
      reference: now,
      categoryIds: {'moto', 'combustible'},
      transactions: [
        _transaction('expense', 10000, 'moto', DateTime.utc(2026, 9, 12)),
        _transaction(
          'creditPurchase',
          4741,
          'combustible',
          DateTime.utc(2026, 9, 12),
        ),
        _transaction('refund', 1000, 'moto', DateTime.utc(2026, 9, 12)),
      ],
    );

    expect(progress.start, DateTime.utc(2026, 9, 1, 5));
    expect(progress.spentMinor, 13741);
    expect(progress.remainingMinor, 6259);
    expect(progress.health, BudgetHealth.normal);
  });

  test('activa advertencia, crítico y excedido en sus umbrales', () {
    BudgetProgress at(int amount) => BudgetCalculator.calculate(
      budget: budget,
      reference: now,
      transactions: [
        _transaction('expense', amount, 'moto', DateTime.utc(2026, 9, 12)),
      ],
    );

    expect(at(14000).health, BudgetHealth.warning);
    expect(at(18000).health, BudgetHealth.critical);
    expect(at(20000).health, BudgetHealth.exceeded);
  });

  test('arrastra el saldo no usado del periodo mensual anterior', () {
    final rolled = Budget(
      id: 'rolled',
      userId: 'user',
      name: 'Mensual',
      period: BudgetPeriod.monthly,
      amountMinor: 20000,
      currency: Currency.pen,
      rollover: true,
      createdAt: now,
      updatedAt: now,
    );
    final progress = BudgetCalculator.calculate(
      budget: rolled,
      reference: now,
      transactions: [
        _transaction('expense', 5000, 'moto', DateTime.utc(2026, 8, 10)),
        _transaction('expense', 10000, 'moto', DateTime.utc(2026, 9, 10)),
      ],
    );

    expect(progress.carriedMinor, 15000);
    expect(progress.limitMinor, 35000);
    expect(progress.remainingMinor, 25000);
  });
}

FinancialTransaction _transaction(
  String kind,
  int amount,
  String category,
  DateTime date,
) => FinancialTransaction(
  id: '$kind-$amount',
  userId: 'user',
  kind: TransactionKind.values.byName(kind),
  amountMinor: amount,
  currency: Currency.pen,
  categoryId: category,
  occurredAt: date,
  createdAt: date,
  updatedAt: date,
);
