import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/resource_schema.dart';
import '../../models/auth_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../widgets/feedback_panel.dart';
import '../../widgets/page_body.dart';

class SessionFormScreen extends StatefulWidget {
  const SessionFormScreen({
    super.key,
    required this.service,
    required this.classId,
    this.record,
  });
  final DataService service;
  final int classId;
  final Map<String, dynamic>? record;
  @override
  State<SessionFormScreen> createState() => _SessionFormScreenState();
}

class _SessionFormScreenState extends State<SessionFormScreen> {
  final _form = GlobalKey<FormState>();
  final _late = TextEditingController();
  final _roomInput = TextEditingController();
  late final bool _canChooseRooms;
  List<Map<String, dynamic>> _rooms = [];
  int? _room;
  DateTime? _start, _end, _closes;
  bool _loading = true, _saving = false;
  String? _error, _loadError;
  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _room = record?['roomId'];
    _roomInput.text = _room?.toString() ?? '';
    _canChooseRooms = context.read<AuthProvider>().user?.role == UserRole.admin;
    _late.text = (record?['lateAfterMinutes'] ?? 15).toString();
    DateTime? parse(String key) =>
        record?[key] == null ? null : DateTime.parse(record![key]).toLocal();
    _start = parse('startAtUtc');
    _end = parse('endAtUtc');
    _closes = parse('attendanceClosesAtUtc');
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      if (_canChooseRooms) _rooms = await widget.service.options('rooms');
    } catch (error) {
      _loadError = describeError(error);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _late.dispose();
    _roomInput.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime? current) async {
    final now = DateTime.now();
    final initial = current ?? now;
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (day == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    return time == null
        ? null
        : DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (!_canChooseRooms) _room = int.parse(_roomInput.text.trim());
    if (_start == null || _end == null || _closes == null) {
      setState(
        () => _error =
            'Chọn đầy đủ thời gian bắt đầu, kết thúc và đóng điểm danh.',
      );
      return;
    }
    final late = int.parse(_late.text);
    if (!_start!.isBefore(_closes!) ||
        _closes!.isAfter(_end!) ||
        _start!.add(Duration(minutes: late)).isAfter(_closes!)) {
      setState(
        () => _error =
            'Cần: bắt đầu < đóng điểm danh ≤ kết thúc; '
            'ngưỡng đi trễ không vượt thời điểm đóng điểm danh.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      'roomId': _room,
      'startAtUtc': _start!.toUtc().toIso8601String(),
      'endAtUtc': _end!.toUtc().toIso8601String(),
      'attendanceClosesAtUtc': _closes!.toUtc().toIso8601String(),
      'lateAfterMinutes': late,
    };
    try {
      if (widget.record == null) {
        await widget.service.api.post(
          'classes/${widget.classId}/sessions',
          body: body,
        );
      } else {
        await widget.service.api.put(
          'sessions/${widget.record!['id']}',
          body: body,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = describeError(error);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.record == null ? 'Tạo buổi học' : 'Sửa buổi học'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? PageBody(
              children: [FeedbackPanel(message: _loadError!, retry: _load)],
            )
          : PageBody(
              children: [
                const Text(
                  'Thời gian bên dưới là giờ địa phương; ứng dụng gửi UTC lên API.',
                ),
                const SizedBox(height: 16),
                if (_error != null) FeedbackPanel(message: _error!),
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_canChooseRooms)
                        DropdownButtonFormField<int>(
                          initialValue:
                              _rooms.any((room) => room['id'] == _room)
                              ? _room
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Phòng học',
                          ),
                          items: _rooms
                              .map(
                                (room) => DropdownMenuItem<int>(
                                  value: room['id'],
                                  child: Text(
                                    recordTitle(room),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _saving ? null : (value) => _room = value,
                          validator: (value) =>
                              value == null ? 'Chọn phòng học.' : null,
                        )
                      else
                        TextFormField(
                          controller: _roomInput,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Số ID phòng',
                            helperText:
                                'Dùng ID phòng do quản trị viên cung cấp.',
                          ),
                          validator: (value) {
                            final id = int.tryParse(value?.trim() ?? '');
                            return id == null || id <= 0
                                ? 'Nhập ID phòng là số nguyên dương.'
                                : null;
                          },
                        ),
                      const SizedBox(height: 12),
                      for (final entry in [
                        ('Bắt đầu', _start, 0),
                        ('Kết thúc', _end, 1),
                        ('Đóng điểm danh', _closes, 2),
                      ])
                        OutlinedButton.icon(
                          onPressed: _saving
                              ? null
                              : () async {
                                  final selected = await _pick(entry.$2);
                                  if (selected != null && mounted) {
                                    setState(() {
                                      if (entry.$3 == 0) {
                                        _start = selected;
                                      } else if (entry.$3 == 1) {
                                        _end = selected;
                                      } else {
                                        _closes = selected;
                                      }
                                    });
                                  }
                                },
                          icon: const Icon(Icons.schedule),
                          label: Text(
                            '${entry.$1}: ${entry.$2 == null ? 'Chọn thời gian' : DateFormat('HH:mm dd/MM/yyyy').format(entry.$2!)}',
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _late,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Ngưỡng đi trễ (phút)',
                        ),
                        validator: (value) {
                          final number = int.tryParse(value ?? '');
                          return number == null || number < 0 || number > 240
                              ? 'Nhập số nguyên từ 0 đến 240.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Đang lưu…' : 'Lưu buổi học'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    ),
  );
}
