import '../models/transaction_type.dart';

/// Keyword → category-name rules used to auto-categorize an imported bank
/// statement row from its free-text description. This mirrors how a real
/// statement importer works: no ML, just a merchant keyword table, checked
/// against every category for every row — which is exactly why doing it
/// for a large CSV synchronously is expensive enough to jank a UI thread
/// (see docs/threading.md).
class TransactionCategorizer {
  static const Map<String, List<String>> _rules = {
    'Food & Dining': [
      'zomato',
      'swiggy',
      'cafe',
      'restaurant',
      'dining',
      'food',
    ],
    'Transport': [
      'uber',
      'ola',
      'cab',
      'petrol',
      'fuel',
      'metro',
      'taxi',
      'bus',
    ],
    'Shopping': ['amazon', 'flipkart', 'myntra', 'shopping', 'mall', 'store'],
    'Bills & Utilities': [
      'electricity',
      'water bill',
      'recharge',
      'broadband',
      'bill',
      'utility',
    ],
    'Entertainment': [
      'netflix',
      'spotify',
      'movie',
      'cinema',
      'entertainment',
      'prime video',
    ],
    'Health': [
      'pharmacy',
      'doctor',
      'hospital',
      'gym',
      'medical',
      'health',
      'clinic',
    ],
    'Salary': ['salary', 'payroll', 'monthly pay'],
    'Freelance': ['freelance', 'contract payment', 'consulting fee'],
  };

  /// Returns the best-matching category name for [description], or `null`
  /// if nothing matches (caller falls back to "Other").
  ///
  /// Deliberately does a full linear scan of every rule's keyword list for
  /// every call — a normalized-substring match, not a precompiled index —
  /// because that is what a naive real-world categorizer looks like, and
  /// it is the cost that makes categorizing tens of thousands of rows
  /// non-trivial CPU work worth moving off the UI isolate.
  static String? categorize(String description) {
    final normalized = description.trim().toLowerCase();
    String? bestMatch;
    var bestScore = 0;

    for (final entry in _rules.entries) {
      for (final keyword in entry.value) {
        if (normalized.contains(keyword)) {
          // Longer keyword matches are treated as stronger signals.
          if (keyword.length > bestScore) {
            bestScore = keyword.length;
            bestMatch = entry.key;
          }
        }
      }
    }
    return bestMatch;
  }

  static TransactionType typeForCategory(String? categoryName) {
    if (categoryName == 'Salary' || categoryName == 'Freelance') {
      return TransactionType.income;
    }
    return TransactionType.expense;
  }
}
