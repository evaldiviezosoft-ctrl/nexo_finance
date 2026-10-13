import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/money/money.dart';
import '../../../core/time/lima_time.dart';
import '../../accounts/domain/financial_account.dart';
import '../../budgets/domain/budget.dart';
import '../../cards/domain/card_statement.dart';
import '../../categories/domain/finance_category.dart';
import '../../debts/domain/debt_record.dart';
import '../../goals/domain/financial_goal.dart';
import '../../recurring/domain/recurring_transaction.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../transactions/domain/ledger_calculator.dart';

abstract final class ExportService {
  static Future<File> transactionsCsv({
    required List<FinancialTransaction> transactions,
    required DateTime start,
    required DateTime end,
    required Map<String, String> accountNames,
    required Map<String, String> categoryNames,
    required bool anonymize,
  }) async {
    final rows = <List<Object?>>[
      [
        'fecha',
        'tipo',
        'descripcion',
        'monto',
        'moneda',
        'cuenta_origen',
        'cuenta_destino',
        'categoria',
        'nota',
      ],
      ...transactions
          .where(
            (t) =>
                t.deletedAt == null &&
                !t.occurredAt.isBefore(start) &&
                t.occurredAt.isBefore(end),
          )
          .map(
            (t) => [
              DateFormat('dd/MM/yyyy HH:mm').format(toLimaTime(t.occurredAt)),
              t.kind.label,
              t.description,
              (t.amountMinor / 100).toStringAsFixed(2),
              t.currency.name.toUpperCase(),
              anonymize
                  ? _masked(t.sourceAccountId)
                  : accountNames[t.sourceAccountId] ?? '',
              anonymize
                  ? _masked(t.destinationAccountId)
                  : accountNames[t.destinationAccountId] ?? '',
              categoryNames[t.categoryId] ?? '',
              t.note,
            ],
          ),
    ];
    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
    return _write('movimientos_${_stamp()}.csv', utf8.encode(csv));
  }

  static Future<File> monthlyPdf({
    required List<FinancialTransaction> transactions,
    required DateTime month,
    required Map<String, String> categoryNames,
    required bool anonymize,
  }) async {
    final start = DateTime.utc(month.year, month.month, 1, 5);
    final end = DateTime.utc(month.year, month.month + 1, 1, 5);
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
    final expenses = transactions.where(
      (t) =>
          t.deletedAt == null &&
          t.currency == Currency.pen &&
          t.kind.countsAsExpense &&
          !t.occurredAt.isBefore(start) &&
          t.occurredAt.isBefore(end),
    );
    final categories = <String, int>{};
    for (final t in expenses) {
      categories.update(
        t.categoryId ?? 'sin_categoria',
        (v) => v + t.amountMinor,
        ifAbsent: () => t.amountMinor,
      );
    }
    final sorted = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => [
          pw.Text(
            'Nexo Finance',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.redAccent,
            ),
          ),
          pw.Text('Reporte mensual · ${DateFormat('MM/yyyy').format(month)}'),
          if (anonymize)
            pw.Text(
              'Datos personales ocultos',
              style: const pw.TextStyle(color: PdfColors.grey),
            ),
          pw.SizedBox(height: 24),
          pw.Row(
            children: [
              _pdfMetric('Ingresos', Money(income, Currency.pen).format()),
              pw.SizedBox(width: 12),
              _pdfMetric('Gastos', Money(expense, Currency.pen).format()),
              pw.SizedBox(width: 12),
              _pdfMetric(
                'Ahorro neto',
                Money(income - expense, Currency.pen).format(),
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Gastos por categoría',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (sorted.isEmpty) pw.Text('Sin gastos en el periodo.'),
          if (sorted.isNotEmpty)
            pw.TableHelper.fromTextArray(
              headers: ['Categoría', 'Monto'],
              data: sorted
                  .map(
                    (e) => [
                      categoryNames[e.key] ?? 'Sin categoría',
                      Money(e.value, Currency.pen).format(),
                    ],
                  )
                  .toList(),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.redAccent,
              ),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
        ],
      ),
    );
    return _write(
      'reporte_${month.year}_${_stamp()}.pdf',
      await document.save(),
    );
  }

  static Future<File> fullJson({
    required List<FinancialAccount> accounts,
    required List<FinanceCategory> categories,
    required List<FinancialTransaction> transactions,
    required List<Budget> budgets,
    required List<CardStatement> statements,
    required List<RecurringTransaction> recurring,
    required List<FinancialGoal> goals,
    required List<DebtRecord> debts,
    required bool anonymize,
  }) async {
    String? name(String? value) =>
        anonymize && value != null ? 'Oculto' : value;
    final data = {
      'format': 'nexo-finance-backup',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'anonymized': anonymize,
      'accounts': accounts
          .map(
            (a) => {
              'id': a.id,
              'name': name(a.name),
              'type': a.type.name,
              'currency': a.currency.name,
              'initialBalanceMinor': a.initialBalanceMinor,
              'institution': name(a.institution),
              'active': a.active,
              'creditLimitMinor': a.creditLimitMinor,
              'closingDay': a.closingDay,
              'paymentDay': a.paymentDay,
              'createdAt': a.createdAt.toIso8601String(),
              'updatedAt': a.updatedAt.toIso8601String(),
              'deletedAt': a.deletedAt?.toIso8601String(),
            },
          )
          .toList(),
      'categories': categories
          .map(
            (c) => {
              'id': c.id,
              'name': c.name,
              'type': c.type.name,
              'parentId': c.parentId,
              'iconCodePoint': c.iconCodePoint,
              'colorValue': c.colorValue,
              'order': c.order,
              'active': c.active,
              'createdAt': c.createdAt.toIso8601String(),
              'updatedAt': c.updatedAt.toIso8601String(),
              'deletedAt': c.deletedAt?.toIso8601String(),
            },
          )
          .toList(),
      'transactions': transactions
          .map(
            (t) => {
              'id': t.id,
              'kind': t.kind.name,
              'amountMinor': t.amountMinor,
              'thirdPartyAmountMinor': t.thirdPartyAmountMinor,
              'currency': t.currency.name,
              'sourceAccountId': t.sourceAccountId,
              'destinationAccountId': t.destinationAccountId,
              'categoryId': t.categoryId,
              'goalId': t.goalId,
              'debtId': t.debtId,
              'relatedTransactionId': t.relatedTransactionId,
              'exchangeRateMicros': t.exchangeRateMicros,
              'destinationAmountMinor': t.destinationAmountMinor,
              'description': t.description,
              'note': t.note,
              'occurredAt': t.occurredAt.toIso8601String(),
              'createdAt': t.createdAt.toIso8601String(),
              'updatedAt': t.updatedAt.toIso8601String(),
              'deletedAt': t.deletedAt?.toIso8601String(),
            },
          )
          .toList(),
      'budgets': budgets
          .map(
            (b) => {
              'id': b.id,
              'name': b.name,
              'period': b.period.name,
              'amountMinor': b.amountMinor,
              'currency': b.currency.name,
              'categoryId': b.categoryId,
              'customStart': b.customStart?.toIso8601String(),
              'customEnd': b.customEnd?.toIso8601String(),
              'rollover': b.rollover,
              'active': b.active,
              'createdAt': b.createdAt.toIso8601String(),
              'updatedAt': b.updatedAt.toIso8601String(),
              'deletedAt': b.deletedAt?.toIso8601String(),
            },
          )
          .toList(),
      'cardStatements': statements
          .map(
            (s) => {
              'id': s.id,
              'cardAccountId': s.cardAccountId,
              'cycleStart': s.cycleStart.toIso8601String(),
              'cycleEnd': s.cycleEnd.toIso8601String(),
              'dueDate': s.dueDate.toIso8601String(),
              'amountDuePenMinor': s.amountDuePenMinor,
              'amountDueUsdMinor': s.amountDueUsdMinor,
              'reservedPenMinor': s.reservedPenMinor,
              'reservedUsdMinor': s.reservedUsdMinor,
              'status': s.status.name,
              'createdAt': s.createdAt.toIso8601String(),
              'updatedAt': s.updatedAt.toIso8601String(),
              'deletedAt': s.deletedAt?.toIso8601String(),
            },
          )
          .toList(),
      'recurring': recurring
          .map(
            (r) => {
              'id': r.id,
              'name': r.name,
              'kind': r.kind.name,
              'amountMinor': r.amountMinor,
              'currency': r.currency.name,
              'frequency': r.frequency.name,
              'interval': r.interval,
              'nextDueAt': r.nextDueAt.toIso8601String(),
              'active': r.active,
              'sourceAccountId': r.sourceAccountId,
              'destinationAccountId': r.destinationAccountId,
              'categoryId': r.categoryId,
              'createdAt': r.createdAt.toIso8601String(),
              'updatedAt': r.updatedAt.toIso8601String(),
              'deletedAt': r.deletedAt?.toIso8601String(),
            },
          )
          .toList(),
      'goals': goals
          .map(
            (g) => {
              'id': g.id,
              'name': g.name,
              'targetMinor': g.targetMinor,
              'openingAmountMinor': g.openingAmountMinor,
              'currency': g.currency.name,
              'deadline': g.deadline?.toIso8601String(),
              'priority': g.priority.name,
              'accountId': g.accountId,
              'iconCodePoint': g.iconCodePoint,
              'colorValue': g.colorValue,
              'automaticContributionMinor': g.automaticContributionMinor,
              'allowWithdrawals': g.allowWithdrawals,
              'notes': g.notes,
              'active': g.active,
              'createdAt': g.createdAt.toIso8601String(),
              'updatedAt': g.updatedAt.toIso8601String(),
              'deletedAt': g.deletedAt?.toIso8601String(),
            },
          )
          .toList(),
      'debts': debts
          .map(
            (d) => {
              'id': d.id,
              'name': d.name,
              'direction': d.direction.name,
              'type': d.type.name,
              'party': name(d.party),
              'initialPrincipalMinor': d.initialPrincipalMinor,
              'currency': d.currency.name,
              'annualRateBasisPoints': d.annualRateBasisPoints,
              'installments': d.installments,
              'installmentMinor': d.installmentMinor,
              'thirdPartyContributionMinor': d.thirdPartyContributionMinor,
              'nextDueDate': d.nextDueDate?.toIso8601String(),
              'paymentDay': d.paymentDay,
              'status': d.status.name,
              'notes': d.notes,
              'createdAt': d.createdAt.toIso8601String(),
              'updatedAt': d.updatedAt.toIso8601String(),
              'deletedAt': d.deletedAt?.toIso8601String(),
            },
          )
          .toList(),
    };
    return _write(
      'copia_nexo_${_stamp()}.json',
      utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
    );
  }

  static pw.Widget _pdfMetric(String label, String value) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    ),
  );
  static String _csvCell(Object? value) =>
      '"${(value ?? '').toString().replaceAll('"', '""')}"';
  static String _masked(String? id) => id == null ? '' : 'Cuenta oculta';
  static String _stamp() =>
      DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  static Future<File> _write(String name, List<int> bytes) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$name');
    return file.writeAsBytes(bytes, flush: true);
  }
}
