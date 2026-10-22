import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/attendance_check_in.dart';
import '../services/attendance_location_service.dart';
import '../services/attendance_service.dart';
import 'auth_provider.dart';

enum CheckInStage { ready, locating, submitting, success, error }

class CheckInProvider extends ChangeNotifier {
  CheckInProvider(this._service, {AttendanceLocationReader? locationReader})
    : _locationReader = locationReader ?? const AttendanceLocationService();
  final AttendanceService _service;
  final AttendanceLocationReader _locationReader;
  CheckInStage stage = CheckInStage.ready;
  AttendanceQrPayload? qr;
  AttendanceLocation? location;
  CheckInResult? result;
  String? error;
  LocationSettingsAction settingsAction = LocationSettingsAction.none;
  bool _disposed = false;
  bool get busy =>
      stage == CheckInStage.locating || stage == CheckInStage.submitting;

  void selectQr(AttendanceQrPayload payload) {
    if (busy || result != null || _disposed) return;
    qr = payload;
    error = null;
    location = null;
    settingsAction = LocationSettingsAction.none;
    stage = CheckInStage.ready;
    notifyListeners();
  }

  Future<void> submit() async {
    if (busy || qr == null || result != null || _disposed) return;
    error = null;
    location = null;
    settingsAction = LocationSettingsAction.none;
    stage = CheckInStage.locating;
    notifyListeners();
    try {
      final position = await _locationReader.current();
      if (_disposed) return;
      position.validate();
      location = position;
      stage = CheckInStage.submitting;
      notifyListeners();
      result = await _service.checkIn(qr!, position);
      stage = CheckInStage.success;
    } on AttendanceLocationException catch (failure) {
      error = failure.message;
      settingsAction = failure.action;
      stage = CheckInStage.error;
    } catch (failure) {
      final wasSending = stage == CheckInStage.submitting;
      error = describeError(failure);
      if (wasSending &&
          failure is ApiException &&
          [
            ApiFailureKind.network,
            ApiFailureKind.timeout,
          ].contains(failure.kind)) {
        error =
            '$error\nChưa xác nhận được kết quả gửi. Kiểm tra lịch sử điểm danh trước khi thử lại.';
      }
      stage = CheckInStage.error;
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
