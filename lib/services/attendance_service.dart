import '../models/attendance_check_in.dart';
import '../models/auth_models.dart';
import 'api_client.dart';

class AttendanceService {
  const AttendanceService(this.api);
  final ApiClient api;

  Future<Map<String, dynamic>> session(int id) async =>
      jsonObject((await api.get('sessions/$id')).data);

  Future<SessionQr> qr(int sessionId) async => SessionQr.fromJson(
    (await api.get('sessions/$sessionId/qr')).data,
    sessionId: sessionId,
  );

  Future<CheckInResult> checkIn(
    AttendanceQrPayload qr,
    AttendanceLocation location,
  ) async {
    location.validate();
    final response = await api.post(
      'attendance/check-in',
      body: location.requestFor(qr),
    );
    if (response.statusCode != 201) {
      throw const FormatException(
        'Backend trả mã HTTP khác hợp đồng check-in. '
        'Kiểm tra lịch sử trước khi gửi lại.',
      );
    }
    return CheckInResult.fromJson(response.data, sessionId: qr.sessionId);
  }
}
