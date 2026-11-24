// Alarmların saklanması, kurulması, ertelenmesi ve senkronizasyonundan sorumlu servis.
// Tek bir örnek (singleton) olarak tüm ekranlardan kullanılır.

import 'dart:async';
import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alarm_item.dart';

class AlarmRepository extends ChangeNotifier {
  AlarmRepository._();
  static final AlarmRepository instance = AlarmRepository._();

  static const String _storageKey = 'alarms_v1';

  final List<AlarmItem> _items = <AlarmItem>[];

  // Şu anda çalan alarmların kimlikleri
  Set<int> _ringingIds = <int>{};
  StreamSubscription<Object?>? _ringingSub;

  // İşlemleri sırayla çalıştırmak için kuyruk (yarış durumlarını önler)
  Future<void> _queue = Future<void>.value();

  /// Saate göre sıralanmış alarm listesi
  List<AlarmItem> get items {
    final list = List<AlarmItem>.of(_items);
    list.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    return list;
  }

  /// En yakın zamanda çalacak açık alarm
  AlarmItem? get nextAlarm {
    AlarmItem? best;
    for (final item in _items) {
      if (!item.enabled || item.nextAt == null) continue;
      if (best == null || item.nextAt!.isBefore(best.nextAt!)) best = item;
    }
    return best;
  }

  AlarmItem? findById(int id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Yeni alarm için benzersiz kimlik üretir
  int newId() {
    var maxId = 0;
    for (final item in _items) {
      if (item.id > maxId) maxId = item.id;
    }
    return maxId + 1;
  }

  /// Verilen işi kuyruğa ekler; bir önceki bitmeden başlamaz
  Future<T> _run<T>(Future<T> Function() task) {
    final result = _queue.then<T>((_) => task());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Uygulama açılışında çağrılır: kayıtlı alarmları yükler ve çalma akışını dinler
  Future<void> init() async {
    await _load();
    _ringingSub ??= Alarm.ringing.listen((alarmSet) {
      final ids = alarmSet.alarms.map((a) => a.id).toSet();
      final stopped = _ringingIds.difference(ids);
      _ringingIds = ids;
      // Bir alarm susturulduysa (nasıl olursa olsun) tekrarlı alarmı bir sonraki güne kur
      if (stopped.isNotEmpty) unawaited(reconcile());
    });
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    _items.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          _items.add(AlarmItem.fromJson(Map<String, dynamic>.from(e as Map)));
        }
      } catch (e) {
        debugPrint('Alarm verisi okunamadı: $e');
      }
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  /// Alarm paketine verilecek ayarları oluşturur
  AlarmSettings _buildSettings(AlarmItem item, DateTime when) {
    final title = item.label.trim().isEmpty ? 'Alarm' : item.label.trim();
    return AlarmSettings(
      id: item.id,
      dateTime: when,
      assetAudioPath: item.sound,
      loopAudio: true, // Kapatılana kadar ses tekrar etsin
      vibrate: item.vibrate,
      // Android'de alarm yerel (native) servisle çalıştığı için bu uyarıya gerek yok
      warningNotificationOnKill: false,
      // Kilit ekranında tam ekran açılsın
      androidFullScreenIntent: true,
      // Sistem uygulamayı öldürse bile alarm susmasın
      androidStopAlarmOnTermination: false,
      // Bildirimdeki "Ertele" düğmesinin süresi
      androidSnoozeDuration: Duration(minutes: item.snoozeMinutes),
      // Maksimum ses açıksa: alarm sesi %100'e çekilir ve çalarken kısılamaz.
      // Kapalıysa telefonun kendi alarm ses seviyesi kullanılır.
      volumeSettings: item.maxVolume
          ? const VolumeSettings.fixed(volume: 1.0, volumeEnforced: true)
          : const VolumeSettings.fixed(),
      notificationSettings: NotificationSettings(
        title: title,
        body: 'Saat ${item.timeText} alarmı çalıyor. Kapatmak için dokunun.',
        // Bilinçli olarak "Kapat" düğmesi koymuyoruz: kapatma uygulama içinden
        // yapılınca tekrarlı alarm bir sonraki güne kesin olarak kurulur.
        androidSnoozeButton: 'Ertele',
        // Bildirim yana kaydırılınca alarm susmasın
        androidStopAlarmOnDismiss: false,
      ),
    );
  }

  /// Alarmı paketin zamanlayıcısına kurar ve sonraki çalma zamanını kaydeder
  Future<void> _schedule(AlarmItem item, {DateTime? at}) async {
    final when = at ?? item.nextOccurrence();
    await Alarm.set(alarmSettings: _buildSettings(item, when));
    item.nextAt = when;
  }

  /// Yeni alarmı ekler veya mevcut alarmı günceller. Kurulan zamanı döndürür.
  Future<DateTime?> save(AlarmItem item) => _run<DateTime?>(() async {
        final index = _items.indexWhere((e) => e.id == item.id);
        if (index >= 0) {
          _items[index] = item;
        } else {
          _items.add(item);
        }
        if (item.enabled) {
          await _schedule(item);
        } else {
          await Alarm.stop(item.id);
          item.nextAt = null;
        }
        await _persist();
        return item.nextAt;
      });

  /// Listedeki anahtar ile alarmı açar/kapatır
  Future<DateTime?> setEnabled(AlarmItem item, bool value) {
    final updated = item.copy()..enabled = value;
    return save(updated);
  }

  /// Alarmı tamamen siler
  Future<void> delete(int id) {
    // Listeden hemen çıkar (kaydırarak silme animasyonu hata vermesin)
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
    return _run<void>(() async {
      await Alarm.stop(id);
      await _persist();
    });
  }

  /// Çalan alarmı erteler: susturur ve X dakika sonrasına yeniden kurar
  Future<void> snooze(AlarmSettings ringing) => _run<void>(() async {
        final item = findById(ringing.id);
        final minutes = item?.snoozeMinutes ?? 5;
        final when = DateTime.now().add(Duration(minutes: minutes));
        await Alarm.stop(ringing.id);
        if (item != null) {
          await _schedule(item, at: when);
        } else {
          await Alarm.set(alarmSettings: ringing.copyWith(dateTime: when));
        }
        await _persist();
      });

  /// Çalan alarmı kapatır: tekrarlıysa bir sonraki güne kurar, değilse pasif yapar
  Future<void> dismiss(int id) => _run<void>(() async {
        await Alarm.stop(id);
        final item = findById(id);
        if (item == null) return;
        if (item.enabled && item.isRepeating) {
          await _schedule(item);
        } else {
          item.enabled = false;
          item.nextAt = null;
        }
        await _persist();
      });

  /// Kayıtlı alarmlarımızı alarm paketindeki gerçek durumla eşitler.
  /// Uygulama açılırken, öne gelirken ve bir alarm susunca çağrılır.
  /// Zamanı gelmiş (çalmakta olan) bir alarm varsa onu döndürür.
  Future<AlarmSettings?> reconcile() => _run<AlarmSettings?>(() async {
        final now = DateTime.now();
        final scheduled = <int, AlarmSettings>{
          for (final a in await Alarm.getAlarms()) a.id: a,
        };
        AlarmSettings? due;

        // Listemizde olmayan veya kapalı olan artık alarmları temizle
        for (final id in scheduled.keys.toList()) {
          final item = findById(id);
          if (item == null || !item.enabled) {
            await Alarm.stop(id);
            scheduled.remove(id);
          }
        }

        for (final item in _items) {
          if (!item.enabled) {
            item.nextAt = null;
            continue;
          }
          final s = scheduled[item.id];
          if (s != null) {
            // Paket bu alarmı hâlâ tutuyor (bekliyor, ertelenmiş ya da çalıyor)
            item.nextAt = s.dateTime;
            if (!s.dateTime.isAfter(now)) due ??= s;
            continue;
          }
          if (_ringingIds.contains(item.id)) continue; // Çalıyor, dokunma

          if (item.nextAt != null && item.nextAt!.isAfter(now)) {
            // Kayıp kurulumu geri yükle (ör. uygulama güncellendikten sonra)
            await _schedule(item, at: item.nextAt);
          } else if (item.isRepeating) {
            // Tekrarlı alarm çaldı ve susturuldu: bir sonraki güne kur
            await _schedule(item);
          } else {
            // Tek seferlik alarm çaldı ve bitti: kapat
            item.enabled = false;
            item.nextAt = null;
          }
        }
        await _persist();
        return due;
      });
}
