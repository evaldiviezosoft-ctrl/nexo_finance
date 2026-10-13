import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../app/bootstrap/firebase_bootstrap.dart';

abstract interface class AuthRepository {
  Stream<User?> authStateChanges();
  Future<void> signInWithEmail(String email, String password);
  Future<void> registerWithEmail(String email, String password);
  Future<void> signInWithGoogle();
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;
  bool _googleInitialized = false;

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  @override
  Future<void> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> registerWithEmail(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _auth.signInWithPopup(GoogleAuthProvider());
      return;
    }
    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleInitialized = true;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final credential = GoogleAuthProvider.credential(
      idToken: account.authentication.idToken,
    );
    await _auth.signInWithCredential(credential);
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  @override
  Future<void> signOut() => _auth.signOut();
}

final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  if (!ref.watch(firebaseBootstrapProvider).isReady) return null;
  return FirebaseAuthRepository(FirebaseAuth.instance);
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider)?.authStateChanges() ??
      Stream<User?>.value(null);
});

final authActionsProvider = Provider<AuthActions>(AuthActions.new);

class AuthActions {
  AuthActions(this._ref);

  final Ref _ref;

  AuthRepository get _repository {
    final repository = _ref.read(authRepositoryProvider);
    if (repository == null) {
      throw StateError('Firebase todavía no está configurado.');
    }
    return repository;
  }

  Future<void> submit({
    required String email,
    required String password,
    required bool register,
  }) => register
      ? _repository.registerWithEmail(email.trim(), password)
      : _repository.signInWithEmail(email.trim(), password);

  Future<void> signInWithGoogle() => _repository.signInWithGoogle();
  Future<void> sendPasswordReset(String email) =>
      _repository.sendPasswordReset(email.trim());
  Future<void> signOut() => _repository.signOut();
}
