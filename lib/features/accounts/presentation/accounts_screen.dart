import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/money/money.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/ledger_calculator.dart';
import '../data/accounts_repository.dart';
import '../domain/financial_account.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final transactions = ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas'),
        actions: [
          IconButton(
            tooltip: 'Agregar cuenta',
            onPressed: () => context.push('/accounts/new'),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(message: error.toString()),
        data: (snapshot) {
          final txs = transactions.value?.items ?? const [];
          final balances = LedgerCalculator.balances(
            accounts: snapshot.items,
            transactions: txs,
          );
          if (snapshot.items.isEmpty) {
            return _EmptyAccounts(
              onPressed: () => context.push('/accounts/new'),
            );
          }
          return Column(
            children: [
              if (snapshot.hasPendingWrites) const LinearProgressIndicator(),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: snapshot.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final account = snapshot.items[index];
                    final value =
                        balances[account.id] ?? account.initialBalanceMinor;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: account.isCreditCard
                              ? const Color(0x33FFB020)
                              : const Color(0x33FF1744),
                          child: Icon(
                            account.isCreditCard
                                ? Icons.credit_card_rounded
                                : Icons.account_balance_wallet_outlined,
                            color: account.isCreditCard
                                ? AppColors.warning
                                : AppColors.primary,
                          ),
                        ),
                        title: Text(account.name),
                        subtitle: Text(
                          '${account.type.label}${account.active ? '' : ' · Archivada'}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              Money(value, account.currency).format(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              account.currency.name.toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        onTap: () => context.push(
                          '/accounts/${account.id}',
                          extra: account,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        tooltip: 'Nueva cuenta',
        onPressed: () => context.push('/accounts/new'),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }
}

class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({this.account, super.key});
  final FinancialAccount? account;

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late final TextEditingController _institution;
  late final TextEditingController _limit;
  late final TextEditingController _closingDay;
  late final TextEditingController _paymentDay;
  late AccountType _type;
  late Currency _currency;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _name = TextEditingController(text: account?.name);
    _balance = TextEditingController(
      text: account == null ? '' : _minorInput(account.initialBalanceMinor),
    );
    _institution = TextEditingController(text: account?.institution);
    _limit = TextEditingController(
      text: account?.creditLimitMinor == null
          ? ''
          : _minorInput(account!.creditLimitMinor!),
    );
    _closingDay = TextEditingController(text: account?.closingDay?.toString());
    _paymentDay = TextEditingController(text: account?.paymentDay?.toString());
    _type = account?.type ?? AccountType.cash;
    _currency = account?.currency ?? Currency.pen;
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _institution.dispose();
    _limit.dispose();
    _closingDay.dispose();
    _paymentDay.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repository = ref.read(accountsRepositoryProvider);
    if (repository == null) return;
    setState(() => _saving = true);
    final now = DateTime.now().toUtc();
    final previous = widget.account;
    final account = FinancialAccount(
      id: previous?.id ?? ref.read(uuidProvider).v4(),
      userId: repository.userId,
      name: _name.text.trim(),
      type: _type,
      currency: _currency,
      initialBalanceMinor: Money.parseMinorUnits(_balance.text)!,
      institution: _institution.text.trim().isEmpty
          ? null
          : _institution.text.trim(),
      creditLimitMinor:
          _type == AccountType.creditCard && _limit.text.isNotEmpty
          ? Money.parseMinorUnits(_limit.text)
          : null,
      closingDay: _type == AccountType.creditCard
          ? int.tryParse(_closingDay.text)
          : null,
      paymentDay: _type == AccountType.creditCard
          ? int.tryParse(_paymentDay.text)
          : null,
      active: previous?.active ?? true,
      deletedAt: previous?.deletedAt,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
      version: (previous?.version ?? 0) + 1,
    );
    try {
      previous == null
          ? await repository.create(account)
          : await repository.update(account);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $error')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.account == null ? 'Nueva cuenta' : 'Editar cuenta'),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Ingresa un nombre'
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<AccountType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: AccountType.values
                .map(
                  (type) =>
                      DropdownMenuItem(value: type, child: Text(type.label)),
                )
                .toList(),
            onChanged: (value) => setState(() => _type = value!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Currency>(
            initialValue: _currency,
            decoration: const InputDecoration(labelText: 'Moneda'),
            items: Currency.values
                .map(
                  (currency) => DropdownMenuItem(
                    value: currency,
                    child: Text(currency.name.toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: widget.account == null
                ? (value) => setState(() => _currency = value!)
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _balance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _type == AccountType.creditCard
                  ? 'Deuda inicial'
                  : 'Saldo inicial',
              helperText: 'No se contabiliza como ingreso.',
              prefixText: _currency == Currency.pen ? 'S/ ' : r'US$ ',
            ),
            validator: (value) => Money.parseMinorUnits(value ?? '') == null
                ? 'Usa un monto válido, por ejemplo 1250.50'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _institution,
            decoration: const InputDecoration(
              labelText: 'Institución (opcional)',
            ),
          ),
          if (_type == AccountType.creditCard) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _limit,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Línea de crédito'),
              validator: (value) =>
                  value == null ||
                      value.isEmpty ||
                      Money.parseMinorUnits(value) != null
                  ? null
                  : 'Ingresa un monto válido',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _closingDay,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Día de cierre',
                    ),
                    validator: _dayValidator,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _paymentDay,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Día de pago'),
                    validator: _dayValidator,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Se usan días fijos, incluso si caen feriado o fin de semana.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Guardando…' : 'Guardar cuenta'),
          ),
          if (widget.account != null && widget.account!.active) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await ref
                    .read(accountsRepositoryProvider)!
                    .archive(widget.account!);
                if (context.mounted) context.pop();
              },
              child: const Text('Archivar cuenta'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 52,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          const Text(
            'Agrega dónde guardas tu dinero',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tu saldo inicial no se contará como ingreso.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onPressed,
            child: const Text('Crear primera cuenta'),
          ),
        ],
      ),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(24), child: Text(message)),
  );
}

String _minorInput(int value) =>
    '${value ~/ 100}.${(value.abs() % 100).toString().padLeft(2, '0')}';

String? _dayValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'Obligatorio';
  final day = int.tryParse(value);
  return day == null || day < 1 || day > 31 ? 'Entre 1 y 31' : null;
}
