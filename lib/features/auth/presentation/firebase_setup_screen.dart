import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/firebase_bootstrap.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';

class FirebaseSetupScreen extends ConsumerWidget {
  const FirebaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(firebaseBootstrapProvider);
    final failed = result.status == FirebaseBootstrapStatus.failed;
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración inicial')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      failed ? Icons.error_outline : Icons.cloud_off_rounded,
                      color: failed ? AppColors.primary : AppColors.warning,
                      size: 40,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      failed
                          ? 'Firebase no pudo iniciar'
                          : 'Conecta tu proyecto Firebase',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      failed
                          ? 'Revisa la configuración y vuelve a ejecutar la app.'
                          : 'No se agregaron credenciales ficticias. Completa estos pasos para habilitar autenticación y sincronización:',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _SetupStep(
                      number: '1',
                      text: 'Crea o selecciona un proyecto en Firebase.',
                    ),
                    const _SetupStep(
                      number: '2',
                      text: 'Ejecuta: flutterfire configure',
                    ),
                    const _SetupStep(
                      number: '3',
                      text:
                          'Habilita Email/Password y Google en Authentication.',
                    ),
                    const _SetupStep(
                      number: '4',
                      text:
                          'Crea Firestore y registra App Check para cada plataforma.',
                    ),
                    if (result.error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Detalle técnico'),
                        children: [
                          SelectableText(
                            result.error.toString(),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0x33FF1744),
            foregroundColor: AppColors.primary,
            child: Text(number),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
