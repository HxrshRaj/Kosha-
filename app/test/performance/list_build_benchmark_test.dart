import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kosha/widgets/transaction_tile.dart';

import '../support/fixtures.dart';

/// Counts how many times its child's build method actually runs, so the
/// benchmark below measures real widget rebuilds instead of assuming them.
/// See docs/performance.md for the numbers this test produces and how
/// they were used to justify `ListView.builder` + `RepaintBoundary` in
/// TransactionListScreen.
class _BuildCounter extends StatelessWidget {
  final Widget child;
  final List<int> counter;
  const _BuildCounter({required this.child, required this.counter});

  @override
  Widget build(BuildContext context) {
    counter[0]++;
    return child;
  }
}

void main() {
  const itemCount = 500;
  final transactions = List.generate(
    itemCount,
    (i) => testTransaction(clientId: 'perf-$i', amount: (i + 1).toDouble()),
  );

  testWidgets('naive Column builds every item immediately, even off-screen ones', (tester) async {
    final counter = [0];
    final stopwatch = Stopwatch()..start();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              for (final t in transactions)
                _BuildCounter(counter: counter, child: TransactionTile(transaction: t)),
            ],
          ),
        ),
      ),
    ));
    stopwatch.stop();

    // The naive approach has no viewport awareness: laying out the
    // scrollable forces every child to build up front.
    expect(counter[0], itemCount);
    // ignore: avoid_print
    print('[perf] naive Column ($itemCount items): ${counter[0]} builds, '
        '${stopwatch.elapsedMilliseconds}ms to pump');
  });

  testWidgets('ListView.builder only builds items near the viewport', (tester) async {
    final counter = [0];
    final stopwatch = Stopwatch()..start();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          itemCount: transactions.length,
          itemBuilder: (context, index) =>
              _BuildCounter(counter: counter, child: TransactionTile(transaction: transactions[index])),
        ),
      ),
    ));
    stopwatch.stop();

    // Default flutter_test surface is 800x600; ListView.builder should
    // build only the visible items plus a small cache extent — a small
    // fraction of the full 500-item list, not all of it.
    expect(counter[0], lessThan(itemCount ~/ 5));
    expect(counter[0], greaterThan(0));
    // ignore: avoid_print
    print('[perf] ListView.builder ($itemCount items): ${counter[0]} builds, '
        '${stopwatch.elapsedMilliseconds}ms to pump');
  });
}
