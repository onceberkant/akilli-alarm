// Uygulama genel ayarları (şimdilik tema). Değişince arayüz anında güncellenir.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _themeKey = 'theme_mode_v1';

  /// Seçili tema: sistem / açık / koyu
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);

  /// Kayıtlı ayarları yükler
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_themeKey);
    themeMode.value = switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  /// Temayı değiştirir ve kaydeder
  static Future<void> setTheme(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }
}
