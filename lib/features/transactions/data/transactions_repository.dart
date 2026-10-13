import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_converters.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/financial_transaction.dart';

class TransactionsRepository {
  TransactionsRepository(this._firestore, this.userId);

  final FirebaseFirestore _firestore;
  final String userId;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(userId).collection('transactions');

  Stream<SyncedList<FinancialTransaction>> watchAll() => _collection
      .orderBy('occurredAt', descending: true)
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => SyncedList(
          items: snapshot.docs
              .map((doc) => FinancialTransaction.fromMap(doc.data()))
              .where((item) => item.deletedAt == null)
              .toList(growable: false),
          hasPendingWrites: snapshot.metadata.hasPendingWrites,
        ),
      );

  Stream<SyncedList<FinancialTransaction>> watchRecent({int limit = 200}) =>
      watchAll().map(
        (snapshot) => SyncedList(
          items: snapshot.items.take(limit).toList(growable: false),
          hasPendingWrites: snapshot.hasPendingWrites,
        ),
      );

  Future<void> create(FinancialTransaction transaction) => _collection
      .doc(transaction.id)
      .set(mapForWrite(transaction, userId: userId, create: true));

  Future<void> update(FinancialTransaction transaction) => _collection
      .doc(transaction.id)
      .set(
        mapForWrite(transaction, userId: userId, create: false),
        SetOptions(merge: true),
      );

  Future<void> softDelete(FinancialTransaction transaction) =>
      _collection.doc(transaction.id).update({
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'version': transaction.version + 1,
      });

  Future<void> restore(FinancialTransaction transaction) =>
      _collection.doc(transaction.id).update({
        'deletedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
        'version': transaction.version + 2,
      });

  static Map<String, Object?> mapForWrite(
    FinancialTransaction value, {
    required String userId,
    required bool create,
  }) => {
    'id': value.id,
    'userId': userId,
    'kind': value.kind.name,
    'amountMinor': value.amountMinor,
    'currency': value.currency.name,
    'sourceAccountId': value.sourceAccountId,
    'destinationAccountId': value.destinationAccountId,
    'categoryId': value.categoryId,
    'description': value.description,
    'note': value.note,
    'relatedTransactionId': value.relatedTransactionId,
    'goalId': value.goalId,
    'debtId': value.debtId,
    'exchangeRateMicros': value.exchangeRateMicros,
    'destinationAmountMinor': value.destinationAmountMinor,
    'thirdPartyAmountMinor': value.thirdPartyAmountMinor,
    'occurredAt': timestampFromDateTime(value.occurredAt),
    if (create) 'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'version': value.version,
    'deletedAt': value.deletedAt == null
        ? null
        : timestampFromDateTime(value.deletedAt!),
  };
}

final transactionsRepositoryProvider = Provider<TransactionsRepository?>((ref) {
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  if (uid == null) return null;
  return TransactionsRepository(FirebaseFirestore.instance, uid);
});

final transactionsProvider = StreamProvider<SyncedList<FinancialTransaction>>((
  ref,
) {
  return ref.watch(transactionsRepositoryProvider)?.watchAll() ??
      Stream.value(const SyncedList(items: []));
});
