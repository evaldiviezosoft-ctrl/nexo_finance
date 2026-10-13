import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_finance/features/security/data/biometric_service.dart';
import 'package:nexo_finance/features/security/presentation/privacy_gate.dart';
import 'package:nexo_finance/features/settings/data/local_settings.dart';

class _FixedSettingsController extends LocalSettingsController {
  _FixedSettingsController(this.initial);

  final LocalSettings initial;

  @override
  LocalSettings build() => initial;
}

class _FakeBiometricService extends BiometricService {
  _FakeBiometricService(this.results);

  final List<bool> results;
  int calls = 0;

  @override
  Future<bool> authenticate() async {
    calls++;
    return results.removeAt(0);
  }
}

class _MemorySettingsStore implements LocalSettingsStore {
  _MemorySettingsStore({
    Map<String, String> values = const {},
    this.readError = false,
    this.writeError = false,
  }) : values = Map.of(values);

  final Map<String, String> values;
  final bool readError;
  final bool writeError;

  @override
  Future<Map<String, String>> readAll() async {
    if (readError) throw StateError('secure storage unavailable');
    return values;
  }

  @override
  Future<void> write({required String key, required String value}) async {
    if (writeError) throw StateError('secure storage unavailable');
    values[key] = value;
  }
}

void main() {
  const sensitive = Key('sensitive-content');

  Widget app({
    required LocalSettings settings,
    required _FakeBiometricService biometrics,
  }) => ProviderScope(
    overrides: [
      localSettingsProvider.overrideWith(
        () => _FixedSettingsController(settings),
      ),
    ],
    child: MaterialApp(
      home: PrivacyGate(
        biometricService: biometrics,
        child: const SizedBox(key: sensitive),
      ),
    ),
  );

  testWidgets('never renders protected content before hydration', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        settings: const LocalSettings(),
        biometrics: _FakeBiometricService([]),
      ),
    );
    await tester.pump();

    expect(find.byKey(sensitive), findsNothing);
    expect(find.text('Protegiendo tus datos…'), findsOneWidget);
  });

  testWidgets('storage failure stays opaque and offers retry', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localSettingsStoreProvider.overrideWithValue(
            _MemorySettingsStore(readError: true),
          ),
        ],
        child: MaterialApp(
          home: PrivacyGate(
            biometricService: _FakeBiometricService([]),
            child: const SizedBox(key: sensitive),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(sensitive), findsNothing);
    expect(
      find.text('No se pudieron verificar los ajustes seguros'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('malformed stored protection stays opaque', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localSettingsStoreProvider.overrideWithValue(
            _MemorySettingsStore(values: {'biometricLock': 'invalid'}),
          ),
        ],
        child: MaterialApp(
          home: PrivacyGate(
            biometricService: _FakeBiometricService([]),
            child: const SizedBox(key: sensitive),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(sensitive), findsNothing);
    expect(
      find.text('No se pudieron verificar los ajustes seguros'),
      findsOneWidget,
    );
  });

  testWidgets('stored disabled lock reveals content only after hydration', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        settings: const LocalSettings(hydrated: true),
        biometrics: _FakeBiometricService([]),
      ),
    );
    await tester.pump();

    expect(find.byKey(sensitive), findsOneWidget);
  });

  testWidgets('failed authentication stays locked and retry can unlock', (
    tester,
  ) async {
    final biometrics = _FakeBiometricService([false, true]);
    await tester.pumpWidget(
      app(
        settings: const LocalSettings(hydrated: true, biometricLock: true),
        biometrics: biometrics,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(sensitive), findsNothing);
    expect(find.text('Desbloquear'), findsOneWidget);

    await tester.tap(find.text('Desbloquear'));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(sensitive), findsOneWidget);
    expect(biometrics.calls, 2);
  });

  testWidgets('backgrounding immediately covers and requires authentication', (
    tester,
  ) async {
    final biometrics = _FakeBiometricService([true, false]);
    await tester.pumpWidget(
      app(
        settings: const LocalSettings(hydrated: true, biometricLock: true),
        biometrics: biometrics,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(sensitive), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(sensitive), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(sensitive), findsNothing);
    expect(biometrics.calls, 2);
  });

  test('failed persistence does not publish biometric protection', () async {
    final container = ProviderContainer(
      overrides: [
        localSettingsStoreProvider.overrideWithValue(
          _MemorySettingsStore(writeError: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(localSettingsProvider);
    await Future<void>.delayed(Duration.zero);
    final before = container.read(localSettingsProvider);
    expect(before.hydrated, isTrue);
    expect(before.biometricLock, isFalse);

    await expectLater(
      container
          .read(localSettingsProvider.notifier)
          .update((current) => current.copyWith(biometricLock: true)),
      throwsStateError,
    );

    expect(container.read(localSettingsProvider).biometricLock, isFalse);
  });

  test('concurrent setting changes are serialized and merged', () async {
    final store = _MemorySettingsStore();
    final container = ProviderContainer(
      overrides: [localSettingsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    container.read(localSettingsProvider);
    await Future<void>.delayed(Duration.zero);
    final controller = container.read(localSettingsProvider.notifier);

    await Future.wait([
      controller.update((current) => current.copyWith(hideBalances: true)),
      controller.update((current) => current.copyWith(notifications: true)),
    ]);

    final result = container.read(localSettingsProvider);
    expect(result.hideBalances, isTrue);
    expect(result.notifications, isTrue);
    expect(store.values.keys, contains('settingsV1'));
    expect(store.values, hasLength(1));
  });
}
