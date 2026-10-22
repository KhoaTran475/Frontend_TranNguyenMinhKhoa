import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/attendance_check_in.dart';

enum LocationSettingsAction { none, location, application }

class AttendanceLocationException implements Exception {
  const AttendanceLocationException(
    this.message, {
    this.action = LocationSettingsAction.none,
  });
  final String message;
  final LocationSettingsAction action;
}

abstract interface class AttendanceLocationReader {
  Future<AttendanceLocation> current();
}

class AttendanceLocationService implements AttendanceLocationReader {
  const AttendanceLocationService();
  @override
  Future<AttendanceLocation> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AttendanceLocationException(
        'GPS đang tắt. Hãy bật vị trí rồi thử lại.',
        action: LocationSettingsAction.location,
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const AttendanceLocationException(
        'Quyền vị trí đã bị từ chối vĩnh viễn. '
        'Mở cài đặt ứng dụng và cho phép vị trí chính xác khi dùng app.',
        action: LocationSettingsAction.application,
      );
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw const AttendanceLocationException(
        'Chưa được cấp quyền vị trí. '
        'Điểm danh cần vị trí hiện tại; hãy cấp quyền rồi thử lại.',
        action: LocationSettingsAction.application,
      );
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final result = AttendanceLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        capturedAt: position.timestamp,
      );
      result.validate();
      return result;
    } on TimeoutException {
      throw const AttendanceLocationException(
        'Chưa lấy được GPS sau 20 giây. '
        'Hãy bật vị trí chính xác, đến nơi thoáng và thử lại.',
      );
    } on LocationServiceDisabledException {
      throw const AttendanceLocationException(
        'GPS đã bị tắt. Hãy bật lại vị trí.',
        action: LocationSettingsAction.location,
      );
    }
  }
}
