// Tek bir alarmın tüm bilgilerini tutan model ve yardımcı fonksiyonlar.

/// Varsayılan zil sesi (assets klasöründeki dosya yolu)
const String kDefaultSound = 'assets/sounds/klasik.wav';

/// Uygulamayla gelen zil sesleri: dosya yolu -> ekranda görünen ad
const Map<String, String> kSounds = {
  'assets/sounds/klasik.wav': 'Klasik Bip',
  'assets/sounds/yumusak.wav': 'Yumuşak Melodi',
  'assets/sounds/dijital.wav': 'Dijital',
};

/// Gün kısaltmaları (DateTime.monday = 1 ... DateTime.sunday = 7 sırasıyla)
const List<String> kDayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

/// Hazır tekrar grupları
const Set<int> kWeekdays = {1, 2, 3, 4, 5};
const Set<int> kWeekend = {6, 7};
const Set<int> kEveryDay = {1, 2, 3, 4, 5, 6, 7};

/// İki kümenin aynı elemanlara sahip olup olmadığını kontrol eder
bool sameDays(Set<int> a, Set<int> b) => a.length == b.length && a.containsAll(b);

/// Sayıyı iki haneli yazar (7 -> "07")
String twoDigits(int n) => n.toString().padLeft(2, '0');

/// Hedef zamana ne kadar kaldığını Türkçe metin olarak döndürür
String formatUntil(DateTime target, [DateTime? from]) {
  final now = from ?? DateTime.now();
  var mins = (target.difference(now).inSeconds / 60).ceil();
  if (mins < 1) mins = 1;
  final days = mins ~/ (24 * 60);
  final hours = (mins % (24 * 60)) ~/ 60;
  final minutes = mins % 60;
  final parts = <String>[];
  if (days > 0) parts.add('$days gün');
  if (hours > 0) parts.add('$hours saat');
  if (minutes > 0) parts.add('$minutes dakika');
  return '${parts.join(' ')} sonra';
}

class AlarmItem {
  AlarmItem({
    required this.id,
    required this.hour,
    required this.minute,
    this.label = '',
    Set<int>? days,
    this.enabled = true,
    this.sound = kDefaultSound,
    this.vibrate = true,
    this.snoozeMinutes = 5,
    this.nextAt,
  }) : days = days ?? <int>{};

  final int id; // Alarm paketinde de aynı kimlik kullanılır
  int hour;
  int minute;
  String label; // Kullanıcının verdiği etiket (ör. "İşe kalk")
  Set<int> days; // Tekrar günleri; boşsa tek seferlik alarm
  bool enabled; // Açık / kapalı
  String sound; // Zil sesi dosya yolu
  bool vibrate; // Titreşim
  int snoozeMinutes; // Erteleme süresi (dakika)
  DateTime? nextAt; // Alarm paketine kurulan bir sonraki çalma zamanı

  bool get isRepeating => days.isNotEmpty;

  String get timeText => '${twoDigits(hour)}:${twoDigits(minute)}';

  /// Tekrar bilgisini okunabilir metne çevirir
  String get repeatText {
    if (days.isEmpty) return 'Tek seferlik';
    if (days.length == 7) return 'Her gün';
    if (sameDays(days, kWeekdays)) return 'Hafta içi';
    if (sameDays(days, kWeekend)) return 'Hafta sonu';
    final sorted = days.toList()..sort();
    return sorted.map((d) => kDayShort[d - 1]).join(', ');
  }

  /// Şu andan sonraki ilk çalma zamanını hesaplar.
  /// Gün eklemeyi DateTime yapıcısıyla yapıyoruz ki ay/yıl geçişleri doğru olsun.
  DateTime nextOccurrence([DateTime? from]) {
    final now = from ?? DateTime.now();
    for (var i = 0; i <= 7; i++) {
      final candidate = DateTime(now.year, now.month, now.day + i, hour, minute);
      if (!candidate.isAfter(now)) continue; // Geçmiş veya tam şu an: atla
      if (days.isEmpty || days.contains(candidate.weekday)) return candidate;
    }
    // Teorik olarak buraya gelinmez; güvenlik için yarına kur
    return DateTime(now.year, now.month, now.day + 1, hour, minute);
  }

  /// Düzenleme ekranında orijinali bozmamak için kopya oluşturur
  AlarmItem copy() => AlarmItem(
        id: id,
        hour: hour,
        minute: minute,
        label: label,
        days: {...days},
        enabled: enabled,
        sound: sound,
        vibrate: vibrate,
        snoozeMinutes: snoozeMinutes,
        nextAt: nextAt,
      );

  /// Kalıcı saklama için JSON'a çevirir
  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'label': label,
        'days': days.toList(),
        'enabled': enabled,
        'sound': sound,
        'vibrate': vibrate,
        'snoozeMinutes': snoozeMinutes,
        'nextAt': nextAt?.millisecondsSinceEpoch,
      };

  /// JSON'dan modeli geri oluşturur (eksik alanlar için güvenli varsayılanlar)
  factory AlarmItem.fromJson(Map<String, dynamic> json) {
    final rawSound = json['sound'] as String? ?? kDefaultSound;
    final rawNext = json['nextAt'] as int?;
    return AlarmItem(
      id: json['id'] as int,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      label: json['label'] as String? ?? '',
      days: ((json['days'] as List<dynamic>?) ?? const [])
          .map((e) => e as int)
          .toSet(),
      enabled: json['enabled'] as bool? ?? true,
      sound: kSounds.containsKey(rawSound) ? rawSound : kDefaultSound,
      vibrate: json['vibrate'] as bool? ?? true,
      snoozeMinutes: json['snoozeMinutes'] as int? ?? 5,
      nextAt: rawNext == null ? null : DateTime.fromMillisecondsSinceEpoch(rawNext),
    );
  }
}
