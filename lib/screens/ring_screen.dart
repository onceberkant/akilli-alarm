// Alarm çalarken açılan tam ekran sayfa.
// - Normal alarm: büyük saat, etiket, "Ertele" (sınır varsa kalan hak) ve "Kapat".
//   Görev açıksa "Kapat"tan sonra matematik / sallama görevi çıkar.
// - "Uyandın mı?" kontrolü: tek büyük "Uyanığım" düğmesi.

import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

import '../models/alarm_item.dart';
import '../services/alarm_repository.dart';
import '../widgets/wake_task.dart';

class RingScreen extends StatefulWidget {
  const RingScreen({super.key, required this.alarm});

  final AlarmSettings alarm;

  @override
  State<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends State<RingScreen> {
  final AlarmRepository _repo = AlarmRepository.instance;
  Timer? _clock; // Ekrandaki saati her saniye günceller
  StreamSubscription<Object?>? _ringSub;
  bool _seenRinging = false; // Bu alarmın çaldığını akıştan gördük mü?
  bool _busy = false; // Bir düğmeye basıldı, işlem sürüyor
  bool _closed = false;
  bool _showTask = false; // Uyanma görevi ekranda mı?

  bool get _isCheck => widget.alarm.id >= kCheckOffset;
  int get _itemId => _isCheck ? widget.alarm.id - kCheckOffset : widget.alarm.id;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    // Alarm başka bir yoldan susturulursa (ör. bildirimdeki Ertele) ekranı kapat
    _ringSub = Alarm.ringing.listen((alarmSet) {
      final stillRinging = alarmSet.alarms.any((a) => a.id == widget.alarm.id);
      if (stillRinging) {
        _seenRinging = true;
      } else if (_seenRinging && !_busy) {
        _close();
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _ringSub?.cancel();
    super.dispose();
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _snooze() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _repo.snooze(widget.alarm);
    _close();
  }

  /// "Kapat": görev varsa önce görevi göster, yoksa hemen kapat
  void _onDismissPressed(AlarmItem? item) {
    if (item != null && item.task != kTaskNone) {
      setState(() => _showTask = true);
    } else {
      _dismiss();
    }
  }

  Future<void> _dismiss() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _repo.dismiss(widget.alarm.id);
    _close();
  }

  Future<void> _confirmAwake() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _repo.confirmAwake(_itemId);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final item = _repo.findById(_itemId);
    final now = DateTime.now();

    // Geri tuşuyla kapatılamaz; mutlaka bir seçim yapılmalı
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B1B3A), Color(0xFF3B2F7A)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _isCheck
                  ? _buildCheck(now)
                  : (_showTask && item != null)
                      ? _buildTask(item)
                      : _buildRing(item, now),
            ),
          ),
        ),
      ),
    );
  }

  Widget _clockText(DateTime now, {double size = 96}) => Text(
        '${twoDigits(now.hour)}:${twoDigits(now.minute)}',
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w200,
          color: Colors.white,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );

  Widget _bigButton({
    required String text,
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 84,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 32),
        label: Text(text, style: const TextStyle(fontSize: 24)),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
    );
  }

  /// Normal alarm görünümü
  Widget _buildRing(AlarmItem? item, DateTime now) {
    final label = item?.displayLabel ?? widget.alarm.notificationSettings.title;
    final canSnooze = item?.canSnooze ?? true;
    final left = item?.snoozesLeft;
    final snoozeText = 'Ertele (${item?.snoozeMinutes ?? 5} dk)'
        '${left != null ? ' · $left hak' : ''}';
    final hasTask = item != null && item.task != kTaskNone;

    return Column(
      children: [
        const Spacer(),
        const Icon(Icons.alarm, size: 64, color: Colors.white70),
        const SizedBox(height: 16),
        _clockText(now),
        Text(
          '${now.day} ${kMonthNames[now.month - 1]} ${kDayNames[now.weekday - 1]}',
          style: const TextStyle(fontSize: 18, color: Colors.white70),
        ),
        const SizedBox(height: 24),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: Colors.white),
        ),
        const Spacer(flex: 2),
        if (canSnooze)
          _bigButton(
            text: snoozeText,
            icon: Icons.snooze,
            onPressed: _busy ? null : _snooze,
            color: Colors.white.withValues(alpha: 0.18),
          )
        else
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Erteleme hakkın bitti — kalkma vakti!',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
          ),
        const SizedBox(height: 16),
        _bigButton(
          text: hasTask ? 'Kapat (görev)' : 'Kapat',
          icon: Icons.alarm_off,
          onPressed: _busy ? null : () => _onDismissPressed(item),
          color: const Color(0xFFE5484D),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Uyanma görevi görünümü (alarm bu sırada çalmaya devam eder)
  Widget _buildTask(AlarmItem item) {
    return Column(
      children: [
        Row(
          children: [
            // Görevden vazgeçip alarm ekranına (Ertele için) dönmek mümkün
            TextButton.icon(
              onPressed: _busy ? null : () => setState(() => _showTask = false),
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              label: const Text('Geri', style: TextStyle(color: Colors.white70)),
            ),
            const Spacer(),
            _clockText(DateTime.now(), size: 28),
          ],
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: WakeTask(item: item, onDone: _dismiss),
            ),
          ),
        ),
      ],
    );
  }

  /// "Uyandın mı?" kontrol görünümü
  Widget _buildCheck(DateTime now) {
    return Column(
      children: [
        const Spacer(),
        const Icon(Icons.verified_user_outlined, size: 72, color: Colors.white70),
        const SizedBox(height: 16),
        _clockText(now),
        const SizedBox(height: 16),
        const Text(
          'Uyandın mı?',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        const SizedBox(height: 8),
        const Text(
          'Uyanık olduğunu onayla',
          style: TextStyle(fontSize: 18, color: Colors.white70),
        ),
        const Spacer(flex: 2),
        _bigButton(
          text: 'Evet, uyanığım',
          icon: Icons.check_circle_outline,
          onPressed: _busy ? null : _confirmAwake,
          color: const Color(0xFF30A46C),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
