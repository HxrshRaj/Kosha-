import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../models/summary.dart';
import 'core_providers.dart';

/// Analytics are computed server-side (see backend `/summary`), so unlike
/// the transaction list there is no local cache to fall back to — this
/// honestly surfaces an offline error instead of pretending to have data.
/// The transaction list and cached total still work offline; only the
/// chart screen degrades, which is called out in README "Simplifications".
final monthlySummaryProvider = FutureProvider.family<MonthlySummary, String>((
  ref,
  month,
) async {
  final api = ref.watch(summaryApiServiceProvider);
  final result = await api.monthly(month);
  return result.when(ok: (s) => s, err: (e) => throw e);
});

final yearlySummaryProvider = FutureProvider.family<YearlySummary, int>((
  ref,
  year,
) async {
  final api = ref.watch(summaryApiServiceProvider);
  final result = await api.yearly(year);
  return result.when(ok: (s) => s, err: (e) => throw e);
});

extension ApiExceptionMessage on Object {
  String get userMessage => this is ApiException
      ? (this as ApiException).message
      : 'Something went wrong.';
}
