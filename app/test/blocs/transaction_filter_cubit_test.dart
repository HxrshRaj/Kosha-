import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kosha/blocs/transaction_filter_cubit.dart';
import 'package:kosha/models/transaction.dart';
import 'package:kosha/models/transaction_type.dart';

Transaction _t(String id, TransactionType type, String? note) => Transaction(
  id: null,
  clientId: id,
  amount: 10,
  type: type,
  categoryId: 1,
  category: null,
  note: note,
  date: DateTime(2026, 3, 1),
  createdAt: null,
);

void main() {
  final all = [
    _t('a', TransactionType.expense, 'Swiggy dinner'),
    _t('b', TransactionType.expense, 'Metro card'),
    _t('c', TransactionType.income, 'Salary March'),
    _t('d', TransactionType.expense, null),
  ];

  group('TransactionFilter.apply', () {
    test('empty filter keeps everything', () {
      expect(const TransactionFilter().apply(all), all);
      expect(const TransactionFilter().isActive, isFalse);
    });

    test('query is case-insensitive and ignores null notes', () {
      final r = const TransactionFilter(query: 'SWIGGY').apply(all);
      expect(r.map((t) => t.clientId), ['a']);
    });

    test('type filter and query combine', () {
      final r = const TransactionFilter(
        query: 'a',
        type: TransactionType.income,
      ).apply(all);
      expect(r.map((t) => t.clientId), ['c']);
    });
  });

  group('TransactionFilterCubit', () {
    blocTest<TransactionFilterCubit, TransactionFilter>(
      'setQuery then setType emits each state',
      build: TransactionFilterCubit.new,
      act: (c) => c
        ..setQuery('metro')
        ..setType(TransactionType.expense),
      expect: () => const [
        TransactionFilter(query: 'metro'),
        TransactionFilter(query: 'metro', type: TransactionType.expense),
      ],
    );

    blocTest<TransactionFilterCubit, TransactionFilter>(
      'setType(null) clears the type only',
      build: TransactionFilterCubit.new,
      seed: () => const TransactionFilter(query: 'x', type: TransactionType.income),
      act: (c) => c.setType(null),
      expect: () => const [TransactionFilter(query: 'x')],
    );

    blocTest<TransactionFilterCubit, TransactionFilter>(
      'clear resets to the default filter',
      build: TransactionFilterCubit.new,
      seed: () => const TransactionFilter(query: 'x', type: TransactionType.income),
      act: (c) => c.clear(),
      expect: () => const [TransactionFilter()],
    );
  });
}
