import 'package:flutter/material.dart';

import '../../widgets/page_body.dart';

class ConfigurationScreen extends StatelessWidget {
  const ConfigurationScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cấu hình kết nối')),
      body: PageBody(
        children: [
          Icon(
            Icons.settings_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            'Cần cấu hình API',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 24),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. Chạy backend trong Visual Studio và SQL Server.'),
                  SizedBox(height: 12),
                  Text('2. Sao chép .env.example thành assets/config/.env.'),
                  SizedBox(height: 12),
                  Text(
                    '3. Gán BASE_URL bằng HTTPS URL Conveyor thực tế, '
                    'kết thúc bằng /api/.',
                  ),
                  SizedBox(height: 12),
                  SelectableText('BASE_URL=https://<conveyor-host>/api/'),
                  SizedBox(height: 12),
                  Text(
                    '4. Dừng app và chạy lại flutter run sau khi lưu file. '
                    'Hot reload không nạp lại .env.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'File .env chỉ chứa cấu hình công khai như BASE_URL. '
            'Không đặt SMTP password, JWT secret hoặc SQL connection string.',
          ),
        ],
      ),
    );
  }
}
