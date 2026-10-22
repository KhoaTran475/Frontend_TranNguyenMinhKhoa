import 'package:flutter/material.dart';

import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../services/attendance_service.dart';
import '../../widgets/attendance_badge.dart';
import '../../widgets/feedback_panel.dart';
import 'attendance_screen.dart';
import 'session_form_screen.dart';
import '../lecturer/session_qr_screen.dart';
import '../student/check_in_screen.dart';

class SessionListScreen extends StatefulWidget {
  const SessionListScreen({
    super.key,
    required this.service,
    this.classId,
    this.title = 'Lịch học của tôi',
    this.canManage = false,
  });
  final DataService service;
  final int? classId;
  final String title;
  final bool canManage;
  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  RecordPage? _data;
  String? _error;
  bool _loading = true, _busy = false;
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
        widget.classId == null
            ? 'me/sessions'
            : 'classes/${widget.classId}/sessions',
        page: _page,
      );
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? record]) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final fresh = record == null
          ? null
          : await widget.service.detail('sessions/${record['id']}');
      if (!mounted) return;
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => SessionFormScreen(
            service: widget.service,
            classId: widget.classId ?? record!['courseClassId'],
            record: fresh,
          ),
        ),
      );
      if (changed == true && mounted) await _load();
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _action(Map<String, dynamic> item, String action) async {
    if (_busy) return;
    if (action == 'qr') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionQrScreen(
            service: AttendanceService(widget.service.api),
            sessionId: item['id'] as int,
          ),
        ),
      );
      return;
    }
    if (action == 'edit') {
      await _edit(item);
      return;
    }
    final label = {
      'open': 'Mở điểm danh',
      'close': 'Đóng điểm danh',
      'delete': 'Xóa buổi học',
    }[action]!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$label?'),
        content: Text(
          action == 'close'
              ? 'Sinh viên chưa điểm danh sẽ được ghi nhận vắng. Không thể mở lại buổi đã đóng.'
              : 'Thao tác được kiểm tra theo thời gian và trạng thái buổi học trên server.',
        ),
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
    if (ok != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      if (action == 'delete') {
        await widget.service.api.delete('sessions/${item['id']}');
        if (_data?.items.length == 1 && _page > 1) _page--;
      } else {
        await widget.service.api.post('sessions/${item['id']}/$action');
      }
      if (mounted) await _load();
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          tooltip: 'Tải lại',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: widget.canManage && widget.classId != null
        ? FloatingActionButton.extended(
            onPressed: _busy ? null : () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Tạo buổi học'),
          )
        : null,
    body: Column(
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) FeedbackPanel(message: _error!, retry: _load),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _data == null || _data!.items.isEmpty
              ? const Center(child: Text('Chưa có buổi học.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    children: [
                      for (final item in _data!.items)
                        Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.event_outlined),
                            ),
                            title: Text(
                              'Buổi #${item['id']} • Lớp #${item['courseClassId']}',
                            ),
                            subtitle: Text(
                              '${localTime(item['startAtUtc'])}\n'
                              'Đóng điểm danh: ${localTime(item['attendanceClosesAtUtc'])}\n'
                              '${{'Scheduled': 'Chưa mở', 'Open': 'Đang điểm danh', 'Closed': 'Đã đóng'}[item['attendanceState']] ?? item['attendanceState']}',
                            ),
                            isThreeLine: true,
                            onTap: widget.canManage
                                ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AttendanceScreen(
                                        service: widget.service,
                                        sessionId: item['id'] as int,
                                        canEdit: true,
                                      ),
                                    ),
                                  )
                                : item['attendanceState'] == 'Open'
                                ? () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CheckInScreen(
                                          service: AttendanceService(
                                            widget.service.api,
                                          ),
                                          expectedSessionId: item['id'] as int,
                                        ),
                                      ),
                                    );
                                    if (mounted) _load();
                                  }
                                : null,
                            trailing:
                                widget.canManage &&
                                    item['attendanceState'] != 'Closed'
                                ? PopupMenuButton<String>(
                                    enabled: !_busy,
                                    onSelected: (action) =>
                                        _action(item, action),
                                    itemBuilder: (_) => [
                                      if (item['attendanceState'] ==
                                          'Scheduled') ...[
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Sửa buổi học'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'open',
                                          child: Text('Mở điểm danh'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Xóa buổi học'),
                                        ),
                                      ],
                                      if (item['attendanceState'] == 'Open')
                                        const PopupMenuItem(
                                          value: 'qr',
                                          child: Text('Hiện QR điểm danh'),
                                        ),
                                      if (item['attendanceState'] == 'Open')
                                        const PopupMenuItem(
                                          value: 'close',
                                          child: Text('Đóng điểm danh'),
                                        ),
                                    ],
                                  )
                                : !widget.canManage &&
                                      item['attendanceState'] == 'Open'
                                ? const Icon(
                                    Icons.qr_code_scanner,
                                    semanticLabel: 'Quét QR điểm danh',
                                  )
                                : null,
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
                onPressed: _loading || _page <= 1
                    ? null
                    : () {
                        _page--;
                        _load();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Trang $_page • ${_data?.total ?? 0} buổi'),
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
