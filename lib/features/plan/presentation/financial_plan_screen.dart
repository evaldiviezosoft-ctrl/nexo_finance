import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../core/time/lima_time.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../accounts/domain/financial_account.dart';
import '../../budgets/data/budgets_repository.dart';
import '../../budgets/domain/budget.dart';
import '../../budgets/domain/budget_calculator.dart';
import '../../cards/data/card_statements_repository.dart';
import '../../cards/domain/card_calculator.dart';
import '../../cards/domain/card_statement.dart';
import '../../cards/domain/card_statement_date_calculator.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/finance_category.dart';
import '../../debts/presentation/debts_tab.dart';
import '../../goals/presentation/goals_tab.dart';
import '../../recurring/data/recurring_repository.dart';
import '../../recurring/domain/recurring_transaction.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/financial_transaction.dart';

class FinancialPlanScreen extends StatelessWidget {
  const FinancialPlanScreen({this.initialTab = 0, super.key})
    : assert(initialTab >= 0 && initialTab < 5);

  final int initialTab;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    key: ValueKey(initialTab),
    length: 5,
    initialIndex: initialTab,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Plan financiero'),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Límites'),
            Tab(text: 'Tarjetas'),
            Tab(text: 'Metas'),
            Tab(text: 'Deudas'),
            Tab(text: 'Recurrentes'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [
          _BudgetsTab(),
          _CardsTab(),
          GoalsTab(),
          DebtsTab(),
          _RecurringTab(),
        ],
      ),
    ),
  );
}

class _BudgetsTab extends ConsumerWidget {
  const _BudgetsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider);
    final transactions =
        ref.watch(transactionsProvider).value?.items ?? const [];
    final categories = ref.watch(categoriesProvider).value?.items ?? const [];
    return budgets.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (snapshot) {
        final active = snapshot.items.where((item) => item.active).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: [
            _IntroCard(
              icon: Icons.speed_rounded,
              title: 'Presupuesto contra gasto real',
              body: 'Las alertas cambian al 70%, 90% y 100% del límite.',
              action: 'Nuevo límite',
              onPressed: () => _showBudgetForm(context, ref, categories),
            ),
            const SizedBox(height: 12),
            if (active.isEmpty)
              const _EmptyCard('Aún no configuraste ningún límite.')
            else
              ...active.map((budget) {
                final ids = <String>{budget.categoryId ?? ''};
                if (budget.categoryId != null) {
                  ids.addAll(
                    categories
                        .where((item) => item.parentId == budget.categoryId)
                        .map((item) => item.id),
                  );
                }
                final progress = BudgetCalculator.calculate(
                  budget: budget,
                  transactions: transactions,
                  reference: DateTime.now().toUtc(),
                  categoryIds: ids,
                );
                final color = switch (progress.health) {
                  BudgetHealth.normal => AppColors.positive,
                  BudgetHealth.warning => AppColors.warning,
                  BudgetHealth.critical ||
                  BudgetHealth.exceeded => AppColors.primary,
                };
                final category = categories
                    .where((item) => item.id == budget.categoryId)
                    .firstOrNull;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                budget.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showBudgetForm(
                                    context,
                                    ref,
                                    categories,
                                    budget: budget,
                                  );
                                } else {
                                  ref
                                      .read(budgetsRepositoryProvider)
                                      ?.archive(budget);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Editar'),
                                ),
                                PopupMenuItem(
                                  value: 'archive',
                                  child: Text('Archivar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          '${budget.period.label} · ${category?.name ?? 'Global'}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        LinearProgressIndicator(
                          value: progress.ratio.clamp(0, 1),
                          color: color,
                          backgroundColor: AppColors.border,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${Money(progress.spentMinor, budget.currency).format()} de ${Money(progress.limitMinor, budget.currency).format()}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Restante ${Money(progress.remainingMinor, budget.currency).format()} · Proyección ${Money(progress.projectedMinor, budget.currency).format()}',
                          style: TextStyle(color: color, fontSize: 12),
                        ),
                        Text(
                          'Disponible por día ${Money(progress.dailyAvailableMinor, budget.currency).format()}'
                          '${progress.carriedMinor > 0 ? ' · Arrastre ${Money(progress.carriedMinor, budget.currency).format()}' : ''}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _CardsTab extends ConsumerWidget {
  const _CardsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value?.items ?? const [];
    final cards = accounts
        .where((item) => item.active && item.isCreditCard)
        .toList();
    final transactions =
        ref.watch(transactionsProvider).value?.items ?? const [];
    final statements = ref.watch(cardStatementsProvider);
    return statements.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (snapshot) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          _IntroCard(
            icon: Icons.shield_outlined,
            title: 'Dinero comprometido',
            body:
                'La deuda total y el pago del ciclo se controlan por separado.',
            action: 'Nuevo ciclo',
            onPressed: cards.isEmpty
                ? null
                : () => _showStatementForm(context, ref, cards),
          ),
          const SizedBox(height: 12),
          if (cards.isEmpty)
            const _EmptyCard('Primero registra una tarjeta de crédito.'),
          ...cards.map((card) {
            final position = CardCalculator.position(card, transactions);
            final cardStatements = snapshot.items
                .where((item) => item.cardAccountId == card.id)
                .toList();
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.credit_card_rounded,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            card.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${(position.utilization * 100).toStringAsFixed(1)}%',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Deuda total ${Money(position.debtMinor, card.currency).format()}',
                    ),
                    if (position.availableCreditMinor != null)
                      Text(
                        'Crédito disponible ${Money(position.availableCreditMinor!, card.currency).format()}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    Text(
                      'Cierre ${card.closingDay ?? '—'} · Pago ${card.paymentDay ?? '—'}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    if (cardStatements.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Sin ciclos registrados.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    else
                      ...cardStatements.map(
                        (statement) => _StatementTile(
                          statement: statement,
                          onReserve: () =>
                              _showReserveForm(context, ref, statement),
                          onPaid: statement.status == CardStatementStatus.paid
                              ? null
                              : () => ref
                                    .read(cardStatementsRepositoryProvider)
                                    ?.save(
                                      statement.copyWith(
                                        status: CardStatementStatus.paid,
                                        updatedAt: DateTime.now().toUtc(),
                                        version: statement.version + 1,
                                      ),
                                      create: false,
                                    ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StatementTile extends StatelessWidget {
  const _StatementTile({
    required this.statement,
    required this.onReserve,
    required this.onPaid,
  });
  final CardStatement statement;
  final VoidCallback onReserve;
  final VoidCallback? onPaid;

  @override
  Widget build(BuildContext context) {
    final status = switch (statement.status) {
      CardStatementStatus.projected => 'Proyectado',
      CardStatementStatus.open => 'Por pagar',
      CardStatementStatus.paid => 'Pagado',
    };
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Vence ${DateFormat('dd/MM/yyyy').format(toLimaTime(statement.dueDate))}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  color: statement.status == CardStatementStatus.paid
                      ? AppColors.positive
                      : AppColors.warning,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (statement.amountDuePenMinor > 0)
            Text(
              'Pago del ciclo ${Money(statement.amountDuePenMinor, Currency.pen).format()}',
            ),
          if (statement.amountDueUsdMinor > 0)
            Text(
              'Pago del ciclo ${Money(statement.amountDueUsdMinor, Currency.usd).format()}',
            ),
          if (statement.status != CardStatementStatus.paid) ...[
            Text(
              'Sin respaldo ${Money(statement.unbackedPenMinor, Currency.pen).format()}'
              '${statement.amountDueUsdMinor > 0 ? ' · ${Money(statement.unbackedUsdMinor, Currency.usd).format()}' : ''}',
              style: const TextStyle(color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                TextButton(onPressed: onReserve, child: const Text('Reservar')),
                TextButton(
                  onPressed: onPaid,
                  child: const Text('Marcar pagado'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RecurringTab extends ConsumerStatefulWidget {
  const _RecurringTab();

  @override
  ConsumerState<_RecurringTab> createState() => _RecurringTabState();
}

class _RecurringTabState extends ConsumerState<_RecurringTab> {
  final _confirmingIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final recurring = ref.watch(recurringTransactionsProvider);
    final accounts = ref.watch(accountsProvider).value?.items ?? const [];
    final categories = ref.watch(categoriesProvider).value?.items ?? const [];
    return recurring.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (snapshot) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          _IntroCard(
            icon: Icons.event_repeat_rounded,
            title: 'Movimientos recurrentes',
            body:
                'Se crean como pendientes y solo se registran cuando los confirmas.',
            action: 'Nueva recurrencia',
            onPressed: accounts.isEmpty
                ? null
                : () => _showRecurringForm(context, ref, accounts, categories),
          ),
          const SizedBox(height: 12),
          if (snapshot.items.where((item) => item.active).isEmpty)
            const _EmptyCard('Aún no hay movimientos recurrentes.'),
          ...snapshot.items.where((item) => item.active).map((item) {
            final due = !item.nextDueAt.isAfter(DateTime.now().toUtc());
            final confirming = _confirmingIds.contains(item.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: (due ? AppColors.warning : AppColors.info)
                      .withValues(alpha: .14),
                  child: Icon(
                    Icons.event_repeat_rounded,
                    color: due ? AppColors.warning : AppColors.info,
                  ),
                ),
                title: Text(item.name),
                subtitle: Text(
                  '${item.frequency.label} · ${DateFormat('dd/MM/yyyy').format(toLimaTime(item.nextDueAt))}',
                ),
                trailing: FilledButton.tonal(
                  onPressed: due && !confirming
                      ? () => _confirmOccurrence(item)
                      : null,
                  child: confirming
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Registrar'),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _confirmOccurrence(RecurringTransaction item) async {
    final repository = ref.read(recurringRepositoryProvider);
    if (repository == null || _confirmingIds.contains(item.id)) return;
    setState(() => _confirmingIds.add(item.id));
    try {
      await repository.confirmOccurrence(recurring: item);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo registrar: $error')));
      }
    } finally {
      if (mounted) setState(() => _confirmingIds.remove(item.id));
    }
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onPressed,
  });
  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add_rounded),
            label: Text(action),
          ),
        ],
      ),
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    ),
  );
}

Future<void> _showBudgetForm(
  BuildContext context,
  WidgetRef ref,
  List<FinanceCategory> categories, {
  Budget? budget,
}) async {
  final name = TextEditingController(text: budget?.name);
  final amount = TextEditingController(
    text: budget == null ? '' : _minorInput(budget.amountMinor),
  );
  var period = budget?.period ?? BudgetPeriod.monthly;
  var currency = budget?.currency ?? Currency.pen;
  var categoryId = budget?.categoryId;
  var rollover = budget?.rollover ?? false;
  var start = budget?.customStart;
  var end = budget?.customEnd;
  final key = GlobalKey<FormState>();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(budget == null ? 'Nuevo límite' : 'Editar límite'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Ingresa un nombre'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Límite'),
                    validator: _positiveMoneyValidator,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<BudgetPeriod>(
                    initialValue: period,
                    decoration: const InputDecoration(labelText: 'Periodo'),
                    items: BudgetPeriod.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => period = value!),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<Currency>(
                    initialValue: currency,
                    decoration: const InputDecoration(labelText: 'Moneda'),
                    items: Currency.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => currency = value!),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    initialValue: categoryId,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todas (global)'),
                      ),
                      ...categories
                          .where(
                            (item) =>
                                item.type == CategoryType.expense &&
                                item.active,
                          )
                          .map(
                            (item) => DropdownMenuItem<String?>(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          ),
                    ],
                    onChanged: (value) => setState(() => categoryId = value),
                  ),
                  if (period == BudgetPeriod.custom) ...[
                    const SizedBox(height: 8),
                    ListTile(
                      title: const Text('Inicio'),
                      subtitle: Text(
                        start == null
                            ? 'Seleccionar'
                            : DateFormat(
                                'dd/MM/yyyy',
                              ).format(toLimaTime(start!)),
                      ),
                      onTap: () async {
                        final value = await _pickDay(context, start);
                        if (value != null) setState(() => start = value);
                      },
                    ),
                    ListTile(
                      title: const Text('Fin'),
                      subtitle: Text(
                        end == null
                            ? 'Seleccionar'
                            : DateFormat('dd/MM/yyyy').format(toLimaTime(end!)),
                      ),
                      onTap: () async {
                        final value = await _pickDay(context, end);
                        if (value != null) {
                          setState(
                            () => end = value.add(const Duration(days: 1)),
                          );
                        }
                      },
                    ),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: rollover,
                    title: const Text('Transferir saldo no usado'),
                    onChanged: (value) => setState(() => rollover = value),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!key.currentState!.validate()) return;
              if (period == BudgetPeriod.custom &&
                  (start == null || end == null || !end!.isAfter(start!))) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Selecciona un rango válido.')),
                );
                return;
              }
              final repository = ref.read(budgetsRepositoryProvider);
              if (repository == null) return;
              final now = DateTime.now().toUtc();
              final value = Budget(
                id: budget?.id ?? ref.read(uuidProvider).v4(),
                userId: repository.userId,
                name: name.text.trim(),
                period: period,
                amountMinor: Money.parseMinorUnits(amount.text)!,
                currency: currency,
                categoryId: categoryId,
                customStart: period == BudgetPeriod.custom ? start : null,
                customEnd: period == BudgetPeriod.custom ? end : null,
                rollover: rollover,
                active: budget?.active ?? true,
                createdAt: budget?.createdAt ?? now,
                updatedAt: now,
                version: (budget?.version ?? 0) + 1,
              );
              await repository.save(value, create: budget == null);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  amount.dispose();
}

Future<void> _showStatementForm(
  BuildContext context,
  WidgetRef ref,
  List<FinancialAccount> cards,
) async {
  var cardId = cards.first.id;
  final initialDates = CardStatementDateCalculator.defaultsFor(cards.first);
  var cycleStart = initialDates.cycleStart;
  var cycleEnd = initialDates.cycleEnd;
  var dueDate = initialDates.dueDate;
  var status = CardStatementStatus.open;
  final pen = TextEditingController();
  final usd = TextEditingController();
  final key = GlobalKey<FormState>();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Nuevo ciclo de tarjeta'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: cardId,
                    decoration: const InputDecoration(labelText: 'Tarjeta'),
                    items: cards
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      final selectedCard = cards.firstWhere(
                        (card) => card.id == value,
                      );
                      final dates = CardStatementDateCalculator.defaultsFor(
                        selectedCard,
                      );
                      setState(() {
                        cardId = value;
                        cycleStart = dates.cycleStart;
                        cycleEnd = dates.cycleEnd;
                        dueDate = dates.dueDate;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  _DateTile(
                    label: 'Inicio del ciclo',
                    value: cycleStart,
                    onTap: () async {
                      final value = await _pickDay(context, cycleStart);
                      if (value != null) setState(() => cycleStart = value);
                    },
                  ),
                  _DateTile(
                    label: 'Cierre',
                    value: cycleEnd,
                    onTap: () async {
                      final value = await _pickDay(context, cycleEnd);
                      if (value != null) setState(() => cycleEnd = value);
                    },
                  ),
                  _DateTile(
                    label: 'Fecha límite',
                    value: dueDate,
                    onTap: () async {
                      final value = await _pickDay(context, dueDate);
                      if (value != null) setState(() => dueDate = value);
                    },
                  ),
                  TextFormField(
                    controller: pen,
                    decoration: const InputDecoration(
                      labelText: 'Pago del ciclo PEN',
                    ),
                    validator: _optionalMoneyValidator,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: usd,
                    decoration: const InputDecoration(
                      labelText: 'Pago del ciclo USD',
                    ),
                    validator: _optionalMoneyValidator,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<CardStatementStatus>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: const [
                      DropdownMenuItem(
                        value: CardStatementStatus.projected,
                        child: Text('Proyectado'),
                      ),
                      DropdownMenuItem(
                        value: CardStatementStatus.open,
                        child: Text('Por pagar'),
                      ),
                      DropdownMenuItem(
                        value: CardStatementStatus.paid,
                        child: Text('Pagado'),
                      ),
                    ],
                    onChanged: (value) => setState(() => status = value!),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!key.currentState!.validate()) return;
              final repository = ref.read(cardStatementsRepositoryProvider);
              if (repository == null) return;
              final now = DateTime.now().toUtc();
              await repository.save(
                CardStatement(
                  id: ref.read(uuidProvider).v4(),
                  userId: repository.userId,
                  cardAccountId: cardId,
                  cycleStart: cycleStart,
                  cycleEnd: cycleEnd,
                  dueDate: dueDate,
                  amountDuePenMinor: Money.parseMinorUnits(pen.text) ?? 0,
                  amountDueUsdMinor: Money.parseMinorUnits(usd.text) ?? 0,
                  reservedPenMinor: 0,
                  reservedUsdMinor: 0,
                  status: status,
                  createdAt: now,
                  updatedAt: now,
                ),
                create: true,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
  pen.dispose();
  usd.dispose();
}

Future<void> _showReserveForm(
  BuildContext context,
  WidgetRef ref,
  CardStatement statement,
) async {
  final pen = TextEditingController(
    text: _minorInput(statement.reservedPenMinor),
  );
  final usd = TextEditingController(
    text: _minorInput(statement.reservedUsdMinor),
  );
  final key = GlobalKey<FormState>();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Dinero reservado'),
      content: Form(
        key: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: pen,
              decoration: const InputDecoration(labelText: 'Reservado en PEN'),
              validator: _moneyValidator,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: usd,
              decoration: const InputDecoration(labelText: 'Reservado en USD'),
              validator: _moneyValidator,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            if (!key.currentState!.validate()) return;
            await ref
                .read(cardStatementsRepositoryProvider)
                ?.save(
                  statement.copyWith(
                    reservedPenMinor: Money.parseMinorUnits(pen.text),
                    reservedUsdMinor: Money.parseMinorUnits(usd.text),
                    updatedAt: DateTime.now().toUtc(),
                    version: statement.version + 1,
                  ),
                  create: false,
                );
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  pen.dispose();
  usd.dispose();
}

Future<void> _showRecurringForm(
  BuildContext context,
  WidgetRef ref,
  List<FinancialAccount> accounts,
  List<FinanceCategory> categories,
) async {
  final name = TextEditingController();
  final amount = TextEditingController();
  var kind = TransactionKind.expense;
  var frequency = RecurringFrequency.monthly;
  var accountId = accounts.where((item) => !item.isCreditCard).firstOrNull?.id;
  String? categoryId;
  var dueDate = startOfLimaDayUtc(DateTime.now().toUtc());
  final key = GlobalKey<FormState>();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Nueva recurrencia'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Ingresa una descripción'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: amount,
                    decoration: const InputDecoration(labelText: 'Monto'),
                    validator: _positiveMoneyValidator,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<TransactionKind>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(
                        value: TransactionKind.expense,
                        child: Text('Gasto'),
                      ),
                      DropdownMenuItem(
                        value: TransactionKind.income,
                        child: Text('Ingreso'),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      kind = value!;
                      categoryId = null;
                    }),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: accountId,
                    decoration: InputDecoration(
                      labelText: kind == TransactionKind.income
                          ? 'Cuenta de destino'
                          : 'Cuenta de origen',
                    ),
                    items: accounts
                        .where((item) => !item.isCreditCard)
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    validator: (value) =>
                        value == null ? 'Selecciona una cuenta' : null,
                    onChanged: (value) => setState(() => accountId = value),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: categoryId,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: categories
                        .where(
                          (item) =>
                              item.active &&
                              item.type ==
                                  (kind == TransactionKind.income
                                      ? CategoryType.income
                                      : CategoryType.expense),
                        )
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    validator: (value) =>
                        value == null ? 'Selecciona una categoría' : null,
                    onChanged: (value) => setState(() => categoryId = value),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<RecurringFrequency>(
                    initialValue: frequency,
                    decoration: const InputDecoration(labelText: 'Frecuencia'),
                    items: RecurringFrequency.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => frequency = value!),
                  ),
                  _DateTile(
                    label: 'Próxima fecha',
                    value: dueDate,
                    onTap: () async {
                      final value = await _pickDay(context, dueDate);
                      if (value != null) setState(() => dueDate = value);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!key.currentState!.validate() ||
                  accountId == null ||
                  categoryId == null) {
                return;
              }
              final repository = ref.read(recurringRepositoryProvider);
              if (repository == null) return;
              final now = DateTime.now().toUtc();
              final account = accounts.firstWhere(
                (item) => item.id == accountId,
              );
              await repository.create(
                RecurringTransaction(
                  id: ref.read(uuidProvider).v4(),
                  userId: repository.userId,
                  name: name.text.trim(),
                  kind: kind,
                  amountMinor: Money.parseMinorUnits(amount.text)!,
                  currency: account.currency,
                  frequency: frequency,
                  interval: 1,
                  nextDueAt: dueDate,
                  sourceAccountId: kind == TransactionKind.expense
                      ? accountId
                      : null,
                  destinationAccountId: kind == TransactionKind.income
                      ? accountId
                      : null,
                  categoryId: categoryId,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  amount.dispose();
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(DateFormat('dd/MM/yyyy').format(toLimaTime(value))),
    trailing: const Icon(Icons.calendar_today_outlined),
    onTap: onTap,
  );
}

Future<DateTime?> _pickDay(BuildContext context, DateTime? current) async {
  final local = current == null ? DateTime.now() : toLimaTime(current);
  final selected = await showDatePicker(
    context: context,
    initialDate: local,
    firstDate: DateTime(2020),
    lastDate: DateTime(2040),
  );
  return selected == null
      ? null
      : limaMidnightUtc(selected.year, selected.month, selected.day);
}

String? _moneyValidator(String? value) {
  final parsed = Money.parseMinorUnits(value ?? '');
  return parsed == null || parsed < 0 ? 'Ingresa un monto válido' : null;
}

String? _positiveMoneyValidator(String? value) {
  final parsed = Money.parseMinorUnits(value ?? '');
  return parsed == null || parsed <= 0 ? 'Ingresa un monto mayor a cero' : null;
}

String? _optionalMoneyValidator(String? value) =>
    value == null || value.trim().isEmpty ? null : _moneyValidator(value);

String _minorInput(int value) =>
    '${value ~/ 100}.${(value.abs() % 100).toString().padLeft(2, '0')}';
