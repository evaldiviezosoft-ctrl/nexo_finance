import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_finance/core/money/money.dart';
import 'package:nexo_finance/features/accounts/domain/financial_account.dart';
import 'package:nexo_finance/features/transactions/domain/financial_transaction.dart';
import 'package:nexo_finance/features/transactions/domain/ledger_calculator.dart';

void main() {
  final date = DateTime.utc(2026, 9, 10);
  FinancialAccount account(
    String id, {
    int initial = 0,
    AccountType type = AccountType.bank,
    Currency currency = Currency.pen,
  }) => FinancialAccount(
    id: id,
    userId: 'user',
    name: id,
    type: type,
    currency: currency,
    initialBalanceMinor: initial,
    createdAt: date,
    updatedAt: date,
  );

  FinancialTransaction transaction(
    String id,
    TransactionKind kind, {
    int amount = 1000,
    String? source,
    String? destination,
    int? destinationAmount,
    DateTime? deletedAt,
  }) => FinancialTransaction(
    id: id,
    userId: 'user',
    kind: kind,
    amountMinor: amount,
    currency: Currency.pen,
    sourceAccountId: source,
    destinationAccountId: destination,
    destinationAmountMinor: destinationAmount,
    occurredAt: date,
    createdAt: date,
    updatedAt: date,
    deletedAt: deletedAt,
  );

  test('saldo inicial is an asset but never income', () {
    final accounts = [account('bank', initial: 125050)];
    final balances = LedgerCalculator.balances(
      accounts: accounts,
      transactions: const [],
    );
    expect(balances['bank'], 125050);
    expect(
      LedgerCalculator.incomeForPeriod(
        const [],
        date,
        date.add(const Duration(days: 1)),
      ),
      0,
    );
  });

  test('expense reduces cash and is counted once', () {
    final tx = transaction('expense', TransactionKind.expense, source: 'cash');
    final balances = LedgerCalculator.balances(
      accounts: [account('cash', initial: 5000)],
      transactions: [tx],
    );
    expect(balances['cash'], 4000);
    expect(
      LedgerCalculator.expenseForPeriod(
        [tx],
        date,
        date.add(const Duration(days: 1)),
      ),
      1000,
    );
  });

  test('credit purchase is expense; card payment is not a second expense', () {
    final purchase = transaction(
      'purchase',
      TransactionKind.creditPurchase,
      amount: 3000,
      source: 'card',
    );
    final payment = transaction(
      'payment',
      TransactionKind.creditPayment,
      amount: 3000,
      source: 'bank',
      destination: 'card',
    );
    final balances = LedgerCalculator.balances(
      accounts: [
        account('bank', initial: 10000),
        account('card', type: AccountType.creditCard),
      ],
      transactions: [purchase, payment],
    );
    expect(balances['bank'], 7000);
    expect(balances['card'], 0);
    expect(
      LedgerCalculator.expenseForPeriod(
        [purchase, payment],
        date,
        date.add(const Duration(days: 1)),
      ),
      3000,
    );
  });

  test('transfer changes accounts but creates no income or expense', () {
    final tx = transaction(
      'transfer',
      TransactionKind.transfer,
      source: 'cash',
      destination: 'bank',
    );
    final balances = LedgerCalculator.balances(
      accounts: [account('cash', initial: 2000), account('bank')],
      transactions: [tx],
    );
    expect(balances, containsPair('cash', 1000));
    expect(balances, containsPair('bank', 1000));
    expect(
      LedgerCalculator.expenseForPeriod(
        [tx],
        date,
        date.add(const Duration(days: 1)),
      ),
      0,
    );
    expect(
      LedgerCalculator.incomeForPeriod(
        [tx],
        date,
        date.add(const Duration(days: 1)),
      ),
      0,
    );
  });

  test('cross-currency transfer preserves destination minor amount', () {
    final tx = transaction(
      'fx',
      TransactionKind.transfer,
      amount: 3750,
      source: 'pen',
      destination: 'usd',
      destinationAmount: 1000,
    );
    final balances = LedgerCalculator.balances(
      accounts: [
        account('pen', initial: 10000),
        account('usd', currency: Currency.usd),
      ],
      transactions: [tx],
    );
    expect(balances['pen'], 6250);
    expect(balances['usd'], 1000);
  });

  test('loan repayment is not new income', () {
    final given = transaction(
      'given',
      TransactionKind.loanGiven,
      source: 'bank',
    );
    final repaid = transaction(
      'repaid',
      TransactionKind.loanRepayment,
      destination: 'bank',
    );
    final balances = LedgerCalculator.balances(
      accounts: [account('bank', initial: 5000)],
      transactions: [given, repaid],
    );
    expect(balances['bank'], 5000);
    expect(
      LedgerCalculator.incomeForPeriod(
        [repaid],
        date,
        date.add(const Duration(days: 1)),
      ),
      0,
    );
  });

  test('refund reduces expense and restores destination balance', () {
    final expense = transaction(
      'expense',
      TransactionKind.expense,
      amount: 2000,
      source: 'bank',
    );
    final refund = transaction(
      'refund',
      TransactionKind.refund,
      amount: 500,
      destination: 'bank',
    );
    final balances = LedgerCalculator.balances(
      accounts: [account('bank', initial: 5000)],
      transactions: [expense, refund],
    );
    expect(balances['bank'], 3500);
    expect(
      LedgerCalculator.expenseForPeriod(
        [expense, refund],
        date,
        date.add(const Duration(days: 1)),
      ),
      1500,
    );
  });

  test('soft-deleted transaction has no effect', () {
    final deleted = transaction(
      'deleted',
      TransactionKind.expense,
      source: 'bank',
      deletedAt: date,
    );
    final balances = LedgerCalculator.balances(
      accounts: [account('bank', initial: 5000)],
      transactions: [deleted],
    );
    expect(balances['bank'], 5000);
  });

  test('managed movements require a goal or debt target', () {
    expect(TransactionKind.goalContribution.isGoalMovement, isTrue);
    expect(TransactionKind.goalWithdrawal.isGoalMovement, isTrue);
    expect(TransactionKind.debtPayment.isDebtMovement, isTrue);
    expect(TransactionKind.loanRepayment.isDebtMovement, isTrue);
    expect(TransactionKind.expense.requiresManagedTarget, isFalse);
    expect(TransactionKind.refund.requiresManagedTarget, isFalse);
  });
}
