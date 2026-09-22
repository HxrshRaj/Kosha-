import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import 'core_providers.dart';

/// Categories rarely change, so this loads the cache instantly, then
/// refreshes from the network in the background and updates state only if
/// the fetch succeeds — an offline user keeps the last-known category list
/// instead of seeing an error.
class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() async {
    final cache = ref.watch(localCacheServiceProvider);
    final cached = cache.getCategories();
    unawaited(_refresh());
    return cached;
  }

  Future<void> _refresh() async {
    final api = ref.read(categoryApiServiceProvider);
    final cache = ref.read(localCacheServiceProvider);
    final result = await api.list();
    result.when(
      ok: (categories) async {
        await cache.saveCategories(categories);
        state = AsyncData(categories);
      },
      err: (_) {}, // keep showing cached categories
    );
  }
}

final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<Category>>(
      CategoriesNotifier.new,
    );
