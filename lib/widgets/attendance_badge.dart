import 'package:flutter/material.dart';

const attendanceLabels = {
  'Present': 'Có mặt',
  'Late': 'Đi trễ',
  'Absent': 'Vắng mặt',
  'Excused': 'Có phép',
};
String localTime(Object? value) {
  if (value == null) return 'Chưa có';
  final date = DateTime.tryParse(value.toString());
  if (date == null) return 'Thời gian không hợp lệ';
  final local = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)} ${two(local.day)}/${two(local.month)}/${local.year}';
}

class AttendanceBadge extends StatelessWidget {
  const AttendanceBadge({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Present' => const Color(0xFF167341),
      'Late' => const Color(0xFF956000),
      'Absent' => const Color(0xFFBA1A1A),
      'Excused' => const Color(0xFF1565C0),
      _ => Colors.grey,
    };
    return Chip(
      label: Text(
        attendanceLabels[status] ?? status,
        style: TextStyle(color: color),
      ),
      side: BorderSide.none,
      backgroundColor: color.withValues(alpha: 0.1),
    );
  }
}
