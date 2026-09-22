import 'package:flutter_test/flutter_test.dart';
import 'package:kosha/models/transaction_type.dart';
import 'package:kosha/services/transaction_categorizer.dart';

void main() {
  group('TransactionCategorizer.categorize', () {
    test('matches food merchants', () {
      expect(TransactionCategorizer.categorize('ZOMATO ORDER #123456'), 'Food & Dining');
      expect(TransactionCategorizer.categorize('  swiggy order #999  '), 'Food & Dining');
    });

    test('matches transport merchants', () {
      expect(TransactionCategorizer.categorize('UBER RIDE #55'), 'Transport');
      expect(TransactionCategorizer.categorize('Petrol pump #1'), 'Transport');
    });

    test('matches income descriptions', () {
      expect(TransactionCategorizer.categorize('MONTHLY SALARY CREDIT'), 'Salary');
      expect(TransactionCategorizer.categorize('Freelance payment received'), 'Freelance');
    });

    test('returns null when nothing matches', () {
      expect(TransactionCategorizer.categorize('random unrecognized text'), isNull);
    });

    test('prefers the longer, more specific keyword match', () {
      // "bill" alone would match Bills & Utilities; ensure a longer,
      // more specific keyword elsewhere does not get shadowed by it.
      expect(TransactionCategorizer.categorize('electricity bill payment'), 'Bills & Utilities');
    });
  });

  group('TransactionCategorizer.typeForCategory', () {
    test('Salary and Freelance are income', () {
      expect(TransactionCategorizer.typeForCategory('Salary'), TransactionType.income);
      expect(TransactionCategorizer.typeForCategory('Freelance'), TransactionType.income);
    });

    test('everything else is expense', () {
      expect(TransactionCategorizer.typeForCategory('Food & Dining'), TransactionType.expense);
      expect(TransactionCategorizer.typeForCategory(null), TransactionType.expense);
    });
  });
}
