import 'package:flutter/material.dart';

import '../../config/validators.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../widgets/attendance_badge.dart';
import '../../widgets/attendance_location_details.dart';
import '../../widgets/feedback_panel.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    required this.service,
    this.sessionId,
    this.canEdit = false,
  });
  final DataService service;
  final int? sessionId;
  final bool canEdit;
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  RecordPage? _data;
  bool _loading = true, _busy = false;
  String? _error;
  int _page = 1;
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
      final data = await widget.service.list(
        widget.sessionId == null
            ? 'me/attendance'
            : 'sessions/${widget.sessionId}/attendance',
        page: _page,
      );
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    if (_busy) return;
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _AttendanceEditDialog(status: item['status'] as String),
    );
    if (result == null || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.service.api.put('attendance/${item['id']}', body: result);
      if (mounted) await _load();
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _history(Map<String, dynamic> item) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final history = await widget.service.options(
        'attendance/${item['id']}/changes',
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lịch sử điều chỉnh'),
          content: SizedBox(
            width: 480,
            child: history.isEmpty
                ? const Text('Chưa có điều chỉnh.')
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final change in history)
                          ListTile(
                            title: Text(
                              '${attendanceLabels[change['previousStatus']]} → ${attendanceLabels[change['newStatus']]}',
                            ),
                            subtitle: Text(
                              '${change['reason']}\n${localTime(change['changedAtUtc'])}',
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.sessionId == null
            ? 'Lịch sử điểm danh của tôi'
            : 'Điểm danh • Buổi #${widget.sessionId}',
      ),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          tooltip: 'Tải lại',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) FeedbackPanel(message: _error!, retry: _load),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _data == null || _data!.items.isEmpty
              ? const Center(child: Text('Chưa có kết quả điểm danh.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (final item in _data!.items)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.sessionId == null
                                            ? 'Buổi học #${item['sessionId']}'
                                            : 'Sinh viên #${item['studentId']}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ),
                                    AttendanceBadge(
                                      status: item['status'].toString(),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Check-in: ${localTime(item['checkedInAtUtc'])}',
                                ),
                                if (item['distanceMeters'] != null)
                                  Text(
                                    'Khoảng cách: ${(item['distanceMeters'] as num).toStringAsFixed(1)} m',
                                  ),
                                AttendanceLocationDetails(attendance: item),
                                if (widget.canEdit)
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      TextButton.icon(
                                        onPressed: _busy
                                            ? null
                                            : () => _edit(item),
                                        icon: const Icon(Icons.edit_outlined),
                                        label: const Text('Điều chỉnh'),
                                      ),
                                      TextButton.icon(
                                        onPressed: _busy
                                            ? null
                                            : () => _history(item),
                                        icon: const Icon(Icons.history),
                                        label: const Text('Lịch sử sửa'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
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
              Text('Trang $_page • ${_data?.total ?? 0} kết quả'),
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

class _AttendanceEditDialog extends StatefulWidget {
  const _AttendanceEditDialog({required this.status});
  final String status;
  @override
  State<_AttendanceEditDialog> createState() => _AttendanceEditDialogState();
}

class _AttendanceEditDialogState extends State<_AttendanceEditDialog> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  late String _status = widget.status;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Điều chỉnh điểm danh'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Trạng thái'),
              items: attendanceLabels.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) => _status = value!,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reason,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Lý do bắt buộc'),
              validator: (value) => Validators.requiredText(value, max: 1000),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, {
              'status': _status,
              'reason': _reason.text.trim(),
            });
          }
        },
        child: const Text('Lưu điều chỉnh'),
      ),
    ],
  );
}
