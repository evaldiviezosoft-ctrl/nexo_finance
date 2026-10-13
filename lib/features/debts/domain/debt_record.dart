import '../../../core/firebase/firestore_converters.dart';
import '../../../core/money/money.dart';

enum DebtDirection { owed, receivable }

enum DebtType { personal, bankLoan, financedPurchase, vehicle, shared, custom }

enum DebtStatus { active, paid, paused }

extension DebtDirectionLabel on DebtDirection {
  String get label => this == DebtDirection.owed ? 'Debo' : 'Me deben';
}

extension DebtTypeLabel on DebtType {
  String get label => switch (this) {
    DebtType.personal => 'Préstamo personal',
    DebtType.bankLoan => 'Préstamo bancario',
    DebtType.financedPurchase => 'Compra financiada',
    DebtType.vehicle => 'Vehículo',
    DebtType.shared => 'Deuda compartida',
    DebtType.custom => 'Otra',
  };
}

class DebtRecord {
  const DebtRecord({
    required this.id,
    required this.userId,
    required this.name,
    required this.direction,
    required this.type,
    required this.party,
    required this.initialPrincipalMinor,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
    this.annualRateBasisPoints = 0,
    this.installments,
    this.installmentMinor,
    this.nextDueDate,
    this.paymentDay,
    this.thirdPartyContributionMinor = 0,
    this.status = DebtStatus.active,
    this.notes = '',
    this.version = 1,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String name;
  final DebtDirection direction;
  final DebtType type;
  final String party;
  final int initialPrincipalMinor;
  final Currency currency;
  final int annualRateBasisPoints;
  final int? installments;
  final int? installmentMinor;
  final DateTime? nextDueDate;
  final int? paymentDay;
  final int thirdPartyContributionMinor;
  final DebtStatus status;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final DateTime? deletedAt;

  factory DebtRecord.fromMap(Map<String, Object?> map) => DebtRecord(
    id: map['id']! as String,
    userId: map['userId']! as String,
    name: map['name']! as String,
    direction: DebtDirection.values.byName(map['direction']! as String),
    type: DebtType.values.byName(map['type']! as String),
    party: map['party']! as String,
    initialPrincipalMinor: map['initialPrincipalMinor']! as int,
    currency: Currency.values.byName(map['currency']! as String),
    annualRateBasisPoints: map['annualRateBasisPoints'] as int? ?? 0,
    installments: map['installments'] as int?,
    installmentMinor: map['installmentMinor'] as int?,
    nextDueDate: nullableDateTimeFromFirestore(map['nextDueDate']),
    paymentDay: map['paymentDay'] as int?,
    thirdPartyContributionMinor:
        map['thirdPartyContributionMinor'] as int? ?? 0,
    status: DebtStatus.values.byName(map['status'] as String? ?? 'active'),
    notes: map['notes'] as String? ?? '',
    createdAt: dateTimeFromFirestore(map['createdAt']),
    updatedAt: dateTimeFromFirestore(map['updatedAt']),
    version: map['version'] as int? ?? 1,
    deletedAt: nullableDateTimeFromFirestore(map['deletedAt']),
  );
}
