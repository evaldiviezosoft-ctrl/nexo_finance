import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../core/time/lima_time.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../accounts/domain/financial_account.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/finance_category.dart';
import '../data/transactions_repository.dart';
import '../domain/financial_transaction.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SearchBar(
              hintText: 'Buscar movimientos',
              leading: const Icon(Icons.search_rounded),
              onChanged: (value) =>
                  setState(() => _search = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: transactions.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (snapshot) {
                final items = snapshot.items.where((item) {
                  return _search.isEmpty ||
                      item.description.toLowerCase().contains(_search) ||
                      item.kind.label.toLowerCase().contains(_search);
                }).toList();
                if (items.isEmpty) return const _EmptyTransactions();
                final groups = _groupByDay(items);
                return Column(
                  children: [
                    if (snapshot.hasPendingWrites)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 110),
                        itemCount: groups.length,
                        itemBuilder: (context, index) =>
                            _TransactionDayGroup(group: groups[index]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionDayGroup extends StatelessWidget {
  const _TransactionDayGroup({required this.group});

  final _DayGroup group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _dayLabel(group.day),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${group.transactions.length} ${group.transactions.length == 1 ? 'movimiento' : 'movimientos'}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: AppColors.border),
            ),
          ),
          child: Column(
            children: [
              for (
                var index = 0;
                index < group.transactions.length;
                index++
              ) ...[
                _TransactionTile(transaction: group.transactions[index]),
                if (index < group.transactions.length - 1)
                  const Divider(height: 1, indent: 72, color: AppColors.border),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DayGroup {
  const _DayGroup(this.day, this.transactions);

  final DateTime day;
  final List<FinancialTransaction> transactions;
}

List<_DayGroup> _groupByDay(List<FinancialTransaction> transactions) {
  final groups = <_DayGroup>[];
  for (final transaction in transactions) {
    final lima = toLimaTime(transaction.occurredAt);
    final day = DateTime(lima.year, lima.month, lima.day);
    if (groups.isEmpty || groups.last.day != day) {
      groups.add(_DayGroup(day, [transaction]));
    } else {
      groups.last.transactions.add(transaction);
    }
  }
  return groups;
}

String _dayLabel(DateTime day) {
  final limaNow = toLimaTime(DateTime.now());
  final today = DateTime(limaNow.year, limaNow.month, limaNow.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return 'Hoy';
  if (difference == 1) return 'Ayer';

  final formatted = DateFormat("EEEE, d 'de' MMMM", 'es_PE').format(day);
  return '${formatted[0].toUpperCase()}${formatted.substring(1)}';
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.transaction});
  final FinancialTransaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positive =
        transaction.kind.countsAsIncome ||
        transaction.kind == TransactionKind.loanRepayment ||
        transaction.kind == TransactionKind.refund;
    final neutral =
        transaction.kind == TransactionKind.transfer ||
        transaction.kind == TransactionKind.goalContribution ||
        transaction.kind == TransactionKind.goalWithdrawal ||
        transaction.kind == TransactionKind.creditPayment;
    final color = neutral
        ? AppColors.info
        : positive
        ? AppColors.positive
        : AppColors.primary;
    final sign = neutral ? '' : (positive ? '+' : '-');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: .14),
        child: Icon(_icon(transaction.kind), color: color),
      ),
      title: Text(
        transaction.description.isEmpty
            ? transaction.kind.label
            : transaction.description,
      ),
      subtitle: Text(
        '${transaction.kind.label} · ${DateFormat('h:mm a', 'es_PE').format(toLimaTime(transaction.occurredAt))}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$sign${Money(transaction.amountMinor, transaction.currency).format()}',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          PopupMenuButton<String>(
            onSelected: (action) async {
              if (action == 'edit') {
                context.push(
                  '/transactions/${transaction.id}',
                  extra: transaction,
                );
              } else if (action == 'duplicate') {
                context.push(
                  '/transactions/new?duplicate=true',
                  extra: transaction,
                );
              } else if (action == 'delete') {
                final repository = ref.read(transactionsRepositoryProvider)!;
                await repository.softDelete(transaction);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Movimiento eliminado'),
                    action: SnackBarAction(
                      label: 'Deshacer',
                      onPressed: () => repository.restore(transaction),
                    ),
                  ),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'duplicate', child: Text('Duplicar')),
              PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
        ],
      ),
    );
  }
}

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({
    required this.initialKind,
    this.transaction,
    this.duplicate = false,
    super.key,
  });

  final TransactionKind initialKind;
  final FinancialTransaction? transaction;
  final bool duplicate;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _description;
  late final TextEditingController _note;
  late final TextEditingController _destinationAmount;
  late TransactionKind _kind;
  String? _sourceId;
  String? _destinationId;
  String? _categoryId;
  late DateTime _occurredAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _kind = transaction?.kind ?? widget.initialKind;
    _amount = TextEditingController(
      text: transaction == null ? '' : _minorInput(transaction.amountMinor),
    );
    _description = TextEditingController(text: transaction?.description);
    _note = TextEditingController(text: transaction?.note);
    _destinationAmount = TextEditingController(
      text: transaction?.destinationAmountMinor == null
          ? ''
          : _minorInput(transaction!.destinationAmountMinor!),
    );
    _sourceId = transaction?.sourceAccountId;
    _destinationId = transaction?.destinationAccountId;
    _categoryId = transaction?.categoryId;
    _occurredAt = transaction?.occurredAt ?? DateTime.now().toUtc();
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _note.dispose();
    _destinationAmount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref
            .watch(accountsProvider)
            .value
            ?.items
            .where((account) => account.active)
            .toList() ??
        const <FinancialAccount>[];
    final categories =
        ref
            .watch(categoriesProvider)
            .value
            ?.items
            .where((category) => category.active)
            .toList() ??
        const <FinanceCategory>[];
    final selectedAccount = accounts
        .where((item) => item.id == (_sourceId ?? _destinationId))
        .firstOrNull;
    final currency = selectedAccount?.currency ?? Currency.pen;
    final sourceAccount = accounts
        .where((item) => item.id == _sourceId)
        .firstOrNull;
    final destinationAccount = accounts
        .where((item) => item.id == _destinationId)
        .firstOrNull;
    final differentCurrencies =
        sourceAccount != null &&
        destinationAccount != null &&
        sourceAccount.currency != destinationAccount.currency;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transaction != null && !widget.duplicate
              ? 'Editar movimiento'
              : _kind.label,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TextFormField(
              controller: _amount,
              autofocus: widget.transaction == null,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Monto',
                prefixText: currency == Currency.pen ? 'S/ ' : r'US$ ',
              ),
              validator: (value) {
                final amount = Money.parseMinorUnits(value ?? '');
                return amount == null || amount <= 0
                    ? 'Ingresa un monto válido'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TransactionKind>(
              initialValue: _kind,
              decoration: const InputDecoration(
                labelText: 'Tipo de movimiento',
              ),
              items: TransactionKind.values
                  .where(
                    (kind) =>
                        !kind.requiresManagedTarget ||
                        kind == widget.transaction?.kind,
                  )
                  .map(
                    (kind) =>
                        DropdownMenuItem(value: kind, child: Text(kind.label)),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _kind = value!;
                _sourceId = null;
                _destinationId = null;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: 12),
            if (_kind.needsSource)
              _AccountDropdown(
                label: _kind == TransactionKind.creditPurchase
                    ? 'Tarjeta de crédito'
                    : 'Cuenta de origen',
                value: _sourceId,
                accounts: _kind == TransactionKind.creditPurchase
                    ? accounts.where((item) => item.isCreditCard).toList()
                    : accounts.where((item) => !item.isCreditCard).toList(),
                onChanged: (value) => setState(() => _sourceId = value),
              ),
            if (_kind.needsSource) const SizedBox(height: 12),
            if (_kind.needsDestination)
              _AccountDropdown(
                label: _kind == TransactionKind.creditPayment
                    ? 'Tarjeta que se paga'
                    : 'Cuenta de destino',
                value: _destinationId,
                accounts: _kind == TransactionKind.creditPayment
                    ? accounts.where((item) => item.isCreditCard).toList()
                    : accounts.where((item) => !item.isCreditCard).toList(),
                onChanged: (value) => setState(() => _destinationId = value),
              ),
            if (_kind.needsDestination) const SizedBox(height: 12),
            if (differentCurrencies) ...[
              TextFormField(
                controller: _destinationAmount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText:
                      'Monto recibido en ${destinationAccount.currency.name.toUpperCase()}',
                  helperText:
                      'El tipo de cambio se conservará con el movimiento.',
                ),
                validator: (value) {
                  final amount = Money.parseMinorUnits(value ?? '');
                  return amount == null || amount <= 0
                      ? 'Ingresa el monto convertido'
                      : null;
                },
              ),
              const SizedBox(height: 12),
            ],
            if (_kind.countsAsExpense || _kind.countsAsIncome)
              DropdownButtonFormField<String>(
                initialValue: categories.any((item) => item.id == _categoryId)
                    ? _categoryId
                    : null,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: categories
                    .where(
                      (category) =>
                          category.type ==
                          (_kind.countsAsIncome
                              ? CategoryType.income
                              : CategoryType.expense),
                    )
                    .map(
                      (category) => DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _categoryId = value),
                validator: (value) =>
                    value == null ? 'Selecciona una categoría' : null,
              ),
            if (_kind.countsAsExpense || _kind.countsAsIncome)
              const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Fecha'),
              subtitle: Text(
                DateFormat('dd/MM/yyyy').format(toLimaTime(_occurredAt)),
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Nota opcional'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: accounts.isEmpty || _saving
                  ? null
                  : () => _save(accounts),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(_saving ? 'Guardando…' : 'Guardar movimiento'),
              ),
            ),
            if (accounts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Primero crea una cuenta desde Ajustes → Cuentas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.warning),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(List<FinancialAccount> accounts) async {
    if (!_formKey.currentState!.validate()) return;
    if (_kind.needsSource && _sourceId == null) {
      return _missing('cuenta de origen');
    }
    if (_kind.needsDestination && _destinationId == null) {
      return _missing('cuenta de destino');
    }
    if (_sourceId != null && _sourceId == _destinationId) {
      return _missing('una cuenta de destino diferente');
    }
    if (_kind.isGoalMovement && widget.transaction?.goalId == null) {
      return _missingManagedTarget('Metas');
    }
    if (_kind.isDebtMovement && widget.transaction?.debtId == null) {
      return _missingManagedTarget('Deudas');
    }
    final account = accounts.firstWhere(
      (item) => item.id == (_sourceId ?? _destinationId),
    );
    final destinationAccount = accounts
        .where((item) => item.id == _destinationId)
        .firstOrNull;
    final amountMinor = Money.parseMinorUnits(_amount.text)!;
    final differentCurrencies =
        destinationAccount != null &&
        destinationAccount.currency != account.currency;
    final destinationAmountMinor = differentCurrencies
        ? Money.parseMinorUnits(_destinationAmount.text)
        : null;
    final repository = ref.read(transactionsRepositoryProvider);
    if (repository == null) return;
    setState(() => _saving = true);
    final previous = widget.duplicate ? null : widget.transaction;
    final now = DateTime.now().toUtc();
    final transaction = FinancialTransaction(
      id: previous?.id ?? ref.read(uuidProvider).v4(),
      userId: repository.userId,
      kind: _kind,
      amountMinor: amountMinor,
      currency: account.currency,
      sourceAccountId: _sourceId,
      destinationAccountId: _destinationId,
      categoryId: _categoryId,
      goalId: _kind.isGoalMovement ? widget.transaction?.goalId : null,
      debtId: _kind.isDebtMovement ? widget.transaction?.debtId : null,
      thirdPartyAmountMinor: _kind.isDebtMovement
          ? widget.transaction?.thirdPartyAmountMinor
          : null,
      description: _description.text.trim(),
      note: _note.text.trim(),
      destinationAmountMinor: destinationAmountMinor,
      exchangeRateMicros: destinationAmountMinor == null
          ? null
          : destinationAmountMinor * 1000000 ~/ amountMinor,
      occurredAt: widget.duplicate ? now : _occurredAt,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
      version: (previous?.version ?? 0) + 1,
    );
    try {
      previous == null
          ? await repository.create(transaction)
          : await repository.update(transaction);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $error')));
      }
    }
  }

  void _missing(String field) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Selecciona $field.')));
  }

  void _missingManagedTarget(String section) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Registra este movimiento desde Plan > $section para vincularlo correctamente.',
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final local = toLimaTime(_occurredAt);
    final selected = await showDatePicker(
      context: context,
      initialDate: local,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selected == null) return;
    setState(() {
      _occurredAt = limaMidnightUtc(selected.year, selected.month, selected.day)
          .add(
            Duration(
              hours: local.hour,
              minutes: local.minute,
              seconds: local.second,
            ),
          );
    });
  }
}

class _AccountDropdown extends StatelessWidget {
  const _AccountDropdown({
    required this.label,
    required this.value,
    required this.accounts,
    required this.onChanged,
  });
  final String label;
  final String? value;
  final List<FinancialAccount> accounts;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: accounts.any((item) => item.id == value) ? value : null,
    decoration: InputDecoration(labelText: label),
    items: accounts
        .map(
          (account) => DropdownMenuItem(
            value: account.id,
            child: Text(
              '${account.name} (${account.currency.name.toUpperCase()})',
            ),
          ),
        )
        .toList(),
    onChanged: onChanged,
    validator: (value) => value == null ? 'Selecciona una cuenta' : null,
  );
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 12),
          Text(
            'Aún no hay movimientos',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            'Usa el botón + para registrar el primero.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

IconData _icon(TransactionKind kind) => switch (kind) {
  TransactionKind.expense => Icons.north_east_rounded,
  TransactionKind.income => Icons.south_west_rounded,
  TransactionKind.transfer => Icons.swap_horiz_rounded,
  TransactionKind.creditPurchase => Icons.credit_card_rounded,
  TransactionKind.creditPayment => Icons.payment_rounded,
  TransactionKind.loanGiven => Icons.person_add_alt_rounded,
  TransactionKind.loanRepayment => Icons.handshake_outlined,
  TransactionKind.goalContribution => Icons.flag_outlined,
  TransactionKind.goalWithdrawal => Icons.savings_outlined,
  TransactionKind.debtPayment => Icons.price_check_rounded,
  TransactionKind.refund => Icons.replay_rounded,
};

String _minorInput(int value) =>
    '${value ~/ 100}.${(value.abs() % 100).toString().padLeft(2, '0')}';
