import 'dart:convert';

import 'auth_models.dart';

class AttendanceQrPayload {
  const AttendanceQrPayload._(this.sessionId, this.token);
  final int sessionId;
  final String token;

  factory AttendanceQrPayload.parse(String text, {int? expectedSessionId}) {
    if (text.length > 4096) {
      throw const FormatException('Mã QR quá dài, không đúng mã điểm danh.');
    }
    final json = jsonObject(jsonDecode(text));
    final id = json['sessionId'];
    final token = json['token'];
    if (json['type'] != 'attendance' ||
        id is! int ||
        id <= 0 ||
        token is! String ||
        token.trim().isEmpty ||
        token.length > 256) {
      throw const FormatException('Đây không phải mã QR điểm danh hợp lệ.');
    }
    if (expectedSessionId != null && id != expectedSessionId) {
      throw const FormatException(
        'Mã QR thuộc buổi học khác. Hãy quét đúng mã của buổi đã chọn.',
      );
    }
    return AttendanceQrPayload._(id, token);
  }
}

class SessionQr {
  const SessionQr._(this.sessionId, this.payload, this.expiresAt);
  final int sessionId;
  // Giữ nguyên chuỗi JSON do server cấp để dựng QR, không tự tạo token.
  final String payload;
  final DateTime expiresAt;

  factory SessionQr.fromJson(Object? value, {required int sessionId}) {
    final json = jsonObject(value);
    final payload = json['qrPayload'];
    final expiry = DateTime.tryParse(json['expiresAtUtc']?.toString() ?? '');
    if (json['sessionId'] != sessionId ||
        payload is! String ||
        expiry == null ||
        expiry.timeZoneOffset != Duration.zero) {
      throw const FormatException(
        'Thông tin QR từ backend không đúng hợp đồng.',
      );
    }
    AttendanceQrPayload.parse(payload, expectedSessionId: sessionId);
    return SessionQr._(sessionId, payload, expiry.toUtc());
  }
}

class AttendanceLocation {
  const AttendanceLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
  });
  final double latitude, longitude, accuracyMeters;
  final DateTime capturedAt;

  void validate({DateTime? now}) {
    if (!latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180 ||
        !accuracyMeters.isFinite ||
        accuracyMeters < 0.01 ||
        accuracyMeters > 50) {
      throw const FormatException(
        'Vị trí chưa đủ chính xác (cần sai số ≤ 50 m). '
        'Hãy bật vị trí chính xác, đến nơi thoáng và lấy lại GPS.',
      );
    }
    final age = (now ?? DateTime.now()).toUtc().difference(capturedAt.toUtc());
    if (age > const Duration(seconds: 30) ||
        age < const Duration(seconds: -5)) {
      throw const FormatException(
        'Vị trí đã cũ hoặc thời gian thiết bị không đúng. Hãy lấy lại GPS.',
      );
    }
  }

  Map<String, Object> requestFor(AttendanceQrPayload qr) => {
    'sessionId': qr.sessionId,
    'qrToken': qr.token,
    'latitude': latitude,
    'longitude': longitude,
    'accuracyMeters': accuracyMeters,
  };
}

class CheckInResult {
  const CheckInResult._(this.status, this.checkedInAt, this.distanceMeters);
  final String status;
  final DateTime checkedInAt;
  final double distanceMeters;

  factory CheckInResult.fromJson(Object? value, {required int sessionId}) {
    final json = jsonObject(value);
    final checked = DateTime.tryParse(json['checkedInAtUtc']?.toString() ?? '');
    final distance = json['distanceMeters'];
    if (json['sessionId'] != sessionId ||
        json['id'] is! int ||
        (json['id'] as int) <= 0 ||
        json['studentId'] is! int ||
        (json['studentId'] as int) <= 0 ||
        !['Present', 'Late'].contains(json['status']) ||
        checked == null ||
        distance is! num ||
        !distance.isFinite ||
        distance < 0) {
      throw const FormatException(
        'Backend chưa trả kết quả check-in đúng hợp đồng. '
        'Hãy kiểm tra lịch sử trước khi gửi lại.',
      );
    }
    return CheckInResult._(
      json['status'] as String,
      checked.toUtc(),
      distance.toDouble(),
    );
  }
}
