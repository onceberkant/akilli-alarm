// Alarmların saklanması, kurulması, ertelenmesi, "Uyandın mı?" kontrolü, şekerleme,
// atlama ve senkronizasyonundan sorumlu servis. Tek örnek (singleton) olarak kullanılır.

import 'dart:async';
import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alarm_item.dart';
import 'sound_library.dart';
import 'widget_service.dart';

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

  /// Bekleyen "Uyandın mı?" kontrolleri
  List<AlarmItem> get pendingChecks => _items.where((e) => e.checkAt != null).toList();

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
      // Bir alarm susturulduysa (nasıl olursa olsun) durumu eşitle
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
    unawaited(WidgetService.update(nextAlarm));
  }

  /// Alarm paketine verilecek ayarları oluşturur.
  /// [check] true ise "Uyandın mı?" kontrol alarmı üretir.
  AlarmSettings _buildSettings(AlarmItem item, DateTime when, {bool check = false}) {
    // Erteleme sınırı varsa bildirimde Ertele düğmesi olmaz (sayılabilmesi için
    // erteleme yalnızca uygulama ekranından yapılır)
    final notificationSnooze = !check && item.maxSnoozes == 0;
    final useFade = !check && item.fadeSeconds > 0;

    final VolumeSettings volume;
    if (useFade) {
      // Artan ses: kısık başlar, verilen sürede hedef sese çıkar
      volume = VolumeSettings.fade(
        fadeDuration: Duration(seconds: item.fadeSeconds),
        volume: item.maxVolume ? 1.0 : null,
        volumeEnforced: item.maxVolume,
      );
    } else if (item.maxVolume) {
      // Maksimum ses: %100'e çekilir ve çalarken kısılamaz
      volume = const VolumeSettings.fixed(volume: 1.0, volumeEnforced: true);
    } else {
      volume = const VolumeSettings.fixed();
    }

    return AlarmSettings(
      id: check ? kCheckOffset + item.id : item.id,
      dateTime: when,
      assetAudioPath: SoundLibrary.resolve(item.sound),
      loopAudio: true, // Kapatılana kadar ses tekrar etsin
      vibrate: item.vibrate,
      // Android'de alarm yerel (native) servisle çalıştığı için bu uyarıya gerek yok
      warningNotificationOnKill: false,
      // Kilit ekranında tam ekran açılsın
      androidFullScreenIntent: true,
      // Sistem uygulamayı öldürse bile alarm susmasın
      androidStopAlarmOnTermination: false,
      androidSnoozeDuration: notificationSnooze ? Duration(minutes: item.snoozeMinutes) : null,
      volumeSettings: volume,
      notificationSettings: NotificationSettings(
        title: check ? 'Uyandın mı?' : item.displayLabel,
        body: check
            ? 'Uyanık olduğunu onaylamak için dokun.'
            : 'Saat ${item.timeText} alarmı çalıyor. Kapatmak için dokunun.',
        // Bilinçli olarak "Kapat" düğmesi yok: kapatma uygulama içinden yapılır
        androidSnoozeButton: notificationSnooze ? 'Ertele' : null,
        // Bildirim yana kaydırılınca alarm susmasın
        androidStopAlarmOnDismiss: false,
      ),
    );
  }

  /// Alarmı paketin zamanlayıcısına kurar. Çalacak zaman yoksa (geçmiş tarih) alarmı kapatır.
  Future<void> _schedule(AlarmItem item, {DateTime? at}) async {
    final when = at ?? item.nextOccurrence();
    if (when == null) {
      await Alarm.stop(item.id);
      item.enabled = false;
      item.nextAt = null;
      return;
    }
    await Alarm.set(alarmSettings: _buildSettings(item, when));
    item.nextAt = when;
  }

  /// Atlanan gün geçtiyse "atla" işaretini temizler
  void _clearOldSkip(AlarmItem item, DateTime now) {
    final skip = item.skipDate;
    if (skip == null) return;
    final endOfSkip = DateTime(skip.year, skip.month, skip.day + 1);
    if (!endOfSkip.isAfter(now)) item.skipDate = null;
  }

  /// Yeni alarmı ekler veya mevcut alarmı günceller. Kurulan zamanı döndürür.
  Future<DateTime?> save(AlarmItem item) => _run<DateTime?>(() async {
        final index = _items.indexWhere((e) => e.id == item.id);
        if (index >= 0) {
          _items[index] = item;
        } else {
          _items.add(item);
        }
        item.snoozeCount = 0;
        _clearOldSkip(item, DateTime.now());
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
      await Alarm.stop(kCheckOffset + id);
      await _persist();
    });
  }

  /// Tekrarlı alarmın bir sonraki çalışını atlar
  Future<DateTime?> skipNext(AlarmItem item) => _run<DateTime?>(() async {
        final target = findById(item.id);
        if (target == null || !target.isRepeating || !target.enabled) return null;
        final upcoming = target.nextAt ?? target.nextOccurrence();
        if (upcoming == null) return null;
        target.skipDate = DateTime(upcoming.year, upcoming.month, upcoming.day);
        await _schedule(target);
        await _persist();
        return target.nextAt;
      });

  /// Atlamayı geri alır
  Future<DateTime?> unskip(AlarmItem item) => _run<DateTime?>(() async {
        final target = findById(item.id);
        if (target == null) return null;
        target.skipDate = null;
        if (target.enabled) await _schedule(target);
        await _persist();
        return target.nextAt;
      });

  /// Hızlı şekerleme: [minutes] dakika sonra çalacak tek seferlik alarm kurar
  Future<DateTime> quickNap(int minutes) => _run<DateTime>(() async {
        final when = DateTime.now().add(Duration(minutes: minutes));
        final item = AlarmItem(
          id: newId(),
          hour: when.hour,
          minute: when.minute,
          label: 'Şekerleme ($minutes dk)',
          isNap: true,
        );
        _items.add(item);
        await _schedule(item, at: when);
        await _persist();
        return when;
      });

  /// Çalan alarmı erteler: susturur ve X dakika sonrasına yeniden kurar
  Future<void> snooze(AlarmSettings ringing) => _run<void>(() async {
        final item = findById(ringing.id);
        final minutes = item?.snoozeMinutes ?? 5;
        final when = DateTime.now().add(Duration(minutes: minutes));
        await Alarm.stop(ringing.id);
        if (item != null) {
          item.snoozeCount++;
          await _schedule(item, at: when);
        } else {
          await Alarm.set(alarmSettings: ringing.copyWith(dateTime: when));
        }
        await _persist();
      });

  /// Çalan alarmı kapatır: tekrarlıysa bir sonraki güne kurar, değilse pasif yapar.
  /// "Uyandın mı?" açıksa kontrol alarmını da kurar.
  Future<void> dismiss(int id) => _run<void>(() async {
        await Alarm.stop(id);
        final item = findById(id);
        if (item == null) return;
        final now = DateTime.now();
        item.snoozeCount = 0;
        _clearOldSkip(item, now);

        if (item.isNap) {
          _items.remove(item); // Şekerleme bir kez çalar ve silinir
        } else if (item.enabled && item.isRepeating) {
          await _schedule(item);
        } else {
          item.enabled = false;
          item.nextAt = null;
        }

        if (!item.isNap && item.wakeCheckMinutes > 0) {
          final checkTime = now.add(Duration(minutes: item.wakeCheckMinutes));
          await Alarm.set(alarmSettings: _buildSettings(item, checkTime, check: true));
          item.checkAt = checkTime;
        }
        await _persist();
      });

  /// "Uyanığım" onayı: bekleyen ya da çalan kontrol alarmını iptal eder
  Future<void> confirmAwake(int itemId) => _run<void>(() async {
        await Alarm.stop(kCheckOffset + itemId);
        findById(itemId)?.checkAt = null;
        await _persist();
      });

  /// Yedekten gelen alarmlarla mevcut listeyi değiştirir
  Future<void> replaceAll(List<AlarmItem> incoming) => _run<void>(() async {
        await Alarm.stopAll();
        _items
          ..clear()
          ..addAll(incoming.where((e) => !e.isNap && e.id > 0 && e.id < kCheckOffset));
        final now = DateTime.now();
        for (final item in _items) {
          item.snoozeCount = 0;
          item.checkAt = null;
          item.nextAt = null;
          _clearOldSkip(item, now);
          if (item.enabled) await _schedule(item);
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

        // 1) Artık karşılığı olmayan alarmları temizle
        for (final id in scheduled.keys.toList()) {
          final bool keep;
          if (id >= kCheckOffset) {
            keep = findById(id - kCheckOffset)?.checkAt != null;
          } else {
            keep = findById(id)?.enabled ?? false;
          }
          if (!keep) {
            await Alarm.stop(id);
            scheduled.remove(id);
          }
        }

        // 2) "Uyandın mı?" kontrolleri
        for (final item in _items) {
          final checkAt = item.checkAt;
          if (checkAt == null) continue;
          final checkId = kCheckOffset + item.id;
          final s = scheduled[checkId];
          if (s != null) {
            if (!s.dateTime.isAfter(now)) due ??= s;
            continue;
          }
          if (_ringingIds.contains(checkId)) continue;
          if (checkAt.isAfter(now)) {
            // Kurulum kaybolmuş: geri yükle
            await Alarm.set(alarmSettings: _buildSettings(item, checkAt, check: true));
          } else {
            item.checkAt = null; // Kontrol çaldı ve onaylandı
          }
        }

        // 3) Normal alarmlar
        final finishedNaps = <AlarmItem>[];
        for (final item in _items) {
          _clearOldSkip(item, now);
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
            await _schedule(item, at: item.nextAt); // Kayıp kurulumu geri yükle
          } else if (item.isRepeating) {
            item.snoozeCount = 0;
            await _schedule(item); // Çaldı ve susturuldu: sonraki güne kur
          } else if (item.isNap) {
            finishedNaps.add(item);
          } else {
            item.enabled = false; // Tek seferlik alarm bitti
            item.nextAt = null;
            item.snoozeCount = 0;
          }
        }
        _items.removeWhere(finishedNaps.contains);
        await _persist();
        return due;
      });
}
