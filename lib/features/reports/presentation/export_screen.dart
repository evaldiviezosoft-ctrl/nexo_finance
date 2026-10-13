import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/time/lima_time.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../budgets/data/budgets_repository.dart';
import '../../cards/data/card_statements_repository.dart';
import '../../categories/data/categories_repository.dart';
import '../../debts/data/debts_repository.dart';
import '../../goals/data/goals_repository.dart';
import '../../recurring/data/recurring_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../data/export_service.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});
  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool anonymize = false;
  bool working = false;
  late DateTimeRange range = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now().add(const Duration(days: 1)),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Datos y exportación')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.date_range_outlined),
                title: const Text('Rango de movimientos'),
                subtitle: Text('${_date(range.start)} – ${_date(range.end)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickRange,
              ),
              SwitchListTile(
                value: anonymize,
                onChanged: working
                    ? null
                    : (v) => setState(() => anonymize = v),
                secondary: const Icon(Icons.visibility_off_outlined),
                title: const Text('Ocultar datos personales'),
                subtitle: const Text(
                  'Reemplaza nombres de cuentas y personas al compartir.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ExportTile(
          icon: Icons.table_view_outlined,
          title: 'Movimientos CSV',
          subtitle: 'Compatible con Excel y Google Sheets.',
          onTap: working ? null : _csv,
        ),
        _ExportTile(
          icon: Icons.picture_as_pdf_outlined,
          title: 'Reporte mensual PDF',
          subtitle: 'Ingresos, gastos, ahorro y categorías del mes.',
          onTap: working ? null : _pdf,
        ),
        _ExportTile(
          icon: Icons.data_object_outlined,
          title: 'Copia completa JSON',
          subtitle: 'Cuentas, movimientos, límites, tarjetas, metas y deudas.',
          onTap: working ? null : _json,
        ),
        if (working)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 18),
          child: Text(
            'Los archivos se generan localmente y solo se comparten cuando eliges una aplicación de destino.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    ),
  );

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: range,
    );
    if (picked != null) setState(() => range = picked);
  }

  Future<void> _csv() async => _run(() async {
    final accounts = ref.read(accountsProvider).value?.items ?? [];
    final categories = ref.read(categoriesProvider).value?.items ?? [];
    final file = await ExportService.transactionsCsv(
      transactions: ref.read(transactionsProvider).value?.items ?? [],
      start: limaMidnightUtc(
        range.start.year,
        range.start.month,
        range.start.day,
      ),
      end: limaMidnightUtc(range.end.year, range.end.month, range.end.day + 1),
      accountNames: {for (final a in accounts) a.id: a.name},
      categoryNames: {for (final c in categories) c.id: c.name},
      anonymize: anonymize,
    );
    await _share(file.path, 'Movimientos de Nexo Finance');
  });
  Future<void> _pdf() async => _run(() async {
    final categories = ref.read(categoriesProvider).value?.items ?? [];
    final file = await ExportService.monthlyPdf(
      transactions: ref.read(transactionsProvider).value?.items ?? [],
      month: range.start,
      categoryNames: {for (final c in categories) c.id: c.name},
      anonymize: anonymize,
    );
    await _share(file.path, 'Reporte mensual de Nexo Finance');
  });
  Future<void> _json() async => _run(() async {
    final file = await ExportService.fullJson(
      accounts: ref.read(accountsProvider).value?.items ?? [],
      categories: ref.read(categoriesProvider).value?.items ?? [],
      transactions: ref.read(transactionsProvider).value?.items ?? [],
      budgets: ref.read(budgetsProvider).value?.items ?? [],
      statements: ref.read(cardStatementsProvider).value?.items ?? [],
      recurring: ref.read(recurringTransactionsProvider).value?.items ?? [],
      goals: ref.read(goalsProvider).value?.items ?? [],
      debts: ref.read(debtsProvider).value?.items ?? [],
      anonymize: anonymize,
    );
    await _share(file.path, 'Copia de Nexo Finance');
  });
  Future<void> _share(String path, String text) =>
      SharePlus.instance.share(ShareParams(text: text, files: [XFile(path)]));
  Future<void> _run(Future<void> Function() action) async {
    setState(() => working = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo exportar: $e')));
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _ExportTile extends StatelessWidget {
  const _ExportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(12),
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.ios_share_outlined),
      onTap: onTap,
    ),
  );
}
