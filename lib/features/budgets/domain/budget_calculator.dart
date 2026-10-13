import '../../../core/time/lima_time.dart';
import '../../transactions/domain/financial_transaction.dart';
import 'budget.dart';

enum BudgetHealth { normal, warning, critical, exceeded }

class BudgetProgress {
  const BudgetProgress({
    required this.spentMinor,
    required this.limitMinor,
    required this.remainingMinor,
    required this.projectedMinor,
    required this.carriedMinor,
    required this.dailyAvailableMinor,
    required this.ratio,
    required this.health,
    required this.start,
    required this.end,
  });

  final int spentMinor;
  final int limitMinor;
  final int remainingMinor;
  final int projectedMinor;
  final int carriedMinor;
  final int dailyAvailableMinor;
  final double ratio;
  final BudgetHealth health;
  final DateTime start;
  final DateTime end;
}

abstract final class BudgetCalculator {
  static (DateTime, DateTime) window(Budget budget, DateTime reference) {
    final day = startOfLimaDayUtc(reference);
    return switch (budget.period) {
      BudgetPeriod.daily => (day, day.add(const Duration(days: 1))),
      BudgetPeriod.weekly => (
        day.subtract(Duration(days: toLimaTime(reference).weekday - 1)),
        day.add(Duration(days: 8 - toLimaTime(reference).weekday)),
      ),
      BudgetPeriod.monthly => (
        startOfLimaMonthUtc(reference),
        limaMidnightUtc(
          toLimaTime(reference).year,
          toLimaTime(reference).month + 1,
          1,
        ),
      ),
      BudgetPeriod.custom => (
        budget.customStart ?? day,
        budget.customEnd ?? day.add(const Duration(days: 1)),
      ),
    };
  }

  static BudgetProgress calculate({
    required Budget budget,
    required Iterable<FinancialTransaction> transactions,
    required DateTime reference,
    Set<String>? categoryIds,
  }) {
    final (start, end) = window(budget, reference);
    final ids =
        categoryIds ??
        (budget.categoryId == null ? null : {budget.categoryId!});
    final spent = _spent(
      budget: budget,
      transactions: transactions,
      start: start,
      end: end,
      categoryIds: ids,
    );
    var carried = 0;
    final previous = _previousWindow(budget, start);
    if (budget.rollover && previous != null) {
      final previousSpent = _spent(
        budget: budget,
        transactions: transactions,
        start: previous.$1,
        end: previous.$2,
        categoryIds: ids,
      );
      carried = (budget.amountMinor - previousSpent).clamp(
        0,
        budget.amountMinor,
      );
    }
    final effectiveLimit = budget.amountMinor + carried;
    final remaining = effectiveLimit - spent;
    final ratio = effectiveLimit == 0 ? 1.0 : spent / effectiveLimit;
    final health = ratio >= 1
        ? BudgetHealth.exceeded
        : ratio >= .9
        ? BudgetHealth.critical
        : ratio >= .7
        ? BudgetHealth.warning
        : BudgetHealth.normal;
    final elapsed = reference
        .toUtc()
        .difference(start)
        .inMinutes
        .clamp(1, end.difference(start).inMinutes);
    final total = end.difference(start).inMinutes;
    final projected = reference.isBefore(start)
        ? 0
        : reference.isAfter(end)
        ? spent
        : (spent * total / elapsed).round();
    final remainingDays =
        (end
                    .difference(
                      reference.isBefore(start) ? start : reference.toUtc(),
                    )
                    .inHours /
                24)
            .ceil()
            .clamp(1, 10000);
    return BudgetProgress(
      spentMinor: spent,
      limitMinor: effectiveLimit,
      remainingMinor: remaining,
      projectedMinor: projected,
      carriedMinor: carried,
      dailyAvailableMinor: remaining.clamp(0, effectiveLimit) ~/ remainingDays,
      ratio: ratio,
      health: health,
      start: start,
      end: end,
    );
  }

  static int _spent({
    required Budget budget,
    required Iterable<FinancialTransaction> transactions,
    required DateTime start,
    required DateTime end,
    required Set<String>? categoryIds,
  }) => transactions
      .where((item) {
        final categoryMatches =
            budget.categoryId == null || categoryIds!.contains(item.categoryId);
        return item.deletedAt == null &&
            item.currency == budget.currency &&
            categoryMatches &&
            !item.occurredAt.isBefore(start) &&
            item.occurredAt.isBefore(end);
      })
      .fold<int>(0, (total, item) {
        if (item.kind == TransactionKind.refund) {
          return total - item.amountMinor;
        }
        return item.kind.countsAsExpense ? total + item.amountMinor : total;
      });

  static (DateTime, DateTime)? _previousWindow(Budget budget, DateTime start) =>
      switch (budget.period) {
        BudgetPeriod.daily => (start.subtract(const Duration(days: 1)), start),
        BudgetPeriod.weekly => (start.subtract(const Duration(days: 7)), start),
        BudgetPeriod.monthly => (
          limaMidnightUtc(
            toLimaTime(start.subtract(const Duration(microseconds: 1))).year,
            toLimaTime(start.subtract(const Duration(microseconds: 1))).month,
            1,
          ),
          start,
        ),
        BudgetPeriod.custom => null,
      };
}
