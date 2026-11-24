// Alarm çalarken açılan tam ekran sayfa: büyük saat, etiket, "Ertele" ve "Kapat" düğmeleri.

import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

import '../models/alarm_item.dart';
import '../services/alarm_repository.dart';

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

  Future<void> _dismiss() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _repo.dismiss(widget.alarm.id);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final item = _repo.findById(widget.alarm.id);
    final label = (item?.label.trim().isNotEmpty ?? false)
        ? item!.label.trim()
        : widget.alarm.notificationSettings.title;
    final snoozeMinutes = item?.snoozeMinutes ?? 5;
    final now = DateTime.now();
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    const weekdays = [
      'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
    ];

    // Geri tuşuyla kapatılamaz; mutlaka Ertele veya Kapat seçilmeli
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
              child: Column(
                children: [
                  const Spacer(),
                  const Icon(Icons.alarm, size: 64, color: Colors.white70),
                  const SizedBox(height: 16),
                  Text(
                    '${twoDigits(now.hour)}:${twoDigits(now.minute)}',
                    style: const TextStyle(
                      fontSize: 96,
                      fontWeight: FontWeight.w200,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    '${now.day} ${months[now.month - 1]} ${weekdays[now.weekday - 1]}',
                    style: const TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(flex: 2),
                  // Büyük "Ertele" düğmesi
                  SizedBox(
                    width: double.infinity,
                    height: 84,
                    child: FilledButton.tonalIcon(
                      onPressed: _busy ? null : _snooze,
                      icon: const Icon(Icons.snooze, size: 32),
                      label: Text('Ertele ($snoozeMinutes dk)',
                          style: const TextStyle(fontSize: 24)),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Büyük "Kapat" düğmesi
                  SizedBox(
                    width: double.infinity,
                    height: 84,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _dismiss,
                      icon: const Icon(Icons.alarm_off, size: 32),
                      label: const Text('Kapat', style: TextStyle(fontSize: 24)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE5484D),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
