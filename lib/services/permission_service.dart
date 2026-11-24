// Alarmın arka planda ve kilit ekranında kesin çalışması için gereken izinler.

import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionService {
  /// Eksik izinlerin kullanıcıya gösterilecek listesini döndürür (boşsa her şey tamam)
  static Future<List<String>> missing() async {
    if (!Platform.isAndroid) return const [];
    final list = <String>[];
    // Android 13+: bildirim izni olmadan alarm ekranı/bildirimi görünmez
    if (!await Permission.notification.isGranted) list.add('Bildirim');
    // Android 12+: tam zamanında (exact) alarm izni
    if (!await Permission.scheduleExactAlarm.isGranted) list.add('Tam zamanlı alarm');
    // Pil optimizasyonu alarmı geciktirebilir / engelleyebilir
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      list.add('Pil optimizasyonundan muafiyet');
    }
    return list;
  }

  /// İzinleri yalnızca uygulamanın ilk açılışında otomatik ister.
  /// Sonraki açılışlarda kullanıcı ana ekrandaki "İzin ver" düğmesini kullanır.
  static Future<void> requestOnFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_askedKey) ?? false) return;
    await prefs.setBool(_askedKey, true);
    await requestAll();
  }

  static const String _askedKey = 'permissions_asked_v1';

  /// Eksik izinleri sırayla ister; kalıcı reddedilmişse uygulama ayarlarını açar
  static Future<void> requestAll() async {
    if (!Platform.isAndroid) return;

    final notification = await Permission.notification.status;
    if (notification.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    if (!notification.isGranted) await Permission.notification.request();

    if (!await Permission.scheduleExactAlarm.isGranted) {
      await Permission.scheduleExactAlarm.request();
    }

    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }
}
