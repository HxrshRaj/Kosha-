/// Typed API failures so the UI can show a specific, honest message instead
/// of a generic "something went wrong" for every error.
sealed class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

/// No connectivity, DNS failure, or the request timed out.
class NetworkException extends ApiException {
  const NetworkException([
    super.message = 'No internet connection. Check your network and try again.',
  ]);
}

/// The server responded with a 4xx/5xx status.
class ServerException extends ApiException {
  final int statusCode;
  const ServerException(this.statusCode, super.message);
}

/// Anything else (malformed response, unexpected exception).
class UnknownApiException extends ApiException {
  const UnknownApiException([
    super.message = 'Something went wrong. Please try again.',
  ]);
}
