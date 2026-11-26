// Ana ekran: alarm listesi, aç/kapat, "bir sonrakini atla", hızlı şekerleme,
// "Uyandın mı?" kontrol uyarısı, izin uyarısı ve ayarlar.

import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

import '../models/alarm_item.dart';
import '../services/alarm_repository.dart';
import '../services/permission_service.dart';
import 'edit_alarm_screen.dart';
import 'ring_screen.dart';
import 'settings_screen.dart';

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
  Timer? _ticker; // "X saat sonra" yazısını düzenli günceller

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

  /// Çalma ekranını bir sonraki karede açar (initState içinde gezinme hatasını önler)
  void _scheduleRingScreen(AlarmSettings settings) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openRingScreen(settings));
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _openRingScreen(AlarmSettings settings) async {
    if (!mounted || _showingRingId != null) return; // Zaten açıksa tekrar açma
    _showingRingId = settings.id;
    // Açık başka sayfalar (düzenleme, ayarlar) varsa önce ana ekrana dön
    Navigator.of(context).popUntil((route) => route.isFirst);
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
    if (result != null) _showSnack('Alarm ${formatUntil(result)} çalacak');
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggle(AlarmItem item, bool value) async {
    final when = await _repo.setEnabled(item, value);
    if (value && when != null) _showSnack('Alarm ${formatUntil(when)} çalacak');
  }

  Future<void> _delete(AlarmItem item) async {
    await _repo.delete(item.id);
    _showSnack('Alarm silindi');
  }

  Future<void> _skip(AlarmItem item) async {
    final when = await _repo.skipNext(item);
    if (when != null) _showSnack('Atlandı. Sonraki: ${shortDate(when)} ${item.timeText}');
  }

  Future<void> _unskip(AlarmItem item) async {
    final when = await _repo.unskip(item);
    if (when != null) _showSnack('Atlama geri alındı. Alarm ${formatUntil(when)} çalacak');
  }

  /// Hızlı şekerleme süresi seçtirir
  Future<void> _openNapSheet() async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hızlı şekerleme', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text('Seçtiğin süre sonra bir kez çalar, sonra kendiliğinden silinir.'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final m in const [5, 10, 15, 20, 30, 45, 60, 90])
                    ActionChip(
                      label: Text('$m dk', style: const TextStyle(fontSize: 16)),
                      onPressed: () => Navigator.pop(context, m),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (minutes == null) return;
    final when = await _repo.quickNap(minutes);
    _showSnack('Şekerleme: ${twoDigits(when.hour)}:${twoDigits(when.minute)}\'de uyandıracağım');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarmlar'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Hızlı şekerleme',
            icon: const Icon(Icons.bedtime_outlined),
            onPressed: _openNapSheet,
          ),
          IconButton(
            tooltip: 'Ayarlar',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
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
          final checks = _repo.pendingChecks;
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
              // Bekleyen "Uyandın mı?" kontrolleri
              for (final c in checks)
                Card(
                  color: scheme.tertiaryContainer,
                  child: ListTile(
                    leading: Icon(Icons.verified_user_outlined, color: scheme.onTertiaryContainer),
                    title: Text(
                      'Uyanıklık kontrolü ${twoDigits(c.checkAt!.hour)}:${twoDigits(c.checkAt!.minute)}\'de',
                      style: TextStyle(color: scheme.onTertiaryContainer, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Onaylamazsan alarm tekrar çalar',
                      style: TextStyle(color: scheme.onTertiaryContainer),
                    ),
                    trailing: FilledButton(
                      onPressed: () => _repo.confirmAwake(c.id),
                      child: const Text('Uyanığım'),
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
                    onSkip: () => _skip(item),
                    onUnskip: () => _unskip(item),
                    onDelete: () => _delete(item),
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
  const _AlarmCard({
    required this.item,
    required this.onTap,
    required this.onToggle,
    required this.onSkip,
    required this.onUnskip,
    required this.onDelete,
  });

  final AlarmItem item;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onSkip;
  final VoidCallback onUnskip;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textColor = item.enabled ? scheme.onSurface : scheme.outline;
    final subtitle = [
      if (item.label.trim().isNotEmpty) item.label.trim(),
      item.repeatText,
    ].join(' • ');
    final skip = item.skipDate;

    // Alarmın açık özelliklerini küçük simgelerle göster
    final features = <IconData>[
      if (item.task == kTaskMath) Icons.calculate_outlined,
      if (item.task == kTaskShake) Icons.screen_rotation_alt,
      if (item.wakeCheckMinutes > 0) Icons.verified_user_outlined,
      if (item.fadeSeconds > 0) Icons.trending_up,
      if (item.skipHolidays && item.isRepeating) Icons.celebration_outlined,
      if (item.isNap) Icons.bedtime_outlined,
    ];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 4, 14),
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
                    if (skip != null && item.enabled)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${shortDate(skip)} atlanacak',
                          style: TextStyle(color: scheme.tertiary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (features.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            for (final f in features)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(f, size: 18, color: scheme.outline),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Switch(value: item.enabled, onChanged: onToggle),
              // Diğer işlemler menüsü
              PopupMenuButton<String>(
                tooltip: 'Diğer',
                onSelected: (v) {
                  switch (v) {
                    case 'skip':
                      onSkip();
                    case 'unskip':
                      onUnskip();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => [
                  if (item.isRepeating && item.enabled && skip == null)
                    const PopupMenuItem(value: 'skip', child: Text('Bir sonrakini atla')),
                  if (skip != null)
                    const PopupMenuItem(value: 'unskip', child: Text('Atlamayı geri al')),
                  const PopupMenuItem(value: 'delete', child: Text('Sil')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
