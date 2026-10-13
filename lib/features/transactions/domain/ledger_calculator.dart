import '../../accounts/domain/financial_account.dart';
import '../../../core/money/money.dart';
import 'financial_transaction.dart';

class LedgerSummary {
  const LedgerSummary({
    required this.balances,
    required this.monthlyExpenseMinor,
    required this.monthlyIncomeMinor,
  });

  final Map<String, int> balances;
  final int monthlyExpenseMinor;
  final int monthlyIncomeMinor;
}

abstract final class LedgerCalculator {
  static Map<String, int> balances({
    required Iterable<FinancialAccount> accounts,
    required Iterable<FinancialTransaction> transactions,
  }) {
    final result = {
      for (final account in accounts) account.id: account.initialBalanceMinor,
    };
    for (final transaction in transactions.where(
      (item) => item.deletedAt == null,
    )) {
      _apply(result, transaction);
    }
    return Map.unmodifiable(result);
  }

  static void _apply(Map<String, int> balances, FinancialTransaction item) {
    void add(String? id, int amount) {
      if (id != null && balances.containsKey(id)) {
        balances[id] = balances[id]! + amount;
      }
    }

    switch (item.kind) {
      case TransactionKind.expense:
      case TransactionKind.loanGiven:
      case TransactionKind.debtPayment:
        add(item.sourceAccountId, -item.amountMinor);
      case TransactionKind.income:
      case TransactionKind.loanRepayment:
      case TransactionKind.refund:
        add(item.destinationAccountId, item.amountMinor);
      case TransactionKind.transfer:
      case TransactionKind.goalContribution:
      case TransactionKind.goalWithdrawal:
        add(item.sourceAccountId, -item.amountMinor);
        add(
          item.destinationAccountId,
          item.destinationAmountMinor ?? item.amountMinor,
        );
      case TransactionKind.creditPurchase:
        add(item.sourceAccountId, item.amountMinor);
      case TransactionKind.creditPayment:
        add(item.sourceAccountId, -item.amountMinor);
        add(
          item.destinationAccountId,
          -(item.destinationAmountMinor ?? item.amountMinor),
        );
    }
  }

  static int expenseForPeriod(
    Iterable<FinancialTransaction> transactions,
    DateTime start,
    DateTime end, {
    Currency? currency,
  }) => transactions
      .where((item) {
        return item.deletedAt == null &&
            (currency == null || item.currency == currency) &&
            !item.occurredAt.isBefore(start) &&
            item.occurredAt.isBefore(end);
      })
      .fold(0, (total, item) {
        if (item.kind == TransactionKind.refund) {
          return total - item.amountMinor;
        }
        return item.kind.countsAsExpense ? total + item.amountMinor : total;
      });

  static int incomeForPeriod(
    Iterable<FinancialTransaction> transactions,
    DateTime start,
    DateTime end, {
    Currency? currency,
  }) => transactions
      .where(
        (item) =>
            item.deletedAt == null &&
            (currency == null || item.currency == currency) &&
            item.kind.countsAsIncome &&
            !item.occurredAt.isBefore(start) &&
            item.occurredAt.isBefore(end),
      )
      .fold(0, (total, item) => total + item.amountMinor);
}
