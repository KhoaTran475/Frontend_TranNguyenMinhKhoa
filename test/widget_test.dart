import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:trannguyenminhkhoa_2380604158/app.dart';
import 'package:trannguyenminhkhoa_2380604158/config/app_config.dart';
import 'package:trannguyenminhkhoa_2380604158/config/app_theme.dart';
import 'package:trannguyenminhkhoa_2380604158/providers/connection_provider.dart';
import 'package:trannguyenminhkhoa_2380604158/screens/shared/connection_screen.dart';
import 'package:trannguyenminhkhoa_2380604158/services/api_client.dart';

import 'helpers/api_fixture.dart';

void main() {
  testWidgets('Thiếu BASE_URL hiển thị hướng dẫn trên màn hình Android nhỏ', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(AttendanceApp(config: AppConfig.fromBaseUrl(null)));
    await tester.pumpAndSettle();
    expect(find.text('Cần cấu hình API'), findsOneWidget);
    expect(find.textContaining('assets/config/.env'), findsOneWidget);
    expect(find.text('Kiểm tra kết nối'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Đang gửi bị khóa nút; HTML lỗi rồi thử lại nhận 401 đúng hợp đồng',
    (tester) async {
      final pending = Completer<http.Response>();
      var requests = 0;
      final provider = ConnectionProvider(
        ApiClient(
          baseUri: Uri.parse('https://example.com/api/'),
          tokenProvider: () async =>
              throw StateError('Probe không được đọc token'),
          client: MockClient((request) {
            requests++;
            expect(request.method, 'GET');
            expect(request.url.path, '/api/auth/me');
            expect(request.headers.containsKey('Authorization'), isFalse);
            return requests == 1
                ? pending.future
                : Future.value(
                    envelope(
                      status: 401,
                      success: false,
                      message: 'Cần đăng nhập.',
                    ),
                  );
          }),
        ),
      );
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('vi'),
            supportedLocales: const [Locale('vi')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const ConnectionScreen(baseUrl: 'https://example.com/api/'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kiểm tra kết nối'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await provider.checkConnection();
      expect(requests, 1);

      pending.complete(
        http.Response(
          '<html>Proxy error</html>',
          401,
          headers: {'content-type': 'text/html'},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('không đúng hợp đồng API'), findsOneWidget);
      expect(find.text('Đã kết nối backend, chưa đăng nhập'), findsNothing);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(find.text('Đã kết nối backend, chưa đăng nhập'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Chỉ 401 đúng envelope, không phải mọi HTTP error, được nhận là kết nối',
    () async {
      final payloads = [
        envelope(status: 404, success: false),
        envelope(status: 500, success: false),
        envelope(status: 401, success: false, data: {'unexpected': true}),
        envelope(data: {'not': 'User'}),
        envelope(status: 401, success: false),
      ];
      final provider = ConnectionProvider(
        ApiClient(
          baseUri: Uri.parse('https://example.com/api/'),
          client: MockClient((_) async => payloads.removeAt(0)),
        ),
      );
      addTearDown(provider.dispose);
      for (var index = 0; index < 4; index++) {
        await provider.checkConnection();
        expect(provider.status, ConnectionStatus.error);
      }
      await provider.checkConnection();
      expect(provider.status, ConnectionStatus.connected);
    },
  );

  test('Không notify sau khi đóng màn hình lúc request đang chạy', () async {
    final pending = Completer<http.Response>();
    final provider = ConnectionProvider(
      ApiClient(
        baseUri: Uri.parse('https://example.com/api/'),
        client: MockClient((_) => pending.future),
      ),
    );
    final operation = provider.checkConnection();
    provider.dispose();
    pending.complete(envelope(status: 401, success: false));
    await operation;
  });
}
