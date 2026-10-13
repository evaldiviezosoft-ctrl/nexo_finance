import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../core/time/lima_time.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../accounts/domain/financial_account.dart';
import '../../budgets/data/budgets_repository.dart';
import '../../budgets/domain/budget_calculator.dart';
import '../../cards/data/card_statements_repository.dart';
import '../../cards/domain/card_calculator.dart';
import '../../cards/domain/card_statement.dart';
import '../../debts/data/debts_repository.dart';
import '../../debts/domain/debt_calculator.dart';
import '../../debts/domain/debt_record.dart';
import '../../goals/data/goals_repository.dart';
import '../../goals/domain/goal_calculator.dart';
import '../../recurring/data/recurring_repository.dart';
import '../../settings/data/local_settings.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../transactions/domain/ledger_calculator.dart';

enum DashboardPeriod { week, month, threeMonths, year, custom }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool? _hideAmounts;
  bool _settingsHideBalances = false;
  DashboardPeriod _period = DashboardPeriod.month;
  DateTimeRange? _customRange;

  bool get _amountsHidden => _hideAmounts ?? _settingsHideBalances;

  String _amount(int value, [Currency currency = Currency.pen]) =>
      _amountsHidden
      ? '${currency == Currency.pen ? 'S/' : r'US$'} ••••••'
      : Money(value, currency).format();

  @override
  Widget build(BuildContext context) {
    _settingsHideBalances = ref.watch(localSettingsProvider).hideBalances;
    final accountState = ref.watch(accountsProvider);
    final transactionState = ref.watch(transactionsProvider);
    final budgets = ref.watch(budgetsProvider).value?.items ?? const [];
    final statements =
        ref.watch(cardStatementsProvider).value?.items ??
        const <CardStatement>[];
    final recurring =
        ref.watch(recurringTransactionsProvider).value?.items ?? const [];
    final debts = ref.watch(debtsProvider).value?.items ?? const <DebtRecord>[];
    final goals = ref.watch(goalsProvider).value?.items ?? const [];
    final accounts = accountState.value?.items ?? const [];
    final transactions =
        transactionState.value?.items ?? const <FinancialTransaction>[];
    final balances = LedgerCalculator.balances(
      accounts: accounts,
      transactions: transactions,
    );
    final now = DateTime.now().toUtc();
    final (
      start,
      end,
    ) = _period == DashboardPeriod.custom && _customRange != null
        ? (
            limaMidnightUtc(
              _customRange!.start.year,
              _customRange!.start.month,
              _customRange!.start.day,
            ),
            limaMidnightUtc(
              _customRange!.end.year,
              _customRange!.end.month,
              _customRange!.end.day + 1,
            ),
          )
        : _range(now, _period);
    final income = LedgerCalculator.incomeForPeriod(
      transactions,
      start,
      end,
      currency: Currency.pen,
    );
    final expense = LedgerCalculator.expenseForPeriod(
      transactions,
      start,
      end,
      currency: Currency.pen,
    );
    var liquid = 0;
    var invested = 0;
    var debt = 0;
    var liquidUsd = 0;
    for (final account in accounts.where(
      (item) => item.currency == Currency.pen && item.active,
    )) {
      final balance = balances[account.id] ?? account.initialBalanceMinor;
      if (account.isCreditCard) {
        debt += balance;
      } else if (account.type == AccountType.crypto) {
        invested += balance;
      } else {
        liquid += balance;
      }
    }
    for (final account in accounts.where(
      (item) =>
          item.currency == Currency.usd && item.active && !item.isCreditCard,
    )) {
      liquidUsd += balances[account.id] ?? account.initialBalanceMinor;
    }
    final reservedPen = CardCalculator.reservedPen(statements);
    final reservedUsd = CardCalculator.reservedUsd(statements);
    final budgetRemaining = budgets
        .where((item) => item.active && item.currency == Currency.pen)
        .fold<int>(0, (total, budget) {
          final progress = BudgetCalculator.calculate(
            budget: budget,
            transactions: transactions,
            reference: now,
          );
          return total + progress.remainingMinor.clamp(0, budget.amountMinor);
        });
    final upcomingStatements =
        statements
            .where((item) => item.status != CardStatementStatus.paid)
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final upcomingRecurring = recurring.where((item) => item.active).toList()
      ..sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));
    final accountsById = {for (final account in accounts) account.id: account};
    final pending =
        (accountState.value?.hasPendingWrites ?? false) ||
        (transactionState.value?.hasPendingWrites ?? false);
    var personalDebt = 0;
    var receivable = 0;
    for (final item in debts.where(
      (item) =>
          item.status == DebtStatus.active && item.currency == Currency.pen,
    )) {
      final remaining = DebtCalculator.position(
        item,
        transactions,
      ).remainingMinor;
      item.direction == DebtDirection.owed
          ? personalDebt += remaining
          : receivable += remaining;
    }
    final activeGoals = goals
        .where((item) => item.active && item.currency == Currency.pen)
        .toList();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              Text(
                'Tu panorama financiero',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: _amountsHidden ? 'Mostrar montos' : 'Ocultar montos',
              onPressed: () => setState(() => _hideAmounts = !_amountsHidden),
              icon: Icon(
                _amountsHidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          sliver: SliverList.list(
            children: [
              SegmentedButton<DashboardPeriod>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: DashboardPeriod.week,
                    label: Text('Sem'),
                  ),
                  ButtonSegment(
                    value: DashboardPeriod.month,
                    label: Text('Mes'),
                  ),
                  ButtonSegment(
                    value: DashboardPeriod.threeMonths,
                    label: Text('3 m'),
                  ),
                  ButtonSegment(
                    value: DashboardPeriod.year,
                    label: Text('Año'),
                  ),
                  ButtonSegment(
                    value: DashboardPeriod.custom,
                    icon: Icon(Icons.date_range_outlined),
                    tooltip: 'Periodo personalizado',
                  ),
                ],
                selected: {_period},
                onSelectionChanged: (value) => _selectPeriod(value.first),
              ),
              if (_period == DashboardPeriod.custom && _customRange != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${_customRange!.start.day.toString().padLeft(2, '0')}/'
                    '${_customRange!.start.month.toString().padLeft(2, '0')}/'
                    '${_customRange!.start.year} – '
                    '${_customRange!.end.day.toString().padLeft(2, '0')}/'
                    '${_customRange!.end.month.toString().padLeft(2, '0')}/'
                    '${_customRange!.end.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22FF1744), blurRadius: 24),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'SALDO DISPONIBLE',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const Spacer(),
                        _StatusPill(pending: pending),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _amount(liquid - reservedPen),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Líquido ${_amount(liquid)} · Invertido ${_amount(invested)}\n'
                      'Patrimonio ${_amount(liquid + invested - debt)} · USD ${_amount(liquidUsd - reservedUsd, Currency.usd)}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Ingresos',
                      value: _amount(income),
                      color: AppColors.positive,
                      icon: Icons.south_west_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricCard(
                      label: 'Gastado',
                      value: _amount(expense),
                      color: AppColors.primary,
                      icon: Icons.north_east_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Otras deudas',
                      value: _amount(personalDebt),
                      color: AppColors.warning,
                      icon: Icons.account_balance_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricCard(
                      label: 'Por cobrar',
                      value: _amount(receivable),
                      color: AppColors.info,
                      icon: Icons.handshake_outlined,
                    ),
                  ),
                ],
              ),
              if (activeGoals.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Metas principales',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...activeGoals.take(2).map((goal) {
                  final progress = GoalCalculator.calculate(goal, transactions);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(goal.name)),
                              Text(
                                '${(progress.progress * 100).toStringAsFixed(0)}%',
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          LinearProgressIndicator(
                            value: progress.progress.clamp(0, 1),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Deuda tarjetas',
                      value: _amount(debt),
                      color: AppColors.warning,
                      icon: Icons.credit_card_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricCard(
                      label: 'Ahorro neto',
                      value: _amount(income - expense),
                      color: AppColors.info,
                      icon: Icons.savings_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Presupuesto disponible',
                      value: _amount(budgetRemaining),
                      color: AppColors.positive,
                      icon: Icons.speed_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricCard(
                      label: 'Reservado tarjetas',
                      value: _amount(reservedPen),
                      color: AppColors.info,
                      icon: Icons.shield_outlined,
                    ),
                  ),
                ],
              ),
              if (upcomingStatements.isNotEmpty ||
                  upcomingRecurring.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Próximos pagos',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                ...upcomingStatements
                    .take(2)
                    .map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.credit_card_rounded),
                        ),
                        title: Text(
                          '${accountsById[item.cardAccountId]?.name ?? 'Tarjeta'} · '
                          '${_amount(item.amountDuePenMinor)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Vence ${item.dueDate.day.toString().padLeft(2, '0')}/${item.dueDate.month.toString().padLeft(2, '0')}/${item.dueDate.year}',
                        ),
                      ),
                    ),
                ...upcomingRecurring
                    .take(2)
                    .map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.event_repeat_rounded),
                        ),
                        title: Text(item.name),
                        subtitle: Text(
                          'Pendiente · ${_amount(item.amountMinor, item.currency)}',
                        ),
                      ),
                    ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'Últimos movimientos',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go('/transactions'),
                    child: const Text('Ver todos'),
                  ),
                ],
              ),
              if (transactions.isEmpty)
                Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: accounts.isEmpty
                        ? () => context.push('/accounts')
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            color: AppColors.textSecondary,
                            size: 38,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            accounts.isEmpty
                                ? 'Crea tu primera cuenta'
                                : 'Aún no hay movimientos',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            accounts.isEmpty
                                ? 'Agrega tu saldo inicial sin registrarlo como ingreso.'
                                : 'Usa el botón + para registrar el primero.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...transactions
                    .take(5)
                    .map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.swap_horiz_rounded),
                        ),
                        title: Text(
                          item.description.isEmpty
                              ? item.kind.label
                              : item.description,
                        ),
                        subtitle: Text(item.kind.label),
                        trailing: Text(
                          _amount(item.amountMinor, item.currency),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _selectPeriod(DashboardPeriod period) async {
    if (period != DashboardPeriod.custom) {
      setState(() => _period = period);
      return;
    }
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange:
          _customRange ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );
    if (picked != null && mounted) {
      setState(() {
        _customRange = picked;
        _period = DashboardPeriod.custom;
      });
    }
  }
}

(DateTime, DateTime) _range(DateTime now, DashboardPeriod period) =>
    switch (period) {
      DashboardPeriod.week => (
        startOfLimaDayUtc(
          now,
        ).subtract(Duration(days: toLimaTime(now).weekday - 1)),
        startOfLimaDayUtc(now).add(Duration(days: 8 - toLimaTime(now).weekday)),
      ),
      DashboardPeriod.month => (
        startOfLimaMonthUtc(now),
        limaMidnightUtc(toLimaTime(now).year, toLimaTime(now).month + 1, 1),
      ),
      DashboardPeriod.threeMonths => (
        limaMidnightUtc(toLimaTime(now).year, toLimaTime(now).month - 2, 1),
        limaMidnightUtc(toLimaTime(now).year, toLimaTime(now).month + 1, 1),
      ),
      DashboardPeriod.year => (
        startOfLimaYearUtc(now),
        limaMidnightUtc(toLimaTime(now).year + 1, 1, 1),
      ),
      DashboardPeriod.custom => (
        startOfLimaMonthUtc(now),
        limaMidnightUtc(toLimaTime(now).year, toLimaTime(now).month + 1, 1),
      ),
    };

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.pending});
  final bool pending;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Color(pending ? 0x22FFB020 : 0x222EE6A6),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Icon(
          pending ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined,
          size: 14,
          color: pending ? AppColors.warning : AppColors.positive,
        ),
        const SizedBox(width: 5),
        Text(
          pending ? 'Pendiente' : 'Sincronizado',
          style: TextStyle(
            color: pending ? AppColors.warning : AppColors.positive,
            fontSize: 11,
          ),
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ],
      ),
    ),
  );
}
