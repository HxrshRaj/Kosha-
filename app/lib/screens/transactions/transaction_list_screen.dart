import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/transaction_type.dart';
import '../../providers/core_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/responsive_content.dart';
import '../../widgets/state_views.dart';
import '../../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';

final _currency = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);
final _monthLabelFormat = DateFormat('MMMM yyyy');

class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final transactionsAsync = ref.watch(transactionsProvider(month));
    final isOnlineAsync = ref.watch(connectivityStatusProvider);
    final isOffline = isOnlineAsync.valueOrNull == false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kosha'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shiftMonth(ref, -1),
          ),
          Center(
            child: Text(
              _monthLabelFormat.format(DateFormat('yyyy-MM').parse(month)),
              style: AppTextStyles.caption,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _shiftMonth(ref, 1),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AddTransactionScreen(month: month)),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: Column(
        children: [
          if (isOffline) const OfflineBanner(),
          Expanded(
            child: transactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorStateView(
                message: error.toString(),
                onRetry: () =>
                    ref.read(transactionsProvider(month).notifier).refresh(),
              ),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.receipt_long_outlined,
                    title: 'No transactions yet',
                    message: 'Tap "Add" to record your first transaction for this month.',
                  );
                }
                final income = transactions
                    .where((t) => t.type == TransactionType.income)
                    .fold<double>(0, (sum, t) => sum + t.amount);
                final expense = transactions
                    .where((t) => t.type == TransactionType.expense)
                    .fold<double>(0, (sum, t) => sum + t.amount);

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(transactionsProvider(month).notifier).refresh(),
                  child: ResponsiveContent(
                    child: ListView.builder(
                      // +1 for the summary header, so the whole screen
                      // (header included) is one scrollable, lazily-built list.
                      itemCount: transactions.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _MonthTotalsHeader(
                            income: income,
                            expense: expense,
                          );
                        }
                        final transaction = transactions[index - 1];
                        return RepaintBoundary(
                          key: ValueKey(transaction.clientId),
                          child: TransactionTile(transaction: transaction),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _shiftMonth(WidgetRef ref, int delta) {
    final current = DateFormat('yyyy-MM')
        .parse(ref.read(selectedMonthProvider));
    final shifted = DateTime(current.year, current.month + delta);
    ref.read(selectedMonthProvider.notifier).state = DateFormat('yyyy-MM')
        .format(shifted);
  }
}

class _MonthTotalsHeader extends StatelessWidget {
  final double income;
  final double expense;

  const _MonthTotalsHeader({required this.income, required this.expense});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: _TotalCard(
              label: 'Income',
              amount: income,
              color: AppColors.income,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _TotalCard(
              label: 'Expense',
              amount: expense,
              color: AppColors.expense,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _TotalCard({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: AppTextStyles.overline.copyWith(color: color),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _currency.format(amount),
              style: AppTextStyles.title.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
