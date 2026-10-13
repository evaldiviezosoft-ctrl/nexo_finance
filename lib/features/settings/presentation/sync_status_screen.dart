import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/data/accounts_repository.dart';
import '../../budgets/data/budgets_repository.dart';
import '../../cards/data/card_statements_repository.dart';
import '../../categories/data/categories_repository.dart';
import '../../debts/data/debts_repository.dart';
import '../../goals/data/goals_repository.dart';
import '../../recurring/data/recurring_repository.dart';
import '../../transactions/data/transactions_repository.dart';

class SyncStatusScreen extends ConsumerStatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  ConsumerState<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends ConsumerState<SyncStatusScreen> {
  StreamSubscription<List<ConnectivityResult>>? subscription;
  List<ConnectivityResult> connectivity = const [];

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then((value) {
      if (mounted) setState(() => connectivity = value);
    });
    subscription = Connectivity().onConnectivityChanged.listen((value) {
      if (mounted) setState(() => connectivity = value);
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final states = [
      ref.watch(accountsProvider),
      ref.watch(categoriesProvider),
      ref.watch(transactionsProvider),
      ref.watch(budgetsProvider),
      ref.watch(cardStatementsProvider),
      ref.watch(recurringTransactionsProvider),
      ref.watch(goalsProvider),
      ref.watch(debtsProvider),
    ];
    final loading = states.any((item) => item.isLoading);
    final error = states.any((item) => item.hasError);
    final pending = states.any((item) => item.value?.hasPendingWrites ?? false);
    final offline = connectivity.contains(ConnectivityResult.none);
    final (icon, title, subtitle, color) = error
        ? (
            Icons.cloud_off_outlined,
            'Error de sincronización',
            'Revisa la conexión y vuelve a intentar.',
            Colors.redAccent,
          )
        : offline
        ? (
            Icons.offline_bolt_outlined,
            'Modo sin conexión',
            'Puedes seguir trabajando; Firebase sincronizará después.',
            Colors.orangeAccent,
          )
        : pending || loading
        ? (
            Icons.cloud_upload_outlined,
            'Sincronización pendiente',
            'Los cambios se están enviando de forma segura.',
            Colors.orangeAccent,
          )
        : (
            Icons.cloud_done_outlined,
            'Todo sincronizado',
            'No hay cambios locales pendientes.',
            Colors.greenAccent,
          );
    return Scaffold(
      appBar: AppBar(title: const Text('Sincronización')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 58),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Volver a comprobar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _refresh() {
    ref
      ..invalidate(accountsProvider)
      ..invalidate(categoriesProvider)
      ..invalidate(transactionsProvider)
      ..invalidate(budgetsProvider)
      ..invalidate(cardStatementsProvider)
      ..invalidate(recurringTransactionsProvider)
      ..invalidate(goalsProvider)
      ..invalidate(debtsProvider);
  }
}
