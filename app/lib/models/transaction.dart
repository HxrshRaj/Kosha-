import 'category.dart';
import 'transaction_type.dart';

/// A transaction as displayed in the UI. [id] is null for a transaction
/// created while offline that the backend hasn't assigned an id to yet —
/// [clientId] is the stable identity used to reconcile it once synced (see
/// SyncService and README "Offline-first behavior").
class Transaction {
  final int? id;
  final String clientId;
  final double amount;
  final TransactionType type;
  final int categoryId;
  final Category? category;
  final String? note;
  final DateTime date;
  final DateTime? createdAt;
  final bool pendingSync;

  const Transaction({
    required this.id,
    required this.clientId,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.category,
    required this.note,
    required this.date,
    required this.createdAt,
    this.pendingSync = false,
  });

  Transaction copyWith({int? id, bool? pendingSync}) => Transaction(
    id: id ?? this.id,
    clientId: clientId,
    amount: amount,
    type: type,
    categoryId: categoryId,
    category: category,
    note: note,
    date: date,
    createdAt: createdAt,
    pendingSync: pendingSync ?? this.pendingSync,
  );

  factory Transaction.fromApiJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as int,
    clientId: (json['client_id'] as String?) ?? 'server-${json['id']}',
    amount: (json['amount'] as num).toDouble(),
    type: TransactionType.fromJson(json['type'] as String),
    categoryId: json['category_id'] as int,
    category: json['category'] != null
        ? Category.fromJson(json['category'] as Map<String, dynamic>)
        : null,
    note: json['note'] as String?,
    date: DateTime.parse(json['date'] as String),
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
  );

  Map<String, dynamic> toCreateJson() => {
    'amount': amount,
    'type': type.toJson(),
    'category_id': categoryId,
    'note': note,
    'date': _dateOnly(date),
    'client_id': clientId,
  };

  /// Cache round-trip (Hive), distinct from the API wire format because it
  /// must also carry [pendingSync] and survive without a server [id].
  factory Transaction.fromCacheJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as int?,
    clientId: json['client_id'] as String,
    amount: (json['amount'] as num).toDouble(),
    type: TransactionType.fromJson(json['type'] as String),
    categoryId: json['category_id'] as int,
    category: json['category'] != null
        ? Category.fromJson(Map<String, dynamic>.from(json['category'] as Map))
        : null,
    note: json['note'] as String?,
    date: DateTime.parse(json['date'] as String),
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    pendingSync: json['pending_sync'] as bool? ?? false,
  );

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'client_id': clientId,
    'amount': amount,
    'type': type.toJson(),
    'category_id': categoryId,
    'category': category?.toJson(),
    'note': note,
    'date': _dateOnly(date),
    'created_at': createdAt?.toIso8601String(),
    'pending_sync': pendingSync,
  };

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
