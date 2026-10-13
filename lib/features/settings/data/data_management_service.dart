import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DataManagementService {
  DataManagementService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : firestore = firestore ?? FirebaseFirestore.instance,
      auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  static const collections = [
    'accounts',
    'categories',
    'transactions',
    'budgets',
    'cardStatements',
    'recurringTransactions',
    'goals',
    'debts',
  ];

  Future<void> clearLocalCache() async {
    await auth.signOut();
    await firestore.terminate();
    await firestore.clearPersistence();
  }

  Future<void> deleteAccountAndData() async {
    final user = auth.currentUser;
    if (user == null) throw StateError('No hay una sesión activa.');
    final lastSignIn = user.metadata.lastSignInTime;
    if (lastSignIn == null ||
        DateTime.now().difference(lastSignIn).inMinutes > 10) {
      throw FirebaseAuthException(
        code: 'requires-recent-login',
        message: 'Vuelve a iniciar sesión antes de eliminar la cuenta.',
      );
    }
    final root = firestore.collection('users').doc(user.uid);
    for (final name in collections) {
      while (true) {
        final page = await root.collection(name).limit(400).get();
        if (page.docs.isEmpty) break;
        final batch = firestore.batch();
        for (final document in page.docs) {
          batch.delete(document.reference);
        }
        await batch.commit();
      }
    }
    await user.delete();
  }
}
