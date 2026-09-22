import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Thin wrapper around Dio: centralizes the base URL, timeouts, logging,
/// and — most importantly — converts every DioException into one of our
/// typed [ApiException]s so callers never have to inspect Dio internals.
///
/// Base URL resolution order:
/// 1. `--dart-define=API_BASE_URL=...` (used for the deployed backend)
/// 2. Platform default: 10.0.2.2 is the Android emulator's alias for the
///    host machine's localhost; physical devices/iOS simulator fall back
///    to localhost and expect `adb reverse` or a LAN IP override.
class ApiClient {
  final Dio _dio;

  ApiClient({String? baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl ?? _defaultBaseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {'Content-Type': 'application/json'},
        ),
      ) {
    _dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true, logPrint: (_) {}),
    );
  }

  static const _fromEnv = String.fromEnvironment('API_BASE_URL');
  static String get _defaultBaseUrl =>
      _fromEnv.isNotEmpty ? _fromEnv : 'http://10.0.2.2:8000';

  Future<T> request<T>(
    Future<Response<dynamic>> Function(Dio dio) call,
    T Function(dynamic data) parse,
  ) async {
    try {
      final response = await call(_dio);
      return parse(response.data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        final detail =
            _extractDetail(e.response?.data) ?? 'Request failed ($status).';
        return ServerException(status, detail);
      case DioExceptionType.cancel:
        return const UnknownApiException('Request was cancelled.');
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
      default:
        return const NetworkException();
    }
  }

  String? _extractDetail(dynamic data) {
    if (data is Map && data['detail'] != null) return data['detail'].toString();
    return null;
  }
}
