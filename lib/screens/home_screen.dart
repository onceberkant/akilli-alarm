// Ana ekran: alarm listesi, aç/kapat anahtarları, izin uyarısı ve yeni alarm düğmesi.

import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

import '../models/alarm_item.dart';
import '../services/alarm_repository.dart';
import '../services/permission_service.dart';
import 'edit_alarm_screen.dart';
import 'ring_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final AlarmRepository _repo = AlarmRepository.instance;
  StreamSubscription<Object?>? _ringSub;
  int? _showingRingId; // Açık olan çalma ekranının alarm kimliği
  List<String> _missingPermissions = const [];
  Timer? _ticker; // "X saat sonra" yazısını dakikada bir günceller

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Bir alarm çalmaya başlayınca tam ekran çalma sayfasını aç
    _ringSub = Alarm.ringing.listen((alarmSet) {
      if (alarmSet.alarms.isNotEmpty) _scheduleRingScreen(alarmSet.alarms.first);
    });

    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });

    // İlk kurulumda izinleri iste, sonra alarmları senkronize et
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refresh();
      if (_showingRingId == null) {
        await PermissionService.requestOnFirstLaunch();
        await _refresh();
      }
    });
  }

  /// Çalma ekranını bir sonraki karede açar (initState içinde gezinme hatasını önler)
  void _scheduleRingScreen(AlarmSettings settings) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openRingScreen(settings));
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ringSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  // Uygulama tekrar öne geldiğinde (ör. ayarlardan dönünce) durumu yenile
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  /// Alarmları paketle eşitler, izinleri kontrol eder; çalan alarm varsa ekranını açar
  Future<void> _refresh() async {
    final due = await _repo.reconcile();
    final missing = await PermissionService.missing();
    if (!mounted) return;
    setState(() => _missingPermissions = missing);
    if (due != null) _scheduleRingScreen(due);
  }

  Future<void> _openRingScreen(AlarmSettings settings) async {
    if (!mounted || _showingRingId != null) return; // Zaten açıksa tekrar açma
    _showingRingId = settings.id;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => RingScreen(alarm: settings),
      ),
    );
    _showingRingId = null;
    if (mounted) await _refresh();
  }

  Future<void> _openEditor([AlarmItem? existing]) async {
    final result = await Navigator.of(context).push<DateTime?>(
      MaterialPageRoute(builder: (_) => EditAlarmScreen(existing: existing)),
    );
    if (result != null) _showScheduledSnack(result);
  }

  void _showScheduledSnack(DateTime when) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Alarm ${formatUntil(when)} çalacak')));
  }

  Future<void> _toggle(AlarmItem item, bool value) async {
    final when = await _repo.setEnabled(item, value);
    if (value && when != null) _showScheduledSnack(when);
  }

  Future<void> _delete(AlarmItem item) async {
    await _repo.delete(item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Alarm silindi')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Alarmlar'), centerTitle: false),
      floatingActionButton: FloatingActionButton.large(
        onPressed: () => _openEditor(),
        tooltip: 'Yeni alarm',
        child: const Icon(Icons.add_alarm),
      ),
      body: ListenableBuilder(
        listenable: _repo,
        builder: (context, _) {
          final items = _repo.items;
          final next = _repo.nextAlarm;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              // Eksik izin uyarısı
              if (_missingPermissions.isNotEmpty)
                Card(
                  color: scheme.errorContainer,
                  child: ListTile(
                    leading: Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
                    title: Text(
                      'Alarmın kesin çalması için izin gerekli',
                      style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Eksik: ${_missingPermissions.join(', ')}',
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                    trailing: FilledButton(
                      onPressed: () async {
                        await PermissionService.requestAll();
                        await _refresh();
                      },
                      child: const Text('İzin ver'),
                    ),
                  ),
                ),
              // Sonraki alarm özeti
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  next == null
                      ? 'Açık alarm yok'
                      : 'Sonraki alarm ${formatUntil(next.nextAt!)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.primary),
                ),
              ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Column(
                    children: [
                      Icon(Icons.alarm_off, size: 72, color: scheme.outline),
                      const SizedBox(height: 12),
                      Text('Henüz alarm yok', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('Eklemek için + düğmesine dokunun',
                          style: TextStyle(color: scheme.outline)),
                    ],
                  ),
                ),
              // Alarm kartları (sola/sağa kaydırınca silinir)
              for (final item in items)
                Dismissible(
                  key: ValueKey(item.id),
                  background: _deleteBackground(scheme, Alignment.centerLeft),
                  secondaryBackground: _deleteBackground(scheme, Alignment.centerRight),
                  onDismissed: (_) => _delete(item),
                  child: _AlarmCard(
                    item: item,
                    onTap: () => _openEditor(item),
                    onToggle: (v) => _toggle(item, v),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _deleteBackground(ColorScheme scheme, Alignment alignment) => Container(
        alignment: alignment,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: scheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete, color: scheme.onError),
      );
}

/// Listede tek bir alarmı gösteren kart
class _AlarmCard extends StatelessWidget {
  const _AlarmCard({required this.item, required this.onTap, required this.onToggle});

  final AlarmItem item;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textColor = item.enabled ? scheme.onSurface : scheme.outline;
    final subtitle = [
      if (item.label.trim().isNotEmpty) item.label.trim(),
      item.repeatText,
    ].join(' • ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.timeText,
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w300,
                        color: textColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(subtitle, style: TextStyle(color: textColor)),
                  ],
                ),
              ),
              Switch(value: item.enabled, onChanged: onToggle),
            ],
          ),
        ),
      ),
    );
  }
}
