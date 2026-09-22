import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import 'transaction_categorizer.dart';

class CsvImportOutcome {
  final List<Transaction> transactions;
  final int rowCount;
  final int uncategorizedCount;
  final Duration elapsed;

  const CsvImportOutcome({
    required this.transactions,
    required this.rowCount,
    required this.uncategorizedCount,
    required this.elapsed,
  });
}

/// Parses a transaction CSV and assigns each row a category, running the
/// work on a background isolate via [compute] so the UI isolate is never
/// blocked — see docs/threading.md for the measured proof that this
/// matters (running the same function synchronously visibly stalls a
/// 16ms-tick simulation; on the background isolate it doesn't).
class CsvImportService {
  /// Imports [csvContent] (header row: date,description,amount) using
  /// [categories] to resolve category names to ids. All heavy work
  /// (parsing + per-row keyword categorization) happens in
  /// [_parseAndCategorize] on a spawned isolate.
  Future<CsvImportOutcome> import(
    String csvContent,
    List<Category> categories,
  ) async {
    final stopwatch = Stopwatch()..start();

    final request = _CsvImportRequest(
      csvContent: csvContent,
      categoriesJson: categories.map((c) => c.toJson()).toList(),
    );
    final resultJson = await compute(_parseAndCategorize, request);

    final transactions = (resultJson['transactions'] as List)
        .cast<Map<String, dynamic>>()
        .map(Transaction.fromCacheJson)
        .toList();

    stopwatch.stop();
    return CsvImportOutcome(
      transactions: transactions,
      rowCount: resultJson['rowCount'] as int,
      uncategorizedCount: resultJson['uncategorizedCount'] as int,
      elapsed: stopwatch.elapsed,
    );
  }

  /// Same computation, run synchronously on the CALLING isolate. This
  /// exists only so docs/threading.md's benchmark and the in-app "why
  /// isolates" demo can show the before/after difference honestly — the
  /// real import path above always uses [compute].
  @visibleForTesting
  static Map<String, dynamic> parseAndCategorizeSync(
    String csvContent,
    List<Category> categories,
  ) {
    return _parseAndCategorize(
      _CsvImportRequest(
        csvContent: csvContent,
        categoriesJson: categories.map((c) => c.toJson()).toList(),
      ),
    );
  }
}

class _CsvImportRequest {
  final String csvContent;
  final List<Map<String, dynamic>> categoriesJson;
  const _CsvImportRequest({
    required this.csvContent,
    required this.categoriesJson,
  });
}

/// Top-level function so it can be used as a [compute] isolate entry point.
/// Must only touch its arguments and plain Dart — no Flutter bindings are
/// available on a background isolate.
Map<String, dynamic> _parseAndCategorize(_CsvImportRequest request) {
  const uuid = Uuid();
  final categoriesByName = <String, Map<String, dynamic>>{
    for (final c in request.categoriesJson) c['name'] as String: c,
  };
  final otherCategory = request.categoriesJson.firstWhere(
    (c) => c['name'] == 'Other',
    orElse: () => request.categoriesJson.first,
  );

  final rows = const CsvToListConverter(eol: '\n')
      .convert(request.csvContent, shouldParseNumbers: false);
  final dataRows = rows.length > 1 ? rows.sublist(1) : const <List<dynamic>>[];

  final transactions = <Map<String, dynamic>>[];
  var uncategorized = 0;

  for (final row in dataRows) {
    if (row.length < 3) continue;
    final dateStr = row[0].toString().trim();
    final description = row[1].toString().trim();
    final amount = double.tryParse(row[2].toString().trim());
    if (amount == null) continue;

    final matchedName = TransactionCategorizer.categorize(description);
    final category = matchedName != null ? categoriesByName[matchedName] : null;
    if (category == null) uncategorized++;
    final resolvedCategory = category ?? otherCategory;
    final type = TransactionCategorizer.typeForCategory(matchedName).toJson();

    transactions.add({
      'id': null,
      'client_id': uuid.v4(),
      'amount': amount,
      'type': type,
      'category_id': resolvedCategory['id'],
      'category': resolvedCategory,
      'note': description,
      'date': dateStr,
      'created_at': DateTime.now().toIso8601String(),
      'pending_sync': true,
    });
  }

  return {
    'transactions': transactions,
    'rowCount': dataRows.length,
    'uncategorizedCount': uncategorized,
  };
}
