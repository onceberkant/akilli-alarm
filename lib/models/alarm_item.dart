// Tek bir alarmın tüm bilgilerini tutan model ve yardımcı fonksiyonlar.

import 'holidays.dart';

/// Varsayılan zil sesi (assets klasöründeki dosya yolu)
const String kDefaultSound = 'assets/sounds/guclu.wav';

/// Uygulamayla gelen zil sesleri: dosya yolu -> ekranda görünen ad
const Map<String, String> kSounds = {
  'assets/sounds/guclu.wav': 'Güçlü Uyandırma',
  'assets/sounds/klasik.wav': 'Klasik Bip',
  'assets/sounds/yumusak.wav': 'Yumuşak Melodi',
  'assets/sounds/dijital.wav': 'Dijital',
};

/// "Uyandın mı?" kontrol alarmlarının kimliği = alarm kimliği + bu sayı
const int kCheckOffset = 100000;

/// Gün kısaltmaları ve adları (DateTime.monday = 1 ... DateTime.sunday = 7)
const List<String> kDayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const List<String> kDayNames = [
  'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
];
const List<String> kMonthShort = [
  'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
];
const List<String> kMonthNames = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

/// Hazır tekrar grupları
const Set<int> kWeekdays = {1, 2, 3, 4, 5};
const Set<int> kWeekend = {6, 7};
const Set<int> kEveryDay = {1, 2, 3, 4, 5, 6, 7};

/// Uyanma görevi türleri
const String kTaskNone = 'none';
const String kTaskMath = 'math';
const String kTaskShake = 'shake';

/// İki kümenin aynı elemanlara sahip olup olmadığını kontrol eder
bool sameDays(Set<int> a, Set<int> b) => a.length == b.length && a.containsAll(b);

/// İki tarihin aynı gün olup olmadığını kontrol eder
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Sayıyı iki haneli yazar (7 -> "07")
String twoDigits(int n) => n.toString().padLeft(2, '0');

/// "27 Kas Cum" biçiminde kısa tarih
String shortDate(DateTime d) =>
    '${d.day} ${kMonthShort[d.month - 1]} ${kDayShort[d.weekday - 1]}';

/// "27 Kasım 2026 Cuma" biçiminde uzun tarih
String longDate(DateTime d) =>
    '${d.day} ${kMonthNames[d.month - 1]} ${d.year} ${kDayNames[d.weekday - 1]}';

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
    this.date,
    this.enabled = true,
    this.sound = kDefaultSound,
    String? soundName,
    this.vibrate = true,
    this.maxVolume = true,
    this.fadeSeconds = 0,
    this.snoozeMinutes = 5,
    this.maxSnoozes = 0,
    this.snoozeCount = 0,
    this.task = kTaskNone,
    this.mathLevel = 2,
    this.mathCount = 3,
    this.shakeCount = 30,
    this.wakeCheckMinutes = 0,
    this.skipHolidays = false,
    this.skipDate,
    this.isNap = false,
    this.nextAt,
    this.checkAt,
  })  : days = days ?? <int>{},
        soundName = soundName ?? kSounds[sound] ?? 'Zil sesi';

  final int id; // Alarm paketinde de aynı kimlik kullanılır
  int hour;
  int minute;
  String label; // Kullanıcının verdiği etiket (ör. "İşe kalk")
  Set<int> days; // Tekrar günleri; boşsa tek seferlik alarm
  DateTime? date; // Belirli bir tarihte bir kez çalacaksa o gün
  bool enabled; // Açık / kapalı
  String sound; // Zil sesi: "assets/..." ya da telefondaki dosyanın tam yolu
  String soundName; // Zil sesinin ekranda görünen adı
  bool vibrate; // Titreşim
  bool maxVolume; // Telefonun sesi kısık olsa bile tam sesle çal
  int fadeSeconds; // Artan ses süresi (0 = kapalı)
  int snoozeMinutes; // Erteleme süresi (dakika)
  int maxSnoozes; // En fazla kaç kez ertelenebilir (0 = sınırsız)
  int snoozeCount; // Bu çalışta kaç kez ertelendi
  String task; // Kapatmak için görev: none / math / shake
  int mathLevel; // Matematik zorluğu: 1 kolay, 2 orta, 3 zor
  int mathCount; // Çözülecek soru sayısı
  int shakeCount; // Gereken sallama sayısı
  int wakeCheckMinutes; // Kapattıktan kaç dk sonra "Uyandın mı?" (0 = kapalı)
  bool skipHolidays; // Resmî tatillerde çalmasın
  DateTime? skipDate; // "Bir sonrakini atla" ile atlanan gün
  bool isNap; // Hızlı şekerleme alarmı (kapatılınca silinir)
  DateTime? nextAt; // Alarm paketine kurulan bir sonraki çalma zamanı
  DateTime? checkAt; // Bekleyen "Uyandın mı?" kontrolünün zamanı

  bool get isRepeating => days.isNotEmpty;

  /// Bu alarm şu an ertelenebilir mi?
  bool get canSnooze => maxSnoozes == 0 || snoozeCount < maxSnoozes;

  /// Kalan erteleme hakkı (sınırsızsa null)
  int? get snoozesLeft => maxSnoozes == 0 ? null : (maxSnoozes - snoozeCount).clamp(0, 99);

  String get timeText => '${twoDigits(hour)}:${twoDigits(minute)}';

  String get displayLabel {
    if (label.trim().isNotEmpty) return label.trim();
    return isNap ? 'Şekerleme' : 'Alarm';
  }

  /// Tekrar bilgisini okunabilir metne çevirir
  String get repeatText {
    if (date != null) return shortDate(date!);
    if (days.isEmpty) return 'Tek seferlik';
    if (days.length == 7) return 'Her gün';
    if (sameDays(days, kWeekdays)) return 'Hafta içi';
    if (sameDays(days, kWeekend)) return 'Hafta sonu';
    final sorted = days.toList()..sort();
    return sorted.map((d) => kDayShort[d - 1]).join(', ');
  }

  /// Şu andan sonraki ilk çalma zamanını hesaplar; yoksa (geçmiş tarih) null döner.
  /// Gün eklemeyi DateTime yapıcısıyla yapıyoruz ki ay/yıl geçişleri doğru olsun.
  DateTime? nextOccurrence([DateTime? from]) {
    final now = from ?? DateTime.now();
    final d = date;
    if (d != null) {
      final c = DateTime(d.year, d.month, d.day, hour, minute);
      return c.isAfter(now) ? c : null;
    }
    // Uzun bayram tatilleri ve atlanan günler için bir yıla kadar ileri bak
    for (var i = 0; i <= 400; i++) {
      final c = DateTime(now.year, now.month, now.day + i, hour, minute);
      if (!c.isAfter(now)) continue; // Geçmiş veya tam şu an: atla
      if (days.isNotEmpty && !days.contains(c.weekday)) continue;
      final skip = skipDate;
      if (skip != null && sameDay(c, skip)) continue; // "Bir sonrakini atla"
      if (days.isNotEmpty && skipHolidays && isTurkishHoliday(c)) continue;
      return c;
    }
    return null;
  }

  /// Düzenleme ekranında orijinali bozmamak için kopya oluşturur
  AlarmItem copy() => AlarmItem(
        id: id,
        hour: hour,
        minute: minute,
        label: label,
        days: {...days},
        date: date,
        enabled: enabled,
        sound: sound,
        soundName: soundName,
        vibrate: vibrate,
        maxVolume: maxVolume,
        fadeSeconds: fadeSeconds,
        snoozeMinutes: snoozeMinutes,
        maxSnoozes: maxSnoozes,
        snoozeCount: snoozeCount,
        task: task,
        mathLevel: mathLevel,
        mathCount: mathCount,
        shakeCount: shakeCount,
        wakeCheckMinutes: wakeCheckMinutes,
        skipHolidays: skipHolidays,
        skipDate: skipDate,
        isNap: isNap,
        nextAt: nextAt,
        checkAt: checkAt,
      );

  /// Kalıcı saklama için JSON'a çevirir
  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'label': label,
        'days': days.toList(),
        'date': date?.millisecondsSinceEpoch,
        'enabled': enabled,
        'sound': sound,
        'soundName': soundName,
        'vibrate': vibrate,
        'maxVolume': maxVolume,
        'fadeSeconds': fadeSeconds,
        'snoozeMinutes': snoozeMinutes,
        'maxSnoozes': maxSnoozes,
        'snoozeCount': snoozeCount,
        'task': task,
        'mathLevel': mathLevel,
        'mathCount': mathCount,
        'shakeCount': shakeCount,
        'wakeCheckMinutes': wakeCheckMinutes,
        'skipHolidays': skipHolidays,
        'skipDate': skipDate?.millisecondsSinceEpoch,
        'isNap': isNap,
        'nextAt': nextAt?.millisecondsSinceEpoch,
        'checkAt': checkAt?.millisecondsSinceEpoch,
      };

  static DateTime? _date(Object? v) =>
      v is int ? DateTime.fromMillisecondsSinceEpoch(v) : null;

  /// JSON'dan modeli geri oluşturur (eski sürümlerden gelen eksik alanlar için varsayılanlar)
  factory AlarmItem.fromJson(Map<String, dynamic> json) {
    final task = json['task'] as String? ?? kTaskNone;
    return AlarmItem(
      id: json['id'] as int,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      label: json['label'] as String? ?? '',
      days: ((json['days'] as List<dynamic>?) ?? const [])
          .map((e) => e as int)
          .toSet(),
      date: _date(json['date']),
      enabled: json['enabled'] as bool? ?? true,
      sound: json['sound'] as String? ?? kDefaultSound,
      soundName: json['soundName'] as String?,
      vibrate: json['vibrate'] as bool? ?? true,
      maxVolume: json['maxVolume'] as bool? ?? true,
      fadeSeconds: json['fadeSeconds'] as int? ?? 0,
      snoozeMinutes: json['snoozeMinutes'] as int? ?? 5,
      maxSnoozes: json['maxSnoozes'] as int? ?? 0,
      snoozeCount: json['snoozeCount'] as int? ?? 0,
      task: const [kTaskNone, kTaskMath, kTaskShake].contains(task) ? task : kTaskNone,
      mathLevel: json['mathLevel'] as int? ?? 2,
      mathCount: json['mathCount'] as int? ?? 3,
      shakeCount: json['shakeCount'] as int? ?? 30,
      wakeCheckMinutes: json['wakeCheckMinutes'] as int? ?? 0,
      skipHolidays: json['skipHolidays'] as bool? ?? false,
      skipDate: _date(json['skipDate']),
      isNap: json['isNap'] as bool? ?? false,
      nextAt: _date(json['nextAt']),
      checkAt: _date(json['checkAt']),
    );
  }
}
