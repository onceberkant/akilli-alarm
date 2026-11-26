// Alarmın ayarındaki uyanma görevini (matematik / sallama) gösteren ortak bileşen
// ve görevi önceden denemek için test ekranı.

import 'package:flutter/material.dart';

import '../models/alarm_item.dart';
import 'math_task.dart';
import 'shake_task.dart';

/// Alarm ayarına göre doğru görevi gösterir
class WakeTask extends StatelessWidget {
  const WakeTask({super.key, required this.item, required this.onDone});

  final AlarmItem item;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    if (item.task == kTaskShake) {
      return ShakeTask(target: item.shakeCount, onDone: onDone);
    }
    return MathTask(level: item.mathLevel, count: item.mathCount, onSolved: onDone);
  }
}

/// Alarm çalmadan görevi denemek için koyu arka planlı ekran
class WakeTaskTestScreen extends StatelessWidget {
  const WakeTaskTestScreen({super.key, required this.item});

  final AlarmItem item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B3A),
      appBar: AppBar(
        title: const Text('Görevi dene'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: WakeTask(
              item: item,
              onDone: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Görev tamamlandı! Alarm böyle kapanacak.')),
                );
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
      ),
    );
  }
}
