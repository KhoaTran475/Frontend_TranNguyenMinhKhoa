import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../services/api_client.dart';

enum ConnectionStatus { idle, checking, connected, error }

class ConnectionProvider extends ChangeNotifier {
  ConnectionProvider(this._api);

  final ApiClient _api;
  bool _disposed = false;
  ConnectionStatus _status = ConnectionStatus.idle;
  String _message = 'Chưa kiểm tra kết nối.';

  ConnectionStatus get status => _status;
  String get message => _message;
  bool get isChecking => _status == ConnectionStatus.checking;

  Future<void> checkConnection() async {
    if (isChecking || _disposed) return;
    _status = ConnectionStatus.checking;
    _message = 'Đang kiểm tra kết nối…';
    notifyListeners();

    try {
      final response = await _api.get('auth/me', authenticated: false);
      if (_isUser(response.data) && response.statusCode == 200) {
        _status = ConnectionStatus.connected;
        _message = 'Đã kết nối backend, nhận phản hồi API hợp lệ (HTTP 200).';
      } else {
        _status = ConnectionStatus.error;
        _message =
            'HTTP ${response.statusCode}: dữ liệu /auth/me '
            'không đúng schema User trong hợp đồng API.';
      }
    } on ApiException catch (error) {
      final envelope = error.response;
      if (error.kind == ApiFailureKind.http &&
          error.statusCode == 401 &&
          envelope != null &&
          !envelope.success &&
          envelope.data == null &&
          envelope.errors == null) {
        _status = ConnectionStatus.connected;
        _message = 'Đã kết nối backend, chưa đăng nhập';
      } else {
        _status = ConnectionStatus.error;
        _message = error.message;
      }
    } catch (_) {
      _status = ConnectionStatus.error;
      _message =
          'Không thể hoàn tất kiểm tra. Hãy kiểm tra cấu hình và thử lại.';
    }
    if (!_disposed) notifyListeners();
  }

  static bool _isUser(Object? value) {
    if (value is! Map<String, dynamic>) return false;
    return [
          'id',
          'username',
          'fullName',
          'email',
        ].every((field) => value[field] is String) &&
        ['Admin', 'Lecturer', 'Student'].contains(value['role']) &&
        ['studentId', 'lecturerId'].every(
          (field) =>
              value.containsKey(field) &&
              (value[field] == null || value[field] is int),
        );
  }

  @override
  void dispose() {
    _disposed = true;
    _api.close();
    super.dispose();
  }
}
