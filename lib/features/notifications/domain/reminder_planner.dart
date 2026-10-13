import '../../../core/money/money.dart';
import '../../../core/time/lima_time.dart';
import '../../accounts/domain/financial_account.dart';
import '../../cards/domain/card_statement.dart';
import '../../debts/domain/debt_record.dart';
import '../../goals/domain/financial_goal.dart';
import '../../recurring/domain/recurring_transaction.dart';

class PlannedReminder {
  const PlannedReminder({
    required this.key,
    required this.title,
    required this.body,
    required this.at,
    required this.payload,
  });
  final String key;
  final String title;
  final String body;
  final DateTime at;
  final String payload;
}

abstract final class ReminderPlanner {
  static List<PlannedReminder> plan({
    required DateTime now,
    required Iterable<FinancialAccount> accounts,
    required Iterable<CardStatement> statements,
    required Iterable<DebtRecord> debts,
    required Iterable<RecurringTransaction> recurring,
    required Iterable<FinancialGoal> goals,
    required bool cardReminders,
    required bool debtReminders,
    required bool recurringReminders,
    required bool goalReminders,
  }) {
    final result = <PlannedReminder>[];
    final accountNames = {for (final item in accounts) item.id: item.name};
    if (cardReminders) {
      for (final item in statements.where(
        (value) =>
            value.deletedAt == null && value.status != CardStatementStatus.paid,
      )) {
        final at = _morning(item.dueDate, daysBefore: 2);
        if (!at.isAfter(now)) continue;
        final pen = Money(item.amountDuePenMinor, Currency.pen).format();
        final usd = Money(item.amountDueUsdMinor, Currency.usd).format();
        final amounts = [
          if (item.amountDuePenMinor > 0) pen,
          if (item.amountDueUsdMinor > 0) usd,
        ].join(' + ');
        result.add(
          PlannedReminder(
            key: 'card:${item.id}',
            title: 'Pago de tarjeta próximo',
            body:
                '${accountNames[item.cardAccountId] ?? 'Tu tarjeta'} vence pronto${amounts.isEmpty ? '.' : ': $amounts.'}',
            at: at,
            payload: '/plan',
          ),
        );
      }
    }
    if (debtReminders) {
      for (final item in debts.where(
        (value) =>
            value.deletedAt == null &&
            value.status == DebtStatus.active &&
            value.nextDueDate != null,
      )) {
        final at = _morning(item.nextDueDate!, daysBefore: 1);
        if (!at.isAfter(now)) continue;
        result.add(
          PlannedReminder(
            key: 'debt:${item.id}',
            title: item.direction == DebtDirection.owed
                ? 'Cuota próxima'
                : 'Cobro próximo',
            body: '${item.name} tiene una fecha próxima. Revisa el monto.',
            at: at,
            payload: '/plan',
          ),
        );
      }
    }
    if (recurringReminders) {
      for (final item in recurring.where(
        (value) => value.deletedAt == null && value.active,
      )) {
        final at = _morning(item.nextDueAt);
        if (!at.isAfter(now)) continue;
        result.add(
          PlannedReminder(
            key: 'recurring:${item.id}',
            title: 'Movimiento pendiente de revisión',
            body:
                '${item.name}: ${Money(item.amountMinor, item.currency).format()}. Confírmalo antes de registrarlo.',
            at: at,
            payload: '/plan',
          ),
        );
      }
    }
    if (goalReminders) {
      for (final item in goals.where(
        (value) => value.deletedAt == null && value.active,
      )) {
        final target = item.deadline;
        if (target == null) continue;
        final at = _morning(target, daysBefore: 7);
        if (!at.isAfter(now)) continue;
        result.add(
          PlannedReminder(
            key: 'goal:${item.id}',
            title: 'Revisa el avance de tu meta',
            body: '${item.name} se acerca a su fecha objetivo.',
            at: at,
            payload: '/plan',
          ),
        );
      }
    }
    result.sort((a, b) => a.at.compareTo(b.at));
    return result.take(60).toList(growable: false);
  }

  static DateTime _morning(DateTime date, {int daysBefore = 0}) {
    final lima = toLimaTime(date).subtract(Duration(days: daysBefore));
    return limaMidnightUtc(
      lima.year,
      lima.month,
      lima.day,
    ).add(const Duration(hours: 9));
  }
}
