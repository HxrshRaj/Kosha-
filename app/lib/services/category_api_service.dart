import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/utils/result.dart';
import '../models/category.dart';

class CategoryApiService {
  final ApiClient _client;
  const CategoryApiService(this._client);

  Future<Result<List<Category>>> list() => _run(
    () => _client.request(
      (dio) => dio.get('/categories'),
      (data) => (data as List)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList(),
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
