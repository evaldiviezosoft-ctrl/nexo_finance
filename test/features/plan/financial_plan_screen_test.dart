import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_finance/core/firebase/firestore_converters.dart';
import 'package:nexo_finance/core/money/money.dart';
import 'package:nexo_finance/features/accounts/data/accounts_repository.dart';
import 'package:nexo_finance/features/accounts/domain/financial_account.dart';
import 'package:nexo_finance/features/budgets/data/budgets_repository.dart';
import 'package:nexo_finance/features/cards/data/card_statements_repository.dart';
import 'package:nexo_finance/features/cards/domain/card_statement.dart';
import 'package:nexo_finance/features/categories/data/categories_repository.dart';
import 'package:nexo_finance/features/debts/data/debts_repository.dart';
import 'package:nexo_finance/features/goals/data/goals_repository.dart';
import 'package:nexo_finance/features/plan/presentation/financial_plan_screen.dart';
import 'package:nexo_finance/features/recurring/data/recurring_repository.dart';
import 'package:nexo_finance/features/transactions/data/transactions_repository.dart';

void main() {
  testWidgets('separa deuda total y pago del ciclo de tarjeta', (tester) async {
    final now = DateTime.utc(2026, 9, 11);
    final card = FinancialAccount(
      id: 'bcp',
      userId: 'user',
      name: 'BCP',
      type: AccountType.creditCard,
      currency: Currency.pen,
      initialBalanceMinor: 125535,
      creditLimitMinor: 240000,
      closingDay: 25,
      paymentDay: 22,
      createdAt: now,
      updatedAt: now,
    );
    final statement = CardStatement(
      id: 'bcp_2026_09',
      userId: 'user',
      cardAccountId: card.id,
      cycleStart: DateTime.utc(2026, 7, 27, 5),
      cycleEnd: DateTime.utc(2026, 8, 25, 5),
      dueDate: DateTime.utc(2026, 9, 22, 5),
      amountDuePenMinor: 61313,
      amountDueUsdMinor: 2446,
      reservedPenMinor: 0,
      reservedUsdMinor: 0,
      status: CardStatementStatus.open,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream.value(SyncedList(items: [card])),
          ),
          transactionsProvider.overrideWith(
            (ref) => Stream.value(const SyncedList(items: [])),
          ),
          categoriesProvider.overrideWith(
            (ref) => Stream.value(const SyncedList(items: [])),
          ),
          budgetsProvider.overrideWith(
            (ref) => Stream.value(const SyncedList(items: [])),
          ),
          cardStatementsProvider.overrideWith(
            (ref) => Stream.value(SyncedList(items: [statement])),
          ),
          recurringTransactionsProvider.overrideWith(
            (ref) => Stream.value(const SyncedList(items: [])),
          ),
          goalsProvider.overrideWith(
            (ref) => Stream.value(const SyncedList(items: [])),
          ),
          debtsProvider.overrideWith(
            (ref) => Stream.value(const SyncedList(items: [])),
          ),
        ],
        child: const MaterialApp(home: FinancialPlanScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tarjetas'));
    await tester.pumpAndSettle();

    expect(find.text('Deuda total S/ 1,255.35'), findsOneWidget);
    expect(find.text('Pago del ciclo S/ 613.13'), findsOneWidget);
    expect(find.text(r'Pago del ciclo US$ 24.46'), findsOneWidget);
    expect(find.text('Cierre 25 · Pago 22'), findsOneWidget);
    expect(find.text('Vence 22/09/2026'), findsOneWidget);
  });
}
