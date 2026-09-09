// اختبار تخطيط: يرسم كل شاشة ببيانات حقيقية على شاشة جوال ضيقة (360x780)
// ويتأكد أنه لا يوجد أي Overflow أو خطأ رسم.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carcare/services/license_service.dart';
import 'package:carcare/models/models.dart';
import 'package:carcare/screens/about_screen.dart';
import 'package:carcare/screens/auth/forgot_password_screen.dart';
import 'package:carcare/screens/auth/login_screen.dart';
import 'package:carcare/screens/auth/register_screen.dart';
import 'package:carcare/screens/license_screen.dart';
import 'package:carcare/screens/record_details_screen.dart';
import 'package:carcare/theme.dart';
import 'package:carcare/widgets/common.dart';

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

/// نسخة من عنصر قائمة الصيانة (نفس التخطيط في maintenance_screen)
Widget maintenanceTile(MaintenanceRecord r) {
  final color = typeColor(r.type);
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.2),
            child: Icon(typeIcon(r.type), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${fmtDate(r.date)} • ${fmtNum(r.odometer)} كم',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'كل ${fmtNum(r.intervalKm)} كم / ${r.intervalDays} يوم',
                  style: const TextStyle(fontSize: 12),
                ),
                if (r.notes.isNotEmpty)
                  Text(r.notes, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(fmtMoney(r.cost)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.edit_outlined, size: 20),
                  SizedBox(width: 12),
                  Icon(Icons.delete_outline, size: 20),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..physicalSize = const Size(360 * 2, 780 * 2)
      ..devicePixelRatio = 2;
  });

  for (final e in {
    'login': () => LoginScreen(onLoggedIn: () {}),
    'register': () => const RegisterScreen(),
    'forgot': () => const ForgotPasswordScreen(),
    'license': () => LicenseScreen(
      gate: const LicenseGateResult(LicenseStatus.needsCode, message: 'رسالة'),
      onUnlocked: () {},
    ),
    'about': () => const AboutScreen(),
  }.entries) {
    testWidgets('screen ${e.key} no overflow', (t) async {
      await t.pumpWidget(wrap(e.value()));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('عنصر الصيانة بأرقام كبيرة وملاحظة طويلة', (t) async {
    final r = MaintenanceRecord(
      id: '1',
      type: MaintenanceType.oil,
      date: DateTime(2026, 9, 9),
      odometer: 1250000,
      intervalKm: 5000,
      intervalDays: 180,
      cost: 6888.5,
      notes: 'زيت موبيل 5W-30 مع فلتر زيت أصلي من الوكالة وملاحظات طويلة جداً',
    );
    await t.pumpWidget(
      wrap(
        Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [maintenanceTile(r), maintenanceTile(r)],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('صفحة التفاصيل بقيم طويلة', (t) async {
    await t.pumpWidget(
      wrap(
        RecordDetailsScreen(
          title: 'تغيير فحمات الفرامل الأمامية والخلفية مع فحص كامل',
          color: Colors.orange,
          icon: Icons.build,
          fields: {
            'التاريخ': '2026/09/09',
            'قراءة العداد': '1,250,000 كم',
            'الصيانة القادمة': '1,255,000 كم أو 2027/03/08',
            'ملاحظات':
                'ملاحظة طويلة جداً جداً جداً تمتد على أكثر من سطر واحد بالتأكيد',
          },
          onEdit: () {},
          onDelete: () async {},
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
