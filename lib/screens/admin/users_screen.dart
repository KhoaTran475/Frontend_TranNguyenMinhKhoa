import 'package:flutter/material.dart';

import '../../config/validators.dart';
import '../../models/auth_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../widgets/feedback_panel.dart';
import '../../widgets/page_body.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({
    super.key,
    required this.service,
    required this.currentUserId,
  });
  final DataService service;
  final String currentUserId;
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  RecordPage? _data;
  final _search = TextEditingController();
  String? _error;
  bool _loading = true, _busy = false;
  int _page = 1, _generation = 0;
  String _term = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.service.list(
        'users',
        page: _page,
        search: _term,
      );
      if (mounted && generation == _generation) setState(() => _data = data);
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = describeError(error));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _toggle(Map<String, dynamic> account) async {
    final user = jsonObject(account['user']);
    if (_busy || user['id'] == widget.currentUserId) return;
    final active = account['isActive'] != true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${active ? 'Mở khóa' : 'Khóa'} tài khoản?'),
        content: Text(user['username'].toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.service.api.patch(
        'users/${Uri.encodeComponent(user['id'].toString())}/active',
        body: {'isActive': active},
      );
      if (mounted) await _load();
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tài khoản người dùng')),
    floatingActionButton: FloatingActionButton.extended(
      icon: const Icon(Icons.person_add_outlined),
      label: const Text('Tạo tài khoản giảng viên'),
      onPressed: _busy
          ? null
          : () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => _CreateLecturerUser(service: widget.service),
                ),
              );
              if (changed == true && mounted) _load();
            },
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _search,
            maxLength: 150,
            decoration: InputDecoration(
              hintText: 'Tìm tên, username hoặc email',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Tìm kiếm',
                icon: const Icon(Icons.arrow_forward),
                onPressed: () {
                  _page = 1;
                  _term = _search.text;
                  _load();
                },
              ),
            ),
            onSubmitted: (_) {
              _page = 1;
              _term = _search.text;
              _load();
            },
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) FeedbackPanel(message: _error!, retry: _load),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _data == null || _data!.items.isEmpty
              ? const Center(child: Text('Chưa có tài khoản.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                    children: [
                      for (final item in _data!.items)
                        Builder(
                          builder: (context) {
                            final user = jsonObject(item['user']);
                            final role = UserRole.values
                                .where((role) => role.value == user['role'])
                                .firstOrNull;
                            return Card(
                              child: ListTile(
                                title: Text(user['fullName'].toString()),
                                subtitle: Text(
                                  '${user['username']} • ${role?.label ?? user['role']}\n'
                                  '${item['isActive'] == true ? 'Đang hoạt động' : 'Đã khóa'} • ${item['emailConfirmed'] == true ? 'Email đã xác minh' : 'Chưa xác minh email'}',
                                ),
                                trailing: IconButton(
                                  tooltip: item['isActive'] == true
                                      ? 'Khóa tài khoản'
                                      : 'Mở khóa',
                                  onPressed:
                                      _busy ||
                                          user['id'] == widget.currentUserId
                                      ? null
                                      : () => _toggle(item),
                                  icon: Icon(
                                    item['isActive'] == true
                                        ? Icons.lock_open
                                        : Icons.lock_outline,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
        ),
        SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _loading || _page == 1
                    ? null
                    : () {
                        _page--;
                        _load();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Trang $_page • ${_data?.total ?? 0} tài khoản'),
              IconButton(
                onPressed: _loading || !(_data?.hasNext ?? false)
                    ? null
                    : () {
                        _page++;
                        _load();
                      },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CreateLecturerUser extends StatefulWidget {
  const _CreateLecturerUser({required this.service});
  final DataService service;
  @override
  State<_CreateLecturerUser> createState() => _CreateLecturerUserState();
}

class _CreateLecturerUserState extends State<_CreateLecturerUser> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController(),
      _password = TextEditingController();
  List<Map<String, dynamic>> _lecturers = [];
  int? _selected;
  bool _loading = true, _busy = false;
  String? _error, _loadError;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      _lecturers = (await widget.service.options('lecturers'))
          .where((item) => item['userId'] == null)
          .toList();
    } catch (error) {
      _loadError = describeError(error);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.api.post(
        'users/lecturer',
        body: {
          'lecturerId': _selected,
          'username': _username.text.trim(),
          'password': _password.text,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = describeError(error);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Tạo tài khoản giảng viên')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? PageBody(
              children: [FeedbackPanel(message: _loadError!, retry: _load)],
            )
          : PageBody(
              children: [
                const Text(
                  'Chọn hồ sơ chưa liên kết. Giảng viên cần xác minh email ở lần đăng nhập đầu tiên.',
                ),
                const SizedBox(height: 16),
                if (_error != null) FeedbackPanel(message: _error!),
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Giảng viên',
                        ),
                        items: _lecturers
                            .map(
                              (item) => DropdownMenuItem<int>(
                                value: item['id'],
                                child: Text(
                                  '${item['lecturerCode']} • ${item['fullName']}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _busy ? null : (value) => _selected = value,
                        validator: (value) => value == null
                            ? 'Chọn giảng viên chưa có tài khoản.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _username,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Tên đăng nhập',
                        ),
                        validator: (value) =>
                            Validators.requiredText(value, max: 100),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        enabled: !_busy,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Mật khẩu ban đầu',
                        ),
                        validator: Validators.password,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        child: Text(_busy ? 'Đang tạo…' : 'Tạo tài khoản'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    ),
  );
}
