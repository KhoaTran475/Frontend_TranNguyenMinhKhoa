import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../models/attendance_check_in.dart';
import '../../providers/check_in_provider.dart';
import '../../services/attendance_location_service.dart';
import '../../services/attendance_service.dart';
import '../../services/data_service.dart';
import '../../widgets/attendance_badge.dart';
import '../../widgets/feedback_panel.dart';
import '../../widgets/page_body.dart';
import '../shared/attendance_screen.dart';
import 'qr_scanner_screen.dart';

class CheckInScreen extends StatelessWidget {
  const CheckInScreen({
    super.key,
    required this.service,
    this.expectedSessionId,
  });
  final AttendanceService service;
  final int? expectedSessionId;
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => CheckInProvider(service),
    child: _CheckInBody(service: service, expectedSessionId: expectedSessionId),
  );
}

class _CheckInBody extends StatelessWidget {
  const _CheckInBody({required this.service, required this.expectedSessionId});
  final AttendanceService service;
  final int? expectedSessionId;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<CheckInProvider>();
    final result = state.result;
    return PopScope(
      canPop: !state.busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Điểm danh bằng QR và vị trí')),
        body: PageBody(
          children: [
            Icon(
              result != null
                  ? Icons.check_circle_outline
                  : Icons.qr_code_scanner,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ứng dụng chỉ lấy vị trí mới khi bạn bấm xác nhận điểm danh. '
              'Tọa độ và độ chính xác được gửi cho hệ thống để kiểm tra bạn đang ở gần phòng học; '
              'không theo dõi vị trí liên tục.',
            ),
            const SizedBox(height: 20),
            if (result == null) ...[
              Text(
                state.qr == null
                    ? 'Bước 1: Quét QR do giảng viên cung cấp'
                    : 'Đã quét QR của buổi #${state.qr!.sessionId}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: state.busy
                    ? null
                    : () async {
                        final payload =
                            await Navigator.push<AttendanceQrPayload>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QrScannerScreen(
                                  expectedSessionId: expectedSessionId,
                                ),
                              ),
                            );
                        if (payload != null && context.mounted) {
                          state.selectQr(payload);
                        }
                      },
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(state.qr == null ? 'Quét mã QR' : 'Quét mã khác'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: state.busy || state.qr == null ? null : state.submit,
                icon: const Icon(Icons.my_location),
                label: Text(switch (state.stage) {
                  CheckInStage.locating => 'Đang lấy GPS mới…',
                  CheckInStage.submitting => 'Đang gửi điểm danh…',
                  _ => 'Chia sẻ vị trí và điểm danh',
                }),
              ),
              if (state.busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                ),
            ],
            if (state.location != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Vị trí: ${state.location!.latitude.toStringAsFixed(6)}, ${state.location!.longitude.toStringAsFixed(6)}\n'
                  'Độ chính xác: ${state.location!.accuracyMeters.toStringAsFixed(1)} m',
                ),
              ),
            if (state.error != null) FeedbackPanel(message: state.error!),
            if (state.settingsAction != LocationSettingsAction.none)
              TextButton(
                onPressed: () async {
                  if (state.settingsAction == LocationSettingsAction.location) {
                    await Geolocator.openLocationSettings();
                  } else {
                    await Geolocator.openAppSettings();
                  }
                },
                child: const Text('Mở cài đặt vị trí'),
              ),
            if (result != null) ...[
              const FeedbackPanel(
                message: 'Điểm danh thành công. Kết quả do backend xác nhận.',
                error: false,
              ),
              AttendanceBadge(status: result.status),
              Text(
                'Thời gian: ${localTime(result.checkedInAt.toIso8601String())}',
              ),
              Text(
                'Khoảng cách đến phòng: ${result.distanceMeters.toStringAsFixed(1)} m',
              ),
            ],
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: state.busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AttendanceScreen(service: DataService(service.api)),
                      ),
                    ),
              icon: const Icon(Icons.history),
              label: const Text('Xem lịch sử điểm danh'),
            ),
          ],
        ),
      ),
    );
  }
}
