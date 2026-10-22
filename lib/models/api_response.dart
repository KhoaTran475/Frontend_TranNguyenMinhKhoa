class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    required this.success,
    required this.message,
    required this.data,
    required this.errors,
  });

  final int statusCode;
  final bool success;
  final String message;
  final Object? data;
  final Object? errors;

  factory ApiResponse.fromJson(Object? json, {required int statusCode}) {
    if (json is! Map<String, dynamic> ||
        json['success'] is! bool ||
        json['message'] is! String ||
        (json['message'] as String).trim().isEmpty ||
        !json.containsKey('data') ||
        !json.containsKey('errors') ||
        !_validErrors(json['errors']) ||
        (json['success'] == true && json['errors'] != null)) {
      throw const FormatException('Response không đúng envelope API v1.');
    }
    return ApiResponse(
      statusCode: statusCode,
      success: json['success'] as bool,
      message: json['message'] as String,
      data: json['data'],
      errors: json['errors'],
    );
  }

  static bool _validErrors(Object? errors) {
    if (errors == null) return true;
    if (errors is Map<String, dynamic>) {
      return errors.values.every(
        (value) => value is List && value.every((item) => item is String),
      );
    }
    if (errors is List) {
      return errors.every(
        (item) =>
            item is Map<String, dynamic> &&
            item['code'] is String &&
            item['description'] is String,
      );
    }
    return false;
  }
}
