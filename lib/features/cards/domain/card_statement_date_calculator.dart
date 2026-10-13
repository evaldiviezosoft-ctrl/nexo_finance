import '../../../core/time/lima_time.dart';
import '../../accounts/domain/financial_account.dart';

class CardStatementDateDefaults {
  const CardStatementDateDefaults({
    required this.cycleStart,
    required this.cycleEnd,
    required this.dueDate,
  });

  final DateTime cycleStart;
  final DateTime cycleEnd;
  final DateTime dueDate;
}

abstract final class CardStatementDateCalculator {
  static CardStatementDateDefaults defaultsFor(
    FinancialAccount card, {
    DateTime? now,
  }) {
    final localNow = toLimaTime(now ?? DateTime.now());
    final today = limaMidnightUtc(localNow.year, localNow.month, localNow.day);
    final closingDay = card.closingDay ?? 31;
    var cycleEnd = _limaDate(localNow.year, localNow.month, closingDay);
    if (cycleEnd.isAfter(today)) {
      cycleEnd = _limaDate(localNow.year, localNow.month - 1, closingDay);
    }

    final cycleEndLocal = toLimaTime(cycleEnd);
    final previousCycleEnd = _limaDate(
      cycleEndLocal.year,
      cycleEndLocal.month - 1,
      closingDay,
    );
    final cycleStart = previousCycleEnd.add(const Duration(days: 1));

    final paymentDay = card.paymentDay ?? 1;
    var dueDate = _limaDate(
      cycleEndLocal.year,
      cycleEndLocal.month,
      paymentDay,
    );
    if (!dueDate.isAfter(cycleEnd)) {
      dueDate = _limaDate(
        cycleEndLocal.year,
        cycleEndLocal.month + 1,
        paymentDay,
      );
    }

    return CardStatementDateDefaults(
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
      dueDate: dueDate,
    );
  }

  static DateTime _limaDate(int year, int month, int requestedDay) {
    final normalizedMonth = DateTime.utc(year, month);
    final lastDay = DateTime.utc(
      normalizedMonth.year,
      normalizedMonth.month + 1,
      0,
    ).day;
    final safeDay = requestedDay < 1
        ? 1
        : requestedDay > lastDay
        ? lastDay
        : requestedDay;
    return limaMidnightUtc(
      normalizedMonth.year,
      normalizedMonth.month,
      safeDay,
    );
  }
}
