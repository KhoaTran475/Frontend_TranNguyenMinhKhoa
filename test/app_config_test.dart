import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trannguyenminhkhoa_2380604158/config/app_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Chuẩn hóa BASE_URL, giữ đúng một /api/', () {
    final config = AppConfig.fromBaseUrl('  https://example.com//api///  ');
    expect(config.isValid, isTrue);
    expect(config.baseUri.toString(), 'https://example.com/api/');
  });

  for (final value in <String?>[
    null,
    '',
    ' ',
    'https://<conveyor-host>/api/',
    'http://example.com/api/',
    'https://example.com/',
    'https://example.com/api/api/',
    'https://user:password@example.com/api/',
    'https://example.com/api/?x=1',
    'https://example.com/api/#secret',
    'https://invalid host/api/',
  ]) {
    test('Cấu hình sai được báo lỗi: $value', () {
      final config = AppConfig.fromBaseUrl(value);
      expect(config.isValid, isFalse);
      expect(config.baseUri, isNull);
      expect(config.error, isNotEmpty);
    });
  }

  test('Đọc .env bằng flutter_dotenv; thiếu asset không gây crash', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    String? content;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      if (key != AppConfig.envAssetPath || content == null) return null;
      return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
    });
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));

    final missing = await AppConfig.load(environment: DotEnv());
    expect(missing.isValid, isFalse);
    expect(missing.error, contains('Chưa tìm thấy file'));

    content = '';
    rootBundle.evict(AppConfig.envAssetPath);
    final empty = await AppConfig.load(environment: DotEnv());
    expect(empty.isValid, isFalse);

    content = 'BASE_URL=https://example.com/api/';
    rootBundle.evict(AppConfig.envAssetPath);
    final valid = await AppConfig.load(environment: DotEnv());
    expect(valid.isValid, isTrue);
    expect(valid.baseUri.toString(), 'https://example.com/api/');
  });
}
