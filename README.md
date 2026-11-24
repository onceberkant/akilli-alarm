# Akıllı Alarm (Flutter MVP)

Android için hafif ve güvenilir alarm uygulaması. Alarm motoru olarak [`alarm`](https://pub.dev/packages/alarm) paketi kullanılır: Android'in tam zamanlı (exact) alarm servisi, ön plan ses servisi ve kilit ekranında tam ekran bildirim.

## MVP özellikleri
- Birden fazla alarm: saat, etiket, zil sesi, titreşim, erteleme süresi (5/10/15 dk)
- Tekrar: Tek seferlik, Hafta içi, Hafta sonu, Her gün veya özel günler
- Tek dokunuşla aç/kapat, kaydırarak veya düzenleme ekranından silme
- Çalma ekranı: büyük **Ertele** ve **Kapat** düğmeleri, geri tuşuyla kapanmaz
- Kilit ekranında tam ekran açılır; uygulama kapalıyken de çalar
- Alarmlar telefona kaydedilir; telefon yeniden başlayınca tekrar kurulur
- Açık/koyu tema telefonun ayarını izler

## Proje yapısı
```
lib/
  main.dart                     Giriş noktası, tema, Türkçe dil
  models/alarm_item.dart        Alarm modeli, tekrar hesabı, zil sesleri
  services/alarm_repository.dart Kaydetme, kurma, erteleme, senkronizasyon
  services/permission_service.dart İzinler
  screens/home_screen.dart      Alarm listesi
  screens/edit_alarm_screen.dart Alarm ekle/düzenle
  screens/ring_screen.dart      Alarm çalma ekranı
assets/sounds/                  3 adet zil sesi (WAV)
android/app/src/main/AndroidManifest.xml  İzinler
tool/hazirla.sh                 Eksik Android dosyalarını üretir
.github/workflows/apk-derle.yml Bulutta APK derleme
```

## Yol A — Bilgisayarsız: GitHub ile bulutta APK (telefondan yapılabilir)
1. github.com'da ücretsiz hesap açın ve **yeni, boş bir depo** oluşturun (ör. `akilli-alarm`).
2. Bu zip'in içindeki tüm dosya ve klasörleri, klasör yapısını koruyarak depoya yükleyin
   ("Add file → Upload files"). `.github/workflows/apk-derle.yml` dosyasının da yüklendiğinden emin olun
   (gizli klasördür; telefonda görünmüyorsa "Add file → Create new file" ile bu yolu yazıp içeriğini yapıştırın).
3. Depoda **Actions** sekmesine girin. "APK Derle" otomatik başlar (yaklaşık 5–8 dk).
4. Bitince depo ana sayfasındaki **Releases** bölümünden `app-release.apk` dosyasını telefona indirin.
5. Dosyayı açın, "Bilinmeyen kaynaklardan yüklemeye izin ver" deyin ve kurun.

## Yol B — Bilgisayarda derleme
Flutter SDK ve Android Studio kurulu olmalı.
```bash
cd akilli_alarm
bash tool/hazirla.sh          # Windows'ta Git Bash ile çalıştırın
flutter run                   # USB ile bağlı telefonda çalıştırır
flutter build apk --release   # APK: build/app/outputs/flutter-apk/app-release.apk
```

## İlk açılışta yapılması gerekenler
1. Uygulama sırayla **Bildirim**, **Tam zamanlı alarm** ve **Pil optimizasyonu muafiyeti** izinlerini ister; hepsini onaylayın.
2. Xiaomi / Redmi / POCO: Ayarlar → Uygulamalar → Alarm → **Otomatik başlatma: Açık**, Pil tasarrufu: **Kısıtlama yok**.
3. Samsung: Ayarlar → Pil → Arka plan kullanım sınırları → Alarm'ı **"Hiç uyutulmayan uygulamalar"**a ekleyin.
4. Android 14+: Ayarlar → Uygulamalar → Alarm → **Tam ekran bildirimler** açık olmalı.

## Bilinçli tasarım kararları
- Bildirimde **Kapat** düğmesi yok, yalnızca **Ertele** var. Kapatma uygulama içindeki çalma ekranından yapılır;
  böylece tekrarlı alarmlar bir sonraki güne her zaman doğru kurulur. Bildirime dokunmak çalma ekranını açar.
- Bildirimi yana kaydırmak alarmı susturmaz.
- Uygulama her açıldığında/öne geldiğinde alarmları alarm motoruyla eşitler (kayıp kurulumları onarır).

## Hızlı test listesi
- [ ] 2 dk sonrasına alarm kurun, ekranı kilitleyin → tam ekran açılmalı, ses çalmalı
- [ ] Ertele → seçilen süre sonra tekrar çalmalı
- [ ] Uygulamayı son uygulamalardan kaydırarak kapatın → alarm yine çalmalı
- [ ] Telefonu yeniden başlatın → alarm listesi ve kurulumlar duruyor olmalı
- [ ] "Hafta içi" alarmı kapatın → ana ekranda "Sonraki alarm" bir sonraki iş gününü göstermeli

## Sonraki adımlar
Artan ses seviyesi, telefondan özel zil sesi seçme, zil sesi önizleme, ana ekran widget'ı, alarm kapatmak için görev (matematik sorusu) vb.
