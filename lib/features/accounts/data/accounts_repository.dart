import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/firebase/firestore_converters.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/financial_account.dart';

class AccountsRepository {
  AccountsRepository(this._firestore, this.userId);

  final FirebaseFirestore _firestore;
  final String userId;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(userId).collection('accounts');

  Stream<SyncedList<FinancialAccount>> watch() => _collection
      .orderBy('createdAt')
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => SyncedList(
          items: snapshot.docs
              .map((doc) => FinancialAccount.fromMap(doc.data()))
              .where((account) => account.deletedAt == null)
              .toList(growable: false),
          hasPendingWrites: snapshot.metadata.hasPendingWrites,
        ),
      );

  Future<void> create(FinancialAccount account) =>
      _collection.doc(account.id).set(_map(account, create: true));

  Future<void> update(FinancialAccount account) => _collection
      .doc(account.id)
      .set(_map(account, create: false), SetOptions(merge: true));

  Future<void> archive(FinancialAccount account) => update(
    account.copyWith(
      active: false,
      updatedAt: DateTime.now().toUtc(),
      version: account.version + 1,
    ),
  );

  Map<String, Object?> _map(FinancialAccount value, {required bool create}) => {
    'id': value.id,
    'userId': userId,
    'name': value.name,
    'type': value.type.name,
    'currency': value.currency.name,
    'initialBalanceMinor': value.initialBalanceMinor,
    'institution': value.institution,
    'active': value.active,
    'creditLimitMinor': value.creditLimitMinor,
    'closingDay': value.closingDay,
    'paymentDay': value.paymentDay,
    'cryptoAssetSymbol': value.cryptoAssetSymbol,
    'cryptoQuantity': value.cryptoQuantity,
    'cryptoAprBasisPoints': value.cryptoAprBasisPoints,
    if (create) 'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'version': value.version,
    'deletedAt': value.deletedAt == null
        ? null
        : timestampFromDateTime(value.deletedAt!),
  };
}

final uuidProvider = Provider<Uuid>((ref) => const Uuid());

final accountsRepositoryProvider = Provider<AccountsRepository?>((ref) {
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  if (uid == null) return null;
  return AccountsRepository(FirebaseFirestore.instance, uid);
});

final accountsProvider = StreamProvider<SyncedList<FinancialAccount>>((ref) {
  return ref.watch(accountsRepositoryProvider)?.watch() ??
      Stream.value(const SyncedList(items: []));
});
