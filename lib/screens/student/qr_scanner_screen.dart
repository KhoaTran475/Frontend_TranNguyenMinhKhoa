import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/attendance_check_in.dart';
import '../../widgets/feedback_panel.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key, this.expectedSessionId});
  final int? expectedSessionId;
  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _returning = false, _starting = false, _foreground = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  Future<void> _start() async {
    if (_starting ||
        _returning ||
        !_foreground ||
        !mounted ||
        _controller.value.isRunning) {
      return;
    }
    _starting = true;
    try {
      await _controller.start();
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Không mở được camera. Kiểm tra quyền camera rồi thử lại.',
        );
      }
    } finally {
      _starting = false;
    }
  }

  Future<void> _stop() async {
    try {
      await _controller.stop();
    } catch (_) {
      /* Camera có thể chưa khởi tạo. */
    }
  }

  void _detected(BarcodeCapture capture) {
    if (_returning || !_foreground || !mounted) return;
    for (final barcode in capture.barcodes) {
      final text = barcode.rawValue;
      if (text == null) continue;
      try {
        final payload = AttendanceQrPayload.parse(
          text,
          expectedSessionId: widget.expectedSessionId,
        );
        _returning = true;
        unawaited(_finish(payload));
        return;
      } catch (_) {
        setState(
          () => _error =
              'QR không hợp lệ hoặc không thuộc buổi học đã chọn. '
              'Hãy quét mã điểm danh do giảng viên hiển thị.',
        );
      }
    }
  }

  Future<void> _finish(AttendanceQrPayload payload) async {
    await _stop();
    if (mounted) Navigator.pop(context, payload);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    // Hộp thoại quyền camera cũng phát lifecycle event khi camera chưa sẵn sàng.
    if (!_controller.value.hasCameraPermission) return;
    if (_foreground) {
      unawaited(_start());
    } else {
      unawaited(_stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose().catchError((Object _) {}));
    super.dispose();
  }

  Widget _cameraError(MobileScannerException error) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FeedbackPanel(
            message: error.errorCode == MobileScannerErrorCode.permissionDenied
                ? 'Chưa được cấp quyền camera. Mở cài đặt và cho phép camera để quét QR.'
                : 'Camera không khả dụng trên thiết bị này. Kiểm tra camera và thử lại.',
            retry: _start,
          ),
          TextButton(
            onPressed: () async {
              await Geolocator.openAppSettings();
            },
            child: const Text('Mở cài đặt ứng dụng'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quét QR điểm danh')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Đưa mã QR của giảng viên vào camera. '
            'Quét xong bạn sẽ xác nhận chia sẻ vị trí trước khi gửi.',
          ),
        ),
        Expanded(
          child: ClipRect(
            child: MobileScanner(
              controller: _controller,
              onDetect: _detected,
              errorBuilder: (context, error) => _cameraError(error),
            ),
          ),
        ),
        if (_error != null) FeedbackPanel(message: _error!, retry: _start),
      ],
    ),
  );
}
