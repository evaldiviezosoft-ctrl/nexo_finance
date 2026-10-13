import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../auth/data/auth_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Ajustes')),
    body: ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        const ListTile(
          leading: CircleAvatar(child: Icon(Icons.person_outline_rounded)),
          title: Text('Perfil financiero'),
          subtitle: Text('Perú · PEN · Español'),
        ),
        const Divider(color: AppColors.border),
        _SettingsTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Cuentas',
          subtitle: 'Saldos iniciales y tarjetas',
          onTap: () => context.push('/accounts'),
        ),
        _SettingsTile(
          icon: Icons.category_outlined,
          title: 'Categorías',
          subtitle: 'Gastos, ingresos y subcategorías',
          onTap: () => context.push('/categories'),
        ),
        _SettingsTile(
          icon: Icons.speed_rounded,
          title: 'Plan financiero',
          subtitle: 'Límites, tarjetas y recurrencias',
          onTap: () => context.go('/plan'),
        ),
        _SettingsTile(
          icon: Icons.palette_outlined,
          title: 'Apariencia',
          subtitle: 'Tema AMOLED',
          onTap: () => context.push('/appearance'),
        ),
        _SettingsTile(
          icon: Icons.fingerprint_rounded,
          title: 'Seguridad',
          subtitle: 'Bloqueo biométrico y privacidad',
          onTap: () => context.push('/security'),
        ),
        _SettingsTile(
          icon: Icons.notifications_none_rounded,
          title: 'Notificaciones',
          subtitle: 'Recordatorios y alertas',
          onTap: () => context.push('/notifications'),
        ),
        _SettingsTile(
          icon: Icons.cloud_done_outlined,
          title: 'Sincronización',
          subtitle: 'Datos sincronizados',
          onTap: () => context.push('/sync'),
        ),
        _SettingsTile(
          icon: Icons.file_download_outlined,
          title: 'Datos y exportación',
          subtitle: 'CSV, PDF y copia JSON',
          onTap: () => context.push('/data'),
        ),
        const Divider(color: AppColors.border),
        ListTile(
          leading: const Icon(Icons.logout_rounded),
          title: const Text('Cerrar sesión'),
          onTap: () => ref.read(authActionsProvider).signOut(),
        ),
      ],
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}
