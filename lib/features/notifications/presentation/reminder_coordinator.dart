import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/data/accounts_repository.dart';
import '../../cards/data/card_statements_repository.dart';
import '../../debts/data/debts_repository.dart';
import '../../goals/data/goals_repository.dart';
import '../../recurring/data/recurring_repository.dart';
import '../../settings/data/local_settings.dart';
import '../data/notification_service.dart';
import '../domain/reminder_planner.dart';

class ReminderCoordinator extends ConsumerStatefulWidget {
  const ReminderCoordinator({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<ReminderCoordinator> createState() =>
      _ReminderCoordinatorState();
}

class _ReminderCoordinatorState extends ConsumerState<ReminderCoordinator> {
  Timer? debounce;
  String? lastSignature;

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(localSettingsProvider);
    final accounts = ref.watch(accountsProvider).value?.items;
    final statements = ref.watch(cardStatementsProvider).value?.items;
    final debts = ref.watch(debtsProvider).value?.items;
    final recurring = ref.watch(recurringTransactionsProvider).value?.items;
    final goals = ref.watch(goalsProvider).value?.items;
    if (settings.notifications &&
        accounts != null &&
        statements != null &&
        debts != null &&
        recurring != null &&
        goals != null) {
      final signature = [
        settings.cardReminders,
        settings.debtReminders,
        settings.recurringReminders,
        settings.goalReminders,
        for (final item in statements) '${item.id}:${item.version}',
        for (final item in debts) '${item.id}:${item.version}',
        for (final item in recurring) '${item.id}:${item.version}',
        for (final item in goals) '${item.id}:${item.version}',
      ].join('|');
      if (signature != lastSignature) {
        lastSignature = signature;
        debounce?.cancel();
        debounce = Timer(const Duration(seconds: 1), () {
          final reminders = ReminderPlanner.plan(
            now: DateTime.now().toUtc(),
            accounts: accounts,
            statements: statements,
            debts: debts,
            recurring: recurring,
            goals: goals,
            cardReminders: settings.cardReminders,
            debtReminders: settings.debtReminders,
            recurringReminders: settings.recurringReminders,
            goalReminders: settings.goalReminders,
          );
          NotificationService.instance.replaceAll(reminders);
        });
      }
    }
    return widget.child;
  }
}
