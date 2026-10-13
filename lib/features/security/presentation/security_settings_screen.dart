import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/data/local_settings.dart';
import '../data/biometric_service.dart';

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() =>
      _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState
    extends ConsumerState<SecuritySettingsScreen> {
  final _biometrics = BiometricService();
  bool checking = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(localSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Seguridad y privacidad')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint_rounded),
            title: const Text('Bloqueo biométrico'),
            subtitle: const Text(
              'Solicita huella o rostro al abrir la app y al regresar.',
            ),
            value: settings.biometricLock,
            onChanged: checking ? null : _toggleBiometrics,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off_outlined),
            title: const Text('Ocultar saldos al iniciar'),
            subtitle: const Text(
              'El botón del ojo permite mostrarlos temporalmente.',
            ),
            value: settings.hideBalances,
            onChanged: (value) => ref
                .read(localSettingsProvider.notifier)
                .update((current) => current.copyWith(hideBalances: value)),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Estas preferencias se guardan cifradas únicamente en este dispositivo.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBiometrics(bool enabled) async {
    if (!enabled) {
      setState(() => checking = true);
      try {
        await ref
            .read(localSettingsProvider.notifier)
            .update((current) => current.copyWith(biometricLock: false));
      } catch (error) {
        if (mounted) _showPersistenceError(error);
      } finally {
        if (mounted) setState(() => checking = false);
      }
      return;
    }
    setState(() => checking = true);
    final available = await _biometrics.isAvailable();
    final authenticated = available && await _biometrics.authenticate();
    if (!mounted) return;
    if (!authenticated) {
      setState(() => checking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            available
                ? 'No se pudo confirmar la identidad.'
                : 'Este dispositivo no tiene biometría configurada.',
          ),
        ),
      );
      return;
    }
    try {
      await ref
          .read(localSettingsProvider.notifier)
          .update((current) => current.copyWith(biometricLock: true));
    } catch (error) {
      if (mounted) _showPersistenceError(error);
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  void _showPersistenceError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo guardar la protección: $error')),
    );
  }
}
