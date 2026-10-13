import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../core/time/lima_time.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../accounts/domain/financial_account.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../data/debts_repository.dart';
import '../domain/debt_calculator.dart';
import '../domain/debt_record.dart';

class DebtsTab extends ConsumerStatefulWidget {
  const DebtsTab({super.key});
  @override
  ConsumerState<DebtsTab> createState() => _DebtsTabState();
}

class _DebtsTabState extends ConsumerState<DebtsTab> {
  DebtDirection? filter;
  @override
  Widget build(BuildContext context) {
    final debts = ref.watch(debtsProvider);
    final txs =
        ref.watch(transactionsProvider).value?.items ??
        const <FinancialTransaction>[];
    final accounts =
        ref.watch(accountsProvider).value?.items ?? const <FinancialAccount>[];
    return debts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text('No se pudieron cargar las deudas: $e')),
      data: (synced) {
        final items = synced.items
            .where(
              (d) =>
                  d.status == DebtStatus.active &&
                  (filter == null || d.direction == filter),
            )
            .toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Obligaciones y cobros',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showDebtForm(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SegmentedButton<DebtDirection?>(
                segments: const [
                  ButtonSegment(value: null, label: Text('Todas')),
                  ButtonSegment(value: DebtDirection.owed, label: Text('Debo')),
                  ButtonSegment(
                    value: DebtDirection.receivable,
                    label: Text('Me deben'),
                  ),
                ],
                selected: {filter},
                onSelectionChanged: (v) => setState(() => filter = v.first),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const _EmptyDebts()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final debt = items[i];
                        final position = DebtCalculator.position(debt, txs);
                        return _DebtCard(
                          debt: debt,
                          position: position,
                          onEdit: () => _showDebtForm(context, ref, debt: debt),
                          onMovement: () => _showDebtMovement(
                            context,
                            ref,
                            debt,
                            accounts,
                            position,
                          ),
                          onSimulate: debt.direction == DebtDirection.owed
                              ? () => _showSimulator(context, debt, position)
                              : null,
                          onClose: () =>
                              ref.read(debtsRepositoryProvider)?.archive(debt),
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

class _DebtCard extends StatelessWidget {
  const _DebtCard({
    required this.debt,
    required this.position,
    required this.onEdit,
    required this.onMovement,
    required this.onSimulate,
    required this.onClose,
  });
  final DebtRecord debt;
  final DebtPosition position;
  final VoidCallback onEdit, onMovement, onClose;
  final VoidCallback? onSimulate;
  @override
  Widget build(BuildContext context) {
    final receivable = debt.direction == DebtDirection.receivable;
    final color = receivable
        ? AppColors.info
        : (debt.annualRateBasisPoints > 0
              ? AppColors.warning
              : AppColors.primary);
    final progress = debt.initialPrincipalMinor == 0
        ? 0.0
        : position.paidMinor / debt.initialPrincipalMinor;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: .14),
                  child: Icon(
                    receivable
                        ? Icons.handshake_outlined
                        : Icons.account_balance_outlined,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${debt.direction.label} · ${debt.party}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') {
                      onEdit();
                    } else {
                      onClose();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(
                      value: 'close',
                      child: Text('Marcar como saldada'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Pendiente ${Money(position.remainingMinor, debt.currency).format()}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: AppColors.border,
              color: color,
            ),
            const SizedBox(height: 6),
            Text(
              'Pagado/cobrado ${Money(position.paidMinor, debt.currency).format()} de ${Money(debt.initialPrincipalMinor, debt.currency).format()}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            Text(
              '${debt.type.label}${debt.annualRateBasisPoints == 0 ? ' · Sin intereses' : ' · ${(debt.annualRateBasisPoints / 100).toStringAsFixed(2)}% anual'}${debt.nextDueDate == null ? '' : ' · Próximo ${DateFormat('dd/MM/yyyy').format(toLimaTime(debt.nextDueDate!))}'}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (debt.direction == DebtDirection.owed &&
                debt.installmentMinor != null &&
                debt.thirdPartyContributionMinor > 0)
              Text(
                'Cuota ${Money(debt.installmentMinor!, debt.currency).format()} · Tercero ${Money(debt.thirdPartyContributionMinor, debt.currency).format()} · Tu parte ${Money((debt.installmentMinor! - debt.thirdPartyContributionMinor).clamp(0, debt.installmentMinor!), debt.currency).format()}',
                style: const TextStyle(color: AppColors.info),
              ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                if (onSimulate != null)
                  OutlinedButton.icon(
                    onPressed: onSimulate,
                    icon: const Icon(Icons.calculate_outlined),
                    label: const Text('Simular'),
                  ),
                FilledButton.tonalIcon(
                  onPressed: position.remainingMinor == 0 ? null : onMovement,
                  icon: Icon(
                    receivable ? Icons.call_received : Icons.payments_outlined,
                  ),
                  label: Text(
                    receivable ? 'Registrar cobro' : 'Registrar pago',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDebts extends StatelessWidget {
  const _EmptyDebts();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.balance_outlined, size: 52, color: AppColors.primary),
          SizedBox(height: 12),
          Text(
            'Sin deudas registradas',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'Registra tanto lo que debes como el dinero que otras personas deben devolverte.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showDebtForm(
  BuildContext context,
  WidgetRef ref, {
  DebtRecord? debt,
}) => showDialog<void>(
  context: context,
  builder: (_) => _DebtFormDialog(debt: debt),
);

class _DebtFormDialog extends ConsumerStatefulWidget {
  const _DebtFormDialog({this.debt});
  final DebtRecord? debt;
  @override
  ConsumerState<_DebtFormDialog> createState() => _DebtFormDialogState();
}

class _DebtFormDialogState extends ConsumerState<_DebtFormDialog> {
  final key = GlobalKey<FormState>();
  late final TextEditingController name,
      party,
      principal,
      rate,
      installments,
      installment,
      thirdParty,
      notes;
  late DebtDirection direction;
  late DebtType type;
  late Currency currency;
  DateTime? due;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final d = widget.debt;
    name = TextEditingController(text: d?.name);
    party = TextEditingController(text: d?.party);
    principal = TextEditingController(
      text: d == null ? '' : _input(d.initialPrincipalMinor),
    );
    rate = TextEditingController(
      text: d == null ? '' : (d.annualRateBasisPoints / 100).toStringAsFixed(2),
    );
    installments = TextEditingController(text: d?.installments?.toString());
    installment = TextEditingController(
      text: d?.installmentMinor == null ? '' : _input(d!.installmentMinor!),
    );
    thirdParty = TextEditingController(
      text: d?.thirdPartyContributionMinor == null
          ? ''
          : _input(d!.thirdPartyContributionMinor),
    );
    notes = TextEditingController(text: d?.notes);
    direction = d?.direction ?? DebtDirection.owed;
    type = d?.type ?? DebtType.personal;
    currency = d?.currency ?? Currency.pen;
    due = d?.nextDueDate;
  }

  @override
  void dispose() {
    for (final c in [
      name,
      party,
      principal,
      rate,
      installments,
      installment,
      thirdParty,
      notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.debt == null ? 'Nueva deuda o préstamo' : 'Editar deuda',
    ),
    content: SizedBox(
      width: 520,
      child: Form(
        key: key,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<DebtDirection>(
                segments: DebtDirection.values
                    .map((d) => ButtonSegment(value: d, label: Text(d.label)))
                    .toList(),
                selected: {direction},
                onSelectionChanged: (v) => setState(() => direction = v.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: _required,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: party,
                decoration: InputDecoration(
                  labelText: direction == DebtDirection.owed
                      ? 'Acreedor'
                      : 'Deudor',
                ),
                validator: _required,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<DebtType>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: DebtType.values
                    .map(
                      (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => type = v!),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: principal,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Saldo inicial/actual',
                      ),
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
                      onChanged: (v) => setState(() => currency = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: rate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Tasa anual efectiva %',
                  helperText: 'Usa 0 si no tiene intereses',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: installments,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cuotas'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: installment,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Monto de cuota',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: const Text('Próxima fecha de pago'),
                subtitle: Text(
                  due == null
                      ? 'Sin fecha'
                      : DateFormat('dd/MM/yyyy').format(toLimaTime(due!)),
                ),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDate:
                        (due == null ? null : toLimaTime(due!)) ??
                        DateTime.now(),
                  );
                  if (picked != null) {
                    setState(
                      () => due = limaMidnightUtc(
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
                controller: thirdParty,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Aporte de tercero por cuota',
                  helperText: 'Parte que otra persona paga de la cuota total',
                ),
              ),
              const SizedBox(height: 10),
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
    final repo = ref.read(debtsRepositoryProvider);
    if (repo == null) return;
    setState(() => saving = true);
    final old = widget.debt, now = DateTime.now().toUtc();
    final rateValue = double.tryParse(rate.text.replaceAll(',', '.')) ?? 0;
    final value = DebtRecord(
      id: old?.id ?? ref.read(uuidProvider).v4(),
      userId: repo.userId,
      name: name.text.trim(),
      direction: direction,
      type: type,
      party: party.text.trim(),
      initialPrincipalMinor: Money.parseMinorUnits(principal.text)!,
      currency: currency,
      annualRateBasisPoints: (rateValue * 100).round(),
      installments: int.tryParse(installments.text),
      installmentMinor: Money.parseMinorUnits(installment.text),
      nextDueDate: due,
      paymentDay: due?.day,
      thirdPartyContributionMinor: Money.parseMinorUnits(thirdParty.text) ?? 0,
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

Future<void> _showDebtMovement(
  BuildContext context,
  WidgetRef ref,
  DebtRecord debt,
  List<FinancialAccount> accounts,
  DebtPosition position,
) => showDialog<void>(
  context: context,
  builder: (_) => _DebtMovementDialog(
    debt: debt,
    accounts: accounts
        .where(
          (a) => a.active && !a.isCreditCard && a.currency == debt.currency,
        )
        .toList(),
    remainingMinor: position.remainingMinor,
  ),
);

class _DebtMovementDialog extends ConsumerStatefulWidget {
  const _DebtMovementDialog({
    required this.debt,
    required this.accounts,
    required this.remainingMinor,
  });
  final DebtRecord debt;
  final List<FinancialAccount> accounts;
  final int remainingMinor;
  @override
  ConsumerState<_DebtMovementDialog> createState() =>
      _DebtMovementDialogState();
}

class _DebtMovementDialogState extends ConsumerState<_DebtMovementDialog> {
  final key = GlobalKey<FormState>();
  late final TextEditingController amount;
  late final TextEditingController thirdParty;
  String? accountId;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final total = widget.debt.installmentMinor ?? 0;
    final other = widget.debt.direction == DebtDirection.owed
        ? widget.debt.thirdPartyContributionMinor
        : 0;
    amount = TextEditingController(
      text: total <= 0 ? '' : _input((total - other).clamp(0, total)),
    );
    thirdParty = TextEditingController(text: other <= 0 ? '' : _input(other));
  }

  @override
  void dispose() {
    amount.dispose();
    thirdParty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final receivable = widget.debt.direction == DebtDirection.receivable;
    return AlertDialog(
      title: Text(receivable ? 'Registrar cobro' : 'Registrar pago'),
      content: Form(
        key: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: receivable ? 'Monto cobrado' : 'Tu aporte',
                prefixText: widget.debt.currency == Currency.pen
                    ? 'S/ '
                    : r'US$ ',
              ),
              validator: (v) {
                final n = Money.parseMinorUnits(v ?? '');
                if (n == null || n <= 0) {
                  return 'Ingresa un monto válido';
                }
                final other = receivable
                    ? 0
                    : Money.parseMinorUnits(thirdParty.text) ?? 0;
                if (n + other > widget.remainingMinor) {
                  return 'Supera el saldo pendiente';
                }
                return null;
              },
            ),
            if (!receivable) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: thirdParty,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Aporte de tercero',
                  prefixText: widget.debt.currency == Currency.pen
                      ? 'S/ '
                      : r'US$ ',
                  helperText:
                      'También reduce la deuda, pero no sale de tu cuenta',
                ),
                onChanged: (_) => key.currentState?.validate(),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: accountId,
              decoration: InputDecoration(
                labelText: receivable ? 'Cuenta que recibe' : 'Cuenta de pago',
              ),
              items: widget.accounts
                  .map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                  )
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
  }

  Future<void> _save() async {
    if (!key.currentState!.validate()) return;
    final repo = ref.read(transactionsRepositoryProvider);
    if (repo == null) return;
    setState(() => saving = true);
    final receivable = widget.debt.direction == DebtDirection.receivable,
        now = DateTime.now().toUtc();
    final value = FinancialTransaction(
      id: ref.read(uuidProvider).v4(),
      userId: repo.userId,
      kind: receivable
          ? TransactionKind.loanRepayment
          : TransactionKind.debtPayment,
      amountMinor: Money.parseMinorUnits(amount.text)!,
      thirdPartyAmountMinor: receivable
          ? null
          : Money.parseMinorUnits(thirdParty.text),
      currency: widget.debt.currency,
      sourceAccountId: receivable ? null : accountId,
      destinationAccountId: receivable ? accountId : null,
      debtId: widget.debt.id,
      description: '${receivable ? 'Cobro' : 'Pago'} · ${widget.debt.name}',
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

Future<void> _showSimulator(
  BuildContext context,
  DebtRecord debt,
  DebtPosition position,
) => showDialog<void>(
  context: context,
  builder: (_) =>
      _SimulatorDialog(debt: debt, remainingMinor: position.remainingMinor),
);

class _SimulatorDialog extends StatefulWidget {
  const _SimulatorDialog({required this.debt, required this.remainingMinor});
  final DebtRecord debt;
  final int remainingMinor;
  @override
  State<_SimulatorDialog> createState() => _SimulatorDialogState();
}

class _SimulatorDialogState extends State<_SimulatorDialog> {
  late final TextEditingController payment, extra, prepayment;
  @override
  void initState() {
    super.initState();
    payment = TextEditingController(
      text: widget.debt.installmentMinor == null
          ? ''
          : _input(widget.debt.installmentMinor!),
    );
    extra = TextEditingController();
    prepayment = TextEditingController();
  }

  @override
  void dispose() {
    payment.dispose();
    extra.dispose();
    prepayment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Money.parseMinorUnits(payment.text) ?? 0,
        x = Money.parseMinorUnits(extra.text) ?? 0,
        pre = Money.parseMinorUnits(prepayment.text) ?? 0;
    final simulation = p <= 0
        ? null
        : DebtCalculator.simulate(
            principalMinor: widget.remainingMinor,
            annualRateBasisPoints: widget.debt.annualRateBasisPoints,
            monthlyPaymentMinor: p,
            extraMonthlyMinor: x,
            prepaymentMinor: pre,
          );
    final invalid =
        simulation != null &&
        simulation.normal.months == 0 &&
        widget.remainingMinor > 0;
    return AlertDialog(
      title: const Text('Simulador de pago'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Saldo: ${Money(widget.remainingMinor, widget.debt.currency).format()} · Tasa ${(widget.debt.annualRateBasisPoints / 100).toStringAsFixed(2)}% anual',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: payment,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Pago mensual'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: extra,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Extra mensual'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: prepayment,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Prepago único'),
              ),
              const SizedBox(height: 16),
              if (invalid)
                const Text(
                  'El pago no cubre los intereses del mes.',
                  style: TextStyle(color: AppColors.primary),
                )
              else if (simulation != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plan normal: ${simulation.normal.months} meses · intereses ${Money(simulation.normal.totalInterestMinor, widget.debt.currency).format()}',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Con extras: ${simulation.accelerated.months} meses · intereses ${Money(simulation.accelerated.totalInterestMinor, widget.debt.currency).format()}',
                        ),
                        const Divider(),
                        Text(
                          'Ahorras ${Money(simulation.interestSavedMinor, widget.debt.currency).format()} y ${simulation.monthsSaved} meses',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.positive,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

String? _required(String? value) =>
    (value?.trim().isEmpty ?? true) ? 'Campo obligatorio' : null;
String? _positive(String? value) {
  final n = Money.parseMinorUnits(value ?? '');
  return n == null || n <= 0 ? 'Ingresa un monto válido' : null;
}

String _input(int minor) =>
    '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';
