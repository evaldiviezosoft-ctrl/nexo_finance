import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_converters.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/card_statement.dart';

class CardStatementsRepository {
  CardStatementsRepository(this._firestore, this.userId);
  final FirebaseFirestore _firestore;
  final String userId;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(userId).collection('cardStatements');

  Stream<SyncedList<CardStatement>> watch() => _collection
      .orderBy('dueDate', descending: false)
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => SyncedList(
          items: snapshot.docs
              .map((doc) => CardStatement.fromMap(doc.data()))
              .where((item) => item.deletedAt == null)
              .toList(growable: false),
          hasPendingWrites: snapshot.metadata.hasPendingWrites,
        ),
      );

  Future<void> save(CardStatement value, {required bool create}) => _collection
      .doc(value.id)
      .set(_map(value, create: create), SetOptions(merge: !create));

  Map<String, Object?> _map(CardStatement value, {required bool create}) => {
    'id': value.id,
    'userId': userId,
    'cardAccountId': value.cardAccountId,
    'cycleStart': timestampFromDateTime(value.cycleStart),
    'cycleEnd': timestampFromDateTime(value.cycleEnd),
    'dueDate': timestampFromDateTime(value.dueDate),
    'amountDuePenMinor': value.amountDuePenMinor,
    'amountDueUsdMinor': value.amountDueUsdMinor,
    'reservedPenMinor': value.reservedPenMinor,
    'reservedUsdMinor': value.reservedUsdMinor,
    'status': value.status.name,
    if (create) 'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'version': value.version,
    'deletedAt': value.deletedAt == null
        ? null
        : timestampFromDateTime(value.deletedAt!),
  };
}

final cardStatementsRepositoryProvider = Provider<CardStatementsRepository?>((
  ref,
) {
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  return uid == null
      ? null
      : CardStatementsRepository(FirebaseFirestore.instance, uid);
});

final cardStatementsProvider = StreamProvider<SyncedList<CardStatement>>(
  (ref) =>
      ref.watch(cardStatementsRepositoryProvider)?.watch() ??
      Stream.value(const SyncedList(items: [])),
);
