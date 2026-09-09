// ============================================================
// خدمة الترخيص - ملف التحكم عن بُعد هو المرجع دائماً
//   { "active": true|false, "code": "XXXX", "message": "..." }
// - active=false  => يُقفل التطبيق عند كل تشغيل (لا يوجد تفعيل دائم)
// - الملف/المستودع محذوف (404) => يُقفل أيضاً
// - code          => كود مؤقت يفتح الجلسة الحالية فقط، ويُقارن بالملف
//                    (يمكن تغييره/حذفه من GitHub في أي وقت)
// ============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LicenseService {
  static const String _remoteUrl =
      'https://raw.githubusercontent.com/MoTechSys/Flutter-Native-App-011/main/license.json';

  static const String _kBlocked = 'lic_blocked';
  static const String _kMessage = 'lic_message';
  static const String _kCode = 'lic_code';

  /// يُقرأ الملف عند كل تشغيل؛ بدون إنترنت تُستخدم آخر حالة محفوظة
  static Future<LicenseState> check() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final uri = Uri.parse(
        '$_remoteUrl?t=${DateTime.now().millisecondsSinceEpoch}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final active = data['active'] == true;
        final msg = (data['message'] ?? '').toString();
        final code = (data['code'] ?? '').toString().trim().toUpperCase();
        await prefs.setBool(_kBlocked, !active);
        await prefs.setString(_kMessage, msg);
        await prefs.setString(_kCode, code);
        return LicenseState(allowed: active, message: msg);
      }
      // الملف أو المستودع محذوف (404 أو أي رد غير 200) => لا ترخيص => قفل
      const msg = 'انتهى ترخيص هذه النسخة. يرجى التواصل مع المطوّر.';
      await prefs.setBool(_kBlocked, true);
      await prefs.setString(_kMessage, msg);
      await prefs.setString(_kCode, '');
      return LicenseState(allowed: false, message: msg);
    } catch (_) {
      // فشل الاتصال فقط (لا إنترنت) -> آخر حالة معروفة
    }
    return LicenseState(
      allowed: !(prefs.getBool(_kBlocked) ?? false),
      message: prefs.getString(_kMessage) ?? '',
    );
  }

  /// فتح مؤقت للجلسة الحالية فقط إذا طابق الكود ما في الملف
  static Future<bool> activate(String input) async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kCode) ?? '';
    if (code.isEmpty) return false; // لا يوجد كود مسموح حالياً
    return input.trim().toUpperCase() == code;
  }
}

class LicenseState {
  final bool allowed;
  final String message;
  LicenseState({required this.allowed, this.message = ''});
}
