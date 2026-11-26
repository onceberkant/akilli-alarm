// Zil sesi seçme ekranı: uygulama sesleri, telefonun alarm/zil sesleri ve
// telefondan müzik dosyası. Bir sese dokununca seçilir ve hemen çalınarak dinletilir.

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../services/sound_library.dart';

class SoundPickerScreen extends StatefulWidget {
  const SoundPickerScreen({super.key, required this.current});

  final SoundOption current; // Şu an seçili ses

  @override
  State<SoundPickerScreen> createState() => _SoundPickerScreenState();
}

class _SoundPickerScreenState extends State<SoundPickerScreen> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _doneSub;

  late SoundOption _selected;
  String? _playingPath; // Şu an önizlemesi çalan ses
  List<SoundOption> _phoneAlarms = const [];
  List<SoundOption> _phoneRingtones = const [];
  SoundOption? _custom; // Telefondan seçilen dosya
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
    // Mevcut ses bir dosyaysa "Müziklerim" bölümünde göster
    if (!widget.current.path.startsWith('assets/') &&
        !widget.current.path.startsWith('/system') &&
        !widget.current.path.startsWith('/product')) {
      _custom = widget.current;
    }
    _doneSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingPath = null);
    });
    _loadPhoneSounds();
  }

  Future<void> _loadPhoneSounds() async {
    final alarms = await SoundLibrary.phoneAlarms();
    final ringtones = await SoundLibrary.phoneRingtones();
    if (!mounted) return;
    setState(() {
      _phoneAlarms = alarms;
      _phoneRingtones = ringtones;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _doneSub?.cancel();
    unawaited(_player.dispose()); // Ekrandan çıkınca ses durur
    super.dispose();
  }

  /// Sesi bir kez çalar (assets veya telefondaki dosya)
  Future<void> _play(SoundOption s) async {
    try {
      await _player.stop();
      final Source source = s.path.startsWith('assets/')
          ? AssetSource(s.path.replaceFirst('assets/', '')) // audioplayers "assets/" ekler
          : DeviceFileSource(s.path);
      await _player.play(source);
      if (mounted) setState(() => _playingPath = s.path);
    } catch (e) {
      debugPrint('Önizleme çalınamadı: $e');
      if (mounted) setState(() => _playingPath = null);
    }
  }

  Future<void> _stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    if (mounted) setState(() => _playingPath = null);
  }

  void _select(SoundOption s) {
    setState(() => _selected = s);
    _play(s);
  }

  /// Telefondan müzik dosyası seçtirir
  Future<void> _pickFile() async {
    await _stop();
    try {
      final picked = await SoundLibrary.importFromDevice();
      if (picked == null || !mounted) return;
      setState(() => _custom = picked);
      _select(picked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya eklenemedi: $e')),
      );
    }
  }

  Future<void> _confirm() async {
    await _stop();
    if (mounted) Navigator.of(context).pop(_selected);
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      );

  Widget _tile(SoundOption s) {
    final selected = s.path == _selected.path;
    final playing = s.path == _playingPath;
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(s.name),
      trailing: IconButton(
        tooltip: playing ? 'Durdur' : 'Dinle',
        icon: Icon(playing ? Icons.stop_circle : Icons.play_circle_outline),
        onPressed: () => playing ? _stop() : _play(s),
      ),
      onTap: () => _select(s),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zil sesi'),
        actions: [
          TextButton(onPressed: _confirm, child: const Text('Seç', style: TextStyle(fontSize: 16))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _header('Uygulama sesleri'),
          for (final s in SoundLibrary.appSounds()) _tile(s),

          _header('Müziklerim'),
          if (_custom != null) _tile(_custom!),
          ListTile(
            leading: const Icon(Icons.library_music_outlined),
            title: const Text('Telefondan müzik / ses dosyası seç'),
            subtitle: const Text('MP3, M4A, OGG, WAV…'),
            onTap: _pickFile,
          ),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (_phoneAlarms.isNotEmpty) _header('Telefonun alarm sesleri'),
            for (final s in _phoneAlarms) _tile(s),
            if (_phoneRingtones.isNotEmpty) _header('Telefonun zil sesleri'),
            for (final s in _phoneRingtones) _tile(s),
            if (_phoneAlarms.isEmpty && _phoneRingtones.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Telefonun hazır seslerine erişilemedi. '
                  'Bir alarm sesini dosya olarak seçebilirsin.',
                ),
              ),
          ],
        ],
      ),
    );
  }
}
