import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:trannguyenminhkhoa_2380604158/models/attendance_check_in.dart';
import 'package:trannguyenminhkhoa_2380604158/providers/check_in_provider.dart';
import 'package:trannguyenminhkhoa_2380604158/screens/lecturer/session_qr_screen.dart';
import 'package:trannguyenminhkhoa_2380604158/services/api_client.dart';
import 'package:trannguyenminhkhoa_2380604158/services/attendance_location_service.dart';
import 'package:trannguyenminhkhoa_2380604158/services/attendance_service.dart';

import 'helpers/api_fixture.dart';

const _payload = '{"type":"attendance","sessionId":123,"token":"unit-test-qr"}';
AttendanceLocation _location({
  double accuracy = 10,
  Duration age = Duration.zero,
}) => AttendanceLocation(
  latitude: 10.762622,
  longitude: 106.660172,
  accuracyMeters: accuracy,
  capturedAt: DateTime.now().toUtc().subtract(age),
);
Map<String, dynamic> _attendance() => {
  'id': 1,
  'sessionId': 123,
  'studentId': 7,
  'status': 'Present',
  'checkedInAtUtc': DateTime.now().toUtc().toIso8601String(),
  'latitude': 10.762622,
  'longitude': 106.660172,
  'accuracyMeters': 10,
  'distanceMeters': 2,
};

class _LocationReader implements AttendanceLocationReader {
  _LocationReader(this.callback);
  final Future<AttendanceLocation> Function() callback;
  int calls = 0;
  @override
  Future<AttendanceLocation> current() {
    calls++;
    return callback();
  }
}

ApiClient _api(Future<http.Response> Function(http.Request) callback) =>
    ApiClient(
      baseUri: Uri.parse('https://example.com/api/'),
      client: MockClient(callback),
    );

void main() {
  test('QR đúng schema; không chấp nhận URL, JWT, JSON khác type/id/token', () {
    expect(AttendanceQrPayload.parse(_payload).sessionId, 123);
    for (final text in [
      'https://example.com',
      'eyJ.invalid.jwt',
      '{}',
      '{"type":"other","sessionId":123,"token":"x"}',
      '{"type":"attendance","sessionId":0,"token":"x"}',
      '{"type":"attendance","sessionId":"123","token":"x"}',
      '{"type":"attendance","sessionId":123,"token":""}',
    ]) {
      expect(() => AttendanceQrPayload.parse(text), throwsFormatException);
    }
    expect(
      () => AttendanceQrPayload.parse(_payload, expectedSessionId: 456),
      throwsFormatException,
    );
  });

  test('Độ chính xác GPS và vị trí mới: chặn sai số >50m, NaN, tọa độ sai, dữ liệu cũ', () {
    _location(accuracy: 50).validate();
    for (final position in [
      _location(accuracy: 50.1),
      _location(accuracy: 0),
      _location(accuracy: double.nan),
      _location(age: const Duration(minutes: 1)),
      AttendanceLocation(
        latitude: 100,
        longitude: 106,
        accuracyMeters: 10,
        capturedAt: DateTime.now(),
      ),
    ]) {
      expect(position.validate, throwsFormatException);
    }
  });

  test(
    'POST đúng DTO; không gửi studentId, thời gian client hoặc cả qrPayload',
    () async {
      final api = _api((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/attendance/check-in');
        final body = jsonDecode(request.body) as Map;
        expect(body.keys.toSet(), {
          'sessionId',
          'qrToken',
          'latitude',
          'longitude',
          'accuracyMeters',
        });
        expect(body['qrToken'], 'unit-test-qr');
        return envelope(status: 201, data: _attendance());
      });
      addTearDown(api.close);
      final result = await AttendanceService(api)
          .checkIn(AttendanceQrPayload.parse(_payload), _location());
      expect(result.status, 'Present');
    },
  );

  test(
    'Chặn callback/gửi lặp cả khi GPS đang chờ và sau khi thành công',
    () async {
      final pending = Completer<AttendanceLocation>();
      final gps = _LocationReader(() => pending.future);
      var requests = 0;
      final api = _api((_) async {
        requests++;
        return envelope(status: 201, data: _attendance());
      });
      addTearDown(api.close);
      final provider = CheckInProvider(
        AttendanceService(api),
        locationReader: gps,
      );
      addTearDown(provider.dispose);
      provider.selectQr(AttendanceQrPayload.parse(_payload));
      final first = provider.submit();
      await provider.submit();
      expect(gps.calls, 1);
      expect(requests, 0);
      pending.complete(_location());
      await first;
      await provider.submit();
      expect(provider.stage, CheckInStage.success);
      expect(requests, 1);
    },
  );

  test('GPS bị từ chối không gọi API và gợi ý cài đặt', () async {
    var requests = 0;
    final api = _api((_) async {
      requests++;
      return envelope();
    });
    addTearDown(api.close);
    final provider = CheckInProvider(
      AttendanceService(api),
      locationReader: _LocationReader(() async {
        throw const AttendanceLocationException(
          'Chưa cấp quyền GPS.',
          action: LocationSettingsAction.application,
        );
      }),
    );
    addTearDown(provider.dispose);
    provider.selectQr(AttendanceQrPayload.parse(_payload));
    await provider.submit();
    expect(provider.settingsAction, LocationSettingsAction.application);
    expect(provider.result, isNull);
    expect(requests, 0);
  });

  for (final status in [400, 403, 409]) {
    test('HTTP $status từ chối check-in; retry luôn lấy vị trí mới', () async {
      var requests = 0;
      final gps = _LocationReader(() async => _location());
      final api = _api((_) async {
        requests++;
        return requests == 1
            ? envelope(
                status: status,
                success: false,
                message: 'Điểm danh bị từ chối.',
              )
            : envelope(status: 201, data: _attendance());
      });
      addTearDown(api.close);
      final provider = CheckInProvider(
        AttendanceService(api),
        locationReader: gps,
      );
      addTearDown(provider.dispose);
      provider.selectQr(AttendanceQrPayload.parse(_payload));
      await provider.submit();
      expect(provider.stage, CheckInStage.error);
      expect(provider.result, isNull);
      await provider.submit();
      expect(provider.stage, CheckInStage.success);
      expect(gps.calls, 2);
    });
  }

  test(
    'Rời màn hình trong khi chờ GPS không gửi check-in sau dispose',
    () async {
      final pending = Completer<AttendanceLocation>();
      var requests = 0;
      final api = _api((_) async {
        requests++;
        return envelope();
      });
      addTearDown(api.close);
      final provider = CheckInProvider(
        AttendanceService(api),
        locationReader: _LocationReader(() => pending.future),
      );
      provider.selectQr(AttendanceQrPayload.parse(_payload));
      final operation = provider.submit();
      provider.dispose();
      pending.complete(_location());
      await operation;
      expect(requests, 0);
    },
  );

  test('HTTP 201 thiếu schema Attendance không được báo thành công', () async {
    final api = _api((_) async => envelope(status: 201, data: {'id': 1}));
    addTearDown(api.close);
    await expectLater(
      AttendanceService(api)
          .checkIn(AttendanceQrPayload.parse(_payload), _location()),
      throwsFormatException,
    );
  });

  testWidgets(
    'Giảng viên dựng đúng QR backend; ẩn mã khi pause và khi phiên đóng',
    (tester) async {
      var open = true;
      var requests = 0;
      final api = _api((request) async {
        requests++;
        if (request.url.path.endsWith('/qr')) {
          return envelope(
            data: {
              'sessionId': 123,
              'qrPayload': _payload,
              'expiresAtUtc': DateTime.now()
                  .toUtc()
                  .add(const Duration(minutes: 2))
                  .toIso8601String(),
            },
          );
        }
        return envelope(
          data: {'id': 123, 'attendanceState': open ? 'Open' : 'Closed'},
        );
      });
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: SessionQrScreen(
            service: AttendanceService(api),
            sessionId: 123,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<QrImageView>(find.byType(QrImageView)).semanticsLabel,
        'QR điểm danh buổi 123',
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byType(QrImageView), findsNothing);
      open = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
      expect(
        find.textContaining('Buổi học chưa mở hoặc đã đóng'),
        findsOneWidget,
      );
      expect(requests, 3);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('QR đã hết hạn từ backend bị ẩn, không tạo mã giả', (
    tester,
  ) async {
    final api = _api(
      (request) async => envelope(
        data: request.url.path.endsWith('/qr')
            ? {
                'sessionId': 123,
                'qrPayload': _payload,
                'expiresAtUtc': DateTime.now()
                    .toUtc()
                    .subtract(const Duration(seconds: 1))
                    .toIso8601String(),
              }
            : {'id': 123, 'attendanceState': 'Open'},
      ),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: SessionQrScreen(service: AttendanceService(api), sessionId: 123),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('QR server trả về đã hết hạn'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
