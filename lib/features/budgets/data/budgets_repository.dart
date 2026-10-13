import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_converters.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/budget.dart';

class BudgetsRepository {
  BudgetsRepository(this._firestore, this.userId);
  final FirebaseFirestore _firestore;
  final String userId;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(userId).collection('budgets');

  Stream<SyncedList<Budget>> watch() => _collection
      .orderBy('createdAt')
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => SyncedList(
          items: snapshot.docs
              .map((doc) => Budget.fromMap(doc.data()))
              .where((item) => item.deletedAt == null)
              .toList(growable: false),
          hasPendingWrites: snapshot.metadata.hasPendingWrites,
        ),
      );

  Future<void> save(Budget value, {required bool create}) => _collection
      .doc(value.id)
      .set(_map(value, create: create), SetOptions(merge: !create));

  Future<void> archive(Budget value) => _collection.doc(value.id).update({
    'active': false,
    'updatedAt': FieldValue.serverTimestamp(),
    'version': value.version + 1,
  });

  Map<String, Object?> _map(Budget value, {required bool create}) => {
    'id': value.id,
    'userId': userId,
    'name': value.name,
    'period': value.period.name,
    'amountMinor': value.amountMinor,
    'currency': value.currency.name,
    'categoryId': value.categoryId,
    'customStart': value.customStart == null
        ? null
        : timestampFromDateTime(value.customStart!),
    'customEnd': value.customEnd == null
        ? null
        : timestampFromDateTime(value.customEnd!),
    'rollover': value.rollover,
    'active': value.active,
    if (create) 'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'version': value.version,
    'deletedAt': value.deletedAt == null
        ? null
        : timestampFromDateTime(value.deletedAt!),
  };
}

final budgetsRepositoryProvider = Provider<BudgetsRepository?>((ref) {
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  return uid == null
      ? null
      : BudgetsRepository(FirebaseFirestore.instance, uid);
});

final budgetsProvider = StreamProvider<SyncedList<Budget>>(
  (ref) =>
      ref.watch(budgetsRepositoryProvider)?.watch() ??
      Stream.value(const SyncedList(items: [])),
);
