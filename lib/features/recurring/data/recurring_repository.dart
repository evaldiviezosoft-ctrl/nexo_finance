import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_converters.dart';
import '../../auth/data/auth_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../domain/recurring_transaction.dart';

class RecurringRepository {
  RecurringRepository(this._firestore, this.userId);
  final FirebaseFirestore _firestore;
  final String userId;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('users')
      .doc(userId)
      .collection('recurringTransactions');

  Stream<SyncedList<RecurringTransaction>> watch() => _collection
      .orderBy('nextDueAt')
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => SyncedList(
          items: snapshot.docs
              .map((doc) => RecurringTransaction.fromMap(doc.data()))
              .where((item) => item.deletedAt == null)
              .toList(growable: false),
          hasPendingWrites: snapshot.metadata.hasPendingWrites,
        ),
      );

  Future<void> create(RecurringTransaction value) =>
      _collection.doc(value.id).set(_map(value, create: true));

  Future<void> update(RecurringTransaction value) => _collection
      .doc(value.id)
      .set(_map(value, create: false), SetOptions(merge: true));

  Future<void> confirmOccurrence({
    required RecurringTransaction recurring,
  }) async {
    final now = DateTime.now().toUtc();
    if (!recurring.active || recurring.deletedAt != null) {
      throw StateError('La recurrencia ya no está activa.');
    }
    if (recurring.nextDueAt.isAfter(now)) {
      throw StateError('La recurrencia todavía no está vencida.');
    }
    final transactionId = RecurrenceCalculator.occurrenceTransactionId(
      recurring,
    );
    final transaction = FinancialTransaction(
      id: transactionId,
      userId: userId,
      kind: recurring.kind,
      amountMinor: recurring.amountMinor,
      currency: recurring.currency,
      sourceAccountId: recurring.sourceAccountId,
      destinationAccountId: recurring.destinationAccountId,
      categoryId: recurring.categoryId,
      description: recurring.name,
      note: 'Creado desde una recurrencia confirmada.',
      occurredAt: recurring.nextDueAt,
      createdAt: now,
      updatedAt: now,
    );
    final batch = _firestore.batch();
    final transactionRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc(transactionId);
    batch.set(
      transactionRef,
      TransactionsRepository.mapForWrite(
        transaction,
        userId: userId,
        create: true,
      ),
    );
    batch.update(_collection.doc(recurring.id), {
      'nextDueAt': timestampFromDateTime(RecurrenceCalculator.next(recurring)),
      'updatedAt': FieldValue.serverTimestamp(),
      'version': recurring.version + 1,
    });
    await batch.commit();
  }

  Map<String, Object?> _map(
    RecurringTransaction value, {
    required bool create,
  }) => {
    'id': value.id,
    'userId': userId,
    'name': value.name,
    'kind': value.kind.name,
    'amountMinor': value.amountMinor,
    'currency': value.currency.name,
    'frequency': value.frequency.name,
    'interval': value.interval,
    'nextDueAt': timestampFromDateTime(value.nextDueAt),
    'sourceAccountId': value.sourceAccountId,
    'destinationAccountId': value.destinationAccountId,
    'categoryId': value.categoryId,
    'active': value.active,
    if (create) 'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'version': value.version,
    'deletedAt': value.deletedAt == null
        ? null
        : timestampFromDateTime(value.deletedAt!),
  };
}

final recurringRepositoryProvider = Provider<RecurringRepository?>((ref) {
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  return uid == null
      ? null
      : RecurringRepository(FirebaseFirestore.instance, uid);
});

final recurringTransactionsProvider =
    StreamProvider<SyncedList<RecurringTransaction>>(
      (ref) =>
          ref.watch(recurringRepositoryProvider)?.watch() ??
          Stream.value(const SyncedList(items: [])),
    );
