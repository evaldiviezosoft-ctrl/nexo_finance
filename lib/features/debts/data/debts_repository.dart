import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_converters.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/debt_record.dart';

class DebtsRepository {
  DebtsRepository(this._firestore, this.userId);
  final FirebaseFirestore _firestore;
  final String userId;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(userId).collection('debts');

  Stream<SyncedList<DebtRecord>> watch() => _collection
      .orderBy('createdAt')
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => SyncedList(
          items: snapshot.docs
              .map((doc) => DebtRecord.fromMap(doc.data()))
              .where((item) => item.deletedAt == null)
              .toList(growable: false),
          hasPendingWrites: snapshot.metadata.hasPendingWrites,
        ),
      );

  Future<void> save(DebtRecord value, {required bool create}) => _collection
      .doc(value.id)
      .set(_map(value, create: create), SetOptions(merge: !create));

  Future<void> archive(DebtRecord value) => _collection.doc(value.id).update({
    'status': DebtStatus.paid.name,
    'updatedAt': FieldValue.serverTimestamp(),
    'version': value.version + 1,
  });

  Map<String, Object?> _map(DebtRecord value, {required bool create}) => {
    'id': value.id,
    'userId': userId,
    'name': value.name,
    'direction': value.direction.name,
    'type': value.type.name,
    'party': value.party,
    'initialPrincipalMinor': value.initialPrincipalMinor,
    'currency': value.currency.name,
    'annualRateBasisPoints': value.annualRateBasisPoints,
    'installments': value.installments,
    'installmentMinor': value.installmentMinor,
    'nextDueDate': value.nextDueDate == null
        ? null
        : timestampFromDateTime(value.nextDueDate!),
    'paymentDay': value.paymentDay,
    'thirdPartyContributionMinor': value.thirdPartyContributionMinor,
    'status': value.status.name,
    'notes': value.notes,
    if (create) 'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'version': value.version,
    'deletedAt': value.deletedAt == null
        ? null
        : timestampFromDateTime(value.deletedAt!),
  };
}

final debtsRepositoryProvider = Provider<DebtsRepository?>((ref) {
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  return uid == null ? null : DebtsRepository(FirebaseFirestore.instance, uid);
});

final debtsProvider = StreamProvider<SyncedList<DebtRecord>>(
  (ref) =>
      ref.watch(debtsRepositoryProvider)?.watch() ??
      Stream.value(const SyncedList(items: [])),
);
