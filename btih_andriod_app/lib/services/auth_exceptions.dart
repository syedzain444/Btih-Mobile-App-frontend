enum AuthErrorType {
  network,
  validation,
  unauthorized,
  server,
  unknown,
}

class AuthApiException implements Exception {
  final String message;
  final AuthErrorType type;
  final int? statusCode;
  final List<String> errors;

  const AuthApiException(
    this.message, {
    this.type = AuthErrorType.unknown,
    this.statusCode,
    this.errors = const [],
  });

  bool get isNetworkError => type == AuthErrorType.network;

  @override
  String toString() => message;
}
