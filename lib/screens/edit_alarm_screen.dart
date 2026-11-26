// Alarm ekleme / düzenleme ekranı: saat, tekrar/tarih, tatil, etiket, zil sesi, ses ayarları,
// erteleme, uyanma görevi ve "Uyandın mı?" kontrolü.

import 'package:flutter/material.dart';

import '../models/alarm_item.dart';
import '../services/alarm_repository.dart';
import '../services/sound_library.dart';
import '../widgets/wake_task.dart';
import 'sound_picker_screen.dart';

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
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  /// 24 saat biçiminde, doğrudan rakam klavyesiyle açılan saat seçici
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _draft.hour, minute: _draft.minute),
      helpText: 'Alarm saati',
      initialEntryMode: TimePickerEntryMode.input,
      hourLabelText: 'Saat',
      minuteLabelText: 'Dakika',
      errorInvalidText: 'Geçerli bir saat girin',
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

  /// Belirli bir tarih seçtirir (o gün bir kez çalar)
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.date ?? today,
      firstDate: today,
      lastDate: DateTime(now.year + 2, now.month, now.day),
      helpText: 'Alarm tarihi',
    );
    if (picked != null) {
      setState(() {
        _draft.date = picked;
        _draft.days = {};
      });
    }
  }

  void _setPreset(Set<int> days) => setState(() {
        _draft.days = {...days};
        _draft.date = null;
      });

  void _toggleDay(int day) => setState(() {
        _draft.date = null;
        if (_draft.days.contains(day)) {
          _draft.days.remove(day);
        } else {
          _draft.days.add(day);
        }
      });

  Future<void> _pickSound() async {
    final result = await Navigator.of(context).push<SoundOption>(
      MaterialPageRoute(
        builder: (_) => SoundPickerScreen(
          current: SoundOption(_draft.sound, _draft.soundName),
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _draft.sound = result.path;
        _draft.soundName = result.name;
      });
    }
  }

  void _testTask() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => WakeTaskTestScreen(item: _draft.copy())),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    // Seçilen tarih + saat geçmişte kaldıysa kaydetme
    if (_draft.nextOccurrence() == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seçilen tarih ve saat geçmişte kaldı')),
      );
      return;
    }
    setState(() => _saving = true);
    _draft.label = _labelController.text.trim();
    _draft.enabled = true; // Kaydedilen alarm her zaman açık olur
    final when = await _repo.save(_draft);
    if (mounted) Navigator.of(context).pop(when);
  }

  Future<void> _delete() async {
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

  // ---- Küçük arayüz yardımcıları ----

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 4),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      );

  /// Sağında açılır menü olan ayar satırı
  Widget _dropdownTile<T>({
    required IconData icon,
    required String title,
    String? subtitle,
    required T value,
    required Map<T, String> options,
    required ValueChanged<T> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: DropdownButton<T>(
        value: value,
        underline: const SizedBox.shrink(),
        items: [
          for (final e in options.entries) DropdownMenuItem<T>(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) {
          if (v != null) setState(() => onChanged(v));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = _draft.days;
    final next = _draft.nextOccurrence();

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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Büyük saat göstergesi: dokununca rakam klavyesi açılır
          Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _pickTime,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
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
          // Uyku süresi / ne zaman çalacağı bilgisi
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bedtime_outlined, size: 18, color: scheme.outline),
                const SizedBox(width: 6),
                Text(
                  next == null
                      ? 'Seçilen tarih geçmişte kaldı'
                      : 'Alarm ${formatUntil(next)} çalacak',
                  style: TextStyle(color: next == null ? scheme.error : scheme.outline),
                ),
              ],
            ),
          ),

          // ---- Tekrar ----
          _section('Tekrar'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Tek seferlik'),
                selected: days.isEmpty && _draft.date == null,
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
              ChoiceChip(
                avatar: const Icon(Icons.calendar_month, size: 18),
                label: Text(_draft.date == null ? 'Tarih seç' : shortDate(_draft.date!)),
                selected: _draft.date != null,
                onSelected: (_) => _pickDate(),
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
          Text(
            _draft.date != null ? longDate(_draft.date!) : _draft.repeatText,
            style: TextStyle(color: scheme.outline),
          ),
          if (_draft.isRepeating)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.celebration_outlined),
              title: const Text('Resmî tatillerde çalma'),
              subtitle: const Text('Bayramlar ve resmî tatil günlerinde atlanır'),
              value: _draft.skipHolidays,
              onChanged: (v) => setState(() => _draft.skipHolidays = v),
            ),

          // ---- Etiket ----
          const SizedBox(height: 16),
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

          // ---- Ses ----
          _section('Ses'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.music_note_outlined),
            title: const Text('Zil sesi'),
            subtitle: Text(_draft.soundName),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickSound,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.volume_up),
            title: const Text('Maksimum ses'),
            subtitle: const Text('Telefonun sesi kısık olsa bile tam sesle çalar'),
            value: _draft.maxVolume,
            onChanged: (v) => setState(() => _draft.maxVolume = v),
          ),
          _dropdownTile<int>(
            icon: Icons.trending_up,
            title: 'Artan ses',
            subtitle: 'Kısık başlar, yavaşça yükselir',
            value: _draft.fadeSeconds,
            options: const {0: 'Kapalı', 30: '30 sn', 60: '1 dk', 120: '2 dk'},
            onChanged: (v) => _draft.fadeSeconds = v,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.vibration),
            title: const Text('Titreşim'),
            value: _draft.vibrate,
            onChanged: (v) => setState(() => _draft.vibrate = v),
          ),

          // ---- Erteleme ----
          _section('Erteleme'),
          _dropdownTile<int>(
            icon: Icons.snooze,
            title: 'Erteleme süresi',
            value: _draft.snoozeMinutes,
            options: const {5: '5 dakika', 10: '10 dakika', 15: '15 dakika'},
            onChanged: (v) => _draft.snoozeMinutes = v,
          ),
          _dropdownTile<int>(
            icon: Icons.block,
            title: 'Erteleme sınırı',
            subtitle: 'Sınır dolunca Ertele düğmesi kaybolur',
            value: _draft.maxSnoozes,
            options: const {0: 'Sınırsız', 1: '1 kez', 2: '2 kez', 3: '3 kez', 5: '5 kez'},
            onChanged: (v) => _draft.maxSnoozes = v,
          ),

          // ---- Uyanma ----
          _section('Uyanma garantisi'),
          _dropdownTile<String>(
            icon: Icons.psychology_alt_outlined,
            title: 'Kapatmak için görev',
            value: _draft.task,
            options: const {kTaskNone: 'Yok', kTaskMath: 'Matematik', kTaskShake: 'Sallama'},
            onChanged: (v) => _draft.task = v,
          ),
          if (_draft.task == kTaskMath) ...[
            _dropdownTile<int>(
              icon: Icons.calculate_outlined,
              title: 'Zorluk',
              value: _draft.mathLevel,
              options: const {1: 'Kolay', 2: 'Orta', 3: 'Zor'},
              onChanged: (v) => _draft.mathLevel = v,
            ),
            _dropdownTile<int>(
              icon: Icons.format_list_numbered,
              title: 'Soru sayısı',
              value: _draft.mathCount,
              options: const {1: '1 soru', 3: '3 soru', 5: '5 soru'},
              onChanged: (v) => _draft.mathCount = v,
            ),
          ],
          if (_draft.task == kTaskShake)
            _dropdownTile<int>(
              icon: Icons.screen_rotation_alt,
              title: 'Sallama sayısı',
              value: _draft.shakeCount,
              options: const {20: '20 kez', 30: '30 kez', 50: '50 kez', 80: '80 kez'},
              onChanged: (v) => _draft.shakeCount = v,
            ),
          if (_draft.task != kTaskNone)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _testTask,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Görevi şimdi dene'),
              ),
            ),
          _dropdownTile<int>(
            icon: Icons.verified_user_outlined,
            title: 'Uyandın mı? kontrolü',
            subtitle: 'Kapattıktan sonra tekrar sorar; onaylamazsan alarm yeniden çalar',
            value: _draft.wakeCheckMinutes,
            options: const {0: 'Kapalı', 3: '3 dk sonra', 5: '5 dk sonra', 10: '10 dk sonra'},
            onChanged: (v) => _draft.wakeCheckMinutes = v,
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
