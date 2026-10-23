import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/transaction.dart';
import '../models/transaction_type.dart';

class TransactionFilter extends Equatable {
  final String query;
  final TransactionType? type;

  const TransactionFilter({this.query = '', this.type});

  bool get isActive => query.trim().isNotEmpty || type != null;

  TransactionFilter copyWith({String? query, TransactionType? type, bool clearType = false}) {
    return TransactionFilter(
      query: query ?? this.query,
      type: clearType ? null : (type ?? this.type),
    );
  }

  /// Pure filtering so it can be unit-tested without a widget tree.
  List<Transaction> apply(List<Transaction> all) {
    final q = query.trim().toLowerCase();
    return all.where((t) {
      if (type != null && t.type != type) return false;
      if (q.isEmpty) return true;
      return (t.note ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  List<Object?> get props => [query, type];
}

/// BLoC-pattern (Cubit) state for the transaction list search and type filter.
/// The data itself stays in Riverpod; this only owns the view filter.
class TransactionFilterCubit extends Cubit<TransactionFilter> {
  TransactionFilterCubit() : super(const TransactionFilter());

  void setQuery(String query) => emit(state.copyWith(query: query));

  void setType(TransactionType? type) =>
      emit(type == null ? state.copyWith(clearType: true) : state.copyWith(type: type));

  void clear() => emit(const TransactionFilter());
}
