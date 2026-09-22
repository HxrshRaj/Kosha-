import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/core_providers.dart';
import 'screens/root/root_shell.dart';
import 'services/local_cache_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cache = LocalCacheService();
  await cache.init();

  runApp(
    ProviderScope(
      overrides: [localCacheServiceProvider.overrideWithValue(cache)],
      child: const KoshaApp(),
    ),
  );
}

class KoshaApp extends StatelessWidget {
  const KoshaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kosha',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const RootShell(),
    );
  }
}
