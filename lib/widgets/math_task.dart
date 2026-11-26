// Uyanma görevi: alarmı kapatmak için matematik sorusu çözme.
// Sistem klavyesi yerine kendi büyük tuş takımımızı kullanıyoruz (kilit ekranında da rahat).

import 'dart:math';

import 'package:flutter/material.dart';

class MathTask extends StatefulWidget {
  const MathTask({
    super.key,
    required this.level,
    required this.count,
    required this.onSolved,
  });

  final int level; // 1 kolay, 2 orta, 3 zor
  final int count; // Çözülecek soru sayısı
  final VoidCallback onSolved; // Tüm sorular doğru çözülünce çağrılır

  @override
  State<MathTask> createState() => _MathTaskState();
}

class _MathTaskState extends State<MathTask> {
  final Random _rnd = Random();
  String _question = '';
  int _answer = 0;
  String _input = '';
  int _solved = 0;
  bool _wrong = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _newQuestion();
  }

  int _between(int min, int max) => min + _rnd.nextInt(max - min + 1);

  /// Zorluğa göre yeni soru üretir
  void _newQuestion() {
    switch (widget.level) {
      case 1:
        {
          // Kolay: iki sayıyı topla
          final a = _between(10, 49), b = _between(10, 49);
          _question = '$a + $b';
          _answer = a + b;
        }
      case 3:
        {
          // Zor: iki basamaklı çarpma + toplama
          final a = _between(13, 29), b = _between(7, 19), c = _between(11, 99);
          _question = '$a × $b + $c';
          _answer = a * b + c;
        }
      default:
        {
          // Orta: çarpım tablosu + toplama
          final a = _between(3, 9), b = _between(6, 12), c = _between(10, 49);
          _question = '$a × $b + $c';
          _answer = a * b + c;
        }
    }
  }

  void _press(String key) {
    if (_finished) return;
    if (key == 'OK') {
      _check();
      return;
    }
    setState(() {
      _wrong = false;
      if (key == 'DEL') {
        if (_input.isNotEmpty) _input = _input.substring(0, _input.length - 1);
      } else if (_input.length < 6) {
        _input += key;
      }
    });
  }

  void _check() {
    if (int.tryParse(_input) == _answer) {
      _solved++;
      if (_solved >= widget.count) {
        _finished = true;
        widget.onSolved();
        return;
      }
      setState(() {
        _input = '';
        _newQuestion();
      });
    } else {
      setState(() {
        _wrong = true;
        _input = '';
      });
    }
  }

  Widget _key(String key) {
    final Widget child;
    if (key == 'DEL') {
      child = const Icon(Icons.backspace_outlined, size: 28);
    } else if (key == 'OK') {
      child = const Icon(Icons.check, size: 32);
    } else {
      child = Text(key, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500));
    }
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: SizedBox(
          height: 64,
          child: FilledButton(
            onPressed: () => _press(key),
            style: FilledButton.styleFrom(
              backgroundColor: key == 'OK'
                  ? const Color(0xFF30A46C)
                  : Colors.white.withValues(alpha: 0.12),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['DEL', '0', 'OK'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Soru ${_solved + 1} / ${widget.count}',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          '$_question = ?',
          style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        // Girilen cevap
        Container(
          width: double.infinity,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _wrong ? const Color(0xFFE5484D) : Colors.white24,
              width: 2,
            ),
          ),
          child: Text(
            _wrong ? 'Yanlış, tekrar dene' : (_input.isEmpty ? ' ' : _input),
            style: TextStyle(
              color: _wrong ? const Color(0xFFFF8A8E) : Colors.white,
              fontSize: _wrong ? 20 : 34,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final row in rows) Row(children: [for (final k in row) _key(k)]),
      ],
    );
  }
}
