import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/attendance_check_in.dart';
import '../../providers/auth_provider.dart';
import '../../services/attendance_service.dart';
import '../../widgets/attendance_badge.dart';
import '../../widgets/feedback_panel.dart';
import '../../widgets/page_body.dart';

class SessionQrScreen extends StatefulWidget {
  const SessionQrScreen({
    super.key,
    required this.service,
    required this.sessionId,
  });
  final AttendanceService service;
  final int sessionId;
  @override
  State<SessionQrScreen> createState() => _SessionQrScreenState();
}

class _SessionQrScreenState extends State<SessionQrScreen>
    with WidgetsBindingObserver {
  SessionQr? _qr;
  String? _error;
  bool _loading = false, _foreground = true, _checking = false;
  int _generation = 0;
  DateTime _lastCheck = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _load() async {
    if (_loading || !_foreground) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _qr = null;
    });
    try {
      final session = await widget.service.session(widget.sessionId);
      if (session['attendanceState'] != 'Open') {
        throw const FormatException(
          'Buổi học chưa mở hoặc đã đóng điểm danh. QR không khả dụng.',
        );
      }
      final qr = await widget.service.qr(widget.sessionId);
      if (!qr.expiresAt.isAfter(DateTime.now().toUtc())) {
        throw const FormatException(
          'QR server trả về đã hết hạn. Kiểm tra giờ thiết bị và thử tải lại.',
        );
      }
      if (mounted && generation == _generation && _foreground) {
        setState(() {
          _qr = qr;
          _lastCheck = DateTime.now();
        });
      }
    } catch (failure) {
      if (mounted && generation == _generation) {
        setState(() => _error = describeError(failure));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _tick() {
    if (!mounted || !_foreground || _qr == null || _loading) return;
    if (!_qr!.expiresAt.isAfter(DateTime.now().toUtc())) {
      unawaited(_load());
      return;
    }
    setState(() {});
    if (DateTime.now().difference(_lastCheck) >= const Duration(seconds: 10)) {
      unawaited(_checkState());
    }
  }

  Future<void> _checkState() async {
    if (_checking || _loading) return;
    _checking = true;
    _lastCheck = DateTime.now();
    final generation = _generation;
    try {
      final session = await widget.service.session(widget.sessionId);
      if (session['attendanceState'] != 'Open') {
        throw const FormatException(
          'Buổi học đã đóng hoặc không còn cho điểm danh. QR đã được ẩn.',
        );
      }
    } catch (failure) {
      if (mounted && generation == _generation && _foreground) {
        setState(() {
          _qr = null;
          _error = describeError(failure);
        });
      }
    } finally {
      _checking = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      unawaited(_load());
    } else {
      _foreground = false;
      _generation++;
      setState(() {
        _qr = null;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qr = _qr;
    final valid =
        _foreground &&
        qr != null &&
        qr.expiresAt.isAfter(DateTime.now().toUtc());
    final remaining = qr == null
        ? 0
        : qr.expiresAt.difference(DateTime.now().toUtc()).inSeconds + 1;
    return Scaffold(
      appBar: AppBar(title: Text('QR điểm danh • Buổi #${widget.sessionId}')),
      body: PageBody(
        children: [
          const Text(
            'Sinh viên quét mã này trên thiết bị của mình và chia sẻ vị trí hiện tại để điểm danh.',
          ),
          const SizedBox(height: 20),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null) FeedbackPanel(message: _error!, retry: _load),
          if (valid) ...[
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: QrImageView(
                  data: qr.payload,
                  size: 240,
                  backgroundColor: Colors.white,
                  semanticsLabel: 'QR điểm danh buổi ${widget.sessionId}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Còn hiệu lực: ${remaining > 0 ? remaining : 0} giây',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'Hết hạn: ${localTime(qr.expiresAt.toIso8601String())}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'QR tự tải lại khi hết hạn. Khi buổi học đóng, server từ chối điểm danh ngay; '
              'màn hình kiểm tra trạng thái mỗi 10 giây.',
            ),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Tải lại QR'),
          ),
        ],
      ),
    );
  }
}
