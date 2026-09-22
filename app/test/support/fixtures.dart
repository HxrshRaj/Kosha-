import 'package:kosha/models/category.dart';
import 'package:kosha/models/transaction.dart';
import 'package:kosha/models/transaction_type.dart';

/// Mirrors the backend's DEFAULT_CATEGORIES seed (backend/app/main.py) so
/// tests exercise the same category set the real app would load.
List<Category> testCategories() => const [
      Category(id: 1, name: 'Food & Dining', type: TransactionType.expense, color: '#FF6B6B', icon: 'restaurant', monthlyBudget: 8000),
      Category(id: 2, name: 'Transport', type: TransactionType.expense, color: '#4D96FF', icon: 'directions_car', monthlyBudget: 3000),
      Category(id: 3, name: 'Shopping', type: TransactionType.expense, color: '#F7B733', icon: 'shopping_bag', monthlyBudget: 5000),
      Category(id: 4, name: 'Bills & Utilities', type: TransactionType.expense, color: '#6C63FF', icon: 'receipt_long', monthlyBudget: 6000),
      Category(id: 5, name: 'Entertainment', type: TransactionType.expense, color: '#00C2A8', icon: 'movie', monthlyBudget: 2000),
      Category(id: 6, name: 'Health', type: TransactionType.expense, color: '#FF8FB1', icon: 'favorite', monthlyBudget: 2500),
      Category(id: 7, name: 'Salary', type: TransactionType.income, color: '#2ECC71', icon: 'payments'),
      Category(id: 8, name: 'Freelance', type: TransactionType.income, color: '#27AE60', icon: 'work'),
      Category(id: 9, name: 'Other', type: TransactionType.expense, color: '#A0A0A0', icon: 'more_horiz'),
    ];

Transaction testTransaction({
  int? id,
  String clientId = 'test-client-id',
  double amount = 100,
  TransactionType type = TransactionType.expense,
  int categoryId = 1,
  Category? category,
  String? note,
  DateTime? date,
  bool pendingSync = false,
}) {
  final categories = testCategories();
  return Transaction(
    id: id,
    clientId: clientId,
    amount: amount,
    type: type,
    categoryId: categoryId,
    category: category ?? categories.firstWhere((c) => c.id == categoryId),
    note: note,
    date: date ?? DateTime(2026, 9, 10),
    createdAt: DateTime(2026, 9, 10),
    pendingSync: pendingSync,
  );
}
