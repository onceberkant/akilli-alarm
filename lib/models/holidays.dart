// Türkiye resmî tatilleri: "Resmî tatillerde çalma" seçeneği için kullanılır.
// Arefe ve 28 Ekim gibi yarım günler tatil sayılmaz (sabah işe gidilir).

/// Her yıl aynı tarihte olan resmî tatiller (ay-gün)
const Set<String> _fixedHolidays = {
  '01-01', // Yılbaşı
  '04-23', // Ulusal Egemenlik ve Çocuk Bayramı
  '05-01', // Emek ve Dayanışma Günü
  '05-19', // Atatürk'ü Anma, Gençlik ve Spor Bayramı
  '07-15', // Demokrasi ve Milli Birlik Günü
  '08-30', // Zafer Bayramı
  '10-29', // Cumhuriyet Bayramı
};

/// Dini bayramlar (Diyanet takvimi). Yeni yıllar açıklandıkça buraya eklenir.
const Set<String> _religiousHolidays = {
  // 2026 Ramazan Bayramı
  '2026-03-20', '2026-03-21', '2026-03-22',
  // 2026 Kurban Bayramı
  '2026-05-27', '2026-05-28', '2026-05-29', '2026-05-30',
  // 2027 Ramazan Bayramı
  '2027-03-09', '2027-03-10', '2027-03-11',
  // 2027 Kurban Bayramı
  '2027-05-16', '2027-05-17', '2027-05-18', '2027-05-19',
};

String _two(int n) => n.toString().padLeft(2, '0');

/// Verilen gün Türkiye'de resmî tatil mi?
bool isTurkishHoliday(DateTime d) {
  final monthDay = '${_two(d.month)}-${_two(d.day)}';
  if (_fixedHolidays.contains(monthDay)) return true;
  return _religiousHolidays.contains('${d.year}-$monthDay');
}
