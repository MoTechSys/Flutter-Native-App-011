// ============================================================
// CarCare - خدمة الجلسة (من المسجّل دخوله حالياً)
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _kEmail = 'session_email';
  static const _kName = 'session_name';

  static Future<bool> isLoggedIn() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kEmail) != null;
  }

  static Future<void> saveSession(String email, String name) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kEmail, email);
    await p.setString(_kName, name);
  }

  static Future<String?> currentEmail() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kEmail);
  }

  static Future<String> currentName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kName) ?? 'المستخدم';
  }

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kEmail);
    await p.remove(_kName);
  }
}
