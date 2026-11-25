// Alarm ekleme / düzenleme ekranı: saat, tekrar günleri, etiket, zil sesi, titreşim, erteleme.

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/alarm_item.dart';
import '../services/alarm_repository.dart';

class EditAlarmScreen extends StatefulWidget {
  const EditAlarmScreen({super.key, this.existing});

  /// Düzenlenecek alarm; null ise yeni alarm oluşturulur
  final AlarmItem? existing;

  @override
  State<EditAlarmScreen> createState() => _EditAlarmScreenState();
}

class _EditAlarmScreenState extends State<EditAlarmScreen> {
  final AlarmRepository _repo = AlarmRepository.instance;
  late final AlarmItem _draft; // Üzerinde çalıştığımız kopya
  late final TextEditingController _labelController;
  bool _saving = false;

  // Zil sesi önizlemesi için ses oynatıcı
  final AudioPlayer _preview = AudioPlayer();
  StreamSubscription<void>? _previewDoneSub;
  bool _previewing = false; // Şu an önizleme çalıyor mu?

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _draft = widget.existing!.copy();
    } else {
      // Yeni alarm: varsayılan olarak 1 saat sonrası, tek seferlik
      final t = DateTime.now().add(const Duration(hours: 1));
      _draft = AlarmItem(id: _repo.newId(), hour: t.hour, minute: t.minute);
    }
    _labelController = TextEditingController(text: _draft.label);
    // Önizleme kendiliğinden bitince düğmeyi tekrar "oynat" durumuna getir
    _previewDoneSub = _preview.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _previewing = false);
    });
  }

  @override
  void dispose() {
    _previewDoneSub?.cancel();
    unawaited(_preview.dispose()); // Ekrandan çıkınca ses de durur
    _labelController.dispose();
    super.dispose();
  }

  /// Seçilen zil sesini bir kez çalar.
  /// audioplayers yolun başına "assets/" eklediği için onu çıkarıyoruz.
  Future<void> _playPreview(String sound) async {
    try {
      await _preview.stop();
      await _preview.play(AssetSource(sound.replaceFirst('assets/', '')));
      if (mounted) setState(() => _previewing = true);
    } catch (e) {
      debugPrint('Önizleme çalınamadı: $e');
      if (mounted) setState(() => _previewing = false);
    }
  }

  /// Çalan önizlemeyi durdurur
  Future<void> _stopPreview() async {
    try {
      await _preview.stop();
    } catch (_) {}
    if (mounted) setState(() => _previewing = false);
  }

  /// 24 saat biçiminde saat seçiciyi açar
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _draft.hour, minute: _draft.minute),
      helpText: 'Alarm saati',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _draft.hour = picked.hour;
        _draft.minute = picked.minute;
      });
    }
  }

  void _setPreset(Set<int> days) => setState(() => _draft.days = {...days});

  void _toggleDay(int day) => setState(() {
        if (_draft.days.contains(day)) {
          _draft.days.remove(day);
        } else {
          _draft.days.add(day);
        }
      });

  Future<void> _save() async {
    if (_saving) return;
    await _stopPreview();
    setState(() => _saving = true);
    _draft.label = _labelController.text.trim();
    _draft.enabled = true; // Kaydedilen alarm her zaman açık olur
    final when = await _repo.save(_draft);
    if (mounted) Navigator.of(context).pop(when);
  }

  Future<void> _delete() async {
    await _stopPreview();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alarm silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.delete(_draft.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = _draft.days;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Yeni alarm' : 'Alarmı düzenle'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Büyük saat göstergesi: dokununca saat seçici açılır
          Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _pickTime,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  _draft.timeText,
                  style: TextStyle(
                    fontSize: 80,
                    fontWeight: FontWeight.w300,
                    color: scheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              'Değiştirmek için saate dokunun',
              style: TextStyle(color: scheme.outline),
            ),
          ),
          const SizedBox(height: 24),

          // Tekrar seçenekleri
          Text('Tekrar', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Tek seferlik'),
                selected: days.isEmpty,
                onSelected: (_) => _setPreset(const {}),
              ),
              ChoiceChip(
                label: const Text('Hafta içi'),
                selected: sameDays(days, kWeekdays),
                onSelected: (_) => _setPreset(kWeekdays),
              ),
              ChoiceChip(
                label: const Text('Hafta sonu'),
                selected: sameDays(days, kWeekend),
                onSelected: (_) => _setPreset(kWeekend),
              ),
              ChoiceChip(
                label: const Text('Her gün'),
                selected: days.length == 7,
                onSelected: (_) => _setPreset(kEveryDay),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Özel günler: her güne ayrı ayrı dokunulabilir
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var d = 1; d <= 7; d++)
                _DayButton(
                  text: kDayShort[d - 1],
                  selected: days.contains(d),
                  onTap: () => _toggleDay(d),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_draft.repeatText, style: TextStyle(color: scheme.outline)),
          const SizedBox(height: 24),

          // Etiket
          TextField(
            controller: _labelController,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Etiket',
              hintText: 'ör. İşe kalk',
              prefixIcon: Icon(Icons.label_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),

          // Zil sesi
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.music_note_outlined),
            title: const Text('Zil sesi'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: _draft.sound,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final e in kSounds.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  // Yeni ses seçilince hemen çalarak dinlet
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _draft.sound = v);
                    _playPreview(v);
                  },
                ),
                // Dinle / Durdur düğmesi
                IconButton(
                  tooltip: _previewing ? 'Durdur' : 'Dinle',
                  iconSize: 32,
                  color: Theme.of(context).colorScheme.primary,
                  icon: Icon(_previewing ? Icons.stop_circle : Icons.play_circle),
                  onPressed: () =>
                      _previewing ? _stopPreview() : _playPreview(_draft.sound),
                ),
              ],
            ),
          ),

          // Erteleme süresi
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.snooze),
            title: const Text('Erteleme süresi'),
            trailing: DropdownButton<int>(
              value: _draft.snoozeMinutes,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 5, child: Text('5 dakika')),
                DropdownMenuItem(value: 10, child: Text('10 dakika')),
                DropdownMenuItem(value: 15, child: Text('15 dakika')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _draft.snoozeMinutes = v);
              },
            ),
          ),

          // Maksimum ses
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.volume_up),
            title: const Text('Maksimum ses'),
            subtitle: const Text('Telefonun sesi kısık olsa bile tam sesle çalar'),
            value: _draft.maxVolume,
            onChanged: (v) => setState(() => _draft.maxVolume = v),
          ),

          // Titreşim
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.vibration),
            title: const Text('Titreşim'),
            value: _draft.vibrate,
            onChanged: (v) => setState(() => _draft.vibrate = v),
          ),
          const SizedBox(height: 24),

          // Kaydet
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: const Text('Kaydet', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gün seçimi için yuvarlak düğme
class _DayButton extends StatelessWidget {
  const _DayButton({required this.text, required this.selected, required this.onTap});

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
