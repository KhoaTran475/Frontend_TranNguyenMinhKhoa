import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/api_exception.dart';
import '../models/api_response.dart';

class ApiClient {
  ApiClient({
    required Uri baseUri,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    this.tokenProvider,
    this.onUnauthorized,
  }) : _baseUri = _validateBaseUri(baseUri),
       _client = client ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;
  final Duration timeout;

  // Giai đoạn sau có thể đọc token từ flutter_secure_storage tại đây.
  final Future<String?> Function()? tokenProvider;
  final Future<void> Function()? onUnauthorized;

  static Uri _validateBaseUri(Uri uri) {
    final config = AppConfig.fromBaseUrl(uri.toString());
    if (!config.isValid) throw ArgumentError(config.error);
    return config.baseUri!;
  }

  Future<ApiResponse> get(
    String path, {
    Map<String, Object?>? query,
    bool authenticated = true,
  }) => _request('GET', path, query: query, authenticated: authenticated);

  Future<ApiResponse> post(
    String path, {
    Object? body,
    Map<String, Object?>? query,
    bool authenticated = true,
  }) => _request(
    'POST',
    path,
    body: body,
    query: query,
    authenticated: authenticated,
  );

  Future<ApiResponse> put(
    String path, {
    Object? body,
    Map<String, Object?>? query,
    bool authenticated = true,
  }) => _request(
    'PUT',
    path,
    body: body,
    query: query,
    authenticated: authenticated,
  );

  Future<ApiResponse> patch(
    String path, {
    Object? body,
    Map<String, Object?>? query,
    bool authenticated = true,
  }) => _request(
    'PATCH',
    path,
    body: body,
    query: query,
    authenticated: authenticated,
  );

  Future<ApiResponse> delete(
    String path, {
    Object? body,
    Map<String, Object?>? query,
    bool authenticated = true,
  }) => _request(
    'DELETE',
    path,
    body: body,
    query: query,
    authenticated: authenticated,
  );

  Uri _resolve(String path, Map<String, Object?>? query) {
    final relative = Uri.parse(path.trim());
    final segments = relative.pathSegments
        .where((part) => part.isNotEmpty)
        .toList();
    if (relative.hasScheme ||
        relative.hasAuthority ||
        relative.hasFragment ||
        segments.isEmpty ||
        segments.any((part) => part == '.' || part == '..')) {
      throw ArgumentError('Endpoint phải là đường dẫn tương đối với /api/.');
    }
    final parameters = <String, dynamic>{...relative.queryParametersAll};
    for (final entry in (query ?? <String, Object?>{}).entries) {
      if (entry.value == null) {
        parameters.remove(entry.key);
      } else if (entry.value is Iterable) {
        parameters[entry.key] = (entry.value as Iterable)
            .map((value) => value.toString())
            .toList();
      } else {
        parameters[entry.key] = entry.value.toString();
      }
    }
    return _baseUri.replace(
      pathSegments: ['api', ...segments],
      queryParameters: parameters.isEmpty ? null : parameters,
    );
  }

  Future<ApiResponse> _request(
    String method,
    String path, {
    Object? body,
    Map<String, Object?>? query,
    required bool authenticated,
  }) async {
    final request = http.Request(method, _resolve(path, query))
      ..followRedirects = false
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      });
    if (authenticated && tokenProvider != null) {
      final token = await tokenProvider!();
      if (token != null && token.trim().isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }
    if (body != null) request.body = jsonEncode(body);

    late http.Response raw;
    try {
      raw = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        kind: ApiFailureKind.timeout,
        message:
            'Kết nối quá thời gian chờ. Kiểm tra backend, mạng và thử lại.',
      );
    } on HandshakeException {
      throw const ApiException(
        kind: ApiFailureKind.network,
        message:
            'Không xác thực được chứng chỉ HTTPS. Kiểm tra URL và '
            'chứng chỉ Conveyor; ứng dụng không bỏ qua kiểm tra chứng chỉ.',
      );
    } on IOException {
      throw const ApiException(
        kind: ApiFailureKind.network,
        message:
            'Không kết nối được máy chủ. Kiểm tra Internet, URL Conveyor '
            'và backend đang chạy.',
      );
    } on http.ClientException {
      throw const ApiException(
        kind: ApiFailureKind.network,
        message:
            'Lỗi kết nối mạng hoặc HTTPS. Kiểm tra URL Conveyor '
            'và backend rồi thử lại.',
      );
    }

    if (raw.statusCode == 401 && authenticated && onUnauthorized != null) {
      await onUnauthorized!();
    }
    late ApiResponse response;
    try {
      final contentType = raw.headers['content-type']
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      if (contentType == null ||
          (contentType != 'application/json' &&
              !(contentType.startsWith('application/') &&
                  contentType.endsWith('+json')))) {
        throw const FormatException('Response không phải JSON.');
      }
      response = ApiResponse.fromJson(
        jsonDecode(utf8.decode(raw.bodyBytes)),
        statusCode: raw.statusCode,
      );
    } on FormatException {
      throw ApiException(
        kind: ApiFailureKind.invalidResponse,
        statusCode: raw.statusCode,
        message:
            'HTTP ${raw.statusCode}: phản hồi không đúng hợp đồng API '
            '(cần JSON envelope success, message, data, errors). '
            'Kiểm tra BASE_URL, backend và Conveyor.',
      );
    }

    if (raw.statusCode < 200 || raw.statusCode >= 300) {
      if (response.success) {
        throw ApiException(
          kind: ApiFailureKind.invalidResponse,
          statusCode: raw.statusCode,
          message:
              'HTTP ${raw.statusCode} không khớp success=true trong phản hồi API.',
        );
      }
      throw ApiException(
        kind: ApiFailureKind.http,
        statusCode: raw.statusCode,
        response: response,
        message: 'HTTP ${raw.statusCode}: ${response.message}',
      );
    }
    if (!response.success) {
      throw ApiException(
        kind: ApiFailureKind.business,
        statusCode: raw.statusCode,
        response: response,
        message: response.message,
      );
    }
    return response;
  }

  void close() => _client.close();
}
