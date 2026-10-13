import 'package:cloud_firestore/cloud_firestore.dart';

DateTime dateTimeFromFirestore(Object? value) {
  if (value is Timestamp) return value.toDate().toUtc();
  if (value is DateTime) return value.toUtc();
  if (value is String) return DateTime.parse(value).toUtc();
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

DateTime? nullableDateTimeFromFirestore(Object? value) =>
    value == null ? null : dateTimeFromFirestore(value);

Timestamp timestampFromDateTime(DateTime value) =>
    Timestamp.fromDate(value.toUtc());

class SyncedList<T> {
  const SyncedList({required this.items, this.hasPendingWrites = false});

  final List<T> items;
  final bool hasPendingWrites;
}
