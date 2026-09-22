import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../models/transaction.dart';
import '../models/transaction_type.dart';

final _currency = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);
final _dayFormat = DateFormat('d MMM');

/// A single transaction row. Marked `const`-friendly (no closures built
/// inline) and used exclusively inside `ListView.builder` — see
/// docs/performance.md for why that combination matters for a long list.
class TransactionTile extends StatelessWidget {
  final Transaction transaction;

  const TransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final category = transaction.category;
    final isIncome = transaction.type == TransactionType.income;
    final amountColor = isIncome ? AppColors.income : AppColors.expense;
    final sign = isIncome ? '+' : '−';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (category?.materialColor ?? AppColors.primary).withValues(
                alpha: 0.15,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              category?.materialIcon ?? Icons.category,
              color: category?.materialColor ?? AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category?.name ?? 'Uncategorized',
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (transaction.note != null && transaction.note!.isNotEmpty)
                  Text(
                    transaction.note!,
                    style: AppTextStyles.caption.copyWith(
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign${_currency.format(transaction.amount)}',
                style: AppTextStyles.bodyStrong.copyWith(color: amountColor),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (transaction.pendingSync) ...[
                    Icon(Icons.sync, size: 12, color: AppColors.warning),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    _dayFormat.format(transaction.date),
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
