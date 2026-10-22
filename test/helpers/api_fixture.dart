import 'dart:convert';

import 'package:http/http.dart' as http;

// Chỉ là fixture cho unit/widget test, không dùng trong ứng dụng hoặc
// làm bằng chứng đã tích hợp backend thật.
http.Response envelope({
  int status = 200,
  bool success = true,
  String message = 'Thành công.',
  Object? data,
  Object? errors,
}) => http.Response(
  jsonEncode({
    'success': success,
    'message': message,
    'data': data,
    'errors': errors,
  }),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
