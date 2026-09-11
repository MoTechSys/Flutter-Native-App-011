// ============================================================
// CarCare - خدمة البريد الإلكتروني (إرسال رموز التحقق OTP)
//
// - الإعدادات تُمرَّر وقت البناء عبر --dart-define (لا تُحفظ في المستودع):
//     SMTP_USER  حساب Gmail المُرسِل
//     SMTP_PASS  كلمة مرور التطبيق (App Password) من Google
//     SMTP_HOST  (اختياري) الافتراضي smtp.gmail.com
//     SMTP_PORT  (اختياري) الافتراضي 465 (SSL)
//     SMTP_NAME  (اختياري) اسم المُرسِل الظاهر، الافتراضي CarCare
// - على الويب (معاينة فقط) لا يوجد SMTP، فتعمل الخدمة في "وضع المعاينة"
//   ويُعرض الرمز داخل التطبيق بدلاً من إرساله.
// - الـ transport قابل للاستبدال في الاختبارات (MailService.transport).
// ============================================================

import 'package:flutter/foundation.dart';

import 'smtp_transport_stub.dart'
    if (dart.library.io) 'smtp_transport_io.dart'
    as platform;

/// إعدادات SMTP المُضمَّنة وقت البناء.
class MailConfig {
  const MailConfig._();
  static const user = String.fromEnvironment('SMTP_USER');
  static const pass = String.fromEnvironment('SMTP_PASS');
  static const host = String.fromEnvironment(
    'SMTP_HOST',
    defaultValue: 'smtp.gmail.com',
  );
  static const port = int.fromEnvironment('SMTP_PORT', defaultValue: 465);
  static const senderName = String.fromEnvironment(
    'SMTP_NAME',
    defaultValue: 'CarCare',
  );
  static bool get isConfigured => user.isNotEmpty && pass.isNotEmpty;
}

/// رسالة بريد جاهزة للإرسال.
class MailMessage {
  final String to;
  final String subject;
  final String html;
  final String text;
  const MailMessage({
    required this.to,
    required this.subject,
    required this.html,
    required this.text,
  });
}

/// واجهة النقل (SMTP حقيقي على أندرويد، وهمي في الاختبارات).
abstract class MailTransport {
  /// true إن كان هذا النقل قادراً على الإرسال فعلاً.
  bool get available;
  Future<void> send(MailMessage message);
}

/// نتيجة محاولة الإرسال.
class MailResult {
  final bool sent;
  final String? error;
  const MailResult.ok() : sent = true, error = null;
  const MailResult.fail(this.error) : sent = false;
}

class MailService {
  const MailService._();

  /// النقل الحالي — يُستبدل في الاختبارات.
  static MailTransport transport = platform.createTransport();

  /// إن كانت null يُحدَّد الوضع تلقائياً؛ وإلا تُفرض القيمة (للاختبارات).
  @visibleForTesting
  static bool? debugCanSendOverride;

  /// هل يمكن إرسال بريد حقيقي على هذه المنصة بهذه الإعدادات؟
  static bool get canSend =>
      debugCanSendOverride ?? (!kIsWeb && transport.available);

  static Future<MailResult> send(MailMessage m) async {
    if (!canSend) return const MailResult.fail('خدمة البريد غير متاحة');
    try {
      await transport.send(m).timeout(const Duration(seconds: 25));
      return const MailResult.ok();
    } catch (e) {
      debugPrint('MailService.send failed: $e');
      return MailResult.fail(_friendly(e));
    }
  }

  static String _friendly(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('timeout')) return 'انتهت مهلة الاتصال بخادم البريد';
    if (s.contains('authentication') || s.contains('535')) {
      return 'فشل التحقق من حساب البريد المُرسِل';
    }
    if (s.contains('socket') || s.contains('network') || s.contains('host')) {
      return 'لا يوجد اتصال بالإنترنت';
    }
    return 'تعذّر إرسال البريد، حاول مجدداً';
  }
}
