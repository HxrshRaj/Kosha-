import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kosha/services/local_cache_service.dart';

import '../support/fixtures.dart';

void main() {
  late Directory tempDir;
  late LocalCacheService cache;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kosha_cache_test_');
    cache = LocalCacheService();
    await cache.init(testPath: tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('upsertTransaction then getTransactions round-trips the data', () async {
    final t = testTransaction(clientId: 'c1', amount: 250, date: DateTime(2026, 9, 5));
    await cache.upsertTransaction(t);

    final cached = cache.getTransactions(month: '2026-09');
    expect(cached, hasLength(1));
    expect(cached.single.amount, 250);
    expect(cached.single.clientId, 'c1');
  });

  test('getTransactions filters by month', () async {
    await cache.upsertTransaction(testTransaction(clientId: 'sep', date: DateTime(2026, 9, 5)));
    await cache.upsertTransaction(testTransaction(clientId: 'oct', date: DateTime(2026, 10, 5)));

    expect(cache.getTransactions(month: '2026-09').map((t) => t.clientId), ['sep']);
    expect(cache.getTransactions(month: '2026-10').map((t) => t.clientId), ['oct']);
    expect(cache.getTransactions(), hasLength(2));
  });

  test('getPendingTransactions returns only rows awaiting sync', () async {
    await cache.upsertTransaction(testTransaction(clientId: 'synced', pendingSync: false));
    await cache.upsertTransaction(testTransaction(clientId: 'pending', pendingSync: true));

    final pending = cache.getPendingTransactions();
    expect(pending.map((t) => t.clientId), ['pending']);
  });

  test('replaceMonth overwrites server-known rows but preserves still-pending local ones', () async {
    // A transaction created offline (pending) and one already synced,
    // both dated in September.
    await cache.upsertTransaction(
      testTransaction(clientId: 'offline-1', pendingSync: true, date: DateTime(2026, 9, 12)),
    );
    await cache.upsertTransaction(
      testTransaction(clientId: 'old-server-1', id: 1, pendingSync: false, date: DateTime(2026, 9, 1)),
    );

    // Server now returns a fresh view of September that does NOT include
    // the still-pending offline row (it hasn't reached the server yet).
    final serverCopy = [
      testTransaction(clientId: 'old-server-1', id: 1, pendingSync: false, date: DateTime(2026, 9, 1)),
      testTransaction(clientId: 'server-2', id: 2, pendingSync: false, date: DateTime(2026, 9, 20)),
    ];
    await cache.replaceMonth('2026-09', serverCopy);

    final result = cache.getTransactions(month: '2026-09');
    final clientIds = result.map((t) => t.clientId).toSet();

    // The pending offline row must survive the overwrite — this is the
    // core "don't blindly overwrite" guarantee from the sync strategy.
    expect(clientIds, {'offline-1', 'old-server-1', 'server-2'});
    expect(result.firstWhere((t) => t.clientId == 'offline-1').pendingSync, isTrue);
  });

  test('categories save and load', () async {
    final categories = testCategories();
    await cache.saveCategories(categories);
    final loaded = cache.getCategories();
    expect(loaded.map((c) => c.name).toSet(), categories.map((c) => c.name).toSet());
  });

  test('lastSyncedAt is null until set', () async {
    expect(cache.lastSyncedAt, isNull);
    final now = DateTime(2026, 9, 22, 10, 30);
    await cache.setLastSyncedAt(now);
    expect(cache.lastSyncedAt, now);
  });
}
