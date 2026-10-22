import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_models.dart';
import '../../models/resource_schema.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../services/attendance_service.dart';
import '../../widgets/feedback_panel.dart';
import '../../widgets/page_body.dart';
import '../admin/users_screen.dart';
import 'attendance_screen.dart';
import 'resource_list_screen.dart';
import 'session_list_screen.dart';
import '../student/check_in_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.openConnection});
  final VoidCallback openConnection;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  DataService get _service => DataService(context.read<AuthProvider>().api);
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.detail('dashboard');
      if (!mounted) return;
      final role = context.read<AuthProvider>().user?.role;
      const counts = [
        'classCount',
        'sessionCount',
        'openSessionCount',
        'presentCount',
        'lateCount',
        'absentCount',
        'excusedCount',
      ];
      if (data['role'] != role?.value ||
          counts.any((key) => data[key] is! int || (data[key] as int) < 0)) {
        throw const FormatException(
          'Dữ liệu dashboard không đúng vai trò hoặc hợp đồng API.',
        );
      }
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();
    final admin = user.role == UserRole.admin;
    final lecturer = user.role == UserRole.lecturer;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          admin
              ? 'Trang quản trị'
              : 'Dashboard ${user.role.label.toLowerCase()}',
        ),
        actions: [
          IconButton(
            onPressed: widget.openConnection,
            tooltip: 'Kiểm tra kết nối',
            icon: const Icon(Icons.wifi_tethering),
          ),
          IconButton(
            onPressed: auth.busy
                ? null
                : () async {
                    final yes = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Đăng xuất?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Hủy'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Đăng xuất'),
                          ),
                        ],
                      ),
                    );
                    if (yes == true) await auth.logout();
                  },
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: PageBody(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Xin chào, ${user.fullName}',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${user.role.label} • ${user.username}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (auth.message != null) FeedbackPanel(message: auth.message!),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) FeedbackPanel(message: _error!, retry: _load),
            if (_data != null)
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final stat in const {
                      'classCount': 'Lớp học phần',
                      'sessionCount': 'Buổi học',
                      'openSessionCount': 'Đang điểm danh',
                      'presentCount': 'Có mặt',
                      'lateCount': 'Đi trễ',
                      'absentCount': 'Vắng mặt',
                      'excusedCount': 'Có phép',
                    }.entries)
                      SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_data![stat.key]}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                                Text(stat.value),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Text('Chức năng', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (admin) ...[
              for (final schema in ResourceSchema.all)
                _tile(
                  schema.title,
                  schema.icon,
                  () => _open(
                    ResourceListScreen(
                      service: _service,
                      schema: schema,
                      canWrite: true,
                      isAdmin: true,
                      canManageSessions: true,
                    ),
                  ),
                ),
              _tile(
                'Tài khoản người dùng',
                Icons.manage_accounts_outlined,
                () => _open(
                  UsersScreen(service: _service, currentUserId: user.id),
                ),
              ),
            ] else ...[
              if (!lecturer)
                _tile(
                  'Quét QR điểm danh',
                  Icons.qr_code_scanner,
                  () => _open(
                    CheckInScreen(service: AttendanceService(_service.api)),
                  ),
                ),
              _tile(
                'Lớp học phần của tôi',
                Icons.groups_outlined,
                () => _open(
                  ResourceListScreen(
                    service: _service,
                    schema: ResourceSchema.classes,
                    path: 'me/classes',
                    canManageSessions: lecturer,
                  ),
                ),
              ),
              _tile(
                'Lịch học của tôi',
                Icons.event_outlined,
                () => _open(
                  SessionListScreen(service: _service, canManage: lecturer),
                ),
              ),
              if (!lecturer)
                _tile(
                  'Kết quả điểm danh',
                  Icons.fact_check_outlined,
                  () => _open(AttendanceScreen(service: _service)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile(String title, IconData icon, VoidCallback open) => Card(
    child: ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: open,
    ),
  );
}
