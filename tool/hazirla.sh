#!/usr/bin/env bash
# Projenin eksik Android dosyalarını üretir ve alarm paketinin istediği ayarları uygular.
# Hem bilgisayarda hem GitHub Actions'ta aynı şekilde çalışır.
set -euo pipefail
cd "$(dirname "$0")/.."

# 1) Eksik platform dosyalarını oluştur (mevcut lib/, pubspec.yaml ve AndroidManifest.xml'e dokunmaz)
flutter create --org com.alarmapp --project-name akilli_alarm --platforms android .

# 2) Şablonun ürettiği örnek test bizim koda uymaz; kaldır
rm -rf test

# 3) Alarm paketi en az Android 6 (API 23) ister; güvenli olarak 24 yapıyoruz
for f in android/app/build.gradle.kts android/app/build.gradle; do
  if [ -f "$f" ]; then
    sed -i -E 's/minSdk(Version)? *=? *flutter\.minSdkVersion/minSdk = 24/' "$f"
    grep -n "minSdk" "$f" || true
  fi
done

# 4) Android Gradle Plugin 9+ kullanılıyorsa alarm paketinin istediği iki ayarı ekle
if grep -Eqs 'com\.android\.application"\)? version "9' android/settings.gradle.kts android/settings.gradle; then
  if ! grep -q "android.builtInKotlin" android/gradle.properties; then
    printf '\nandroid.builtInKotlin=false\nandroid.newDsl=false\n' >> android/gradle.properties
  fi
fi

flutter pub get
echo "Hazır. APK için: flutter build apk --release"
