// ignore_for_file: avoid_print
// Standalone benchmark — run with `dart run tool/isolate_jank_benchmark.dart`
// from the `app/` directory. No Flutter engine/device needed: it uses only
// `dart:isolate` and the pure-Dart `csv` package, reusing the exact same
// `TransactionCategorizer` the real CSV-import feature uses (see
// lib/services/csv_import_service.dart).
//
// What it measures: a `Timer.periodic` every 16ms stands in for the UI
// thread's per-frame callback. We record the real gap between consecutive
// ticks while the heavy categorization work runs (a) synchronously on the
// same isolate as the timer, and (b) on a background isolate via
// `Isolate.run`. If (a) blocks the event loop, the periodic timer simply
// cannot fire until the blocking call returns — that shows up directly as
// one huge measured gap. This is the same mechanism that drops UI frames
// in a real Flutter app: `Timer.periodic` and `SchedulerBinding`'s frame
// callbacks both run on the isolate's event loop, so blocking the isolate
// blocks both identically.
//
// Results from an actual run are recorded in docs/threading.md — this
// file is that measurement's source, not a demo.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:csv/csv.dart';
import 'package:kosha/services/transaction_categorizer.dart';

int categorizeAndCount(String csvContent) {
  final rows = const CsvToListConverter(eol: '\n').convert(csvContent, shouldParseNumbers: false);
  final dataRows = rows.length > 1 ? rows.sublist(1) : const <List<dynamic>>[];

  var categorized = 0;
  for (final row in dataRows) {
    if (row.length < 3) continue;
    final description = row[1].toString();
    final amount = double.tryParse(row[2].toString().trim());
    if (amount == null) continue;
    final name = TransactionCategorizer.categorize(description);
    TransactionCategorizer.typeForCategory(name);
    categorized++;
  }
  return categorized;
}

Future<void> main() async {
  final csvPath = 'assets/sample_data/sample_transactions_large.csv';
  final csvContent = await File(csvPath).readAsString();
  final rowCount = '\n'.allMatches(csvContent).length;
  print('Loaded $csvPath (${csvContent.length} bytes, ~$rowCount rows)\n');

  await _runScenario(
    'SYNCHRONOUS on the timer-owning isolate (equivalent to calling the '
    'categorizer directly from a widget callback on the UI isolate)',
    () async => categorizeAndCount(csvContent),
  );

  await _runScenario(
    'BACKGROUND ISOLATE via Isolate.run (what CsvImportService actually does)',
    () async => Isolate.run(() => categorizeAndCount(csvContent)),
  );
}

Future<void> _runScenario(String label, Future<void> Function() work) async {
  print('=== $label ===');
  const targetFrameMs = 1000 / 60; // 16.666...

  final tickGapsMs = <double>[];
  final stopwatch = Stopwatch()..start();
  // Seeded at 0 (timer start), NOT null — this is what lets the gap before
  // the very first tick be measured. If the isolate is blocked from the
  // moment the timer starts, that blockage shows up as the gap on the
  // first tick; seeding with null would silently discard exactly that
  // measurement, which is the one that matters most in the synchronous
  // scenario below.
  int lastTickMicros = 0;

  final timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
    final now = stopwatch.elapsedMicroseconds;
    tickGapsMs.add((now - lastTickMicros) / 1000);
    lastTickMicros = now;
  });

  final workStopwatch = Stopwatch()..start();
  await work();
  workStopwatch.stop();

  // Let a few more ticks land so the recovery after the work finishes is
  // visible in the trace too.
  await Future<void>.delayed(const Duration(milliseconds: 150));
  timer.cancel();

  final maxGap = tickGapsMs.isEmpty ? 0.0 : tickGapsMs.reduce((a, b) => a > b ? a : b);
  final droppedFrameTicks = tickGapsMs.where((g) => g > targetFrameMs * 1.5).toList();
  final estimatedDroppedFrames = droppedFrameTicks.fold<int>(
    0,
    (sum, g) => sum + (g / targetFrameMs).floor() - 1,
  );

  print('  Work duration:              ${workStopwatch.elapsedMilliseconds} ms');
  print('  Timer ticks recorded:       ${tickGapsMs.length}');
  print('  Max gap between ticks:      ${maxGap.toStringAsFixed(1)} ms  (target ~${targetFrameMs.toStringAsFixed(1)} ms)');
  print('  Ticks that missed budget:   ${droppedFrameTicks.length}');
  print('  Estimated dropped frames:   $estimatedDroppedFrames  (at a 16.7ms/frame budget)');
  print('');
}
