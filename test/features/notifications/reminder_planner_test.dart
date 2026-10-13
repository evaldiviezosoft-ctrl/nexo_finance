import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_finance/core/money/money.dart';
import 'package:nexo_finance/features/accounts/domain/financial_account.dart';
import 'package:nexo_finance/features/cards/domain/card_statement.dart';
import 'package:nexo_finance/features/notifications/domain/reminder_planner.dart';

void main() {
  test('programa el pago de tarjeta dos días antes a las 9 en Lima', () {
    final now = DateTime.utc(2026, 9, 13, 15);
    final account = FinancialAccount(
      id: 'amex',
      userId: 'user',
      name: 'Amex',
      type: AccountType.creditCard,
      currency: Currency.pen,
      initialBalanceMinor: 0,
      createdAt: now,
      updatedAt: now,
    );
    final statement = CardStatement(
      id: 'cycle',
      userId: 'user',
      cardAccountId: 'amex',
      cycleStart: DateTime.utc(2026, 8, 27, 5),
      cycleEnd: DateTime.utc(2026, 9, 26, 5),
      dueDate: DateTime.utc(2026, 10, 21, 5),
      amountDuePenMinor: 40815,
      amountDueUsdMinor: 0,
      reservedPenMinor: 0,
      reservedUsdMinor: 0,
      status: CardStatementStatus.open,
      createdAt: now,
      updatedAt: now,
    );
    final reminders = ReminderPlanner.plan(
      now: now,
      accounts: [account],
      statements: [statement],
      debts: const [],
      recurring: const [],
      goals: const [],
      cardReminders: true,
      debtReminders: true,
      recurringReminders: true,
      goalReminders: true,
    );
    expect(reminders, hasLength(1));
    expect(reminders.single.at, DateTime.utc(2026, 10, 19, 14));
    expect(reminders.single.body, contains('Amex'));
    expect(reminders.single.body, contains('S/ 408.15'));
  });

  test('no programa ciclos pagados ni fechas vencidas', () {
    final now = DateTime.utc(2026, 9, 13, 15);
    CardStatement statement(String id, CardStatementStatus status) =>
        CardStatement(
          id: id,
          userId: 'user',
          cardAccountId: 'card',
          cycleStart: DateTime.utc(2026, 7, 1, 5),
          cycleEnd: DateTime.utc(2026, 8, 1, 5),
          dueDate: DateTime.utc(2026, 8, 21, 5),
          amountDuePenMinor: 10000,
          amountDueUsdMinor: 0,
          reservedPenMinor: 0,
          reservedUsdMinor: 0,
          status: status,
          createdAt: now,
          updatedAt: now,
        );
    final reminders = ReminderPlanner.plan(
      now: now,
      accounts: const [],
      statements: [
        statement('paid', CardStatementStatus.paid),
        statement('late', CardStatementStatus.open),
      ],
      debts: const [],
      recurring: const [],
      goals: const [],
      cardReminders: true,
      debtReminders: true,
      recurringReminders: true,
      goalReminders: true,
    );
    expect(reminders, isEmpty);
  });
}
