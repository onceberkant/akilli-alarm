// Alarmları JSON dosyası olarak dışa aktarma ve yedekten geri yükleme.

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/alarm_item.dart';
import 'alarm_repository.dart';

class BackupService {
  /// Tüm alarmları bir dosyaya kaydeder. Başarılıysa true döner.
  static Future<bool> export() async {
    final now = DateTime.now();
    final data = {
      'app': 'akilli_alarm',
      'version': 1,
      'createdAt': now.toIso8601String(),
      'alarms': AlarmRepository.instance.items.map((e) => e.toJson()).toList(),
    };
    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
    );
    final name = 'alarm_yedek_${now.year}${twoDigits(now.month)}${twoDigits(now.day)}.json';
    final uri = await FilePicker.saveFile(
      fileName: name,
      bytes: bytes,
      mimeType: 'application/json',
      dialogTitle: 'Yedeği kaydet',
    );
    return uri != null;
  }

  /// Kullanıcının seçtiği yedek dosyasını okur. İptal edilirse null döner.
  /// Dosya geçersizse FormatException fırlatır.
  static Future<List<AlarmItem>?> pickBackup() async {
    final files = await FilePicker.pickFiles(dialogTitle: 'Yedek dosyasını seçin');
    if (files.isEmpty) return null;
    final text = utf8.decode(await files.first.readAsBytes());
    final decoded = jsonDecode(text);
    if (decoded is! Map || decoded['app'] != 'akilli_alarm' || decoded['alarms'] is! List) {
      throw const FormatException('Bu dosya bir alarm yedeği değil');
    }
    return [
      for (final e in decoded['alarms'] as List)
        AlarmItem.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  }
}
