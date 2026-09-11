// اختبارات: الإعدادات + الوضع الداكن/الفاتح + القائمة الجانبية
import 'package:carcare/main.dart';
import 'package:carcare/screens/settings_screen.dart';
import 'package:carcare/services/settings_service.dart';
import 'package:carcare/services/storage_service.dart';
import 'package:carcare/theme.dart';
import 'package:carcare/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget host(Widget child, {bool dark = true}) => MaterialApp(
  theme: buildTheme(dark: dark),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (c, w) =>
      Directionality(textDirection: TextDirection.rtl, child: w!),
  home: child,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await StorageService.instance.init(dbName: 'test_settings.db');
  });

  group('SettingsService', () {
    test('defaults, persistence and toggle', () async {
      SharedPreferences.setMockInitialValues({});
      final s = SettingsService.instance;
      await s.load();
      expect(s.themeMode, ThemeMode.dark);
      expect(s.currency, 'ر.س');
      expect(s.reminderKm, 500);

      await s.setThemeMode(ThemeMode.light);
      await s.setCurrency('ر.ي');
      await s.setReminderKm(1000);
      final p = await SharedPreferences.getInstance();
      expect(p.getString('settings.theme_mode'), 'light');
      expect(p.getString('settings.currency'), 'ر.ي');
      expect(p.getInt('settings.reminder_km'), 1000);

      await s.load();
      expect(s.themeMode, ThemeMode.light);
      await s.setThemeMode(ThemeMode.dark);
      await s.setCurrency('ر.س');
      await s.setReminderKm(500);
    });
  });

  group('buildTheme', () {
    test('dark and light palettes drive AppColors', () {
      final d = buildTheme(dark: true);
      expect(d.brightness, Brightness.dark);
      expect(AppColors.bg, AppPalette.dark.bg);
      expect(d.scaffoldBackgroundColor, AppPalette.dark.bg);

      final l = buildTheme(dark: false);
      expect(l.brightness, Brightness.light);
      expect(AppColors.bg, AppPalette.light.bg);
      expect(AppColors.text, AppPalette.light.text);
      expect(l.scaffoldBackgroundColor, AppPalette.light.bg);
      buildTheme(dark: true);
    });
  });

  testWidgets('settings screen: switch toggles theme mode', (t) async {
    t.view.physicalSize = const Size(390 * 2, 1400 * 2);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.resetPhysicalSize);
    final s = SettingsService.instance;
    await s.setThemeMode(ThemeMode.dark);

    await t.pumpWidget(host(SettingsScreen(onLogout: () {})));
    await t.pumpAndSettle();
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('الوضع الداكن'), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.tap(find.byKey(const Key('dark_mode_switch')));
    await t.pumpAndSettle();
    expect(s.themeMode, ThemeMode.light);

    await t.tap(find.text('النظام'));
    await t.pumpAndSettle();
    expect(s.themeMode, ThemeMode.system);
    await s.setThemeMode(ThemeMode.dark);
  });

  testWidgets('settings screen renders in light mode without overflow', (
    t,
  ) async {
    t.view.physicalSize = const Size(360 * 2, 780 * 2);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(host(SettingsScreen(onLogout: () {}), dark: false));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    buildTheme(dark: true);
  });

  testWidgets('main shell: drawer opens, navigates, and toggles dark mode', (
    t,
  ) async {
    t.view.physicalSize = const Size(390 * 2, 844 * 2);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.resetPhysicalSize);
    final s = SettingsService.instance;
    await s.setThemeMode(ThemeMode.dark);

    await t.pumpWidget(host(MainShell(onLogout: () {})));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('menu_button')));
    await t.pumpAndSettle();
    expect(find.byType(AppDrawer), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);

    await t.tap(find.byKey(const Key('drawer_dark_switch')));
    await t.pumpAndSettle();
    expect(s.themeMode, ThemeMode.light);

    await t.tap(
      find.descendant(
        of: find.byType(AppDrawer),
        matching: find.text('الوقود'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('استهلاك الوقود'), findsOneWidget);
    expect(t.takeException(), isNull);
    await s.setThemeMode(ThemeMode.dark);
  });
}
