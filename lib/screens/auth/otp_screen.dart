import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/feedback_panel.dart';
import '../../widgets/page_body.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otp = TextEditingController();
  final _form = GlobalKey<FormState>();
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final challenge = auth.challenge!;
    final now = DateTime.now().toUtc();
    final remaining = challenge.resendAt.difference(now).inSeconds + 1;
    final expired = !now.isBefore(challenge.expiresAt);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          challenge.verifiesEmail ? 'Xác minh email' : 'OTP đăng nhập',
        ),
      ),
      body: PageBody(
        children: [
          Icon(
            Icons.mark_email_read_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            'Nhập mã xác minh',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text('Mã OTP gửi tới ${challenge.email}.'),
          Text(
            'Hết hạn lúc ${DateFormat('HH:mm:ss dd/MM/yyyy').format(challenge.expiresAt.toLocal())}.',
          ),
          const SizedBox(height: 16),
          if (auth.message != null)
            FeedbackPanel(message: auth.message!, error: auth.messageIsError),
          if (expired)
            const FeedbackPanel(
              message: 'Mã đã hết hạn. Vui lòng gửi lại OTP.',
            ),
          Form(
            key: _form,
            child: TextFormField(
              controller: _otp,
              enabled: !auth.busy,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'OTP gồm 6 chữ số'),
              validator: (value) => RegExp(r'^\d{6}$').hasMatch(value ?? '')
                  ? null
                  : 'Nhập đủ 6 chữ số OTP.',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: auth.busy || expired
                ? null
                : () async {
                    if (_form.currentState!.validate()) {
                      await auth.verify(_otp.text);
                    }
                  },
            child: Text(auth.busy ? 'Đang xử lý…' : 'Xác minh'),
          ),
          TextButton(
            onPressed: auth.busy || remaining > 0
                ? null
                : () async {
                    await auth.resend();
                    if (mounted) _otp.clear();
                  },
            child: Text(
              remaining > 0 ? 'Gửi lại sau ${remaining}s' : 'Gửi lại OTP',
            ),
          ),
          TextButton(
            onPressed: auth.busy ? null : auth.cancelChallenge,
            child: const Text('Quay lại đăng nhập'),
          ),
        ],
      ),
    );
  }
}
