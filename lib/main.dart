import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap/firebase_bootstrap.dart';
import 'features/notifications/data/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  final firebase = await FirebaseBootstrap.initialize();

  runApp(
    ProviderScope(
      overrides: [firebaseBootstrapProvider.overrideWithValue(firebase)],
      child: const NexoFinanceApp(),
    ),
  );
}
