import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../settings/data/local_settings.dart';
import '../data/biometric_service.dart';

class PrivacyGate extends ConsumerStatefulWidget {
  const PrivacyGate({required this.child, this.biometricService, super.key});

  final Widget child;
  final BiometricService? biometricService;

  @override
  ConsumerState<PrivacyGate> createState() => _PrivacyGateState();
}

class _PrivacyGateState extends ConsumerState<PrivacyGate>
    with WidgetsBindingObserver {
  late final BiometricService _biometrics;
  bool _locked = true;
  bool _authorizedForForeground = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _biometrics = widget.biometricService ?? BiometricService();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applySettings(ref.read(localSettingsProvider));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _applySettings(ref.read(localSettingsProvider));
      return;
    }

    final settings = ref.read(localSettingsProvider);
    if (!settings.hydrated || settings.biometricLock) {
      _authorizedForForeground = false;
      if (!_locked && mounted) {
        setState(() => _locked = true);
      }
    }
  }

  void _applySettings(LocalSettings settings) {
    if (!mounted) return;
    if (!settings.hydrated) {
      _authorizedForForeground = false;
      if (!_locked) setState(() => _locked = true);
      return;
    }
    if (!settings.biometricLock) {
      _authorizedForForeground = true;
      if (_locked) setState(() => _locked = false);
      return;
    }
    if (!_authorizedForForeground) {
      _unlockIfRequired();
    }
  }

  Future<void> _unlockIfRequired() async {
    final settings = ref.read(localSettingsProvider);
    if (!mounted ||
        !settings.hydrated ||
        !settings.biometricLock ||
        _checking) {
      return;
    }
    setState(() {
      _locked = true;
      _checking = true;
    });
    final authenticated = await _biometrics.authenticate();
    if (!mounted) return;
    setState(() {
      _authorizedForForeground = authenticated;
      _locked = !authenticated;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(localSettingsProvider, (_, next) => _applySettings(next));
    final settings = ref.watch(localSettingsProvider);
    if (!settings.hydrated) {
      return _buildLoadingCover(settings.hydrationFailed);
    }
    if (!settings.biometricLock || !_locked) return widget.child;
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.primary,
                  size: 52,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Nexo Finance está bloqueado',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tus datos permanecen ocultos hasta confirmar tu identidad.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _checking ? null : _unlockIfRequired,
                  icon: _checking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fingerprint_rounded),
                  label: const Text('Desbloquear'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingCover(bool failed) => ColoredBox(
    color: AppColors.background,
    child: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.shield_outlined,
                color: AppColors.primary,
                size: 52,
              ),
              const SizedBox(height: 18),
              Text(
                failed
                    ? 'No se pudieron verificar los ajustes seguros'
                    : 'Protegiendo tus datos…',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              if (failed) ...[
                const Text(
                  'El contenido seguirá oculto hasta recuperar el almacenamiento seguro.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(localSettingsProvider.notifier).reload(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ] else
                const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    ),
  );
}
