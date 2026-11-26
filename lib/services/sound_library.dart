// Zil sesi kaynakları: uygulama sesleri, telefonun kendi alarm/zil sesleri ve
// kullanıcının telefondan seçtiği müzik dosyaları.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/alarm_item.dart';

/// Seçilebilir tek bir ses
class SoundOption {
  const SoundOption(this.path, this.name);
  final String path; // "assets/..." ya da dosyanın tam yolu
  final String name; // Ekranda görünen ad
}

class SoundLibrary {
  // Android'in hazır seslerinin bulunduğu klasörler (markaya göre değişir)
  static const List<String> _alarmDirs = [
    '/system/media/audio/alarms',
    '/product/media/audio/alarms',
    '/system/product/media/audio/alarms',
  ];
  static const List<String> _ringtoneDirs = [
    '/system/media/audio/ringtones',
    '/product/media/audio/ringtones',
    '/system/product/media/audio/ringtones',
  ];
  static const Set<String> _audioExt = {'ogg', 'mp3', 'wav', 'm4a', 'aac', 'flac'};

  /// Uygulamayla gelen sesler
  static List<SoundOption> appSounds() =>
      [for (final e in kSounds.entries) SoundOption(e.key, e.value)];

  /// Telefonun hazır alarm sesleri
  static Future<List<SoundOption>> phoneAlarms() => _scan(_alarmDirs);

  /// Telefonun hazır zil sesleri
  static Future<List<SoundOption>> phoneRingtones() => _scan(_ringtoneDirs);

  /// Klasörleri tarar; okunamayan klasörleri sessizce atlar
  static Future<List<SoundOption>> _scan(List<String> dirs) async {
    final byName = <String, SoundOption>{};
    for (final path in dirs) {
      try {
        final dir = Directory(path);
        if (!await dir.exists()) continue;
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is! File) continue;
          final fileName = entity.path.split('/').last;
          final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
          if (!_audioExt.contains(ext)) continue;
          final name = prettyName(fileName);
          byName.putIfAbsent(name, () => SoundOption(entity.path, name));
        }
      } catch (e) {
        debugPrint('Ses klasörü okunamadı ($path): $e');
      }
    }
    final list = byName.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Telefondan bir müzik/ses dosyası seçtirir ve uygulamanın kendi klasörüne kopyalar.
  /// Kopyalıyoruz ki dosya taşınsa ya da silinse bile alarm çalmaya devam etsin.
  static Future<SoundOption?> importFromDevice() async {
    final files = await FilePicker.pickFiles(type: FileType.audio);
    if (files.isEmpty) return null;
    final picked = files.first;

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/sounds');
    await dir.create(recursive: true);
    final safe = picked.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final dest = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$safe');

    final source = picked.path;
    if (source != null && await File(source).exists()) {
      await File(source).copy(dest.path);
    } else {
      await dest.writeAsBytes(await picked.readAsBytes());
    }
    return SoundOption(dest.path, prettyName(picked.name));
  }

  /// Alarm çalarken kullanılacak ses yolunu döndürür.
  /// Dosya artık yoksa alarm sessiz kalmasın diye varsayılan sese döner.
  static String resolve(String path) {
    if (path.startsWith('assets/')) return path;
    try {
      if (File(path).existsSync()) return path;
    } catch (_) {}
    return kDefaultSound;
  }

  /// "Cesium_Alarm.ogg" -> "Cesium Alarm"
  static String prettyName(String fileName) {
    var name = fileName;
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    name = name.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    if (name.isEmpty) return 'Ses';
    return name[0].toUpperCase() + name.substring(1);
  }
}
