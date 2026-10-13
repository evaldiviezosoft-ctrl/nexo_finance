import 'dart:math' as math;

import '../../transactions/domain/financial_transaction.dart';
import 'debt_record.dart';

class DebtPosition {
  const DebtPosition({required this.paidMinor, required this.remainingMinor});
  final int paidMinor;
  final int remainingMinor;
}

class AmortizationResult {
  const AmortizationResult({
    required this.months,
    required this.totalInterestMinor,
    required this.monthlyPaymentMinor,
  });
  final int months;
  final int totalInterestMinor;
  final int monthlyPaymentMinor;
}

class DebtSimulation {
  const DebtSimulation({
    required this.normal,
    required this.accelerated,
    required this.interestSavedMinor,
    required this.monthsSaved,
  });
  final AmortizationResult normal;
  final AmortizationResult accelerated;
  final int interestSavedMinor;
  final int monthsSaved;
}

abstract final class DebtCalculator {
  static DebtPosition position(
    DebtRecord debt,
    Iterable<FinancialTransaction> transactions,
  ) {
    final kind = debt.direction == DebtDirection.owed
        ? TransactionKind.debtPayment
        : TransactionKind.loanRepayment;
    final paid = transactions
        .where(
          (item) =>
              item.deletedAt == null &&
              item.debtId == debt.id &&
              item.kind == kind,
        )
        .fold<int>(
          0,
          (sum, item) =>
              sum + item.amountMinor + (item.thirdPartyAmountMinor ?? 0),
        );
    return DebtPosition(
      paidMinor: paid,
      remainingMinor: math.max(0, debt.initialPrincipalMinor - paid),
    );
  }

  static DebtSimulation simulate({
    required int principalMinor,
    required int annualRateBasisPoints,
    required int monthlyPaymentMinor,
    int extraMonthlyMinor = 0,
    int prepaymentMinor = 0,
  }) {
    final normal = _amortize(
      principalMinor: principalMinor,
      annualRateBasisPoints: annualRateBasisPoints,
      monthlyPaymentMinor: monthlyPaymentMinor,
    );
    final accelerated = _amortize(
      principalMinor: math.max(0, principalMinor - prepaymentMinor),
      annualRateBasisPoints: annualRateBasisPoints,
      monthlyPaymentMinor: monthlyPaymentMinor + extraMonthlyMinor,
    );
    return DebtSimulation(
      normal: normal,
      accelerated: accelerated,
      interestSavedMinor: math.max(
        0,
        normal.totalInterestMinor - accelerated.totalInterestMinor,
      ),
      monthsSaved: math.max(0, normal.months - accelerated.months),
    );
  }

  static AmortizationResult _amortize({
    required int principalMinor,
    required int annualRateBasisPoints,
    required int monthlyPaymentMinor,
  }) {
    if (principalMinor <= 0) {
      return const AmortizationResult(
        months: 0,
        totalInterestMinor: 0,
        monthlyPaymentMinor: 0,
      );
    }
    final annualRate = annualRateBasisPoints / 10000;
    final monthlyRate = annualRate == 0
        ? 0.0
        : math.pow(1 + annualRate, 1 / 12).toDouble() - 1;
    var payment = monthlyPaymentMinor;
    if (payment <= 0 && monthlyRate == 0) payment = principalMinor;
    final firstInterest = (principalMinor * monthlyRate).round();
    if (payment <= firstInterest) {
      return AmortizationResult(
        months: 0,
        totalInterestMinor: 0,
        monthlyPaymentMinor: payment,
      );
    }
    var balance = principalMinor;
    var interestTotal = 0;
    var months = 0;
    while (balance > 0 && months < 1200) {
      final interest = (balance * monthlyRate).round();
      interestTotal += interest;
      balance -= math.min(balance, payment - interest);
      months++;
    }
    return AmortizationResult(
      months: months,
      totalInterestMinor: interestTotal,
      monthlyPaymentMinor: payment,
    );
  }
}
