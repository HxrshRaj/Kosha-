import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/utils/result.dart';
import '../models/summary.dart';

class SummaryApiService {
  final ApiClient _client;
  const SummaryApiService(this._client);

  Future<Result<MonthlySummary>> monthly(String month) => _run(
    () => _client.request(
      (dio) => dio.get('/summary', queryParameters: {'month': month}),
      (data) => MonthlySummary.fromJson(data as Map<String, dynamic>),
    ),
  );

  Future<Result<YearlySummary>> yearly(int year) => _run(
    () => _client.request(
      (dio) => dio.get('/summary/yearly', queryParameters: {'year': year}),
      (data) => YearlySummary.fromJson(data as Map<String, dynamic>),
    ),
  );

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
