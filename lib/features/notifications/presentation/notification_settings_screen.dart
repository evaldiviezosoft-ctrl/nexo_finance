import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/data/accounts_repository.dart';
import '../../cards/data/card_statements_repository.dart';
import '../../debts/data/debts_repository.dart';
import '../../goals/data/goals_repository.dart';
import '../../recurring/data/recurring_repository.dart';
import '../../settings/data/local_settings.dart';
import '../data/notification_service.dart';
import '../domain/reminder_planner.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool working = false;
  int? pending;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.pendingCount().then((value) {
      if (mounted) setState(() => pending = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(localSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Activar recordatorios'),
            subtitle: Text(
              pending == null
                  ? 'Recordatorios locales, sin enviar datos.'
                  : '$pending recordatorio(s) programado(s).',
            ),
            value: settings.notifications,
            onChanged: working ? null : _toggleMaster,
          ),
          const Divider(),
          _toggle(
            'Pagos de tarjetas',
            'Aviso dos días antes del vencimiento.',
            settings.cardReminders,
            (current, value) => current.copyWith(cardReminders: value),
          ),
          _toggle(
            'Cuotas y cobros',
            'Aviso un día antes de la fecha registrada.',
            settings.debtReminders,
            (current, value) => current.copyWith(debtReminders: value),
          ),
          _toggle(
            'Movimientos recurrentes',
            'Solo recuerda revisar; nunca registra el gasto automáticamente.',
            settings.recurringReminders,
            (current, value) => current.copyWith(recurringReminders: value),
          ),
          _toggle(
            'Metas financieras',
            'Aviso previo a la fecha objetivo.',
            settings.goalReminders,
            (current, value) => current.copyWith(goalReminders: value),
          ),
          _toggle(
            'Alertas de presupuesto',
            'Mantiene activos los avisos del 70%, 90% y 100% dentro de la app.',
            settings.budgetAlerts,
            (current, value) => current.copyWith(budgetAlerts: value),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: !settings.notifications || working
                  ? null
                  : () => _reschedule(settings),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Actualizar recordatorios'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggle(
    String title,
    String subtitle,
    bool value,
    LocalSettings Function(LocalSettings current, bool value) change,
  ) => SwitchListTile(
    title: Text(title),
    subtitle: Text(subtitle),
    value: value,
    onChanged: working
        ? null
        : (enabled) async {
            await ref
                .read(localSettingsProvider.notifier)
                .update((current) => change(current, enabled));
            final next = ref.read(localSettingsProvider);
            if (next.notifications) await _reschedule(next);
          },
  );

  Future<void> _toggleMaster(bool enabled) async {
    if (!enabled) {
      setState(() => working = true);
      await NotificationService.instance.cancelAll();
      await ref
          .read(localSettingsProvider.notifier)
          .update((current) => current.copyWith(notifications: false));
      if (mounted) {
        setState(() {
          working = false;
          pending = 0;
        });
      }
      return;
    }
    final allowed = await NotificationService.instance.requestPermission();
    if (!mounted) return;
    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Android no concedió el permiso.')),
      );
      return;
    }
    await ref
        .read(localSettingsProvider.notifier)
        .update((current) => current.copyWith(notifications: true));
    final next = ref.read(localSettingsProvider);
    await _reschedule(next);
  }

  Future<void> _reschedule(LocalSettings settings) async {
    setState(() => working = true);
    try {
      final reminders = ReminderPlanner.plan(
        now: DateTime.now().toUtc(),
        accounts: ref.read(accountsProvider).value?.items ?? const [],
        statements: ref.read(cardStatementsProvider).value?.items ?? const [],
        debts: ref.read(debtsProvider).value?.items ?? const [],
        recurring:
            ref.read(recurringTransactionsProvider).value?.items ?? const [],
        goals: ref.read(goalsProvider).value?.items ?? const [],
        cardReminders: settings.cardReminders,
        debtReminders: settings.debtReminders,
        recurringReminders: settings.recurringReminders,
        goalReminders: settings.goalReminders,
      );
      await NotificationService.instance.replaceAll(reminders);
      if (mounted) setState(() => pending = reminders.length);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }
}
