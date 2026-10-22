import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trannguyenminhkhoa_2380604158/models/api_exception.dart';
import 'package:trannguyenminhkhoa_2380604158/services/api_client.dart';

import 'helpers/api_fixture.dart';

void main() {
  final baseUri = Uri.parse('https://example.com/api/');
  TypeMatcher<ApiException> failure(ApiFailureKind kind, {int? status}) =>
      isA<ApiException>()
          .having((error) => error.kind, 'kind', kind)
          .having((error) => error.statusCode, 'statusCode', status);

  test('Năm method, body JSON UTF-8, slash, query và Bearer hook', () async {
    final requests = <http.Request>[];
    final api = ApiClient(
      baseUri: baseUri,
      tokenProvider: () async => 'test-token',
      client: MockClient((request) async {
        requests.add(request);
        return envelope();
      }),
    );
    addTearDown(api.close);

    await api.get(
      '/auth//me/',
      query: {'search': 'Tiếng Việt', 'page': 2, 'omit': null},
    );
    await api.post('resource', body: {'name': 'Sinh viên'});
    await api.put('resource/1', body: {'name': 'Giảng viên'});
    await api.patch('resource/1', body: {'isActive': true});
    await api.delete('resource/1', query: {'page': 1});

    expect(requests.map((request) => request.method), [
      'GET',
      'POST',
      'PUT',
      'PATCH',
      'DELETE',
    ]);
    expect(requests.first.url.path, '/api/auth/me');
    expect(requests.first.url.queryParameters, {
      'search': 'Tiếng Việt',
      'page': '2',
    });
    expect(requests.last.url.queryParameters['page'], '1');
    expect(jsonDecode(requests[1].body), {'name': 'Sinh viên'});
    for (final request in requests) {
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.headers['Content-Type'], startsWith('application/json'));
      expect(request.followRedirects, isFalse);
    }
  });

  test('Probe có thể chủ động bỏ Bearer token', () async {
    var tokenReads = 0;
    final api = ApiClient(
      baseUri: baseUri,
      tokenProvider: () async {
        tokenReads++;
        return 'test-token';
      },
      client: MockClient((request) async {
        expect(request.headers.containsKey('Authorization'), isFalse);
        return envelope();
      }),
    );
    addTearDown(api.close);
    await api.get('auth/me', authenticated: false);
    expect(tokenReads, 0);
  });

  test(
    'Không gửi token đến endpoint tuyệt đối hoặc đi ra ngoài /api',
    () async {
      var calls = 0;
      final api = ApiClient(
        baseUri: baseUri,
        client: MockClient((_) async {
          calls++;
          return envelope();
        }),
      );
      addTearDown(api.close);
      for (final path in [
        'https://other.example/auth/me',
        '//other.example/me',
        '../me',
      ]) {
        await expectLater(api.get(path), throwsArgumentError);
      }
      expect(calls, 0);
    },
  );

  test('Đọc envelope và data.items, kể cả danh sách rỗng', () async {
    final api = ApiClient(
      baseUri: baseUri,
      client: MockClient(
        (_) async => envelope(
          data: {'items': [], 'totalCount': 0, 'page': 1, 'pageSize': 20},
        ),
      ),
    );
    addTearDown(api.close);
    final response = await api.get('items');
    expect((response.data as Map)['items'], isEmpty);
    expect(response.message, 'Thành công.');
  });

  test(
    'HTTP 503 giữ lại data Challenge; HTTP 400 giữ errors validation/Identity',
    () async {
      final challenge = {'challengeId': 'unit-test-only', 'purpose': 'Login'};
      final payloads = [
        envelope(status: 503, success: false, data: challenge),
        envelope(
          status: 400,
          success: false,
          errors: {
            'Email': ['Email không hợp lệ.'],
          },
        ),
        envelope(
          status: 400,
          success: false,
          errors: [
            {'code': 'Duplicate', 'description': 'Trùng.'},
          ],
        ),
      ];
      final api = ApiClient(
        baseUri: baseUri,
        client: MockClient((_) async => payloads.removeAt(0)),
      );
      addTearDown(api.close);
      await expectLater(
        api.get('resource'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.kind, 'kind', ApiFailureKind.http)
              .having((error) => error.response?.data, 'Challenge', challenge),
        ),
      );
      await expectLater(
        api.get('resource'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.response?.errors,
            'errors',
            isA<Map>(),
          ),
        ),
      );
      await expectLater(
        api.get('resource'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.response?.errors,
            'errors',
            isA<List>(),
          ),
        ),
      );
    },
  );

  test('Phân biệt lỗi nghiệp vụ HTTP 200 và lỗi HTTP 500', () async {
    final payloads = [
      envelope(success: false),
      envelope(status: 500, success: false),
    ];
    final api = ApiClient(
      baseUri: baseUri,
      client: MockClient((_) async => payloads.removeAt(0)),
    );
    addTearDown(api.close);
    await expectLater(
      api.get('resource'),
      throwsA(failure(ApiFailureKind.business, status: 200)),
    );
    await expectLater(
      api.get('resource'),
      throwsA(failure(ApiFailureKind.http, status: 500)),
    );
  });

  for (final status in [200, 401, 404, 502]) {
    test('HTML HTTP $status không phải API hợp lệ', () async {
      final api = ApiClient(
        baseUri: baseUri,
        client: MockClient(
          (_) async => http.Response(
            '<html>Conveyor</html>',
            status,
            headers: {'content-type': 'text/html'},
          ),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        api.get('auth/me'),
        throwsA(failure(ApiFailureKind.invalidResponse, status: status)),
      );
    });
  }

  test(
    'Từ chối JSON hỏng, thiếu envelope, sai errors và status mâu thuẫn',
    () async {
      final payloads = [
        http.Response('{', 200, headers: {'content-type': 'application/json'}),
        http.Response(
          '{"success":true}',
          200,
          headers: {'content-type': 'application/json'},
        ),
        envelope(status: 401),
        envelope(errors: 'không đúng định dạng'),
      ];
      final api = ApiClient(
        baseUri: baseUri,
        client: MockClient((_) async => payloads.removeAt(0)),
      );
      addTearDown(api.close);
      for (var index = 0; index < 4; index++) {
        await expectLater(
          api.get('auth/me'),
          throwsA(
            isA<ApiException>().having(
              (error) => error.kind,
              'kind',
              ApiFailureKind.invalidResponse,
            ),
          ),
        );
      }
    },
  );

  test('Lỗi DNS/mạng được phân loại; không lộ nội dung lỗi gốc', () async {
    final api = ApiClient(
      baseUri: baseUri,
      client: MockClient((_) async {
        throw const SocketException('sensitive-information');
      }),
    );
    addTearDown(api.close);
    await expectLater(
      api.get('auth/me'),
      throwsA(
        failure(ApiFailureKind.network).having(
          (error) => error.message,
          'message',
          isNot(contains('sensitive-information')),
        ),
      ),
    );
  });

  test('Lỗi chứng chỉ HTTPS không được bỏ qua', () async {
    final api = ApiClient(
      baseUri: baseUri,
      client: MockClient((_) async {
        throw const HandshakeException('certificate error');
      }),
    );
    addTearDown(api.close);
    await expectLater(
      api.get('auth/me'),
      throwsA(
        failure(ApiFailureKind.network).having(
          (error) => error.message,
          'message',
          contains('chứng chỉ HTTPS'),
        ),
      ),
    );
  });

  test('Timeout cho phép trả quyền điều khiển để thử lại', () async {
    final pending = Completer<http.Response>();
    final api = ApiClient(
      baseUri: baseUri,
      timeout: const Duration(milliseconds: 20),
      client: MockClient((_) => pending.future),
    );
    addTearDown(api.close);
    await expectLater(
      api.get('auth/me'),
      throwsA(failure(ApiFailureKind.timeout)),
    );
    pending.complete(envelope());
  });
}
