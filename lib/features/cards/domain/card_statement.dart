import '../../../core/firebase/firestore_converters.dart';

enum CardStatementStatus { projected, open, paid }

class CardStatement {
  const CardStatement({
    required this.id,
    required this.userId,
    required this.cardAccountId,
    required this.cycleStart,
    required this.cycleEnd,
    required this.dueDate,
    required this.amountDuePenMinor,
    required this.amountDueUsdMinor,
    required this.reservedPenMinor,
    required this.reservedUsdMinor,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String cardAccountId;
  final DateTime cycleStart;
  final DateTime cycleEnd;
  final DateTime dueDate;
  final int amountDuePenMinor;
  final int amountDueUsdMinor;
  final int reservedPenMinor;
  final int reservedUsdMinor;
  final CardStatementStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final DateTime? deletedAt;

  int get unbackedPenMinor =>
      (amountDuePenMinor - reservedPenMinor).clamp(0, amountDuePenMinor);
  int get unbackedUsdMinor =>
      (amountDueUsdMinor - reservedUsdMinor).clamp(0, amountDueUsdMinor);

  CardStatement copyWith({
    int? amountDuePenMinor,
    int? amountDueUsdMinor,
    int? reservedPenMinor,
    int? reservedUsdMinor,
    CardStatementStatus? status,
    DateTime? updatedAt,
    int? version,
  }) => CardStatement(
    id: id,
    userId: userId,
    cardAccountId: cardAccountId,
    cycleStart: cycleStart,
    cycleEnd: cycleEnd,
    dueDate: dueDate,
    amountDuePenMinor: amountDuePenMinor ?? this.amountDuePenMinor,
    amountDueUsdMinor: amountDueUsdMinor ?? this.amountDueUsdMinor,
    reservedPenMinor: reservedPenMinor ?? this.reservedPenMinor,
    reservedUsdMinor: reservedUsdMinor ?? this.reservedUsdMinor,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    deletedAt: deletedAt,
  );

  factory CardStatement.fromMap(Map<String, Object?> map) => CardStatement(
    id: map['id']! as String,
    userId: map['userId']! as String,
    cardAccountId: map['cardAccountId']! as String,
    cycleStart: dateTimeFromFirestore(map['cycleStart']),
    cycleEnd: dateTimeFromFirestore(map['cycleEnd']),
    dueDate: dateTimeFromFirestore(map['dueDate']),
    amountDuePenMinor: map['amountDuePenMinor'] as int? ?? 0,
    amountDueUsdMinor: map['amountDueUsdMinor'] as int? ?? 0,
    reservedPenMinor: map['reservedPenMinor'] as int? ?? 0,
    reservedUsdMinor: map['reservedUsdMinor'] as int? ?? 0,
    status: CardStatementStatus.values.byName(map['status']! as String),
    createdAt: dateTimeFromFirestore(map['createdAt']),
    updatedAt: dateTimeFromFirestore(map['updatedAt']),
    version: map['version'] as int? ?? 1,
    deletedAt: nullableDateTimeFromFirestore(map['deletedAt']),
  );
}
