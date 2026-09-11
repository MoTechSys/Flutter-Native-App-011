// ============================================================
// CarCare - إعدادات التطبيق (الوضع الداكن/الفاتح + تفضيلات)
// تُحفظ في SharedPreferences وتُبلّغ المستمعين عند التغيير.
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService instance = SettingsService._();
  SettingsService._();

  static const _kThemeMode = 'settings.theme_mode'; // system | dark | light
  static const _kCurrency = 'settings.currency';
  static const _kReminderKm = 'settings.reminder_km';

  ThemeMode _themeMode = ThemeMode.dark;
  String _currency = 'ر.س';
  int _reminderKm = 500;

  /// يُستدعى بعد تغيير وضع المظهر ليُعيد رسم الشاشات التي تقرأ AppColors
  /// مباشرة (وليس عبر Theme.of) — يضبطه main.dart.
  VoidCallback? onThemeChanged;

  ThemeMode get themeMode => _themeMode;
  String get currency => _currency;

  /// عدد الكيلومترات قبل الاستحقاق التي تُعتبر حالة "قريب".
  int get reminderKm => _reminderKm;

  /// هل الوضع الفعلي داكن؟ (يحسم وضع النظام عبر platformBrightness)
  bool isDark(BuildContext context) => switch (_themeMode) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark,
  };

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _themeMode = _parseMode(p.getString(_kThemeMode));
    _currency = p.getString(_kCurrency) ?? _currency;
    _reminderKm = p.getInt(_kReminderKm) ?? _reminderKm;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    if (m == _themeMode) return;
    _themeMode = m;
    notifyListeners();
    // بعد أن يبني MaterialApp الثيم الجديد (ويضبط AppColors.palette) نعيد رسم
    // بقية الشاشات في الإطار التالي حتى تلتقط الألوان الجديدة.
    WidgetsBinding.instance.addPostFrameCallback((_) => onThemeChanged?.call());
    final p = await SharedPreferences.getInstance();
    await p.setString(_kThemeMode, m.name);
  }

  /// تبديل سريع بين داكن وفاتح (زر في القائمة الجانبية).
  Future<void> toggleDark(BuildContext context) =>
      setThemeMode(isDark(context) ? ThemeMode.light : ThemeMode.dark);

  Future<void> setCurrency(String c) async {
    _currency = c;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kCurrency, c);
  }

  Future<void> setReminderKm(int km) async {
    _reminderKm = km;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kReminderKm, km);
  }

  static ThemeMode _parseMode(String? s) => switch (s) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };
}
