import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import '../features/notifications/presentation/reminder_coordinator.dart';
import '../features/security/presentation/privacy_gate.dart';

class NexoFinanceApp extends ConsumerWidget {
  const NexoFinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Nexo Finance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.amoled,
      routerConfig: router,
      builder: (context, child) => ReminderCoordinator(
        child: PrivacyGate(child: child ?? const SizedBox.shrink()),
      ),
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
