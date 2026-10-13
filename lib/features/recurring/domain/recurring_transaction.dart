import 'package:uuid/uuid.dart';

import '../../../core/firebase/firestore_converters.dart';
import '../../../core/money/money.dart';
import '../../transactions/domain/financial_transaction.dart';

enum RecurringFrequency { weekly, monthly, yearly }

extension RecurringFrequencyLabel on RecurringFrequency {
  String get label => switch (this) {
    RecurringFrequency.weekly => 'Semanal',
    RecurringFrequency.monthly => 'Mensual',
    RecurringFrequency.yearly => 'Anual',
  };
}

class RecurringTransaction {
  const RecurringTransaction({
    required this.id,
    required this.userId,
    required this.name,
    required this.kind,
    required this.amountMinor,
    required this.currency,
    required this.frequency,
    required this.interval,
    required this.nextDueAt,
    required this.createdAt,
    required this.updatedAt,
    this.sourceAccountId,
    this.destinationAccountId,
    this.categoryId,
    this.active = true,
    this.version = 1,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String name;
  final TransactionKind kind;
  final int amountMinor;
  final Currency currency;
  final RecurringFrequency frequency;
  final int interval;
  final DateTime nextDueAt;
  final String? sourceAccountId;
  final String? destinationAccountId;
  final String? categoryId;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final DateTime? deletedAt;

  factory RecurringTransaction.fromMap(Map<String, Object?> map) =>
      RecurringTransaction(
        id: map['id']! as String,
        userId: map['userId']! as String,
        name: map['name']! as String,
        kind: TransactionKind.values.byName(map['kind']! as String),
        amountMinor: map['amountMinor']! as int,
        currency: Currency.values.byName(map['currency']! as String),
        frequency: RecurringFrequency.values.byName(
          map['frequency']! as String,
        ),
        interval: map['interval'] as int? ?? 1,
        nextDueAt: dateTimeFromFirestore(map['nextDueAt']),
        sourceAccountId: map['sourceAccountId'] as String?,
        destinationAccountId: map['destinationAccountId'] as String?,
        categoryId: map['categoryId'] as String?,
        active: map['active'] as bool? ?? true,
        createdAt: dateTimeFromFirestore(map['createdAt']),
        updatedAt: dateTimeFromFirestore(map['updatedAt']),
        version: map['version'] as int? ?? 1,
        deletedAt: nullableDateTimeFromFirestore(map['deletedAt']),
      );
}

abstract final class RecurrenceCalculator {
  static const _uuid = Uuid();

  static DateTime next(RecurringTransaction item) => switch (item.frequency) {
    RecurringFrequency.weekly => item.nextDueAt.add(
      Duration(days: 7 * item.interval),
    ),
    RecurringFrequency.monthly => _addMonths(item.nextDueAt, item.interval),
    RecurringFrequency.yearly => _addMonths(item.nextDueAt, 12 * item.interval),
  };

  static String occurrenceTransactionId(RecurringTransaction item) => _uuid.v5(
    Namespace.url.value,
    'nexo-finance://recurring/${item.id}/'
    '${item.nextDueAt.toUtc().microsecondsSinceEpoch}',
  );

  static DateTime _addMonths(DateTime date, int months) {
    final first = DateTime.utc(date.year, date.month + months, 1);
    final lastDay = DateTime.utc(first.year, first.month + 1, 0).day;
    return DateTime.utc(
      first.year,
      first.month,
      date.day.clamp(1, lastDay),
      date.hour,
      date.minute,
    );
  }
}
