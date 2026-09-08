// ============================================================
// CarCare - خدمة الترخيص
// - يتحقق من ملف التحكم عن بُعد عند كل تشغيل
// - كود التفعيل يفتح التطبيق نهائياً (مخزّن كبصمة SHA-256 فقط)
// ============================================================

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LicenseService {
  static const String _remoteUrl =
      'https://raw.githubusercontent.com/MoTechSys/Flutter-Native-App-011/main/license.json';

  // بصمة كود التفعيل (لا يُخزّن الكود نفسه)
  static const String _activationHash =
      '193167029e2553403414869d6fcb118b078c102850572b9bbbe3b06baf853dc1';

  static const String _kActivated = 'lic_activated';
  static const String _kBlocked = 'lic_blocked';
  static const String _kMessage = 'lic_message';

  /// نتيجة التحقق
  static Future<LicenseState> check() async {
    final prefs = await SharedPreferences.getInstance();

    // 1) مفعّل بكود؟ يفتح دائماً
    if (prefs.getBool(_kActivated) == true) {
      return LicenseState(allowed: true);
    }

    // 2) نحاول قراءة ملف التحكم عن بُعد
    try {
      final uri = Uri.parse(
          '$_remoteUrl?t=${DateTime.now().millisecondsSinceEpoch}');
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final active = data['active'] == true;
        final msg = (data['message'] ?? '').toString();
        // نحفظ آخر حالة معروفة للاستخدام بدون نت
        await prefs.setBool(_kBlocked, !active);
        await prefs.setString(_kMessage, msg);
        return LicenseState(allowed: active, message: msg);
      }
    } catch (_) {
      // لا يوجد إنترنت أو خطأ -> نستخدم آخر حالة محفوظة
    }

    final blocked = prefs.getBool(_kBlocked) ?? false;
    return LicenseState(
      allowed: !blocked,
      message: prefs.getString(_kMessage) ?? '',
    );
  }

  /// محاولة التفعيل بالكود
  static Future<bool> activate(String code) async {
    final hash =
        sha256.convert(utf8.encode(code.trim().toUpperCase())).toString();
    if (hash == _activationHash) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kActivated, true);
      await prefs.setBool(_kBlocked, false);
      return true;
    }
    return false;
  }
}

class LicenseState {
  final bool allowed;
  final String message;
  LicenseState({required this.allowed, this.message = ''});
}
