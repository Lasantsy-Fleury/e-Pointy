import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/constants.dart';
import 'state/app_settings.dart';
import 'state/session_controller.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sur poste de développement (Windows/Linux/macOS), SQLite est fourni par
  // sqflite_common_ffi. Sur Android, sqflite natif est utilisé.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  Intl.defaultLocale = 'fr_FR';
  await initializeDateFormatting('fr_FR', null);

  final settings = AppSettings();
  await settings.load();

  runApp(MipointyApp(settings: settings));
}

class MipointyApp extends StatelessWidget {
  const MipointyApp({super.key, required this.settings, this.controller});

  final AppSettings settings;

  /// Contrôleur optionnel, injecté par les tests (base isolée).
  final SessionController? controller;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettings>.value(value: settings),
        ChangeNotifierProvider<SessionController>(
          create: (_) => controller ?? SessionController(settings: settings),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomeScreen(),
      ),
    );
  }
}
