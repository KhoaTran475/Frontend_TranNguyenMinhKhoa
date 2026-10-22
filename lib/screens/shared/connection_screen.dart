import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/connection_provider.dart';
import '../../widgets/page_body.dart';

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key, required this.baseUrl});

  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();
    final hasError = connection.status == ConnectionStatus.error;
    final connected = connection.status == ConnectionStatus.connected;
    final colors = Theme.of(context).colorScheme;
    final statusColor = hasError ? colors.error : colors.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Điểm danh sinh viên')),
      body: PageBody(
        children: [
          Text(
            'Kiểm tra kết nối API',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text('Chạy backend và bật HTTPS Conveyor trước khi kiểm tra.'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BASE_URL hiện tại',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(baseUrl),
                  const SizedBox(height: 12),
                  const Text('Endpoint kiểm tra: GET /auth/me'),
                  const SizedBox(height: 8),
                  const Text(
                    'HTTP 401 đúng hợp đồng nghĩa là đã kết nối '
                    'backend và chưa đăng nhập.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: connection.isChecking
                ? null
                : connection.checkConnection,
            icon: connection.isChecking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(hasError ? Icons.refresh : Icons.wifi_tethering),
            label: Text(
              connection.isChecking
                  ? 'Đang kiểm tra…'
                  : hasError
                  ? 'Thử lại'
                  : 'Kiểm tra kết nối',
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            liveRegion: true,
            child: Card(
              color: hasError ? colors.errorContainer : colors.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      connected
                          ? Icons.check_circle_outline
                          : hasError
                          ? Icons.error_outline
                          : Icons.info_outline,
                      color: statusColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      connection.message,
                      style: TextStyle(
                        color: hasError
                            ? colors.onErrorContainer
                            : colors.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Thời gian chờ tối đa 15 giây. '
            'Sau khi đổi .env, dừng và chạy lại app để áp dụng URL mới.',
          ),
        ],
      ),
    );
  }
}
