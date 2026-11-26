// Ayarlar: tema, yedekleme / geri yükleme, izinler ve ana ekran widget'ı bilgisi.

import 'package:flutter/material.dart';

import '../services/alarm_repository.dart';
import '../services/backup_service.dart';
import '../services/permission_service.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _export(BuildContext context) async {
    try {
      final ok = await BackupService.export();
      if (context.mounted && ok) _snack(context, 'Yedek kaydedildi');
    } catch (e) {
      if (context.mounted) _snack(context, 'Yedeklenemedi: $e');
    }
  }

  Future<void> _import(BuildContext context) async {
    try {
      final items = await BackupService.pickBackup();
      if (items == null || !context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Yedek geri yüklensin mi?'),
          content: Text(
            'Yedekte ${items.length} alarm var. Şu anki alarmların yerine geçecek.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Geri yükle')),
          ],
        ),
      );
      if (ok != true) return;
      await AlarmRepository.instance.replaceAll(items);
      if (context.mounted) _snack(context, '${items.length} alarm geri yüklendi');
    } catch (e) {
      if (context.mounted) _snack(context, 'Geri yüklenemedi: $e');
    }
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Tema seçimi
          _section(context, 'Görünüm'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: SettingsService.themeMode,
              builder: (context, mode, _) => SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Sistem'),
                    icon: Icon(Icons.brightness_auto),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Açık'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Koyu'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (s) => SettingsService.setTheme(s.first),
              ),
            ),
          ),

          // Yedekleme
          _section(context, 'Yedekleme'),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Alarmları yedekle'),
            subtitle: const Text('Tüm alarmları bir dosyaya kaydeder'),
            onTap: () => _export(context),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Yedekten geri yükle'),
            subtitle: const Text('Telefon değiştirdiğinde ya da yeniden kurduğunda'),
            onTap: () => _import(context),
          ),

          // İzinler
          _section(context, 'Güvenilirlik'),
          ListTile(
            leading: const Icon(Icons.verified_outlined),
            title: const Text('İzinleri kontrol et'),
            subtitle: const Text('Bildirim, tam zamanlı alarm, pil optimizasyonu'),
            onTap: () async {
              await PermissionService.requestAll();
              final missing = await PermissionService.missing();
              if (!context.mounted) return;
              _snack(
                context,
                missing.isEmpty ? 'Tüm izinler tamam' : 'Eksik: ${missing.join(', ')}',
              );
            },
          ),

          // Widget bilgisi
          _section(context, 'Ana ekran widget\'ı'),
          const ListTile(
            leading: Icon(Icons.widgets_outlined),
            title: Text('Sonraki alarmı ana ekranda göster'),
            subtitle: Text(
              'Ana ekranda boş bir yere basılı tut → Widget\'lar → Alarm → "Sonraki alarm"',
            ),
          ),

          const SizedBox(height: 24),
          const Center(child: Text('Akıllı Alarm v1.1', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }
}
