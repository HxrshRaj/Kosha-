import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kosha/models/category.dart';
import 'package:kosha/providers/category_providers.dart';
import 'package:kosha/screens/transactions/add_transaction_screen.dart';

import '../support/fixtures.dart';

/// Serves a fixed category list without touching LocalCacheService or the
/// network, so this test exercises only the form widget.
class _FixedCategoriesNotifier extends CategoriesNotifier {
  @override
  Future<List<Category>> build() async => testCategories();
}

void main() {
  Widget wrap() => ProviderScope(
        overrides: [categoriesProvider.overrideWith(_FixedCategoriesNotifier.new)],
        child: const MaterialApp(home: AddTransactionScreen(month: '2026-09')),
      );

  testWidgets('shows validation errors when submitting an empty form', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid amount'), findsOneWidget);
    expect(find.text('Choose a category'), findsOneWidget);
  });

  testWidgets('expense is selected by default and category list is filtered to expense categories', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Open the category dropdown.
    await tester.tap(find.byType(DropdownButtonFormField<Category>));
    await tester.pumpAndSettle();

    expect(find.text('Food & Dining').hitTestable(), findsOneWidget);
    // Salary is an income-only category and should not be offered while
    // "Expense" is selected.
    expect(find.text('Salary'), findsNothing);
  });

  testWidgets('switching to Income filters the category list to income categories', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<Category>));
    await tester.pumpAndSettle();

    expect(find.text('Salary').hitTestable(), findsOneWidget);
    expect(find.text('Food & Dining'), findsNothing);
  });

  testWidgets('rejects a zero or negative amount', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '0');
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid amount'), findsOneWidget);
  });
}
