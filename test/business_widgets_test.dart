import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:trannguyenminhkhoa_2380604158/config/app_theme.dart';
import 'package:trannguyenminhkhoa_2380604158/models/resource_schema.dart';
import 'package:trannguyenminhkhoa_2380604158/providers/auth_provider.dart';
import 'package:trannguyenminhkhoa_2380604158/screens/auth/session_gate.dart';
import 'package:trannguyenminhkhoa_2380604158/screens/shared/dashboard_screen.dart';
import 'package:trannguyenminhkhoa_2380604158/screens/shared/resource_list_screen.dart';
import 'package:trannguyenminhkhoa_2380604158/services/api_client.dart';
import 'package:trannguyenminhkhoa_2380604158/services/data_service.dart';

import 'auth_provider_test.dart' show MemoryTokenStore, userData;
import 'helpers/api_fixture.dart';

Widget testApp(Widget child) => MaterialApp(
  theme: AppTheme.light,
  locale: const Locale('vi'),
  supportedLocales: const [Locale('vi')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: child,
);

void main() {
  for (final role in ['Admin', 'Lecturer', 'Student']) {
    testWidgets(
      'Dashboard $role chỉ có chức năng đúng vai trò; logout xóa route bảo vệ',
      (tester) async {
        final store = MemoryTokenStore()..token = 'test-token';
        final auth = AuthProvider(
          baseUri: Uri.parse('https://example.com/api/'),
          store: store,
          client: MockClient(
            (request) async => envelope(
              data: request.url.path.endsWith('/me')
                  ? userData(role)
                  : {
                      'role': role,
                      'classCount': 2,
                      'sessionCount': 3,
                      'openSessionCount': 0,
                      'presentCount': 1,
                      'lateCount': 0,
                      'absentCount': 0,
                      'excusedCount': 0,
                    },
            ),
          ),
        );
        addTearDown(auth.dispose);
        await auth.restore();
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: auth,
            child: testApp(SessionGate(openConnection: (_) {})),
          ),
        );
        await tester.pumpAndSettle();
        if (role == 'Admin') {
          expect(find.text('Trang quản trị'), findsOneWidget);
          expect(find.text('Tài khoản người dùng'), findsOneWidget);
        } else {
          expect(find.text('Tài khoản người dùng'), findsNothing);
          expect(find.text('Lớp học phần của tôi'), findsOneWidget);
          expect(
            find.text('Kết quả điểm danh'),
            role == 'Student' ? findsOneWidget : findsNothing,
          );
        }
        final navigator = Navigator.of(
          tester.element(find.byType(DashboardScreen)),
        );
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Protected detail')),
          ),
        );
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Protected detail'), findsNothing);
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Protected detail')),
          ),
        );
        await tester.pumpAndSettle();
        await auth.logout();
        await tester.pumpAndSettle();
        expect(find.text('Chào mừng trở lại'), findsOneWidget);
        expect(find.text('Trang quản trị'), findsNothing);
        expect(find.text('Protected detail'), findsNothing);
        expect(store.token, isNull);
      },
    );
  }

  testWidgets('CRUD môn học: tạo → tìm kiếm → sửa → xóa đúng DTO và endpoint', (
    tester,
  ) async {
    final records = <Map<String, dynamic>>[];
    final writes = <String>[];
    final api = ApiClient(
      baseUri: Uri.parse('https://example.com/api/'),
      client: MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'GET' && path == '/api/subjects') {
          return envelope(
            data: {
              'items': records,
              'totalCount': records.length,
              'page': 1,
              'pageSize': 20,
            },
          );
        }
        if (request.method == 'GET') return envelope(data: records.single);
        writes.add('${request.method} $path');
        if (request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.keys.toSet(), {'code', 'name'});
          records.add({'id': 1, ...body});
        } else if (request.method == 'PUT') {
          records[0] = {
            'id': 1,
            ...jsonDecode(request.body) as Map<String, dynamic>,
          };
        } else if (request.method == 'DELETE') {
          records.clear();
        }
        return envelope(
          status: request.method == 'POST' ? 201 : 200,
          data: records.firstOrNull,
        );
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      testApp(
        ResourceListScreen(
          service: DataService(api),
          schema: ResourceSchema.subjects,
          canWrite: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm mới'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'LTDD');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Lập trình di động',
    );
    await tester.tap(find.text('Lưu thông tin'));
    await tester.pumpAndSettle();
    expect(find.text('Lập trình di động'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'LTDD');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sửa'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Lập trình Flutter',
    );
    await tester.tap(find.text('Lưu thông tin'));
    await tester.pumpAndSettle();
    expect(find.text('Lập trình Flutter'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có dữ liệu.'), findsOneWidget);
    expect(writes, [
      'POST /api/subjects',
      'PUT /api/subjects/1',
      'DELETE /api/subjects/1',
    ]);
    expect(tester.takeException(), isNull);
  });
}
