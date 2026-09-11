// ============================================================
// CarCare - محرك رموز التحقق (OTP) + قوالب رسائل البريد
//
// - رمز من 6 أرقام (Random.secure)، صالح 10 دقائق، 5 محاولات،
//   إعادة إرسال بعد 60 ثانية.
// - لا يُخزَّن الرمز نصاً صريحاً، بل تجزئة SHA-256 (رمز + بريد + غرض).
// - يُستخدم في: تأكيد البريد عند إنشاء الحساب، واستعادة كلمة المرور.
// ============================================================

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'mail/mail_service.dart';

enum OtpPurpose { signUp, resetPassword }

enum OtpCheck { ok, wrong, expired, locked, none }

/// جلسة رمز تحقق واحدة (لبريد وغرض محدَّدين).
class OtpSession {
  static const codeLength = 6;
  static const validity = Duration(minutes: 10);
  static const maxAttempts = 5;
  static const resendCooldown = Duration(seconds: 60);

  final String email;
  final OtpPurpose purpose;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String _hash;
  int _attempts = 0;

  /// الرمز الصريح يُحتفظ به فقط ليُرسل بالبريد أو يُعرض في وضع المعاينة.
  final String code;

  OtpSession._(this.email, this.purpose, this.code, this.issuedAt)
    : expiresAt = issuedAt.add(validity),
      _hash = hashCode_(code, email, purpose);

  factory OtpSession.issue(String email, OtpPurpose purpose, {Random? rnd}) {
    final r = rnd ?? Random.secure();
    final code = List.generate(codeLength, (_) => r.nextInt(10)).join();
    return OtpSession._(
      email.trim().toLowerCase(),
      purpose,
      code,
      DateTime.now(),
    );
  }

  static String hashCode_(String code, String email, OtpPurpose p) => sha256
      .convert(utf8.encode('$code|${email.toLowerCase()}|${p.name}'))
      .toString();

  int get attemptsLeft => maxAttempts - _attempts;
  bool get isLocked => _attempts >= maxAttempts;
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remaining {
    final d = expiresAt.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  Duration get resendIn {
    final d = issuedAt.add(resendCooldown).difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  bool get canResend => resendIn == Duration.zero;

  /// الخطوة 4 من حالة الاستخدام: هل الرمز المدخل هو نفسه المُرسل؟
  OtpCheck verify(String typed) {
    if (isLocked) return OtpCheck.locked;
    if (isExpired) return OtpCheck.expired;
    final t = typed.trim();
    if (t.length != codeLength || hashCode_(t, email, purpose) != _hash) {
      _attempts++;
      return isLocked ? OtpCheck.locked : OtpCheck.wrong;
    }
    return OtpCheck.ok;
  }
}

/// نتيجة إصدار رمز وإرساله.
class OtpIssueResult {
  final OtpSession session;

  /// true إذا أُرسل فعلاً بالبريد؛ false إذا كنا في وضع المعاينة (يُعرض الرمز).
  final bool delivered;
  final String? error;
  const OtpIssueResult(this.session, {required this.delivered, this.error});
}

class OtpService {
  const OtpService._();

  /// يولّد رمزاً ويرسله بالبريد. إن لم يكن الإرسال ممكناً (ويب/بدون إعدادات)
  /// يُرجع الجلسة مع delivered=false ليعرض التطبيق الرمز محلياً.
  static Future<OtpIssueResult> issueAndSend(
    String email,
    OtpPurpose purpose, {
    String? recipientName,
  }) async {
    final s = OtpSession.issue(email, purpose);
    if (!MailService.canSend) {
      return OtpIssueResult(s, delivered: false);
    }
    final r = await MailService.send(
      buildMessage(s, recipientName: recipientName),
    );
    return OtpIssueResult(s, delivered: r.sent, error: r.error);
  }

  // ------------------------------------------------------------ templates
  static String purposeTitle(OtpPurpose p) => switch (p) {
    OtpPurpose.signUp => 'تأكيد البريد الإلكتروني',
    OtpPurpose.resetPassword => 'استعادة كلمة المرور',
  };

  static MailMessage buildMessage(OtpSession s, {String? recipientName}) {
    final title = purposeTitle(s.purpose);
    final minutes = OtpSession.validity.inMinutes;
    final hello = (recipientName == null || recipientName.trim().isEmpty)
        ? 'مرحباً،'
        : 'مرحباً ${recipientName.trim()}،';
    final intro = switch (s.purpose) {
      OtpPurpose.signUp =>
        'شكراً لانضمامك إلى CarCare. أدخل رمز التحقق التالي في التطبيق لتأكيد بريدك الإلكتروني وإكمال إنشاء حسابك.',
      OtpPurpose.resetPassword =>
        'وصلنا طلب لإعادة تعيين كلمة مرور حسابك في CarCare. أدخل الرمز التالي في التطبيق للمتابعة.',
    };
    final text =
        '''
$hello

$intro

رمز التحقق: ${s.code}

الرمز صالح لمدة $minutes دقائق فقط. إن لم تطلب هذا الرمز فتجاهل هذه الرسالة.

CarCare - سجل السيارة الذكي
''';
    final html =
        '''
<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#0d1b2a;font-family:Segoe UI,Tahoma,Arial,sans-serif;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#0d1b2a;padding:32px 12px;">
<tr><td align="center">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:480px;background:#16263b;border-radius:18px;overflow:hidden;">
  <tr><td style="background:#ff6b35;padding:20px 24px;text-align:center;">
    <div style="font-size:24px;font-weight:800;color:#fff;letter-spacing:.5px;">CarCare</div>
    <div style="font-size:13px;color:#fff3ea;margin-top:2px;">سجل السيارة الذكي</div>
  </td></tr>
  <tr><td style="padding:28px 24px 8px;color:#ffffff;">
    <div style="font-size:18px;font-weight:700;margin-bottom:10px;">$title</div>
    <div style="font-size:15px;line-height:1.8;color:#c8d3e3;">$hello<br>$intro</div>
  </td></tr>
  <tr><td style="padding:18px 24px;" align="center">
    <div dir="ltr" style="display:inline-block;background:#1e3350;border:1px solid #00b4d8;border-radius:14px;padding:16px 28px;font-size:34px;font-weight:800;letter-spacing:10px;color:#00b4d8;font-family:Consolas,Menlo,monospace;">${s.code}</div>
    <div style="font-size:12px;color:#8fa3bf;margin-top:10px;">اضغط مطوّلاً على الرمز لنسخه</div>
  </td></tr>
  <tr><td style="padding:4px 24px 26px;color:#8fa3bf;font-size:13px;line-height:1.8;">
    ⏱ الرمز صالح لمدة <b style="color:#fff;">$minutes دقائق</b> فقط.<br>
    إن لم تطلب هذا الرمز فتجاهل هذه الرسالة، ولا تشاركه مع أي شخص.
  </td></tr>
  <tr><td style="background:#0d1b2a;padding:14px 24px;text-align:center;font-size:11px;color:#5f7391;">
    رسالة آلية من تطبيق CarCare — الرجاء عدم الرد عليها.
  </td></tr>
</table>
</td></tr></table>
</body></html>
''';
    return MailMessage(
      to: s.email,
      subject: '$title — رمز التحقق ${s.code} | CarCare',
      html: html,
      text: text,
    );
  }
}
