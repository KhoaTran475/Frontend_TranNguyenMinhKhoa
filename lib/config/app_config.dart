import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._({this.baseUri, this.error});

  static const envAssetPath = 'assets/config/.env';

  final Uri? baseUri;
  final String? error;

  bool get isValid => baseUri != null && error == null;

  static Future<AppConfig> load({DotEnv? environment}) async {
    final env = environment ?? dotenv;
    try {
      await env.load(fileName: envAssetPath);
      return AppConfig.fromBaseUrl(env.env['BASE_URL']);
    } on FileNotFoundError {
      return const AppConfig._(error: 'Chưa tìm thấy file assets/config/.env.');
    } on EmptyEnvFileError {
      return const AppConfig._(
        error: 'File .env đang trống. Cần khai báo BASE_URL.',
      );
    } catch (_) {
      return const AppConfig._(
        error: 'Không đọc được cấu hình .env. Hãy kiểm tra nội dung file.',
      );
    }
  }

  factory AppConfig.fromBaseUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return const AppConfig._(
        error: 'Chưa khai báo BASE_URL trong file .env.',
      );
    }

    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        RegExp(r'[\s<>\\{}]').hasMatch(text) ||
        !_isValidHost(uri.host) ||
        uri.pathSegments.where((segment) => segment.isNotEmpty).join('/') !=
            'api') {
      return const AppConfig._(
        error:
            'BASE_URL không hợp lệ. Cần URL HTTPS thực tế, dạng '
            'https://ten-may-chu.conveyor.cloud/api/. '
            'Không dùng <conveyor-host>, thông tin đăng nhập, query hoặc fragment.',
      );
    }

    return AppConfig._(baseUri: uri.replace(path: '/api/'));
  }

  static bool _isValidHost(String host) {
    if (host.contains(':')) return true;
    return host
        .split('.')
        .every(
          (label) =>
              RegExp(r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?$')
                  .hasMatch(label),
        );
  }
}
