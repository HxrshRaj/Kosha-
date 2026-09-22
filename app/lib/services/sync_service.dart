import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import '../core/network/api_exception.dart';
import '../core/utils/result.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/transaction_type.dart';
import 'local_cache_service.dart';
import 'transaction_api_service.dart';

/// Offline-first reconciliation between the local Hive cache and the
/// backend. The policy, spelled out because "sync" hides a lot of
/// decisions:
///
/// 1. Reads always return the cache immediately — the UI never blocks on
///    the network (see README "Offline-first behavior").
/// 2. A transaction created offline is written to the cache right away
///    with `pendingSync: true` and a client-generated [Uuid] `client_id`.
///    It is NOT lost, and it is NOT silently dropped if the network never
///    comes back — it just stays queued.
/// 3. On refresh (pull-to-refresh, reconnect, or app start), pending rows
///    are pushed first via the idempotent `/transactions/bulk` endpoint
///    (keyed by `client_id`, so retrying a partially-applied push never
///    double-creates a transaction), THEN the server's copy for that month
///    is fetched and replaces the cache — except any row that is *still*
///    pending (push failed again) is preserved rather than being
///    overwritten by an incomplete server view. This is why the sync is
///    "push-then-pull" rather than a blind last-write-wins overwrite.
class SyncService {
  final TransactionApiService _api;
  final LocalCacheService _cache;
  final Connectivity _connectivity;
  final Uuid _uuid = const Uuid();

  SyncService(this._api, this._cache, this._connectivity);

  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  List<Transaction> cachedTransactions({String? month}) =>
      _cache.getTransactions(month: month);

  /// Creates a transaction optimistically: cached instantly, pushed to the
  /// backend immediately if online, otherwise left queued for the next
  /// sync. Always succeeds from the caller's point of view (the write is
  /// never lost) — the returned [Result] only reports whether the network
  /// push happened right now.
  Future<Result<Transaction>> createTransaction({
    required double amount,
    required TransactionType type,
    required int categoryId,
    required Category? category,
    String? note,
    required DateTime date,
  }) async {
    final draft = Transaction(
      id: null,
      clientId: _uuid.v4(),
      amount: amount,
      type: type,
      categoryId: categoryId,
      category: category,
      note: note,
      date: date,
      createdAt: DateTime.now(),
      pendingSync: true,
    );
    await _cache.upsertTransaction(draft);

    if (!await isOnline) {
      return Result.ok(draft);
    }

    final result = await _api.create(draft);
    return result.when(
      ok: (created) async {
        final synced = created.copyWith(pendingSync: false);
        await _cache.upsertTransaction(synced);
        return Result.ok(synced);
      },
      err: (_) => Result.ok(draft), // stays queued; UI already shows it
    );
  }

  /// Push-then-pull reconciliation for one month. Returns the resulting
  /// cached list either way; the [Result] communicates whether the network
  /// round trip succeeded so the UI can show a "couldn't refresh" banner
  /// without losing the data already on screen.
  Future<Result<List<Transaction>>> sync(String month) async {
    if (!await isOnline) {
      return Result.err(const NetworkException());
    }

    final pending = _cache.getPendingTransactions();
    if (pending.isNotEmpty) {
      final pushResult = await _api.bulkCreate(pending);
      pushResult.when(
        ok: (synced) {
          for (final t in synced) {
            _cache.upsertTransaction(t.copyWith(pendingSync: false));
          }
        },
        err: (_) {}, // still pending; will retry on next sync
      );
    }

    final fetchResult = await _api.list(month: month);
    return fetchResult.when(
      ok: (serverTransactions) async {
        await _cache.replaceMonth(month, serverTransactions);
        await _cache.setLastSyncedAt(DateTime.now());
        return Result.ok(_cache.getTransactions(month: month));
      },
      err: (e) => Result.err(e),
    );
  }
}
