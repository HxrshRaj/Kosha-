import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/utils/result.dart';
import '../models/transaction.dart';
import '../models/transaction_type.dart';

class TransactionApiService {
  final ApiClient _client;
  const TransactionApiService(this._client);

  Future<Result<List<Transaction>>> list({
    String? month,
    int? categoryId,
    TransactionType? type,
  }) {
    return _run(
      () => _client.request(
        (dio) => dio.get(
          '/transactions',
          queryParameters: {
            if (month != null) 'month': month,
            if (categoryId != null) 'category_id': categoryId,
            if (type != null) 'type': type.toJson(),
          },
        ),
        (data) => (data as List)
            .map((e) => Transaction.fromApiJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  Future<Result<Transaction>> create(Transaction transaction) {
    return _run(
      () => _client.request(
        (dio) => dio.post('/transactions', data: transaction.toCreateJson()),
        (data) => Transaction.fromApiJson(data as Map<String, dynamic>),
      ),
    );
  }

  /// Pushes many locally-queued transactions in one request. The backend is
  /// idempotent on `client_id`, so retrying a partially-failed sync is safe.
  Future<Result<List<Transaction>>> bulkCreate(List<Transaction> transactions) {
    return _run(
      () => _client.request(
        (dio) => dio.post(
          '/transactions/bulk',
          data: transactions.map((t) => t.toCreateJson()).toList(),
        ),
        (data) => (data as List)
            .map((e) => Transaction.fromApiJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  Future<Result<void>> delete(int id) {
    return _run(
      () => _client.request((dio) => dio.delete('/transactions/$id'), (_) {}),
    );
  }

  Future<Result<T>> _run<T>(Future<T> Function() body) async {
    try {
      return Result.ok(await body());
    } on ApiException catch (e) {
      return Result.err(e);
    } catch (_) {
      return Result.err(const UnknownApiException());
    }
  }
}
