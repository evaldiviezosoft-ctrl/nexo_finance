import '../../../core/money/money.dart';
import '../../../core/time/lima_time.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../transactions/domain/ledger_calculator.dart';

class MonthlyReportPoint {
  const MonthlyReportPoint({
    required this.month,
    required this.incomeMinor,
    required this.expenseMinor,
  });
  final DateTime month;
  final int incomeMinor;
  final int expenseMinor;
  int get savingsMinor => incomeMinor - expenseMinor;
}

class DailyReportPoint {
  const DailyReportPoint({
    required this.day,
    required this.actualMinor,
    required this.allowedMinor,
    required this.projectedMinor,
    required this.observed,
  });
  final int day;
  final int actualMinor;
  final int allowedMinor;
  final int projectedMinor;
  final bool observed;
}

abstract final class ReportCalculator {
  static List<MonthlyReportPoint> monthlySeries({
    required Iterable<FinancialTransaction> transactions,
    required DateTime reference,
    required int months,
    required Currency currency,
  }) {
    final localReference = toLimaTime(reference);
    return List.generate(months, (index) {
      final offset = months - index - 1;
      final start = limaMidnightUtc(
        localReference.year,
        localReference.month - offset,
        1,
      );
      final end = limaMidnightUtc(start.year, start.month + 1, 1);
      return MonthlyReportPoint(
        month: start,
        incomeMinor: LedgerCalculator.incomeForPeriod(
          transactions,
          start,
          end,
          currency: currency,
        ),
        expenseMinor: LedgerCalculator.expenseForPeriod(
          transactions,
          start,
          end,
          currency: currency,
        ),
      );
    });
  }

  static Map<String, int> categoryTotals({
    required Iterable<FinancialTransaction> transactions,
    required DateTime start,
    required DateTime end,
    required Currency currency,
  }) {
    final result = <String, int>{};
    for (final item in transactions) {
      if (item.deletedAt != null ||
          item.currency != currency ||
          item.categoryId == null ||
          item.occurredAt.isBefore(start) ||
          !item.occurredAt.isBefore(end)) {
        continue;
      }
      if (item.kind.countsAsExpense) {
        result.update(
          item.categoryId!,
          (value) => value + item.amountMinor,
          ifAbsent: () => item.amountMinor,
        );
      } else if (item.kind == TransactionKind.refund) {
        result.update(
          item.categoryId!,
          (value) => value - item.amountMinor,
          ifAbsent: () => -item.amountMinor,
        );
      }
    }
    return Map.unmodifiable(
      result.map(
        (categoryId, total) => MapEntry(categoryId, total < 0 ? 0 : total),
      ),
    );
  }

  static List<DailyReportPoint> dailyCumulative({
    required Iterable<FinancialTransaction> transactions,
    required DateTime month,
    required Currency currency,
    required int budgetMinor,
    DateTime? now,
  }) {
    final localMonth = toLimaTime(month);
    final today = toLimaTime(now ?? DateTime.now().toUtc());
    final days = DateTime.utc(localMonth.year, localMonth.month + 1, 0).day;
    var accumulated = 0;
    final points = <DailyReportPoint>[];
    for (var day = 1; day <= days; day++) {
      final start = limaMidnightUtc(localMonth.year, localMonth.month, day);
      final end = start.add(const Duration(days: 1));
      final elapsed =
          today.year == localMonth.year && today.month == localMonth.month
          ? today.day.clamp(1, days)
          : days;
      if (day <= elapsed) {
        accumulated += LedgerCalculator.expenseForPeriod(
          transactions,
          start,
          end,
          currency: currency,
        );
      }
      final projection = day <= elapsed
          ? accumulated
          : (accumulated / elapsed * day).round();
      points.add(
        DailyReportPoint(
          day: day,
          actualMinor: accumulated,
          allowedMinor: budgetMinor * day ~/ days,
          projectedMinor: projection,
          observed: day <= elapsed,
        ),
      );
    }
    return points;
  }
}
