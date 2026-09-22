import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../services/category_api_service.dart';
import '../services/local_cache_service.dart';
import '../services/summary_api_service.dart';
import '../services/sync_service.dart';
import '../services/transaction_api_service.dart';

/// [LocalCacheService] must be initialized (Hive boxes opened) before the
/// app starts, so main.dart creates and initializes it, then overrides
/// this provider — every other provider can then depend on it
/// synchronously instead of every screen awaiting a FutureProvider.
final localCacheServiceProvider = Provider<LocalCacheService>(
  (ref) => throw UnimplementedError('Overridden in main() after Hive.init()'),
);

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final transactionApiServiceProvider = Provider<TransactionApiService>(
  (ref) => TransactionApiService(ref.watch(apiClientProvider)),
);

final categoryApiServiceProvider = Provider<CategoryApiService>(
  (ref) => CategoryApiService(ref.watch(apiClientProvider)),
);

final summaryApiServiceProvider = Provider<SummaryApiService>(
  (ref) => SummaryApiService(ref.watch(apiClientProvider)),
);

final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(
    ref.watch(transactionApiServiceProvider),
    ref.watch(localCacheServiceProvider),
    ref.watch(connectivityProvider),
  ),
);

/// Live online/offline status, used to drive the offline banner.
final connectivityStatusProvider = StreamProvider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.onConnectivityChanged.map(
    (results) => !results.contains(ConnectivityResult.none),
  );
});
