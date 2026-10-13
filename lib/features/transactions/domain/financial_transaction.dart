import '../../../core/firebase/firestore_converters.dart';
import '../../../core/money/money.dart';

enum TransactionKind {
  expense,
  income,
  transfer,
  creditPurchase,
  creditPayment,
  loanGiven,
  loanRepayment,
  goalContribution,
  goalWithdrawal,
  debtPayment,
  refund,
}

extension TransactionKindLabel on TransactionKind {
  String get label => switch (this) {
    TransactionKind.expense => 'Gasto',
    TransactionKind.income => 'Ingreso',
    TransactionKind.transfer => 'Transferencia',
    TransactionKind.creditPurchase => 'Compra con tarjeta',
    TransactionKind.creditPayment => 'Pago de tarjeta',
    TransactionKind.loanGiven => 'Préstamo entregado',
    TransactionKind.loanRepayment => 'Cobro de préstamo',
    TransactionKind.goalContribution => 'Aporte a meta',
    TransactionKind.goalWithdrawal => 'Retiro de meta',
    TransactionKind.debtPayment => 'Pago de deuda',
    TransactionKind.refund => 'Reembolso',
  };

  bool get countsAsExpense =>
      this == TransactionKind.expense || this == TransactionKind.creditPurchase;
  bool get countsAsIncome => this == TransactionKind.income;

  bool get isGoalMovement =>
      this == TransactionKind.goalContribution ||
      this == TransactionKind.goalWithdrawal;

  bool get isDebtMovement =>
      this == TransactionKind.debtPayment ||
      this == TransactionKind.loanRepayment;

  bool get requiresManagedTarget => isGoalMovement || isDebtMovement;

  bool get needsSource => switch (this) {
    TransactionKind.income ||
    TransactionKind.loanRepayment ||
    TransactionKind.refund => false,
    _ => true,
  };
  bool get needsDestination => switch (this) {
    TransactionKind.income ||
    TransactionKind.transfer ||
    TransactionKind.creditPayment ||
    TransactionKind.loanRepayment ||
    TransactionKind.goalContribution ||
    TransactionKind.goalWithdrawal ||
    TransactionKind.refund => true,
    _ => false,
  };
}

class FinancialTransaction {
  const FinancialTransaction({
    required this.id,
    required this.userId,
    required this.kind,
    required this.amountMinor,
    required this.currency,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    this.sourceAccountId,
    this.destinationAccountId,
    this.categoryId,
    this.description = '',
    this.note = '',
    this.relatedTransactionId,
    this.goalId,
    this.debtId,
    this.exchangeRateMicros,
    this.destinationAmountMinor,
    this.thirdPartyAmountMinor,
    this.version = 1,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final TransactionKind kind;
  final int amountMinor;
  final Currency currency;
  final String? sourceAccountId;
  final String? destinationAccountId;
  final String? categoryId;
  final String description;
  final String note;
  final String? relatedTransactionId;
  final String? goalId;
  final String? debtId;
  final int? exchangeRateMicros;
  final int? destinationAmountMinor;
  final int? thirdPartyAmountMinor;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final DateTime? deletedAt;

  factory FinancialTransaction.fromMap(Map<String, Object?> map) =>
      FinancialTransaction(
        id: map['id']! as String,
        userId: map['userId']! as String,
        kind: TransactionKind.values.byName(map['kind']! as String),
        amountMinor: map['amountMinor']! as int,
        currency: Currency.values.byName(map['currency']! as String),
        sourceAccountId: map['sourceAccountId'] as String?,
        destinationAccountId: map['destinationAccountId'] as String?,
        categoryId: map['categoryId'] as String?,
        description: map['description'] as String? ?? '',
        note: map['note'] as String? ?? '',
        relatedTransactionId: map['relatedTransactionId'] as String?,
        goalId: map['goalId'] as String?,
        debtId: map['debtId'] as String?,
        exchangeRateMicros: map['exchangeRateMicros'] as int?,
        destinationAmountMinor: map['destinationAmountMinor'] as int?,
        thirdPartyAmountMinor: map['thirdPartyAmountMinor'] as int?,
        occurredAt: dateTimeFromFirestore(map['occurredAt']),
        createdAt: dateTimeFromFirestore(map['createdAt']),
        updatedAt: dateTimeFromFirestore(map['updatedAt']),
        version: map['version'] as int? ?? 1,
        deletedAt: nullableDateTimeFromFirestore(map['deletedAt']),
      );
}
