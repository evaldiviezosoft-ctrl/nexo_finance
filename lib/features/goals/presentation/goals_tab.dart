import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/icons/material_icon_registry.dart';
import '../../../core/money/money.dart';
import '../../../core/time/lima_time.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../accounts/domain/financial_account.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../data/goals_repository.dart';
import '../domain/financial_goal.dart';
import '../domain/goal_calculator.dart';

class GoalsTab extends ConsumerWidget {
  const GoalsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final transactions =
        ref.watch(transactionsProvider).value?.items ??
        const <FinancialTransaction>[];
    final accounts =
        ref.watch(accountsProvider).value?.items ?? const <FinancialAccount>[];
    return goals.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('No se pudieron cargar las metas: $error')),
      data: (synced) {
        final items = synced.items.where((item) => item.active).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Objetivos de ahorro',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showGoalForm(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const _EmptyGoals()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final goal = items[index];
                        final progress = GoalCalculator.calculate(
                          goal,
                          transactions,
                        );
                        return _GoalCard(
                          goal: goal,
                          progress: progress,
                          account: accounts
                              .where((a) => a.id == goal.accountId)
                              .firstOrNull,
                          onEdit: () => _showGoalForm(context, ref, goal: goal),
                          onContribute: () => _showGoalMovement(
                            context,
                            ref,
                            goal,
                            accounts,
                            progress,
                          ),
                          onArchive: () =>
                              ref.read(goalsRepositoryProvider)?.archive(goal),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.progress,
    required this.account,
    required this.onEdit,
    required this.onContribute,
    required this.onArchive,
  });
  final FinancialGoal goal;
  final GoalProgress progress;
  final FinancialAccount? account;
  final VoidCallback onEdit;
  final VoidCallback onContribute;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final color = Color(goal.colorValue);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: .16),
                  child: Icon(
                    materialIconForCodePoint(
                      goal.iconCodePoint,
                      fallback: Icons.chat,
                    ),
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${goal.priority.label} · ${account?.name ?? 'Sin cuenta asociada'}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) =>
                      value == 'edit' ? onEdit() : onArchive(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'archive', child: Text('Archivar')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress.progress.clamp(0, 1),
              minHeight: 9,
              borderRadius: BorderRadius.circular(10),
              backgroundColor: AppColors.border,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              '${Money(progress.accumulatedMinor, goal.currency).format()} de ${Money(goal.targetMinor, goal.currency).format()}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Falta ${Money(progress.remainingMinor, goal.currency).format()} · ${(progress.progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (goal.deadline != null)
              Text(
                'Aporte recomendado: ${Money(progress.recommendedMonthlyMinor, goal.currency).format()}/mes · Meta ${DateFormat('dd/MM/yyyy').format(toLimaTime(goal.deadline!))}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            if (progress.averageMonthlyMinor > 0)
              Text(
                'Ritmo real: ${Money(progress.averageMonthlyMinor, goal.currency).format()}/mes${progress.estimatedCompletion == null ? '' : ' · Estimada ${DateFormat('MM/yyyy').format(toLimaTime(progress.estimatedCompletion!))}'}',
                style: TextStyle(
                  color: progress.paceDifferenceMinor >= 0
                      ? AppColors.positive
                      : AppColors.warning,
                ),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onContribute,
                icon: const Icon(Icons.savings_outlined),
                label: const Text('Registrar aporte'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_outlined, size: 52, color: AppColors.primary),
          SizedBox(height: 12),
          Text(
            'Aún no tienes metas',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'Crea una meta y registra aportes como transferencias, sin inflar tus gastos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showGoalForm(
  BuildContext context,
  WidgetRef ref, {
  FinancialGoal? goal,
}) async {
  final accounts =
      ref
          .read(accountsProvider)
          .value
          ?.items
          .where((a) => a.active && !a.isCreditCard)
          .toList() ??
      <FinancialAccount>[];
  await showDialog<void>(
    context: context,
    builder: (_) => _GoalFormDialog(goal: goal, accounts: accounts),
  );
}

class _GoalFormDialog extends ConsumerStatefulWidget {
  const _GoalFormDialog({required this.goal, required this.accounts});
  final FinancialGoal? goal;
  final List<FinancialAccount> accounts;
  @override
  ConsumerState<_GoalFormDialog> createState() => _GoalFormDialogState();
}

class _GoalFormDialogState extends ConsumerState<_GoalFormDialog> {
  final key = GlobalKey<FormState>();
  late final TextEditingController name, target, opening, automatic, notes;
  late Currency currency;
  late GoalPriority priority;
  String? accountId;
  DateTime? deadline;
  bool withdrawals = false, saving = false;

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    name = TextEditingController(text: g?.name);
    target = TextEditingController(
      text: g == null ? '' : _input(g.targetMinor),
    );
    opening = TextEditingController(
      text: g == null ? '' : _input(g.openingAmountMinor),
    );
    automatic = TextEditingController(
      text: g?.automaticContributionMinor == null
          ? ''
          : _input(g!.automaticContributionMinor!),
    );
    notes = TextEditingController(text: g?.notes);
    currency = g?.currency ?? Currency.pen;
    priority = g?.priority ?? GoalPriority.medium;
    accountId = g?.accountId;
    deadline = g?.deadline;
    withdrawals = g?.allowWithdrawals ?? false;
  }

  @override
  void dispose() {
    for (final c in [name, target, opening, automatic, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.goal == null ? 'Nueva meta' : 'Editar meta'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: key,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Escribe un nombre' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: target,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Objetivo'),
                      validator: _positive,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<Currency>(
                      initialValue: currency,
                      decoration: const InputDecoration(labelText: 'Moneda'),
                      items: Currency.values
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.name.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() {
                        currency = v!;
                        accountId = null;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: opening,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Ya acumulado',
                  helperText: 'Saldo reservado antes de usar la app',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue:
                    widget.accounts.any(
                      (a) => a.id == accountId && a.currency == currency,
                    )
                    ? accountId
                    : null,
                decoration: const InputDecoration(labelText: 'Cuenta asociada'),
                items: widget.accounts
                    .where((a) => a.currency == currency)
                    .map(
                      (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => accountId = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<GoalPriority>(
                initialValue: priority,
                decoration: const InputDecoration(labelText: 'Prioridad'),
                items: GoalPriority.values
                    .map(
                      (p) => DropdownMenuItem(value: p, child: Text(p.label)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => priority = v!),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: const Text('Fecha objetivo'),
                subtitle: Text(
                  deadline == null
                      ? 'Sin fecha'
                      : DateFormat('dd/MM/yyyy').format(toLimaTime(deadline!)),
                ),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                    initialDate:
                        (deadline == null ? null : toLimaTime(deadline!)) ??
                        DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(
                      () => deadline = limaMidnightUtc(
                        picked.year,
                        picked.month,
                        picked.day,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: automatic,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Aporte mensual planeado (opcional)',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Permitir retiros'),
                value: withdrawals,
                onChanged: (v) => setState(() => withdrawals = v),
              ),
              TextFormField(
                controller: notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notas'),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: saving ? null : _save,
        child: Text(saving ? 'Guardando…' : 'Guardar'),
      ),
    ],
  );

  Future<void> _save() async {
    if (!key.currentState!.validate()) return;
    final repo = ref.read(goalsRepositoryProvider);
    if (repo == null) return;
    setState(() => saving = true);
    final old = widget.goal, now = DateTime.now().toUtc();
    final value = FinancialGoal(
      id: old?.id ?? ref.read(uuidProvider).v4(),
      userId: repo.userId,
      name: name.text.trim(),
      targetMinor: Money.parseMinorUnits(target.text)!,
      openingAmountMinor: Money.parseMinorUnits(opening.text) ?? 0,
      currency: currency,
      deadline: deadline,
      priority: priority,
      accountId: accountId,
      automaticContributionMinor: Money.parseMinorUnits(automatic.text),
      allowWithdrawals: withdrawals,
      notes: notes.text.trim(),
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
      version: (old?.version ?? 0) + 1,
    );
    try {
      await repo.save(value, create: old == null);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    }
  }
}

Future<void> _showGoalMovement(
  BuildContext context,
  WidgetRef ref,
  FinancialGoal goal,
  List<FinancialAccount> accounts,
  GoalProgress progress,
) async {
  final linked = accounts.where((a) => a.id == goal.accountId).firstOrNull;
  if (linked == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edita la meta y asocia una cuenta antes de aportar.'),
      ),
    );
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => _GoalMovementDialog(
      goal: goal,
      accounts: accounts
          .where(
            (a) => a.active && !a.isCreditCard && a.currency == goal.currency,
          )
          .toList(),
      remainingMinor: progress.accumulatedMinor,
    ),
  );
}

class _GoalMovementDialog extends ConsumerStatefulWidget {
  const _GoalMovementDialog({
    required this.goal,
    required this.accounts,
    required this.remainingMinor,
  });
  final FinancialGoal goal;
  final List<FinancialAccount> accounts;
  final int remainingMinor;
  @override
  ConsumerState<_GoalMovementDialog> createState() =>
      _GoalMovementDialogState();
}

class _GoalMovementDialogState extends ConsumerState<_GoalMovementDialog> {
  final key = GlobalKey<FormState>();
  final amount = TextEditingController();
  String? accountId;
  bool withdrawal = false, saving = false;
  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(withdrawal ? 'Retirar de la meta' : 'Aportar a la meta'),
    content: Form(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.goal.allowWithdrawals)
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Aporte')),
                ButtonSegment(value: true, label: Text('Retiro')),
              ],
              selected: {withdrawal},
              onSelectionChanged: (v) => setState(() {
                withdrawal = v.first;
                accountId = null;
              }),
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto',
              prefixText: widget.goal.currency == Currency.pen
                  ? 'S/ '
                  : r'US$ ',
            ),
            validator: (v) {
              final n = Money.parseMinorUnits(v ?? '');
              if (n == null || n <= 0) {
                return 'Ingresa un monto válido';
              }
              if (withdrawal && n > widget.remainingMinor) {
                return 'Supera lo acumulado';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: accountId,
            decoration: InputDecoration(
              labelText: withdrawal ? 'Cuenta que recibe' : 'Cuenta de origen',
            ),
            items: widget.accounts
                .where((a) => a.id != widget.goal.accountId)
                .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                .toList(),
            onChanged: (v) => setState(() => accountId = v),
            validator: (v) => v == null ? 'Selecciona una cuenta' : null,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: saving ? null : _save,
        child: Text(saving ? 'Guardando…' : 'Guardar'),
      ),
    ],
  );
  Future<void> _save() async {
    if (!key.currentState!.validate()) return;
    final repo = ref.read(transactionsRepositoryProvider);
    if (repo == null) return;
    setState(() => saving = true);
    final now = DateTime.now().toUtc();
    final value = FinancialTransaction(
      id: ref.read(uuidProvider).v4(),
      userId: repo.userId,
      kind: withdrawal
          ? TransactionKind.goalWithdrawal
          : TransactionKind.goalContribution,
      amountMinor: Money.parseMinorUnits(amount.text)!,
      currency: widget.goal.currency,
      sourceAccountId: withdrawal ? widget.goal.accountId : accountId,
      destinationAccountId: withdrawal ? accountId : widget.goal.accountId,
      goalId: widget.goal.id,
      description: '${withdrawal ? 'Retiro' : 'Aporte'} · ${widget.goal.name}',
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await repo.create(value);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo registrar: $e')));
      }
    }
  }
}

String? _positive(String? value) {
  final n = Money.parseMinorUnits(value ?? '');
  return n == null || n <= 0 ? 'Ingresa un monto válido' : null;
}

String _input(int minor) =>
    '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';
