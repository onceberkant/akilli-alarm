// Uygulamanın giriş noktası: alarm motorunu başlatır, kayıtlı alarmları yükler.

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'services/alarm_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Alarm ekranı için uygulamayı dikey modda sabitle
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Alarm paketini başlat (Android yerel servisleriyle bağlantı kurar)
  await Alarm.init();
  // Kayıtlı alarmları SharedPreferences'tan yükle
  await AlarmRepository.instance.init();
  runApp(const AlarmApp());
}

class AlarmApp extends StatelessWidget {
  const AlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF5B5BD6);
    return MaterialApp(
      title: 'Alarm',
      debugShowCheckedModeBanner: false,
      // Telefonun sistem temasına göre açık/koyu
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      ),
      // Türkçe dil desteği (saat seçici, düğmeler vb.)
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const HomeScreen(),
    );
  }
}
