import '../../../core/firebase/firestore_converters.dart';
import '../../../core/money/money.dart';

enum BudgetPeriod { daily, weekly, monthly, custom }

extension BudgetPeriodLabel on BudgetPeriod {
  String get label => switch (this) {
    BudgetPeriod.daily => 'Diario',
    BudgetPeriod.weekly => 'Semanal',
    BudgetPeriod.monthly => 'Mensual',
    BudgetPeriod.custom => 'Personalizado',
  };
}

class Budget {
  const Budget({
    required this.id,
    required this.userId,
    required this.name,
    required this.period,
    required this.amountMinor,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.customStart,
    this.customEnd,
    this.rollover = false,
    this.active = true,
    this.version = 1,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String name;
  final BudgetPeriod period;
  final int amountMinor;
  final Currency currency;
  final String? categoryId;
  final DateTime? customStart;
  final DateTime? customEnd;
  final bool rollover;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final DateTime? deletedAt;

  factory Budget.fromMap(Map<String, Object?> map) => Budget(
    id: map['id']! as String,
    userId: map['userId']! as String,
    name: map['name']! as String,
    period: BudgetPeriod.values.byName(map['period']! as String),
    amountMinor: map['amountMinor']! as int,
    currency: Currency.values.byName(map['currency']! as String),
    categoryId: map['categoryId'] as String?,
    customStart: nullableDateTimeFromFirestore(map['customStart']),
    customEnd: nullableDateTimeFromFirestore(map['customEnd']),
    rollover: map['rollover'] as bool? ?? false,
    active: map['active'] as bool? ?? true,
    createdAt: dateTimeFromFirestore(map['createdAt']),
    updatedAt: dateTimeFromFirestore(map['updatedAt']),
    version: map['version'] as int? ?? 1,
    deletedAt: nullableDateTimeFromFirestore(map['deletedAt']),
  );
}
