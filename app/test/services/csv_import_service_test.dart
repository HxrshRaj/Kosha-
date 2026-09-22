import 'package:flutter_test/flutter_test.dart';
import 'package:kosha/services/csv_import_service.dart';

import '../support/fixtures.dart';

const _sampleCsv = '''
date,description,amount
2026-09-01,ZOMATO ORDER #1,450.50
2026-09-02,UBER RIDE #2,120.00
2026-09-03,MONTHLY SALARY CREDIT,50000.00
2026-09-04,totally unknown merchant,75.00
''';

void main() {
  group('CsvImportService parsing/categorization', () {
    test('parses every data row and assigns categories correctly', () {
      final categories = testCategories();
      final result = CsvImportService.parseAndCategorizeSync(_sampleCsv, categories);

      expect(result['rowCount'], 4);
      final transactions = (result['transactions'] as List).cast<Map<String, dynamic>>();
      expect(transactions.length, 4);

      final foodRow = transactions.firstWhere((t) => (t['note'] as String).contains('ZOMATO'));
      expect((foodRow['category'] as Map)['name'], 'Food & Dining');
      expect(foodRow['type'], 'expense');

      final transportRow = transactions.firstWhere((t) => (t['note'] as String).contains('UBER'));
      expect((transportRow['category'] as Map)['name'], 'Transport');

      final salaryRow = transactions.firstWhere((t) => (t['note'] as String).contains('SALARY'));
      expect((salaryRow['category'] as Map)['name'], 'Salary');
      expect(salaryRow['type'], 'income');

      // 1 row does not match any keyword rule and should fall back to Other.
      expect(result['uncategorizedCount'], 1);
      final fallbackRow = transactions.firstWhere((t) => (t['note'] as String).contains('unknown'));
      expect((fallbackRow['category'] as Map)['name'], 'Other');
    });

    test('every generated row gets a unique client_id', () {
      final categories = testCategories();
      final result = CsvImportService.parseAndCategorizeSync(_sampleCsv, categories);
      final transactions = (result['transactions'] as List).cast<Map<String, dynamic>>();
      final ids = transactions.map((t) => t['client_id']).toSet();
      expect(ids.length, transactions.length);
    });

    test('skips malformed rows instead of throwing', () {
      const malformed = 'date,description,amount\n2026-09-01,missing amount\n';
      final result = CsvImportService.parseAndCategorizeSync(malformed, testCategories());
      final transactions = (result['transactions'] as List).cast<Map<String, dynamic>>();
      expect(transactions, isEmpty);
    });
  });
}
