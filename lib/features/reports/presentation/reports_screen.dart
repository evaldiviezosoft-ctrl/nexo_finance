import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../core/time/lima_time.dart';
import '../../budgets/data/budgets_repository.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/finance_category.dart';
import '../../categories/presentation/category_visuals.dart';
import '../../debts/data/debts_repository.dart';
import '../../debts/domain/debt_calculator.dart';
import '../../debts/domain/debt_record.dart';
import '../../goals/data/goals_repository.dart';
import '../../goals/domain/goal_calculator.dart';
import '../../goals/domain/financial_goal.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../domain/report_calculator.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int months = 6;
  Currency currency = Currency.pen;

  @override
  Widget build(BuildContext context) {
    final transactions =
        ref.watch(transactionsProvider).value?.items ??
        const <FinancialTransaction>[];
    final categories =
        ref.watch(categoriesProvider).value?.items ?? const <FinanceCategory>[];
    final budgets = ref.watch(budgetsProvider).value?.items ?? const [];
    final goals =
        ref.watch(goalsProvider).value?.items ?? const <FinancialGoal>[];
    final debts = ref.watch(debtsProvider).value?.items ?? const <DebtRecord>[];
    final now = DateTime.now().toUtc();
    final localNow = toLimaTime(now);
    final series = ReportCalculator.monthlySeries(
      transactions: transactions,
      reference: now,
      months: months,
      currency: currency,
    );
    final start = limaMidnightUtc(
      localNow.year,
      localNow.month - months + 1,
      1,
    );
    final end = limaMidnightUtc(localNow.year, localNow.month + 1, 1);
    final categoryTotals = ReportCalculator.categoryTotals(
      transactions: transactions,
      start: start,
      end: end,
      currency: currency,
    );
    final globalBudgets = budgets
        .where(
          (b) => b.active && b.currency == currency && b.categoryId == null,
        )
        .toList();
    final categoryBudgets = budgets
        .where(
          (b) => b.active && b.currency == currency && b.categoryId != null,
        )
        .toList();
    final budgetMinor =
        (globalBudgets.isNotEmpty ? globalBudgets : categoryBudgets).fold<int>(
          0,
          (sum, b) => sum + b.amountMinor,
        );
    final daily = ReportCalculator.dailyCumulative(
      transactions: transactions,
      month: now,
      currency: currency,
      budgetMinor: budgetMinor,
      now: now,
    );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reportes'),
          actions: [
            IconButton(
              tooltip: 'Exportar',
              onPressed: () => context.push('/export'),
              icon: const Icon(Icons.file_download_outlined),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Resumen'),
              Tab(text: 'Categorías'),
              Tab(text: 'Plan'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 3, label: Text('3 m')),
                        ButtonSegment(value: 6, label: Text('6 m')),
                        ButtonSegment(value: 12, label: Text('1 año')),
                      ],
                      selected: {months},
                      onSelectionChanged: (v) =>
                          setState(() => months = v.first),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<Currency>(
                    value: currency,
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
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _SummaryTab(
                    series: series,
                    daily: daily,
                    currency: currency,
                    budgetMinor: budgetMinor,
                  ),
                  _CategoriesTab(
                    totals: categoryTotals,
                    categories: categories,
                    currency: currency,
                  ),
                  _PlanTab(
                    goals: goals,
                    debts: debts,
                    transactions: transactions,
                    currency: currency,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({
    required this.series,
    required this.daily,
    required this.currency,
    required this.budgetMinor,
  });
  final List<MonthlyReportPoint> series;
  final List<DailyReportPoint> daily;
  final Currency currency;
  final int budgetMinor;
  @override
  Widget build(BuildContext context) {
    final income = series.fold<int>(0, (s, p) => s + p.incomeMinor),
        expense = series.fold<int>(0, (s, p) => s + p.expenseMinor);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
      children: [
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Ingresos',
                value: Money(income, currency).format(),
                color: AppColors.positive,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric(
                label: 'Gastos',
                value: Money(expense, currency).format(),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric(
                label: 'Ahorro',
                value: Money(income - expense, currency).format(),
                color: AppColors.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ChartCard(
          title: 'Ingresos contra gastos',
          subtitle: 'Toca una barra para ver el monto exacto.',
          child: SizedBox(
            height: 250,
            child: _MonthlyBars(series: series, currency: currency),
          ),
        ),
        const SizedBox(height: 12),
        _ChartCard(
          title: 'Gasto acumulado del mes',
          subtitle: budgetMinor == 0
              ? 'Rojo: real · Azul: proyección al cierre.'
              : 'Rojo: real · Gris: permitido · Azul: proyección.',
          child: SizedBox(
            height: 250,
            child: _DailyLine(points: daily, currency: currency),
          ),
        ),
      ],
    );
  }
}

class _MonthlyBars extends StatelessWidget {
  const _MonthlyBars({required this.series, required this.currency});
  final List<MonthlyReportPoint> series;
  final Currency currency;
  @override
  Widget build(BuildContext context) {
    final maxValue = series.fold<int>(
      1,
      (m, p) => math.max(m, math.max(p.incomeMinor, p.expenseMinor)),
    );
    return BarChart(
      BarChartData(
        maxY: maxValue * 1.2,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= series.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('MMM', 'es_PE').format(series[i].month),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
                  Money(rod.toY.round(), currency).format(),
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
          ),
        ),
        barGroups: List.generate(
          series.length,
          (i) => BarChartGroupData(
            x: i,
            barsSpace: 3,
            barRods: [
              BarChartRodData(
                toY: series[i].incomeMinor.toDouble(),
                width: 9,
                color: AppColors.positive,
                borderRadius: BorderRadius.circular(3),
              ),
              BarChartRodData(
                toY: series[i].expenseMinor.toDouble(),
                width: 9,
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyLine extends StatelessWidget {
  const _DailyLine({required this.points, required this.currency});
  final List<DailyReportPoint> points;
  final Currency currency;
  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<int>(
      1,
      (m, p) => math.max(
        m,
        math.max(p.projectedMinor, math.max(p.actualMinor, p.allowedMinor)),
      ),
    );
    return LineChart(
      LineChartData(
        minX: 1,
        maxX: points.length.toDouble(),
        minY: 0,
        maxY: maxValue * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 5,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map(
                  (s) => LineTooltipItem(
                    '${s.x.toInt()}: ${Money(s.y.round(), currency).format()}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: points
                .where((p) => p.observed)
                .map((p) => FlSpot(p.day.toDouble(), p.actualMinor.toDouble()))
                .toList(),
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: points
                .map((p) => FlSpot(p.day.toDouble(), p.allowedMinor.toDouble()))
                .toList(),
            color: AppColors.textSecondary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: points
                .where((p) => !p.observed)
                .map(
                  (p) => FlSpot(p.day.toDouble(), p.projectedMinor.toDouble()),
                )
                .toList(),
            color: AppColors.info,
            barWidth: 2,
            dashArray: [6, 4],
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}

class _CategoriesTab extends StatefulWidget {
  const _CategoriesTab({
    required this.totals,
    required this.categories,
    required this.currency,
  });
  final Map<String, int> totals;
  final List<FinanceCategory> categories;
  final Currency currency;
  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> {
  int touched = -1;
  @override
  Widget build(BuildContext context) {
    final entries = widget.totals.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    if (entries.isEmpty) {
      return const _Empty(message: 'Aún no hay gastos en este periodo.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
      children: [
        _ChartCard(
          title: 'Distribución por categorías',
          subtitle: 'Toca una sección para resaltarla.',
          child: SizedBox(
            height: 260,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 52,
                sectionsSpace: 2,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) => setState(
                    () => touched =
                        response?.touchedSection?.touchedSectionIndex ?? -1,
                  ),
                ),
                sections: List.generate(entries.length, (i) {
                  final c = widget.categories
                      .where((x) => x.id == entries[i].key)
                      .firstOrNull;
                  final visual = c == null
                      ? CategoryVisualStyle(
                          color: Colors.primaries[i % Colors.primaries.length],
                          icon: Icons.category_rounded,
                        )
                      : categoryVisualStyle(c, fallbackIndex: i);
                  final selected = i == touched;
                  return PieChartSectionData(
                    value: entries[i].value.toDouble(),
                    color: visual.color,
                    radius: selected ? 66 : 58,
                    title:
                        '${(entries[i].value / total * 100).toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(entries.length, (i) {
          final e = entries[i];
          final c = widget.categories.where((x) => x.id == e.key).firstOrNull;
          final visual = c == null
              ? CategoryVisualStyle(
                  color: Colors.primaries[i % Colors.primaries.length],
                  icon: Icons.category_rounded,
                )
              : categoryVisualStyle(c, fallbackIndex: i);
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: visual.color.withValues(alpha: .16),
              child: Icon(visual.icon, color: visual.color, size: 20),
            ),
            title: Text(c?.name ?? 'Sin categoría'),
            subtitle: Text('${(e.value / total * 100).toStringAsFixed(1)}%'),
            trailing: Text(
              Money(e.value, widget.currency).format(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          );
        }),
      ],
    );
  }
}

class _PlanTab extends StatelessWidget {
  const _PlanTab({
    required this.goals,
    required this.debts,
    required this.transactions,
    required this.currency,
  });
  final List<FinancialGoal> goals;
  final List<DebtRecord> debts;
  final List<FinancialTransaction> transactions;
  final Currency currency;
  @override
  Widget build(BuildContext context) {
    final activeDebts = debts
        .where((d) => d.status == DebtStatus.active && d.currency == currency)
        .toList();
    final activeGoals = goals
        .where((g) => g.active && g.currency == currency)
        .toList();
    if (activeDebts.isEmpty && activeGoals.isEmpty) {
      return const _Empty(
        message: 'Crea metas o deudas para ver su evolución.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
      children: [
        if (activeDebts.isNotEmpty)
          _ChartCard(
            title: 'Deudas pendientes',
            subtitle: 'Saldo reconstruido desde los pagos.',
            child: Column(
              children: activeDebts.map<Widget>((d) {
                final p = DebtCalculator.position(d, transactions);
                final ratio = d.initialPrincipalMinor == 0
                    ? 0.0
                    : p.remainingMinor / d.initialPrincipalMinor;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(d.name)),
                          Text(Money(p.remainingMinor, d.currency).format()),
                        ],
                      ),
                      const SizedBox(height: 5),
                      LinearProgressIndicator(
                        value: ratio.clamp(0, 1),
                        minHeight: 9,
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.warning,
                        backgroundColor: AppColors.border,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        if (activeDebts.isNotEmpty && activeGoals.isNotEmpty)
          const SizedBox(height: 12),
        if (activeGoals.isNotEmpty)
          _ChartCard(
            title: 'Metas financieras',
            subtitle: 'Avance real respecto al objetivo.',
            child: Column(
              children: activeGoals.map<Widget>((g) {
                final p = GoalCalculator.calculate(g, transactions);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(g.name)),
                          Text('${(p.progress * 100).toStringAsFixed(0)}%'),
                        ],
                      ),
                      const SizedBox(height: 5),
                      LinearProgressIndicator(
                        value: p.progress.clamp(0, 1),
                        minHeight: 9,
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.positive,
                        backgroundColor: AppColors.border,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title, subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    ),
  );
}
