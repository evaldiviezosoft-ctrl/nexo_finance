import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_converters.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/financial_goal.dart';

class GoalsRepository {
  GoalsRepository(this._firestore, this.userId);
  final FirebaseFirestore _firestore;
  final String userId;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(userId).collection('goals');

  Stream<SyncedList<FinancialGoal>> watch() => _collection
      .orderBy('createdAt')
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => SyncedList(
          items: snapshot.docs
              .map((doc) => FinancialGoal.fromMap(doc.data()))
              .where((item) => item.deletedAt == null)
              .toList(growable: false),
          hasPendingWrites: snapshot.metadata.hasPendingWrites,
        ),
      );

  Future<void> save(FinancialGoal value, {required bool create}) => _collection
      .doc(value.id)
      .set(_map(value, create: create), SetOptions(merge: !create));

  Future<void> archive(FinancialGoal value) =>
      _collection.doc(value.id).update({
        'active': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'version': value.version + 1,
      });

  Map<String, Object?> _map(FinancialGoal value, {required bool create}) => {
    'id': value.id,
    'userId': userId,
    'name': value.name,
    'targetMinor': value.targetMinor,
    'openingAmountMinor': value.openingAmountMinor,
    'currency': value.currency.name,
    'deadline': value.deadline == null
        ? null
        : timestampFromDateTime(value.deadline!),
    'priority': value.priority.name,
    'accountId': value.accountId,
    'iconCodePoint': value.iconCodePoint,
    'colorValue': value.colorValue,
    'automaticContributionMinor': value.automaticContributionMinor,
    'allowWithdrawals': value.allowWithdrawals,
    'notes': value.notes,
    'active': value.active,
    if (create) 'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'version': value.version,
    'deletedAt': value.deletedAt == null
        ? null
        : timestampFromDateTime(value.deletedAt!),
  };
}

final goalsRepositoryProvider = Provider<GoalsRepository?>((ref) {
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  return uid == null ? null : GoalsRepository(FirebaseFirestore.instance, uid);
});

final goalsProvider = StreamProvider<SyncedList<FinancialGoal>>(
  (ref) =>
      ref.watch(goalsRepositoryProvider)?.watch() ??
      Stream.value(const SyncedList(items: [])),
);
