// Uyanma görevi: alarmı kapatmak için telefonu belirli sayıda sallama.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ShakeTask extends StatefulWidget {
  const ShakeTask({super.key, required this.target, required this.onDone});

  final int target; // Gereken sallama sayısı
  final VoidCallback onDone; // Hedefe ulaşınca çağrılır

  @override
  State<ShakeTask> createState() => _ShakeTaskState();
}

class _ShakeTaskState extends State<ShakeTask> {
  // Yer çekimi çıkarılmış ivme bu eşiği geçince bir sallama sayılır (m/s²)
  static const double _threshold = 13;
  // İki sallama arasında en az bu kadar süre olmalı (tek hareket iki kez sayılmasın)
  static const int _minGapMs = 220;

  StreamSubscription<UserAccelerometerEvent>? _sub;
  int _count = 0;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  bool _sensorError = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _sub = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 20),
    ).listen(
      _onEvent,
      onError: (Object _) {
        if (mounted) setState(() => _sensorError = true);
      },
      cancelOnError: true,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(UserAccelerometerEvent e) {
    if (_done) return;
    final force = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    final now = DateTime.now();
    if (force < _threshold || now.difference(_last).inMilliseconds < _minGapMs) return;
    _last = now;
    setState(() => _count++);
    if (_count >= widget.target) _finish();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _sub?.cancel();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    if (_sensorError) {
      // Sensör yoksa kullanıcı alarmın içinde kilitli kalmasın
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sensors_off, color: Colors.white70, size: 56),
          const SizedBox(height: 12),
          const Text(
            'Hareket sensörü bulunamadı',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _finish, child: const Text('Alarmı kapat')),
        ],
      );
    }
    final progress = (_count / widget.target).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Telefonu salla!',
          style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 14,
                color: const Color(0xFF30A46C),
                backgroundColor: Colors.white12,
              ),
              Center(
                child: Text(
                  '$_count / ${widget.target}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Güçlüce salla, her hareket sayılır',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ],
    );
  }
}
