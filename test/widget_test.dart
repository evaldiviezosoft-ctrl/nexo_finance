import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_finance/app/app.dart';
import 'package:nexo_finance/app/bootstrap/firebase_bootstrap.dart';
import 'package:nexo_finance/features/auth/data/auth_repository.dart';
import 'package:nexo_finance/features/settings/data/local_settings.dart';

class _ReadyLocalSettingsController extends LocalSettingsController {
  @override
  LocalSettings build() => const LocalSettings(hydrated: true);
}

void main() {
  testWidgets('shows Firebase setup guidance when configuration is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localSettingsProvider.overrideWith(_ReadyLocalSettingsController.new),
        ],
        child: const NexoFinanceApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conecta tu proyecto Firebase'), findsOneWidget);
    expect(find.textContaining('flutterfire configure'), findsOneWidget);
  });

  testWidgets('shows protected login when Firebase is ready and signed out', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localSettingsProvider.overrideWith(_ReadyLocalSettingsController.new),
          firebaseBootstrapProvider.overrideWithValue(
            const FirebaseBootstrapResult.ready(),
          ),
          authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const NexoFinanceApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Iniciar sesión'), findsOneWidget);
  });
}
