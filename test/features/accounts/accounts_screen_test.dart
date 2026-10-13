import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_finance/core/firebase/firestore_converters.dart';
import 'package:nexo_finance/core/money/money.dart';
import 'package:nexo_finance/features/accounts/data/accounts_repository.dart';
import 'package:nexo_finance/features/accounts/domain/financial_account.dart';
import 'package:nexo_finance/features/accounts/presentation/accounts_screen.dart';
import 'package:nexo_finance/features/transactions/data/transactions_repository.dart';

void main() {
  testWidgets('shows the initial account balance without counting an income', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 9, 11);
    final account = FinancialAccount(
      id: 'bank',
      userId: 'user',
      name: 'Cuenta principal',
      type: AccountType.bank,
      currency: Currency.pen,
      initialBalanceMinor: 125050,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream.value(SyncedList(items: [account])),
          ),
          transactionsProvider.overrideWith(
            (ref) => Stream.value(const SyncedList(items: [])),
          ),
        ],
        child: const MaterialApp(home: AccountsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cuenta principal'), findsOneWidget);
    expect(find.text(r'S/ 1,250.50'), findsOneWidget);
  });
}
