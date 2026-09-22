import 'package:hive_flutter/hive_flutter.dart';

import '../models/category.dart';
import '../models/transaction.dart';

/// Offline cache backed by Hive. See README "Local storage" for why Hive
/// was chosen over sqflite: the app has no relational local queries (all
/// aggregation happens server-side via /summary), so a schema-less
/// key/value store that round-trips the same JSON shape as the REST API is
/// simpler than standing up SQL tables + a migration story for two boxes.
///
/// Transactions are keyed by `client_id` (not server id) because an
/// offline-created transaction has no server id yet — that's also the key
/// SyncService uses to reconcile local and remote state.
class LocalCacheService {
  static const _transactionsBoxName = 'transactions';
  static const _categoriesBoxName = 'categories';
  static const _metaBoxName = 'meta';

  Box<Map>? _transactionsBox;
  Box<Map>? _categoriesBox;
  Box<dynamic>? _metaBox;

  /// [testPath] lets unit tests point Hive at a temp directory via
  /// `Hive.init` instead of `Hive.initFlutter` (which needs the
  /// path_provider platform channel that isn't available under plain
  /// `flutter_test`). Production code never passes it.
  Future<void> init({String? testPath}) async {
    if (testPath != null) {
      Hive.init(testPath);
    } else {
      await Hive.initFlutter();
    }
    _transactionsBox = await Hive.openBox<Map>(_transactionsBoxName);
    _categoriesBox = await Hive.openBox<Map>(_categoriesBoxName);
    _metaBox = await Hive.openBox(_metaBoxName);
  }

  Box<Map> get _transactions => _transactionsBox!;
  Box<Map> get _categories => _categoriesBox!;
  Box get _meta => _metaBox!;

  // ---- Transactions ----

  List<Transaction> getTransactions({String? month}) {
    final all =
        _transactions.values
            .map(
              (raw) =>
                  Transaction.fromCacheJson(Map<String, dynamic>.from(raw)),
            )
            .where((t) => month == null || _monthKey(t.date) == month)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return all;
  }

  List<Transaction> getPendingTransactions() =>
      getTransactions().where((t) => t.pendingSync).toList();

  /// Replaces the cache for [month] with the server's copy while preserving
  /// any not-yet-synced local rows for that month (see SyncService for the
  /// full reconciliation policy — this method is the low-level primitive).
  Future<void> replaceMonth(
    String month,
    List<Transaction> serverTransactions,
  ) async {
    final pendingForMonth = getTransactions(month: month)
        .where((t) => t.pendingSync);
    final keysForMonth = _transactions.keys.where((k) {
      final raw = _transactions.get(k);
      if (raw == null) return false;
      final date = DateTime.parse(raw['date'] as String);
      return _monthKey(date) == month;
    }).toList();
    await _transactions.deleteAll(keysForMonth);

    for (final t in serverTransactions) {
      await _transactions.put(t.clientId, t.toCacheJson());
    }
    for (final t in pendingForMonth) {
      await _transactions.put(t.clientId, t.toCacheJson());
    }
  }

  Future<void> upsertTransaction(Transaction transaction) =>
      _transactions.put(transaction.clientId, transaction.toCacheJson());

  Future<void> upsertMany(List<Transaction> transactions) async {
    for (final t in transactions) {
      await _transactions.put(t.clientId, t.toCacheJson());
    }
  }

  Future<void> deleteTransaction(String clientId) =>
      _transactions.delete(clientId);

  static String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  // ---- Categories ----

  List<Category> getCategories() => _categories.values
      .map((raw) => Category.fromJson(Map<String, dynamic>.from(raw)))
      .toList();

  Future<void> saveCategories(List<Category> categories) async {
    await _categories.clear();
    for (final c in categories) {
      await _categories.put(c.id, c.toJson());
    }
  }

  // ---- Sync metadata ----

  DateTime? get lastSyncedAt {
    final raw = _meta.get('last_synced_at') as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setLastSyncedAt(DateTime time) =>
      _meta.put('last_synced_at', time.toIso8601String());
}
