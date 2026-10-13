import '../../accounts/domain/financial_account.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../transactions/domain/ledger_calculator.dart';
import 'card_statement.dart';

class CardPosition {
  const CardPosition({
    required this.debtMinor,
    required this.availableCreditMinor,
    required this.utilization,
  });
  final int debtMinor;
  final int? availableCreditMinor;
  final double utilization;
}

abstract final class CardCalculator {
  static CardPosition position(
    FinancialAccount card,
    Iterable<FinancialTransaction> transactions,
  ) {
    final debt =
        LedgerCalculator.balances(
          accounts: [card],
          transactions: transactions,
        )[card.id] ??
        card.initialBalanceMinor;
    final limit = card.creditLimitMinor;
    return CardPosition(
      debtMinor: debt,
      availableCreditMinor: limit == null ? null : limit - debt,
      utilization: limit == null || limit == 0 ? 0 : debt / limit,
    );
  }

  static int reservedPen(Iterable<CardStatement> statements) => statements
      .where((item) => item.status != CardStatementStatus.paid)
      .fold(0, (total, item) => total + item.reservedPenMinor);

  static int reservedUsd(Iterable<CardStatement> statements) => statements
      .where((item) => item.status != CardStatementStatus.paid)
      .fold(0, (total, item) => total + item.reservedUsdMinor);
}
