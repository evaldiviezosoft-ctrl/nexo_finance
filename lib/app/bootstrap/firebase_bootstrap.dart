import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';

enum FirebaseBootstrapStatus { ready, configurationRequired, failed }

class FirebaseBootstrapResult {
  const FirebaseBootstrapResult._(this.status, [this.error]);

  const FirebaseBootstrapResult.ready() : this._(FirebaseBootstrapStatus.ready);

  const FirebaseBootstrapResult.configurationRequired([Object? error])
    : this._(FirebaseBootstrapStatus.configurationRequired, error);

  const FirebaseBootstrapResult.failed(Object error)
    : this._(FirebaseBootstrapStatus.failed, error);

  final FirebaseBootstrapStatus status;
  final Object? error;

  bool get isReady => status == FirebaseBootstrapStatus.ready;
}

final firebaseBootstrapProvider = Provider<FirebaseBootstrapResult>(
  (ref) => const FirebaseBootstrapResult.configurationRequired(),
);

abstract final class FirebaseBootstrap {
  static Future<FirebaseBootstrapResult> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestProvider(),
      );
      return const FirebaseBootstrapResult.ready();
    } on FirebaseException catch (error) {
      if (error.code == 'core/not-initialized' ||
          error.code == 'core/no-app' ||
          error.message?.contains('configuration') == true ||
          error.message?.contains('options') == true) {
        return FirebaseBootstrapResult.configurationRequired(error);
      }
      return FirebaseBootstrapResult.failed(error);
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('google-services') ||
          message.contains('firebase_options') ||
          message.contains('configuration') ||
          message.contains('options')) {
        return FirebaseBootstrapResult.configurationRequired(error);
      }
      return FirebaseBootstrapResult.failed(error);
    }
  }
}
