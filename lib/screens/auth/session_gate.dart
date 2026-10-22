import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/feedback_panel.dart';
import '../../widgets/page_body.dart';
import '../shared/dashboard_screen.dart';
import 'login_screen.dart';
import 'otp_screen.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key, required this.openConnection});
  final void Function(BuildContext) openConnection;
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  String? _sessionId;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sessionId = auth.user?.id ?? 'guest';
    if (_sessionId != sessionId) {
      _sessionId = sessionId;
      _navigatorKey = GlobalKey<NavigatorState>();
    }
    if (auth.booting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth.bootError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Khôi phục phiên đăng nhập')),
        body: PageBody(
          children: [
            FeedbackPanel(message: auth.bootError!, retry: auth.restore),
            TextButton(
              onPressed: auth.busy ? null : auth.logout,
              child: const Text('Xóa phiên và đăng nhập lại'),
            ),
          ],
        ),
      );
    }
    // Khi user thay đổi, bỏ toàn bộ các màn hình/dialog của phiên trước.
    return NavigatorPopHandler<Object?>(
      onPopWithResult: (result) => _navigatorKey.currentState?.pop(result),
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (context) => Consumer<AuthProvider>(
            builder: (context, session, _) {
              if (session.user != null) {
                return DashboardScreen(
                  openConnection: () => widget.openConnection(context),
                );
              }
              if (session.challenge != null) return const OtpScreen();
              return LoginScreen(
                openConnection: () => widget.openConnection(context),
              );
            },
          ),
        ),
      ),
    );
  }
}
