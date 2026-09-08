// ============================================================
// CarCare - الثيم (لوحة قيادة داكنة)
// ============================================================

import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0D1B2A);
  static const card = Color(0xFF16263B);
  static const cardLight = Color(0xFF1E3350);
  static const orange = Color(0xFFFF6B35);
  static const teal = Color(0xFF00B4D8);
  static const green = Color(0xFF2ECC71);
  static const purple = Color(0xFF9B59B6);
  static const yellow = Color(0xFFF1C40F);
  static const red = Color(0xFFE74C3C);
  static const textDim = Color(0xFF8FA3BF);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.orange,
      secondary: AppColors.teal,
      surface: AppColors.card,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      indicatorColor: AppColors.orange.withValues(alpha: 0.2),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, color: Colors.white),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.orange
                : AppColors.textDim,
          )),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.orange,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      labelStyle: const TextStyle(color: AppColors.textDim),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.orange,
      unselectedLabelColor: AppColors.textDim,
      indicatorColor: AppColors.orange,
    ),
  );
}
