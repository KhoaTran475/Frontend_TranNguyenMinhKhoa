import 'api_response.dart';

enum ApiFailureKind { network, timeout, http, business, invalidResponse }

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.response,
  });

  final ApiFailureKind kind;
  final String message;
  final int? statusCode;

  // Giữ cả Challenge khi HTTP 403/429/503 và lỗi validation/Identity.
  final ApiResponse? response;

  @override
  String toString() => message;
}
