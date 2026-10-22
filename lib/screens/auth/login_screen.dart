import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/feedback_panel.dart';
import '../../widgets/page_body.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.openConnection});
  final VoidCallback openConnection;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController(),
      _password = TextEditingController();
  final _code = TextEditingController(),
      _name = TextEditingController(),
      _email = TextEditingController();
  final _confirm = TextEditingController();
  bool _register = false, _obscure = true;
  @override
  void initState() {
    super.initState();
    _username.text = context.read<AuthProvider>().lastUsername;
  }

  @override
  void dispose() {
    for (final c in [_username, _password, _code, _name, _email, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    if (_register) {
      await auth.register({
        'studentCode': _code.text.trim(),
        'fullName': _name.text.trim(),
        'email': _email.text.trim(),
        'username': _username.text.trim(),
        'password': _password.text,
      });
    } else {
      await auth.login(_username.text.trim(), _password.text);
    }
    if (mounted) {
      _password.clear();
      _confirm.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Điểm danh sinh viên'),
        actions: [
          IconButton(
            onPressed: auth.busy ? null : widget.openConnection,
            tooltip: 'Kiểm tra kết nối',
            icon: const Icon(Icons.wifi_tethering),
          ),
        ],
      ),
      body: PageBody(
        children: [
          Icon(
            Icons.school_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            _register ? 'Tạo tài khoản sinh viên' : 'Chào mừng trở lại',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _register
                ? 'Mã sinh viên và email phải khớp hồ sơ nhà trường đã tạo.'
                : 'Đăng nhập bằng tài khoản, sau đó xác minh OTP gửi qua email.',
          ),
          const SizedBox(height: 20),
          if (auth.message != null)
            FeedbackPanel(message: auth.message!, error: auth.messageIsError),
          Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                children: [
                  if (_register) ...[
                    _field(
                      _code,
                      'Mã sinh viên',
                      max: 40,
                      icon: Icons.badge_outlined,
                    ),
                    _field(_name, 'Họ và tên', icon: Icons.person_outline),
                    _field(
                      _email,
                      'Email',
                      icon: Icons.email_outlined,
                      email: true,
                    ),
                  ],
                  _field(
                    _username,
                    'Tên đăng nhập',
                    max: 100,
                    icon: Icons.person_outline,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      controller: _password,
                      enabled: !auth.busy,
                      obscureText: _obscure,
                      autofillHints: [
                        _register
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: _register
                          ? Validators.password
                          : (value) => Validators.requiredText(value, max: 128),
                      onFieldSubmitted: (_) {
                        if (!auth.busy) _submit();
                      },
                    ),
                  ),
                  if (_register)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextFormField(
                        controller: _confirm,
                        enabled: !auth.busy,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Nhập lại mật khẩu',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (value) => value != _password.text
                            ? 'Mật khẩu chưa khớp.'
                            : Validators.password(value),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: auth.busy ? null : _submit,
                      child: Text(
                        auth.busy
                            ? 'Đang xử lý…'
                            : _register
                            ? 'Đăng ký qua email'
                            : 'Đăng nhập',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: auth.busy
                        ? null
                        : () {
                            setState(() {
                              _register = !_register;
                              _password.clear();
                              _confirm.clear();
                              _form.currentState?.reset();
                            });
                          },
                    child: Text(
                      _register
                          ? 'Đã có tài khoản? Đăng nhập'
                          : 'Sinh viên chưa có tài khoản? Đăng ký',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int max = 150,
    required IconData icon,
    bool email = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !context.read<AuthProvider>().busy,
      keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: email
          ? Validators.email
          : (value) => Validators.requiredText(value, max: max),
    ),
  );
}
