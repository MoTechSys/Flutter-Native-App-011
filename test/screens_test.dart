// اختبار الشاشات الفعلية ببيانات حقيقية عبر SQLite (في الذاكرة)
// على مقاس جوال ضيق 360x780 – يفشل إن وُجد أي Overflow.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:carcare/models/models.dart';
import 'package:carcare/screens/fuel_screen.dart';
import 'package:carcare/screens/home_screen.dart';
import 'package:carcare/screens/maintenance_screen.dart';
import 'package:carcare/screens/repairs_screen.dart';
import 'package:carcare/services/storage_service.dart';
import 'package:carcare/theme.dart';

Widget wrap(Widget child) => MaterialApp(
  theme: buildTheme(),
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
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final s = StorageService.instance;
    await s.init();
    // بيانات كبيرة/طويلة عمداً لكشف مشاكل التخطيط
    await s.saveCar(
      Car(name: 'تويوتا لاندكروزر VXR 2022 فل كامل', odometer: 1250000),
    );
    for (final t in MaintenanceType.values) {
      await s.addMaintenance(
        MaintenanceRecord(
          id: '',
          type: t,
          date: DateTime(2026, 9, 9),
          odometer: 1250000,
          intervalKm: t.defaultIntervalKm,
          intervalDays: t.defaultIntervalDays,
          cost: 6888.5,
          notes:
              'زيت موبيل 5W-30 مع فلتر زيت أصلي من الوكالة وملاحظات طويلة جداً',
        ),
      );
    }
    await s.addFuel(
      FuelRecord(
        id: '',
        date: DateTime(2026, 9, 1),
        odometer: 1249000,
        liters: 999.9,
        totalPrice: 99999.99,
      ),
    );
    await s.addFuel(
      FuelRecord(
        id: '',
        date: DateTime(2026, 9, 9),
        odometer: 1250000,
        liters: 42.5,
        totalPrice: 98.5,
      ),
    );
    await s.addRepair(
      RepairRecord(
        id: '',
        date: DateTime(2026, 9, 9),
        odometer: 1250000,
        title: 'تغيير فحمات الفرامل الأمامية والخلفية مع فحص كامل للنظام',
        workshop: 'ورشة الأمانة المتقدمة لصيانة السيارات الحديثة',
        cost: 123456.78,
        notes: 'ملاحظة طويلة جداً جداً تمتد على أكثر من سطر واحد بالتأكيد',
      ),
    );
  });

  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..physicalSize = const Size(360 * 2, 780 * 2)
      ..devicePixelRatio = 2;
  });

  testWidgets('الرئيسية', (t) async {
    await t.pumpWidget(wrap(HomeScreen(onNavigate: (_) {}, onLogout: () {})));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.drag(find.byType(ListView), const Offset(0, -600));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('الصيانة – كل التبويبات', (t) async {
    await t.pumpWidget(wrap(const MaintenanceScreen()));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    for (final tab in ['الإطارات', 'البطارية', 'صيانة دورية']) {
      await t.tap(find.text(tab).first);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: tab);
    }
  });

  testWidgets('الصيانة – نموذج الإضافة', (t) async {
    await t.pumpWidget(wrap(const MaintenanceScreen()));
    await t.pumpAndSettle();
    await t.tap(find.text('إضافة'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('الوقود', (t) async {
    await t.pumpWidget(wrap(const FuelScreen()));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.tap(find.text('تعبئة'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('الإصلاحات', (t) async {
    await t.pumpWidget(wrap(const RepairsScreen()));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.tap(find.text('إصلاح'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
