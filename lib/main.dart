// Uygulamanın giriş noktası: alarm motorunu başlatır, ayarları ve kayıtlı alarmları yükler.

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'services/alarm_repository.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Alarm ekranı için uygulamayı dikey modda sabitle
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Alarm paketini başlat (Android yerel servisleriyle bağlantı kurar)
  await Alarm.init();
  // Tema ayarını ve kayıtlı alarmları yükle
  await SettingsService.load();
  await AlarmRepository.instance.init();
  runApp(const AlarmApp());
}

class AlarmApp extends StatelessWidget {
  const AlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF5B5BD6);
    // Tema ayarı değişince uygulama anında yeniden çizilir
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: SettingsService.themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'Alarm',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: seed),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        ),
        // Türkçe dil desteği (saat/tarih seçici, düğmeler vb.)
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const HomeScreen(),
      ),
    );
  }
}
