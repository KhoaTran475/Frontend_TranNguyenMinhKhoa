import 'package:flutter/material.dart';

import '../../models/resource_schema.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../widgets/feedback_panel.dart';
import 'session_list_screen.dart';

class ClassDetailScreen extends StatefulWidget {
  const ClassDetailScreen({
    super.key,
    required this.service,
    required this.courseClass,
    required this.isAdmin,
    required this.canManage,
  });
  final DataService service;
  final Map<String, dynamic> courseClass;
  final bool isAdmin, canManage;
  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  RecordPage? _students;
  String? _error;
  bool _loading = true, _busy = false;
  int _page = 1;
  String get _path => 'classes/${widget.courseClass['id']}/students';
  @override
  void initState() {
    super.initState();
    if (widget.canManage) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.service.list(_path, page: _page);
      if (mounted) setState(() => _students = data);
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enroll() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final options = await widget.service.options('students');
      if (!mounted) return;
      int? selected;
      final id = await showDialog<int>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Thêm sinh viên vào lớp'),
            content: SizedBox(
              width: 420,
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sinh viên'),
                items: options
                    .map(
                      (item) => DropdownMenuItem<int>(
                        value: item['id'] as int,
                        child: Text(
                          '${item['studentCode']} • ${item['fullName']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setDialogState(() => selected = value),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () => Navigator.pop(context, selected),
                child: const Text('Thêm'),
              ),
            ],
          ),
        ),
      );
      if (id == null) return;
      await widget.service.api.post(_path, body: {'studentId': id});
      if (mounted) await _load();
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> student) async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gỡ sinh viên khỏi lớp?'),
        content: Text(recordTitle(student)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gỡ khỏi lớp'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.service.api.delete('$_path/${student['id']}');
      if (_students?.items.length == 1 && _page > 1) _page--;
      if (mounted) await _load();
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.courseClass['name'].toString())),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Lớp ${widget.courseClass['code']}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SessionListScreen(
                      service: widget.service,
                      classId: widget.courseClass['id'] as int,
                      title: 'Buổi học • ${widget.courseClass['code']}',
                      canManage: widget.canManage,
                    ),
                  ),
                ),
                icon: const Icon(Icons.event_outlined),
                label: const Text('Xem các buổi học'),
              ),
              if (widget.isAdmin)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _enroll,
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Thêm sinh viên vào lớp'),
                ),
            ],
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) FeedbackPanel(message: _error!, retry: _load),
        if (widget.canManage)
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _students == null || _students!.items.isEmpty
                ? const Center(child: Text('Lớp chưa có sinh viên.'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      children: [
                        for (final student in _students!.items)
                          Card(
                            child: ListTile(
                              title: Text(recordTitle(student)),
                              subtitle: Text(recordSubtitle(student)),
                              trailing: widget.isAdmin
                                  ? IconButton(
                                      tooltip: 'Gỡ khỏi lớp',
                                      onPressed: _busy
                                          ? null
                                          : () => _remove(student),
                                      icon: const Icon(
                                        Icons.person_remove_outlined,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        if (widget.canManage)
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
                Text('Trang $_page • ${_students?.total ?? 0} sinh viên'),
                IconButton(
                  onPressed: _loading || !(_students?.hasNext ?? false)
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
