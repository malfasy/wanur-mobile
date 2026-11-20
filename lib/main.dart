import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'data/data_source_controller.dart';
import 'providers/glove_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // Pastikan binding initialized sebelum menjalankan app (Best Practice)
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id');

  // GloveProvider = koneksi BLE. DataSourceController = sumber data aktif
  // (glove nyata atau simulasi) + opsi Pengaturan Pengembang.
  final glove = GloveProvider();
  final sources = DataSourceController(glove);
  await sources.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<GloveProvider>.value(value: glove),
        ChangeNotifierProvider<DataSourceController>.value(value: sources),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wanur Glove',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // Alur: Splash -> Quote -> Home
      home: const SplashScreen(),
    );
  }
}
