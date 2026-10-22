import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trannguyenminhkhoa_2380604158/models/api_exception.dart';
import 'package:trannguyenminhkhoa_2380604158/models/auth_models.dart';
import 'package:trannguyenminhkhoa_2380604158/providers/auth_provider.dart';
import 'package:trannguyenminhkhoa_2380604158/services/token_store.dart';

import 'helpers/api_fixture.dart';

class MemoryTokenStore implements TokenStore {
  String? token;
  bool failWrite = false;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('test storage unavailable');
    token = value;
  }

  @override
  Future<void> delete() async {
    token = null;
  }
}

Map<String, dynamic> challengeData({
  String id = 'challenge-one',
  String purpose = 'Login',
  Duration resendDelay = Duration.zero,
}) => {
  'challengeId': id,
  'purpose': purpose,
  'maskedEmail': 's***@example.com',
  'expiresAtUtc': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 5))
      .toIso8601String(),
  'resendAvailableAtUtc': DateTime.now()
      .toUtc()
      .add(resendDelay)
      .toIso8601String(),
};
Map<String, dynamic> userData(String role) => {
  'id': 'user-one',
  'username': 'student.test',
  'fullName': 'Nguyễn Văn An',
  'email': 'student@example.com',
  'role': role,
  'studentId': role == 'Student' ? 1 : null,
  'lecturerId': role == 'Lecturer' ? 1 : null,
};
Map<String, dynamic> loginData(String role) => {
  'accessToken': 'test-only-jwt',
  'expiresAtUtc': DateTime.now()
      .toUtc()
      .add(const Duration(hours: 1))
      .toIso8601String(),
  'user': userData(role),
};

void main() {
  final base = Uri.parse('https://example.com/api/');
  for (final role in UserRole.values) {
    test('Password → OTP → lưu token → /me → logout: ${role.value}', () async {
      final store = MemoryTokenStore();
      final calls = <String>[];
      final auth = AuthProvider(
        baseUri: base,
        store: store,
        client: MockClient((request) async {
          calls.add(request.url.path);
          if (request.url.path == '/api/auth/login') {
            expect(request.headers.containsKey('Authorization'), isFalse);
            expect(jsonDecode(request.body), {
              'username': 'test',
              'password': 'Password!1',
            });
            return envelope(data: challengeData());
          }
          if (request.url.path == '/api/auth/verify-login-otp') {
            expect(jsonDecode(request.body), {
              'challengeId': 'challenge-one',
              'otp': '123456',
            });
            return envelope(data: loginData(role.value));
          }
          expect(request.url.path, '/api/auth/me');
          expect(request.headers['Authorization'], 'Bearer test-only-jwt');
          return envelope(data: userData(role.value));
        }),
      );
      addTearDown(auth.dispose);
      await auth.restore();
      expect(auth.user, isNull);
      expect(await auth.login('test', 'Password!1'), isTrue);
      expect(auth.user, isNull);
      expect(store.token, isNull);
      expect(await auth.verify('123456'), isTrue);
      expect(auth.user?.role, role);
      expect(store.token, 'test-only-jwt');
      await auth.restore();
      expect(auth.user?.role, role);
      await auth.logout();
      expect(store.token, isNull);
      expect(auth.user, isNull);
      expect(calls.length, 3);
    });
  }

  test(
    'SMTP 503 vẫn mở OTP, resend thay challengeId; verify email không cấp JWT',
    () async {
      final store = MemoryTokenStore();
      final paths = <String>[];
      final auth = AuthProvider(
        baseUri: base,
        store: store,
        client: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path.endsWith('/register')) {
            return envelope(
              status: 503,
              success: false,
              message: 'SMTP chưa được cấu hình.',
              data: challengeData(purpose: 'VerifyEmail'),
            );
          }
          if (request.url.path.endsWith('/resend-otp')) {
            expect(jsonDecode(request.body)['challengeId'], 'challenge-one');
            return envelope(
              data: challengeData(id: 'challenge-two', purpose: 'VerifyEmail'),
            );
          }
          expect(request.url.path, '/api/auth/verify-email');
          expect(jsonDecode(request.body)['challengeId'], 'challenge-two');
          return envelope(data: {'emailVerified': true});
        }),
      );
      addTearDown(auth.dispose);
      await auth.restore();
      expect(
        await auth.register({
          'studentCode': 'SV1',
          'fullName': 'An',
          'email': 'student@example.com',
          'username': 'student',
          'password': 'Password!1',
        }),
        isFalse,
      );
      expect(auth.challenge?.verifiesEmail, isTrue);
      expect(auth.message, contains('SMTP'));
      expect(await auth.resend(), isTrue);
      expect(auth.challenge?.id, 'challenge-two');
      expect(await auth.verify('123456'), isTrue);
      expect(auth.challenge, isNull);
      expect(auth.user, isNull);
      expect(store.token, isNull);
      expect(paths, [
        '/api/auth/register',
        '/api/auth/resend-otp',
        '/api/auth/verify-email',
      ]);
    },
  );

  test(
    'Login 403 VerifyEmail điều hướng sang xác minh; cooldown chặn resend',
    () async {
      var requests = 0;
      final auth = AuthProvider(
        baseUri: base,
        store: MemoryTokenStore(),
        client: MockClient((_) async {
          requests++;
          return envelope(
            status: 403,
            success: false,
            data: challengeData(
              purpose: 'VerifyEmail',
              resendDelay: const Duration(seconds: 60),
            ),
          );
        }),
      );
      addTearDown(auth.dispose);
      await auth.login('test', 'Password!1');
      expect(auth.challenge?.verifiesEmail, isTrue);
      expect(await auth.resend(), isFalse);
      expect(requests, 1);
    },
  );

  test('Chặn gửi password lặp khi đang chờ', () async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final auth = AuthProvider(
      baseUri: base,
      store: MemoryTokenStore(),
      client: MockClient((_) {
        calls++;
        return pending.future;
      }),
    );
    addTearDown(auth.dispose);
    final first = auth.login('test', 'Password!1');
    expect(await auth.login('test', 'Password!1'), isFalse);
    pending.complete(envelope(data: challengeData()));
    await first;
    expect(calls, 1);
    expect(auth.busy, isFalse);
  });

  test(
    '401 có JWT xóa token; 401 login công khai không gọi xóa phiên',
    () async {
      final store = MemoryTokenStore()..token = 'old-token';
      final auth = AuthProvider(
        baseUri: base,
        store: store,
        client: MockClient(
          (_) async =>
              envelope(status: 401, success: false, message: 'Cần đăng nhập.'),
        ),
      );
      addTearDown(auth.dispose);
      await auth.restore();
      expect(store.token, isNull);
      expect(auth.user, isNull);
      expect(auth.bootError, isNull);
      expect(await auth.login('test', 'wrong'), isFalse);
      expect(auth.message, contains('HTTP 401'));
    },
  );

  test('Mạng lỗi khi mở app giữ token để retry, không tự đăng nhập bằng dữ liệu lưu', () async {
    final store = MemoryTokenStore()..token = 'old-token';
    var fail = true;
    final auth = AuthProvider(
      baseUri: base,
      store: store,
      client: MockClient((_) async {
        if (fail) throw http.ClientException('offline');
        return envelope(data: userData('Student'));
      }),
    );
    addTearDown(auth.dispose);
    await auth.restore();
    expect(auth.user, isNull);
    expect(auth.bootError, isNotNull);
    expect(store.token, 'old-token');
    fail = false;
    await auth.restore();
    expect(auth.user?.role, UserRole.student);
    expect(auth.bootError, isNull);
  });

  test('Không chấp nhận role lạ hoặc storage không lưu được token', () async {
    final store = MemoryTokenStore()..failWrite = true;
    var role = 'Owner';
    final auth = AuthProvider(
      baseUri: base,
      store: store,
      client: MockClient(
        (request) async => envelope(
          data: request.url.path.endsWith('/login')
              ? challengeData()
              : loginData(role),
        ),
      ),
    );
    addTearDown(auth.dispose);
    await auth.login('test', 'Password!1');
    expect(await auth.verify('123456'), isFalse);
    expect(auth.user, isNull);
    role = 'Admin';
    expect(await auth.verify('123456'), isFalse);
    expect(auth.user, isNull);
    expect(store.token, isNull);
  });

  test('401 từ request nghiệp vụ làm mất phiên đã đăng nhập', () async {
    final store = MemoryTokenStore()..token = 'old-token';
    final auth = AuthProvider(
      baseUri: base,
      store: store,
      client: MockClient(
        (request) async => request.url.path.endsWith('/me')
            ? envelope(data: userData('Admin'))
            : envelope(status: 401, success: false),
      ),
    );
    addTearDown(auth.dispose);
    await auth.restore();
    await expectLater(auth.api.get('students'), throwsA(isA<ApiException>()));
    expect(auth.user, isNull);
    expect(store.token, isNull);
  });
}
