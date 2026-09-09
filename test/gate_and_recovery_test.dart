// اختبارات بوابة الترخيص (بعميل HTTP وهمي) + استعادة كلمة المرور عبر OTP
import 'dart:convert';

import 'package:carcare/screens/auth/forgot_password_screen.dart';
import 'package:carcare/services/license_service.dart';
import 'package:carcare/services/storage_service.dart';
import 'package:carcare/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget host(Widget child) => MaterialApp(
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

/// خادم وهمي: يحاكي GitHub API (المصدر الأول) والملف الخام
http.Client server({
  bool? active,
  String code = 'CAR-7K2M',
  bool gone = false,
}) => MockClient((req) async {
  if (gone) return http.Response('', 404);
  final body = jsonEncode({'active': active, 'code': code, 'message': 'm'});
  if (req.url.host == 'api.github.com') {
    return http.Response(
      jsonEncode({'content': base64Encode(utf8.encode(body))}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
  return http.Response(body, 200);
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LicenseGate', () {
    test('active=true -> open, clears an old lock', () async {
      SharedPreferences.setMockInitialValues({
        'gate.status': LicenseStatus.needsCode.index,
      });
      LicenseGate.http_ = server(active: true);
      final r = await LicenseGate.evaluate();
      expect(r.status, LicenseStatus.open);
      expect(r.canEnter, isTrue);
    });

    test(
      'active=false -> needsCode; unlock persists; code change relocks',
      () async {
        SharedPreferences.setMockInitialValues({});
        LicenseGate.http_ = server(active: false);
        expect((await LicenseGate.evaluate()).status, LicenseStatus.needsCode);
        expect(await LicenseGate.unlock('nope'), isFalse);
        expect(await LicenseGate.unlock('car-7k2m'), isTrue);
        expect((await LicenseGate.evaluate()).status, LicenseStatus.open);
        LicenseGate.http_ = server(active: false, code: 'CAR-NEW1');
        expect((await LicenseGate.evaluate()).status, LicenseStatus.needsCode);
        LicenseGate.http_ = server(active: true, code: 'CAR-NEW1');
        expect((await LicenseGate.evaluate()).status, LicenseStatus.open);
      },
    );

    test('404 -> revoked, no code works', () async {
      SharedPreferences.setMockInitialValues({
        'gate.unlocked_with': 'CAR-7K2M',
      });
      LicenseGate.http_ = server(gone: true);
      final r = await LicenseGate.evaluate();
      expect(r.status, LicenseStatus.revoked);
      expect(await LicenseGate.unlock('CAR-7K2M'), isFalse);
    });

    test('offline -> last known status', () async {
      SharedPreferences.setMockInitialValues({
        'gate.status': LicenseStatus.needsCode.index,
      });
      LicenseGate.http_ = MockClient((_) async => throw Exception('offline'));
      final r = await LicenseGate.evaluate();
      expect(r.status, LicenseStatus.needsCode);
      expect(r.fromCache, isTrue);
    });
  });

  group('password recovery (OTP)', () {
    final s = StorageService.instance;
    final email = 'driver${DateTime.now().microsecondsSinceEpoch}@car.com';
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await s.init();
      await s.register('سائق', email, 'old12345');
    });

    testWidgets('email -> code -> verify -> new password', (t) async {
      t.view.physicalSize = const Size(390 * 2, 1200 * 2);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.resetPhysicalSize);
      String? clip;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (c) async {
            if (c.method == 'Clipboard.setData') {
              clip = (c.arguments as Map)['text'] as String;
            }
            return null;
          });

      await t.pumpWidget(host(const ForgotPasswordScreen()));
      await t.pumpAndSettle();

      // بريد غير موجود
      await t.enterText(find.byType(TextFormField), 'x@car.com');
      await t.runAsync(() async {
        await t.tap(find.text('إرسال رمز التحقق'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await t.pump();
      expect(find.text('هذا البريد غير مسجّل لدينا'), findsOneWidget);

      // بريد صحيح -> مرحلة التحقق
      await t.enterText(find.byType(TextFormField), email);
      await t.runAsync(() async {
        await t.tap(find.text('إرسال رمز التحقق'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('تأكيد الرمز'), findsOneWidget);

      await t.tap(find.text('نسخ'));
      await t.pump();
      expect(clip, isNotNull);
      expect(clip!.length, 4);

      // رمز خاطئ
      await t.enterText(find.byKey(const Key('otp_field')), '0000');
      await t.tap(find.text('تأكيد الرمز'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 700));
      expect(find.textContaining('رمز غير صحيح'), findsOneWidget);

      // رمز صحيح -> مرحلة كلمة المرور
      await t.enterText(find.byKey(const Key('otp_field')), clip!);
      await t.tap(find.text('تأكيد الرمز'));
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      expect(find.text('تحديث كلمة المرور'), findsOneWidget);

      final f = find.byType(TextFormField);
      await t.enterText(f.at(0), 'newpass9');
      await t.enterText(f.at(1), 'newpass8');
      await t.tap(find.text('تحديث كلمة المرور'));
      await t.pumpAndSettle();
      expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);

      await t.enterText(f.at(1), 'newpass9');
      await t.runAsync(() async {
        await t.tap(find.text('تحديث كلمة المرور'));
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await t.pumpAndSettle();

      await t.runAsync(() async {
        expect(await s.login(email, 'old12345'), isNull);
        expect(await s.login(email, 'newpass9'), isNotNull);
      });
    });
  });
}
