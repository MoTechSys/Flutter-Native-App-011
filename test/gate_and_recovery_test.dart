// اختبارات بوابة الترخيص (بعميل HTTP وهمي) + استعادة كلمة المرور عبر OTP
import 'dart:convert';

import 'package:carcare/screens/auth/forgot_password_screen.dart';
import 'package:carcare/screens/auth/register_screen.dart';
import 'package:carcare/services/license_service.dart';
import 'package:carcare/services/mail/mail_service.dart';
import 'package:carcare/services/otp_service.dart';
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

  group('OtpSession', () {
    test('6 digits, 10 min validity, 5 attempts, 60s cooldown', () {
      final s = OtpSession.issue('A@Car.com', OtpPurpose.signUp);
      expect(s.code.length, 6);
      expect(int.tryParse(s.code), isNotNull);
      expect(s.email, 'a@car.com');
      expect(OtpSession.validity, const Duration(minutes: 10));
      expect(OtpSession.maxAttempts, 5);
      expect(OtpSession.resendCooldown, const Duration(seconds: 60));
      expect(s.remaining.inMinutes, inInclusiveRange(9, 10));
      expect(s.canResend, isFalse);
      expect(s.resendIn.inSeconds, inInclusiveRange(58, 60));
    });

    test('verify: same code -> ok; different -> wrong; 5 wrong -> locked', () {
      final s = OtpSession.issue('a@car.com', OtpPurpose.resetPassword);
      final wrong = s.code == '000000' ? '111111' : '000000';
      for (var i = 1; i < OtpSession.maxAttempts; i++) {
        expect(s.verify(wrong), OtpCheck.wrong);
        expect(s.attemptsLeft, OtpSession.maxAttempts - i);
      }
      expect(s.verify(wrong), OtpCheck.locked);
      expect(s.isLocked, isTrue);
      // بعد القفل حتى الرمز الصحيح يُرفض
      expect(s.verify(s.code), OtpCheck.locked);
    });

    test('verify: correct code -> ok (also with spaces)', () {
      final s = OtpSession.issue('a@car.com', OtpPurpose.resetPassword);
      expect(s.verify(' ${s.code} '), OtpCheck.ok);
    });

    test('mail template contains code, purpose and validity', () {
      final s = OtpSession.issue('user@car.com', OtpPurpose.signUp);
      final m = OtpService.buildMessage(s, recipientName: 'سائق');
      expect(m.to, 'user@car.com');
      expect(m.subject, contains(s.code));
      expect(m.subject, contains('تأكيد البريد الإلكتروني'));
      expect(m.html, contains(s.code));
      expect(m.html, contains('10 دقائق'));
      expect(m.html, contains('مرحباً سائق'));
      expect(m.text, contains(s.code));
      final r = OtpService.buildMessage(
        OtpSession.issue('user@car.com', OtpPurpose.resetPassword),
      );
      expect(r.subject, contains('استعادة كلمة المرور'));
    });
  });

  group('OtpService + MailService', () {
    tearDown(() {
      MailService.debugCanSendOverride = null;
      MailService.transport = _FakeTransport();
    });

    test(
      'preview mode (web / no SMTP) -> delivered=false, code exposed',
      () async {
        MailService.debugCanSendOverride = false;
        final r = await OtpService.issueAndSend('a@car.com', OtpPurpose.signUp);
        expect(r.delivered, isFalse);
        expect(r.error, isNull);
        expect(r.session.code.length, 6);
      },
    );

    test('SMTP ok -> delivered=true and message sent to the user', () async {
      final fake = _FakeTransport();
      MailService.transport = fake;
      MailService.debugCanSendOverride = true;
      final r = await OtpService.issueAndSend(
        'a@car.com',
        OtpPurpose.resetPassword,
      );
      expect(r.delivered, isTrue);
      expect(fake.sent.single.to, 'a@car.com');
      expect(fake.sent.single.html, contains(r.session.code));
    });

    test('SMTP failure -> delivered=false with friendly error', () async {
      MailService.transport = _FakeTransport(fail: 'SocketException: host');
      MailService.debugCanSendOverride = true;
      final r = await OtpService.issueAndSend('a@car.com', OtpPurpose.signUp);
      expect(r.delivered, isFalse);
      expect(r.error, 'لا يوجد اتصال بالإنترنت');
    });
  });

  group('auth flows with e-mail OTP (preview mode)', () {
    final s = StorageService.instance;
    final email = 'driver${DateTime.now().microsecondsSinceEpoch}@car.com';
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await s.init();
      await s.register('سائق', email, 'old12345');
      MailService.debugCanSendOverride = false; // الرمز يُعرض داخل التطبيق
    });
    tearDownAll(() => MailService.debugCanSendOverride = null);

    Future<void> tapAsync(WidgetTester t, String label) => t.runAsync(() async {
      await t.tap(find.text(label));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });

    testWidgets(
      'recovery: email -> otp (wrong fails, right passes) -> new password',
      (t) async {
        t.view.physicalSize = const Size(390 * 2, 1400 * 2);
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

        // 1) بريد غير موجود
        await t.enterText(find.byType(TextFormField), 'x@car.com');
        await tapAsync(t, 'إرسال رمز التحقق');
        await t.pump();
        expect(find.text('هذا البريد غير مسجّل لدينا'), findsOneWidget);

        // 1) بريد صحيح -> 2) مرحلة الرمز
        await t.enterText(find.byType(TextFormField), email);
        await tapAsync(t, 'إرسال رمز التحقق');
        await t.pump(const Duration(milliseconds: 400));
        expect(find.text('تأكيد الرمز'), findsOneWidget);
        expect(find.textContaining('ينتهي خلال'), findsOneWidget);

        await t.tap(find.text('نسخ الرمز'));
        await t.pump();
        expect(clip, isNotNull);
        expect(clip!.length, 6);

        // 3+4) رمز خاطئ -> رسالة فشل
        final wrong = clip == '000000' ? '111111' : '000000';
        await t.enterText(find.byKey(const Key('otp_field')), wrong);
        await t.pump();
        await t.pump(const Duration(milliseconds: 700));
        expect(find.textContaining('فشلت العملية'), findsOneWidget);
        expect(find.text('المحاولات المتبقية: 4'), findsOneWidget);
        expect(find.text('تحديث كلمة المرور'), findsNothing);

        // 4+5) رمز صحيح -> مرحلة كلمة المرور
        await t.enterText(find.byKey(const Key('otp_field')), clip!);
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
      },
    );

    testWidgets('sign-up: account is created only after e-mail is verified', (
      t,
    ) async {
      t.view.physicalSize = const Size(390 * 2, 1400 * 2);
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
      final newEmail = 'new${DateTime.now().microsecondsSinceEpoch}@car.com';

      await t.pumpWidget(host(const RegisterScreen()));
      await t.pumpAndSettle();
      final f = find.byType(TextFormField);
      await t.enterText(f.at(0), 'سائق جديد');
      await t.enterText(f.at(1), newEmail);
      await t.enterText(f.at(2), 'pass1234');
      await t.enterText(f.at(3), 'pass1234');
      await tapAsync(t, 'إرسال رمز التحقق');
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('تأكيد وإنشاء الحساب'), findsOneWidget);

      // لم يُنشأ الحساب بعد
      await t.runAsync(() async {
        expect(await s.emailExists(newEmail), isFalse);
      });

      await t.tap(find.text('نسخ الرمز'));
      await t.pump();
      expect(clip?.length, 6);

      await t.runAsync(() async {
        await t.enterText(find.byKey(const Key('otp_field')), clip!);
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await t.pumpAndSettle();

      await t.runAsync(() async {
        expect(await s.emailExists(newEmail), isTrue);
        expect(await s.login(newEmail, 'pass1234'), isNotNull);
      });
    });

    testWidgets('sign-up: already registered e-mail is rejected before OTP', (
      t,
    ) async {
      t.view.physicalSize = const Size(390 * 2, 1400 * 2);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(host(const RegisterScreen()));
      await t.pumpAndSettle();
      final f = find.byType(TextFormField);
      await t.enterText(f.at(0), 'سائق');
      await t.enterText(f.at(1), email);
      await t.enterText(f.at(2), 'pass1234');
      await t.enterText(f.at(3), 'pass1234');
      await tapAsync(t, 'إرسال رمز التحقق');
      await t.pump();
      expect(find.text('البريد الإلكتروني مسجّل مسبقاً'), findsOneWidget);
      expect(find.text('تأكيد وإنشاء الحساب'), findsNothing);
    });
  });
}

/// نقل بريد وهمي للاختبارات
class _FakeTransport implements MailTransport {
  final String? fail;
  final sent = <MailMessage>[];
  _FakeTransport({this.fail});
  @override
  bool get available => true;
  @override
  Future<void> send(MailMessage message) async {
    if (fail != null) throw Exception(fail);
    sent.add(message);
  }
}
