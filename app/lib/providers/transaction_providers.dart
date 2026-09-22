import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/network/api_exception.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/transaction_type.dart';
import 'core_providers.dart';

final selectedMonthProvider = StateProvider<String>(
  (ref) => DateFormat('yyyy-MM').format(DateTime.now()),
);

/// Per-month transaction list. Reads the cache synchronously on build
/// (instant, works offline), then kicks off a push-then-pull sync in the
/// background — the "last known data immediately" behavior from the
/// README's offline-first requirement.
class TransactionsNotifier
    extends FamilyAsyncNotifier<List<Transaction>, String> {
  bool _syncFailed = false;
  bool get syncFailed => _syncFailed;

  @override
  Future<List<Transaction>> build(String month) async {
    final sync = ref.watch(syncServiceProvider);
    final cached = sync.cachedTransactions(month: month);
    // Kick off the network reconciliation without blocking the first paint.
    Future.microtask(() => refresh());
    return cached;
  }

  Future<void> refresh() async {
    final sync = ref.read(syncServiceProvider);
    final result = await sync.sync(arg);
    result.when(
      ok: (transactions) {
        _syncFailed = false;
        state = AsyncData(transactions);
      },
      err: (e) {
        _syncFailed = true;
        // Keep showing whatever is cached; just flag that refresh failed.
        if (e is! NetworkException) {
          debugPrint('Sync failed for $arg: $e');
        }
        state = AsyncData(sync.cachedTransactions(month: arg));
      },
    );
  }

  Future<ApiException?> addTransaction({
    required double amount,
    required TransactionType type,
    required int categoryId,
    required Category? category,
    String? note,
    required DateTime date,
  }) async {
    final sync = ref.read(syncServiceProvider);
    final result = await sync.createTransaction(
      amount: amount,
      type: type,
      categoryId: categoryId,
      category: category,
      note: note,
      date: date,
    );
    state = AsyncData(sync.cachedTransactions(month: arg));
    return result.when(ok: (_) => null, err: (e) => e);
  }

  Future<void> importTransactions(List<Transaction> imported) async {
    final cache = ref.read(localCacheServiceProvider);
    await cache.upsertMany(imported);
    final sync = ref.read(syncServiceProvider);
    state = AsyncData(sync.cachedTransactions(month: arg));
    await refresh();
  }
}

final transactionsProvider =
    AsyncNotifierProviderFamily<
      TransactionsNotifier,
      List<Transaction>,
      String
    >(TransactionsNotifier.new);
