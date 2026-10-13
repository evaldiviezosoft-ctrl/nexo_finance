import '../../transactions/domain/financial_transaction.dart';
import 'financial_goal.dart';

class GoalProgress {
  const GoalProgress({
    required this.accumulatedMinor,
    required this.remainingMinor,
    required this.progress,
    required this.recommendedMonthlyMinor,
    required this.averageMonthlyMinor,
    required this.expectedMinor,
    this.estimatedCompletion,
  });

  final int accumulatedMinor;
  final int remainingMinor;
  final double progress;
  final int recommendedMonthlyMinor;
  final int averageMonthlyMinor;
  final int expectedMinor;
  final DateTime? estimatedCompletion;

  int get paceDifferenceMinor => accumulatedMinor - expectedMinor;
}

abstract final class GoalCalculator {
  static GoalProgress calculate(
    FinancialGoal goal,
    Iterable<FinancialTransaction> transactions, {
    DateTime? now,
  }) {
    final today = (now ?? DateTime.now()).toUtc();
    final linked = transactions.where(
      (item) =>
          item.deletedAt == null &&
          item.goalId == goal.id &&
          item.currency == goal.currency,
    );
    final contributed = linked.fold<int>(
      0,
      (sum, item) =>
          sum +
          switch (item.kind) {
            TransactionKind.goalContribution => item.amountMinor,
            TransactionKind.goalWithdrawal => -item.amountMinor,
            _ => 0,
          },
    );
    final accumulated = (goal.openingAmountMinor + contributed).clamp(
      0,
      goal.targetMinor,
    );
    final remaining = (goal.targetMinor - accumulated).clamp(
      0,
      goal.targetMinor,
    );
    final monthsElapsed = _monthsBetween(goal.createdAt, today).clamp(1, 1200);
    final average = contributed ~/ monthsElapsed;
    final monthsRemaining = goal.deadline == null
        ? 0
        : _monthsBetween(today, goal.deadline!).clamp(1, 1200);
    final recommended = monthsRemaining == 0
        ? 0
        : (remaining / monthsRemaining).ceil();
    final totalPlanMonths = goal.deadline == null
        ? 0
        : _monthsBetween(goal.createdAt, goal.deadline!).clamp(1, 1200);
    final expected = totalPlanMonths == 0
        ? accumulated
        : (goal.targetMinor * (monthsElapsed / totalPlanMonths)).round().clamp(
            0,
            goal.targetMinor,
          );
    DateTime? estimated;
    if (remaining == 0) {
      estimated = today;
    } else if (average > 0) {
      estimated = DateTime.utc(
        today.year,
        today.month + (remaining / average).ceil(),
        today.day,
      );
    }
    return GoalProgress(
      accumulatedMinor: accumulated,
      remainingMinor: remaining,
      progress: goal.targetMinor == 0 ? 0 : accumulated / goal.targetMinor,
      recommendedMonthlyMinor: recommended,
      averageMonthlyMinor: average,
      expectedMinor: expected,
      estimatedCompletion: estimated,
    );
  }

  static int _monthsBetween(DateTime from, DateTime to) {
    if (!to.isAfter(from)) return 1;
    return (to.year - from.year) * 12 + to.month - from.month + 1;
  }
}
