import '../../../core/firebase/firestore_converters.dart';
import '../../../core/money/money.dart';

enum GoalPriority { low, medium, high }

extension GoalPriorityLabel on GoalPriority {
  String get label => switch (this) {
    GoalPriority.low => 'Baja',
    GoalPriority.medium => 'Media',
    GoalPriority.high => 'Alta',
  };
}

class FinancialGoal {
  const FinancialGoal({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetMinor,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
    this.openingAmountMinor = 0,
    this.deadline,
    this.priority = GoalPriority.medium,
    this.accountId,
    this.iconCodePoint = 0xe153,
    this.colorValue = 0xffff1744,
    this.automaticContributionMinor,
    this.allowWithdrawals = false,
    this.notes = '',
    this.active = true,
    this.version = 1,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String name;
  final int targetMinor;
  final int openingAmountMinor;
  final Currency currency;
  final DateTime? deadline;
  final GoalPriority priority;
  final String? accountId;
  final int iconCodePoint;
  final int colorValue;
  final int? automaticContributionMinor;
  final bool allowWithdrawals;
  final String notes;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final DateTime? deletedAt;

  factory FinancialGoal.fromMap(Map<String, Object?> map) => FinancialGoal(
    id: map['id']! as String,
    userId: map['userId']! as String,
    name: map['name']! as String,
    targetMinor: map['targetMinor']! as int,
    openingAmountMinor: map['openingAmountMinor'] as int? ?? 0,
    currency: Currency.values.byName(map['currency']! as String),
    deadline: nullableDateTimeFromFirestore(map['deadline']),
    priority: GoalPriority.values.byName(
      map['priority'] as String? ?? GoalPriority.medium.name,
    ),
    accountId: map['accountId'] as String?,
    iconCodePoint: map['iconCodePoint'] as int? ?? 0xe153,
    colorValue: map['colorValue'] as int? ?? 0xffff1744,
    automaticContributionMinor: map['automaticContributionMinor'] as int?,
    allowWithdrawals: map['allowWithdrawals'] as bool? ?? false,
    notes: map['notes'] as String? ?? '',
    active: map['active'] as bool? ?? true,
    createdAt: dateTimeFromFirestore(map['createdAt']),
    updatedAt: dateTimeFromFirestore(map['updatedAt']),
    version: map['version'] as int? ?? 1,
    deletedAt: nullableDateTimeFromFirestore(map['deletedAt']),
  );
}
