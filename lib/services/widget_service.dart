// Ana ekran widget'ına "sonraki alarm" bilgisini gönderir.
// Widget'ın görünümü Android tarafında (NextAlarmWidgetProvider.kt) çizilir.

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/alarm_item.dart';

class WidgetService {
  static const String _provider = 'com.alarmapp.akilli_alarm.NextAlarmWidgetProvider';

  static Future<void> update(AlarmItem? next) async {
    try {
      final at = next?.nextAt;
      final time = at == null ? '--:--' : '${twoDigits(at.hour)}:${twoDigits(at.minute)}';
      // "Bugün/Yarın" yerine gün adı yazıyoruz ki gece yarısı geçince bilgi eskimesin
      final info = (at == null || next == null)
          ? 'Açık alarm yok'
          : '${shortDate(at)} · ${next.displayLabel}';
      await HomeWidget.saveWidgetData<String>('next_time', time);
      await HomeWidget.saveWidgetData<String>('next_info', info);
      await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    } catch (e) {
      debugPrint('Widget güncellenemedi: $e');
    }
  }
}
