import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/summary.dart';
import '../../providers/summary_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/category_budget_bar.dart';
import '../../widgets/responsive_content.dart';
import '../../widgets/state_views.dart';

final _currency = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider(month));
    final year = int.parse(month.split('-')[0]);
    final yearlyAsync = ref.watch(yearlySummaryProvider(year));

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorStateView(
          message: "Analytics need a connection.\n${error.userMessage}",
          onRetry: () => ref.invalidate(monthlySummaryProvider(month)),
        ),
        data: (summary) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(monthlySummaryProvider(month)),
          child: ResponsiveContent(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _NetCard(summary: summary),
                const SizedBox(height: AppSpacing.lg),
                if (summary.byCategory.isNotEmpty) ...[
                  Text(
                    'Spending by category',
                    style: AppTextStyles.title.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 200,
                    child: _CategoryPieChart(byCategory: summary.byCategory),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Column(
                        children: summary.byCategory
                            .map((c) => CategoryBudgetBar(spend: c))
                            .toList(),
                      ),
                    ),
                  ),
                ] else
                  const EmptyStateView(
                    icon: Icons.pie_chart_outline_rounded,
                    title: 'No spending yet',
                    message: 'Add a transaction this month to see your breakdown here.',
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Last 12 months',
                  style: AppTextStyles.title.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 180,
                  child: yearlyAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => const SizedBox.shrink(),
                    data: (yearly) => _YearlyBarChart(months: yearly.months),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NetCard extends StatelessWidget {
  final MonthlySummary summary;
  const _NetCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NET THIS MONTH',
              style: AppTextStyles.overline.copyWith(
                color: onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _currency.format(summary.net),
              style: AppTextStyles.amountLg.copyWith(
                color: summary.net >= 0 ? AppColors.income : AppColors.expense,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _MiniStat(
                  label: 'Income',
                  value: summary.totalIncome,
                  color: AppColors.income,
                ),
                const SizedBox(width: AppSpacing.lg),
                _MiniStat(
                  label: 'Expense',
                  value: summary.totalExpense,
                  color: AppColors.expense,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
        Text(
          _currency.format(value),
          style: AppTextStyles.bodyStrong.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  final List<CategorySpend> byCategory;
  const _CategoryPieChart({required this.byCategory});

  @override
  Widget build(BuildContext context) {
    final total = byCategory.fold<double>(0, (sum, c) => sum + c.total);
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: byCategory.map((c) {
          final color = Color(
            int.parse('FF${c.color.replaceFirst('#', '')}', radix: 16),
          );
          final pct = total == 0 ? 0.0 : (c.total / total) * 100;
          return PieChartSectionData(
            value: c.total,
            color: color,
            title: '${pct.toStringAsFixed(0)}%',
            radius: 56,
            titleStyle: AppTextStyles.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _YearlyBarChart extends StatelessWidget {
  final List<MonthPoint> months;
  const _YearlyBarChart({required this.months});

  @override
  Widget build(BuildContext context) {
    final maxY = months.fold<double>(
      0,
      (max, m) =>
          [max, m.totalIncome, m.totalExpense].reduce((a, b) => a > b ? a : b),
    );
    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 100 : maxY * 1.2,
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
                final index = value.toInt();
                if (index < 0 || index >= months.length) {
                  return const SizedBox.shrink();
                }
                final monthNum = int.parse(months[index].month.split('-')[1]);
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('MMM').format(DateTime(2024, monthNum)),
                    style: AppTextStyles.caption,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < months.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: months[i].totalExpense,
                  color: AppColors.expense,
                  width: 8,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
