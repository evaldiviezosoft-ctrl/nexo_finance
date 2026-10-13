import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class LocalSettingsStore {
  Future<Map<String, String>> readAll();
  Future<void> write({required String key, required String value});
}

class SecureLocalSettingsStore implements LocalSettingsStore {
  const SecureLocalSettingsStore([
    this._storage = const FlutterSecureStorage(),
  ]);

  final FlutterSecureStorage _storage;

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);
}

final localSettingsStoreProvider = Provider<LocalSettingsStore>(
  (_) => const SecureLocalSettingsStore(),
);

class LocalSettings {
  const LocalSettings({
    this.hydrated = false,
    this.hydrationFailed = false,
    this.biometricLock = false,
    this.hideBalances = false,
    this.notifications = false,
    this.cardReminders = true,
    this.debtReminders = true,
    this.recurringReminders = true,
    this.goalReminders = true,
    this.budgetAlerts = true,
  });

  final bool hydrated;
  final bool hydrationFailed;
  final bool biometricLock;
  final bool hideBalances;
  final bool notifications;
  final bool cardReminders;
  final bool debtReminders;
  final bool recurringReminders;
  final bool goalReminders;
  final bool budgetAlerts;

  LocalSettings copyWith({
    bool? hydrated,
    bool? hydrationFailed,
    bool? biometricLock,
    bool? hideBalances,
    bool? notifications,
    bool? cardReminders,
    bool? debtReminders,
    bool? recurringReminders,
    bool? goalReminders,
    bool? budgetAlerts,
  }) => LocalSettings(
    hydrated: hydrated ?? this.hydrated,
    hydrationFailed: hydrationFailed ?? this.hydrationFailed,
    biometricLock: biometricLock ?? this.biometricLock,
    hideBalances: hideBalances ?? this.hideBalances,
    notifications: notifications ?? this.notifications,
    cardReminders: cardReminders ?? this.cardReminders,
    debtReminders: debtReminders ?? this.debtReminders,
    recurringReminders: recurringReminders ?? this.recurringReminders,
    goalReminders: goalReminders ?? this.goalReminders,
    budgetAlerts: budgetAlerts ?? this.budgetAlerts,
  );
}

class LocalSettingsController extends Notifier<LocalSettings> {
  static const _settingsBlobKey = 'settingsV1';
  bool _loading = false;
  Future<void> _updateQueue = Future.value();

  @override
  LocalSettings build() {
    unawaited(Future<void>.microtask(reload));
    return const LocalSettings();
  }

  Future<void> reload() async {
    if (_loading) return;
    _loading = true;
    state = state.copyWith(hydrated: false, hydrationFailed: false);
    try {
      final values = await ref.read(localSettingsStoreProvider).readAll();
      state = _decodeSettings(values);
    } catch (_) {
      state = state.copyWith(hydrated: false, hydrationFailed: true);
    } finally {
      _loading = false;
    }
  }

  Future<void> update(LocalSettings Function(LocalSettings current) mutation) {
    if (!state.hydrated) {
      return Future.error(StateError('Local settings are not ready'));
    }
    final completer = Completer<void>();
    _updateQueue = _updateQueue.then((_) async {
      try {
        if (!state.hydrated) {
          throw StateError('Local settings are not ready');
        }
        final next = mutation(
          state,
        ).copyWith(hydrated: true, hydrationFailed: false);
        await ref
            .read(localSettingsStoreProvider)
            .write(key: _settingsBlobKey, value: _encodeSettings(next));
        state = next;
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

LocalSettings _decodeSettings(Map<String, String> values) {
  final blob = values[LocalSettingsController._settingsBlobKey];
  if (blob != null) {
    final decoded = jsonDecode(blob);
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
      throw const FormatException('Invalid local settings blob');
    }
    bool read(String key, bool fallback) {
      final value = decoded[key];
      if (value == null) return fallback;
      if (value is! bool) {
        throw FormatException('Invalid local setting: $key');
      }
      return value;
    }

    return LocalSettings(
      hydrated: true,
      biometricLock: read('biometricLock', false),
      hideBalances: read('hideBalances', false),
      notifications: read('notifications', false),
      cardReminders: read('cardReminders', true),
      debtReminders: read('debtReminders', true),
      recurringReminders: read('recurringReminders', true),
      goalReminders: read('goalReminders', true),
      budgetAlerts: read('budgetAlerts', true),
    );
  }

  bool readLegacy(String key, bool fallback) {
    final value = values[key];
    if (value == null) return fallback;
    return switch (value) {
      'true' => true,
      'false' => false,
      _ => throw FormatException('Invalid local setting: $key'),
    };
  }

  return LocalSettings(
    hydrated: true,
    biometricLock: readLegacy('biometricLock', false),
    hideBalances: readLegacy('hideBalances', false),
    notifications: readLegacy('notifications', false),
    cardReminders: readLegacy('cardReminders', true),
    debtReminders: readLegacy('debtReminders', true),
    recurringReminders: readLegacy('recurringReminders', true),
    goalReminders: readLegacy('goalReminders', true),
    budgetAlerts: readLegacy('budgetAlerts', true),
  );
}

String _encodeSettings(LocalSettings value) => jsonEncode({
  'version': 1,
  'biometricLock': value.biometricLock,
  'hideBalances': value.hideBalances,
  'notifications': value.notifications,
  'cardReminders': value.cardReminders,
  'debtReminders': value.debtReminders,
  'recurringReminders': value.recurringReminders,
  'goalReminders': value.goalReminders,
  'budgetAlerts': value.budgetAlerts,
});

final localSettingsProvider =
    NotifierProvider<LocalSettingsController, LocalSettings>(
      LocalSettingsController.new,
    );
