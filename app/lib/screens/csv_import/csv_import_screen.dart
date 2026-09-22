import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/category_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../services/csv_import_service.dart';
import '../../widgets/responsive_content.dart';

/// Import screen for a bank-statement CSV. Parsing + per-row keyword
/// categorization always runs via [CsvImportService.import], which uses
/// `compute()` to hop to a background isolate — see docs/threading.md.
///
/// The spinning indicator + live frame counter below are not decorative:
/// both are driven by the engine's own frame scheduler, so if the heavy
/// work ever ran on the UI isolate instead, they would visibly stall.
/// Leaving them running smoothly during a real 60k-row import is the
/// in-app version of the proof written up in docs/threading.md.
class CsvImportScreen extends ConsumerStatefulWidget {
  const CsvImportScreen({super.key});

  @override
  ConsumerState<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends ConsumerState<CsvImportScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int _frameCount = 0;
  bool _importing = false;
  CsvImportOutcome? _lastOutcome;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => setState(() => _frameCount++))..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedMonthProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(title: const Text('Import statement')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UI frame ticker: $_frameCount',
                        style: AppTextStyles.caption.copyWith(
                          color: onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Ticks every frame the engine renders. If it keeps counting up smoothly during an import, the UI isolate was never blocked.',
                        style: AppTextStyles.caption.copyWith(
                          color: onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Import a transaction CSV',
                style: AppTextStyles.title.copyWith(color: onSurface),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Columns: date, description, amount. Each row is auto-categorized from its description and queued for sync into $month and beyond.',
                style: AppTextStyles.caption.copyWith(
                  color: onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: _importing
                    ? null
                    : () => _runImport(() => _loadSampleCsv(large: true)),
                icon: const Icon(Icons.dataset_outlined),
                label: const Text('Import bundled sample (60,000 rows)'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _importing
                    ? null
                    : () => _runImport(() => _loadSampleCsv(large: false)),
                icon: const Icon(Icons.dataset_linked_outlined),
                label: const Text('Import bundled sample (25 rows)'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _importing ? null : () => _runImport(_pickCsvFile),
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('Choose a CSV from device'),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_importing) const Center(child: CircularProgressIndicator()),
              if (_error != null)
                Text(
                  _error!,
                  style: AppTextStyles.body.copyWith(color: AppColors.expense),
                ),
              if (_lastOutcome != null) _ImportSummary(outcome: _lastOutcome!),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _loadSampleCsv({required bool large}) async {
    final path = large
        ? 'assets/sample_data/sample_transactions_large.csv'
        : 'assets/sample_data/sample_transactions_small.csv';
    return rootBundle.loadString(path);
  }

  Future<String?> _pickCsvFile() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    final path = result?.path;
    if (path == null) return null;
    return File(path).readAsString();
  }

  Future<void> _runImport(Future<String?> Function() loadCsv) async {
    setState(() {
      _importing = true;
      _error = null;
    });

    try {
      final csvContent = await loadCsv();
      if (csvContent == null) {
        setState(() => _importing = false);
        return;
      }

      final categories = ref.read(categoriesProvider).valueOrNull ?? const [];
      if (categories.isEmpty) {
        setState(() {
          _importing = false;
          _error = 'Categories have not loaded yet — try again in a moment.';
        });
        return;
      }

      final service = CsvImportService();
      final outcome = await service.import(csvContent, categories);

      final month = ref.read(selectedMonthProvider);
      await ref
          .read(transactionsProvider(month).notifier)
          .importTransactions(outcome.transactions);

      if (!mounted) return;
      setState(() {
        _importing = false;
        _lastOutcome = outcome;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _error = 'Import failed: $e';
      });
    }
  }
}

class _ImportSummary extends StatelessWidget {
  final CsvImportOutcome outcome;
  const _ImportSummary({required this.outcome});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import complete',
              style: AppTextStyles.bodyStrong.copyWith(color: AppColors.income),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${outcome.rowCount} rows parsed and categorized',
              style: AppTextStyles.body.copyWith(color: onSurface),
            ),
            Text(
              '${outcome.uncategorizedCount} rows fell back to "Other"',
              style: AppTextStyles.caption.copyWith(
                color: onSurface.withValues(alpha: 0.7),
              ),
            ),
            Text(
              'Background isolate time: ${outcome.elapsed.inMilliseconds} ms',
              style: AppTextStyles.caption.copyWith(
                color: onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
