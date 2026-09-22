import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kosha/models/transaction_type.dart';
import 'package:kosha/widgets/transaction_tile.dart';

import '../support/fixtures.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows category name, note, and formatted expense amount', (tester) async {
    final transaction = testTransaction(
      amount: 450,
      type: TransactionType.expense,
      categoryId: 1, // Food & Dining
      note: 'Groceries',
    );

    await tester.pumpWidget(wrap(TransactionTile(transaction: transaction)));

    expect(find.text('Food & Dining'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.textContaining('450'), findsOneWidget);
    // Expense amounts are prefixed with a minus sign.
    expect(find.textContaining('−'), findsOneWidget);
  });

  testWidgets('income transactions show a plus sign', (tester) async {
    final transaction = testTransaction(
      amount: 50000,
      type: TransactionType.income,
      categoryId: 7, // Salary
      note: null,
    );

    await tester.pumpWidget(wrap(TransactionTile(transaction: transaction)));

    expect(find.textContaining('+'), findsOneWidget);
  });

  testWidgets('pending-sync transactions show the sync icon', (tester) async {
    final transaction = testTransaction(pendingSync: true);
    await tester.pumpWidget(wrap(TransactionTile(transaction: transaction)));
    expect(find.byIcon(Icons.sync), findsOneWidget);
  });

  testWidgets('synced transactions do not show the sync icon', (tester) async {
    final transaction = testTransaction(pendingSync: false);
    await tester.pumpWidget(wrap(TransactionTile(transaction: transaction)));
    expect(find.byIcon(Icons.sync), findsNothing);
  });
}
