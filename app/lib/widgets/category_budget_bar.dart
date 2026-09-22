import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../models/summary.dart';

final _currency = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

class CategoryBudgetBar extends StatelessWidget {
  final CategorySpend spend;

  const CategoryBudgetBar({super.key, required this.spend});

  @override
  Widget build(BuildContext context) {
    final color = Color(
      int.parse('FF${spend.color.replaceFirst('#', '')}', radix: 16),
    );
    final budget = spend.budget;
    final progress = (budget != null && budget > 0)
        ? (spend.total / budget).clamp(0.0, 1.0)
        : null;
    final overBudget = budget != null && spend.total > budget;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  spend.categoryName,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                budget != null
                    ? '${_currency.format(spend.total)} / ${_currency.format(budget)}'
                    : _currency.format(spend.total),
                style: AppTextStyles.caption.copyWith(
                  color: overBudget
                      ? AppColors.expense
                      : Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(
                  overBudget ? AppColors.expense : color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
