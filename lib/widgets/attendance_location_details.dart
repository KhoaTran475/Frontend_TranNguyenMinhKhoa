import 'package:flutter/material.dart';

class AttendanceLocationDetails extends StatelessWidget {
  const AttendanceLocationDetails({super.key, required this.attendance});
  final Map<String, dynamic> attendance;
  @override
  Widget build(BuildContext context) {
    final latitude = attendance['latitude'];
    final longitude = attendance['longitude'];
    final accuracy = attendance['accuracyMeters'];
    if (latitude is! num || longitude is! num) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SelectableText(
        'Vị trí lúc điểm danh: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}'
        '${accuracy is num ? '\nĐộ chính xác GPS: ${accuracy.toStringAsFixed(1)} m' : ''}',
      ),
    );
  }
}
