import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'providers/connection_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/session_gate.dart';
import 'screens/shared/configuration_screen.dart';
import 'screens/shared/connection_screen.dart';
import 'services/api_client.dart';

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'Điểm danh sinh viên',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: config.isValid
          ? SessionGate(
              openConnection: (context) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ConnectionScreen(baseUrl: config.baseUri.toString()),
                ),
              ),
            )
          : ConfigurationScreen(message: config.error!),
    );

    if (!config.isValid) return app;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(baseUri: config.baseUri!)..restore(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              ConnectionProvider(ApiClient(baseUri: config.baseUri!)),
        ),
      ],
      child: app,
    );
  }
}
