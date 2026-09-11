// ============================================================
// CarCare - الثيم (داكن / فاتح)
//
// - الألوان المميِّزة (برتقالي/سماوي/أخضر…) ثابتة في الوضعين.
// - ألوان الأسطح والنص (bg/card/cardLight/text/textDim/divider) تُقرأ من
//   اللوحة الحالية `AppColors.palette` التي يبدّلها ThemeController،
//   حتى تعمل كل الشاشات القديمة بلا تعديل مواقع الاستخدام.
// ============================================================

import 'package:flutter/material.dart';

/// لوحة ألوان الأسطح لوضع واحد.
class AppPalette {
  final Brightness brightness;
  final Color bg, card, cardLight, text, textDim, divider;
  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.card,
    required this.cardLight,
    required this.text,
    required this.textDim,
    required this.divider,
  });

  static const dark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF0D1B2A),
    card: Color(0xFF16263B),
    cardLight: Color(0xFF1E3350),
    text: Colors.white,
    textDim: Color(0xFF8FA3BF),
    divider: Colors.white12,
  );

  static const light = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF3F6FA),
    card: Colors.white,
    cardLight: Color(0xFFE8EEF6),
    text: Color(0xFF0D1B2A),
    textDim: Color(0xFF5C6F8A),
    divider: Colors.black12,
  );

  bool get isDark => brightness == Brightness.dark;
}

class AppColors {
  const AppColors._();

  /// اللوحة الحالية — يبدّلها ThemeController قبل إعادة البناء.
  static AppPalette palette = AppPalette.dark;

  // ألوان الأسطح والنص (تتبع الوضع)
  static Color get bg => palette.bg;
  static Color get card => palette.card;
  static Color get cardLight => palette.cardLight;
  static Color get text => palette.text;
  static Color get textDim => palette.textDim;
  static Color get divider => palette.divider;

  // ألوان مميِّزة ثابتة
  static const orange = Color(0xFFFF6B35);
  static const teal = Color(0xFF00B4D8);
  static const green = Color(0xFF2ECC71);
  static const purple = Color(0xFF9B59B6);
  static const yellow = Color(0xFFF1C40F);
  static const red = Color(0xFFE74C3C);
}

/// يبني ThemeData للوضع المطلوب ويضبط `AppColors.palette` عليه.
ThemeData buildTheme({bool dark = true}) {
  final p = dark ? AppPalette.dark : AppPalette.light;
  AppColors.palette = p;
  final base = dark
      ? ThemeData.dark(useMaterial3: true)
      : ThemeData.light(useMaterial3: true);
  final scheme = dark
      ? ColorScheme.dark(
          primary: AppColors.orange,
          secondary: AppColors.teal,
          surface: p.card,
          onSurface: p.text,
        )
      : ColorScheme.light(
          primary: AppColors.orange,
          secondary: AppColors.teal,
          surface: p.card,
          onSurface: p.text,
        );
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    colorScheme: scheme,
    dividerColor: p.divider,
    textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    iconTheme: IconThemeData(color: p.text),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.text,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: p.text),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: p.text,
      ),
    ),
    cardTheme: CardThemeData(
      color: p.card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      titleTextStyle: TextStyle(
        color: p.text,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      contentTextStyle: TextStyle(color: p.text, fontSize: 15),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      modalBackgroundColor: p.card,
    ),
    drawerTheme: DrawerThemeData(backgroundColor: p.bg),
    listTileTheme: ListTileThemeData(textColor: p.text, iconColor: p.textDim),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : p.textDim,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? AppColors.orange : p.cardLight,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.card,
      indicatorColor: AppColors.orange.withValues(alpha: 0.2),
      labelTextStyle: WidgetStateProperty.all(
        TextStyle(fontSize: 12, color: p.text),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.orange
              : p.textDim,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.orange,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.cardLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      labelStyle: TextStyle(color: p.textDim),
      hintStyle: TextStyle(color: p.textDim),
      prefixIconColor: p.textDim,
      suffixIconColor: p.textDim,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.orange,
      unselectedLabelColor: p.textDim,
      indicatorColor: AppColors.orange,
    ),
    snackBarTheme: const SnackBarThemeData(
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: p.card,
      headerForegroundColor: p.text,
    ),
  );
}
