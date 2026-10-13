import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_finance/core/money/money.dart';
import 'package:nexo_finance/features/goals/domain/financial_goal.dart';
import 'package:nexo_finance/features/goals/domain/goal_calculator.dart';
import 'package:nexo_finance/features/transactions/domain/financial_transaction.dart';

void main() {
  final created = DateTime.utc(2026, 1, 1);
  FinancialTransaction movement(String id, TransactionKind kind, int amount) =>
      FinancialTransaction(
        id: id,
        userId: 'user',
        kind: kind,
        amountMinor: amount,
        currency: Currency.pen,
        sourceAccountId: kind == TransactionKind.goalWithdrawal
            ? 'goal'
            : 'bank',
        destinationAccountId: kind == TransactionKind.goalWithdrawal
            ? 'bank'
            : 'goal',
        goalId: 'goal-1',
        occurredAt: created,
        createdAt: created,
        updatedAt: created,
      );

  test('aportes y retiros actualizan la meta sin ser gasto o ingreso', () {
    final goal = FinancialGoal(
      id: 'goal-1',
      userId: 'user',
      name: 'Fondo de emergencia',
      targetMinor: 120000,
      openingAmountMinor: 10000,
      currency: Currency.pen,
      deadline: DateTime.utc(2026, 12, 31),
      createdAt: created,
      updatedAt: created,
    );
    final result = GoalCalculator.calculate(goal, [
      movement('one', TransactionKind.goalContribution, 20000),
      movement('two', TransactionKind.goalWithdrawal, 5000),
    ], now: DateTime.utc(2026, 6, 1));
    expect(result.accumulatedMinor, 25000);
    expect(result.remainingMinor, 95000);
    expect(result.recommendedMonthlyMinor, greaterThan(0));
  });
}
