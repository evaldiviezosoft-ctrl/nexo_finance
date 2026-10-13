import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_converters.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/finance_category.dart';

class CategoriesRepository {
  CategoriesRepository(this._firestore, this.userId);

  final FirebaseFirestore _firestore;
  final String userId;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(userId).collection('categories');

  Stream<SyncedList<FinanceCategory>> watch() => _collection
      .orderBy('order')
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => SyncedList(
          items: snapshot.docs
              .map((doc) => FinanceCategory.fromMap(doc.data()))
              .where((category) => category.deletedAt == null)
              .toList(growable: false),
          hasPendingWrites: snapshot.metadata.hasPendingWrites,
        ),
      );

  Future<void> create(FinanceCategory category) =>
      _collection.doc(category.id).set(_map(category, create: true));

  Future<void> update(FinanceCategory category) => _collection
      .doc(category.id)
      .set(_map(category, create: false), SetOptions(merge: true));

  Future<void> archive(FinanceCategory category) =>
      _collection.doc(category.id).update({
        'active': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'version': category.version + 1,
      });

  Future<void> seedDefaultsIfEmpty() async {
    final existing = await _collection.limit(1).get();
    if (existing.docs.isNotEmpty) return;
    const defaults = <(String, CategoryType, String?)>[
      ('Alimentación', CategoryType.expense, null),
      ('Desayuno', CategoryType.expense, 'alimentacion'),
      ('Almuerzo', CategoryType.expense, 'alimentacion'),
      ('Cena', CategoryType.expense, 'alimentacion'),
      ('Transporte', CategoryType.expense, null),
      ('Combustible', CategoryType.expense, 'transporte'),
      ('Moto', CategoryType.expense, 'transporte'),
      ('Taxi', CategoryType.expense, 'transporte'),
      ('Deporte', CategoryType.expense, null),
      ('Teléfono e internet', CategoryType.expense, null),
      ('Higiene personal', CategoryType.expense, null),
      ('Salud', CategoryType.expense, null),
      ('Ropa y calzado', CategoryType.expense, null),
      ('Entretenimiento', CategoryType.expense, null),
      ('Viajes', CategoryType.expense, null),
      ('Hogar', CategoryType.expense, null),
      ('Deudas', CategoryType.expense, null),
      ('Tarjetas', CategoryType.expense, null),
      ('Ahorro', CategoryType.expense, null),
      ('Inversiones', CategoryType.expense, null),
      ('Otros', CategoryType.expense, null),
      ('Sueldo', CategoryType.income, null),
      ('Ingreso adicional', CategoryType.income, null),
    ];
    final batch = _firestore.batch();
    for (var index = 0; index < defaults.length; index++) {
      final item = defaults[index];
      final id = _slug(item.$1);
      batch.set(_collection.doc(id), {
        'id': id,
        'userId': userId,
        'name': item.$1,
        'type': item.$2.name,
        'parentId': item.$3,
        'iconCodePoint': 0xe57f,
        'colorValue': 0xffff1744,
        'order': index,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'version': 1,
        'deletedAt': null,
      });
    }
    await batch.commit();
  }

  Map<String, Object?> _map(FinanceCategory value, {required bool create}) => {
    'id': value.id,
    'userId': userId,
    'name': value.name,
    'type': value.type.name,
    'parentId': value.parentId,
    'iconCodePoint': value.iconCodePoint,
    'colorValue': value.colorValue,
    'order': value.order,
    'active': value.active,
    if (create) 'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'version': value.version,
    'deletedAt': value.deletedAt == null
        ? null
        : timestampFromDateTime(value.deletedAt!),
  };

  String _slug(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[áàä]'), 'a')
      .replaceAll(RegExp('[éèë]'), 'e')
      .replaceAll(RegExp('[íìï]'), 'i')
      .replaceAll(RegExp('[óòö]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp('[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

final categoriesRepositoryProvider = Provider<CategoriesRepository?>((ref) {
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  if (uid == null) return null;
  return CategoriesRepository(FirebaseFirestore.instance, uid);
});

final categoriesProvider = StreamProvider<SyncedList<FinanceCategory>>((ref) {
  final repository = ref.watch(categoriesRepositoryProvider);
  if (repository == null) return Stream.value(const SyncedList(items: []));
  return _seedThenWatch(repository);
});

Stream<SyncedList<FinanceCategory>> _seedThenWatch(
  CategoriesRepository repository,
) async* {
  try {
    await repository.seedDefaultsIfEmpty();
  } on FirebaseException {
    // Offline startup still uses the cached collection and queues user writes.
  }
  yield* repository.watch();
}
