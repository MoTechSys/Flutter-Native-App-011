// ============================================================
// CarCare - بوابة الترخيص (Remote Kill-Switch)
//
// يُقرأ ملف license.json من مستودع GitHub عند كل تشغيل:
//   { "active": true|false, "code": "XXXX", "message": "..." }
//
// حالات البوابة (LicenseStatus):
//   open      : active=true  -> دخول مباشر بلا كود
//   needsCode : active=false -> يلزم إدخال الكود (يُحفظ بعد أول نجاح)
//   revoked   : الملف/المستودع غير موجود (404) -> إغلاق تام
//
// ملاحظة تقنية: الملف الخام (raw) يُخزَّن في CDN لعدة دقائق، لذلك نستعلم
// أولاً من GitHub REST API (بيانات حية)، ونستخدم الخام كخيار ثانٍ فقط.
// ============================================================

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum LicenseStatus { open, needsCode, revoked }

class LicenseGateResult {
  final LicenseStatus status;
  final String message;

  /// true عندما تعذّر الاتصال واستُخدمت آخر حالة محفوظة
  final bool fromCache;

  const LicenseGateResult(
    this.status, {
    this.message = '',
    this.fromCache = false,
  });

  bool get canEnter => status == LicenseStatus.open;
}

/// نتيجة قراءة الملف البعيد
class _RemotePayload {
  final bool active;
  final String code;
  final String message;
  const _RemotePayload(this.active, this.code, this.message);

  factory _RemotePayload.fromJson(Map<String, dynamic> j) => _RemotePayload(
    j['active'] == true,
    (j['code'] ?? '').toString().trim().toUpperCase(),
    (j['message'] ?? '').toString(),
  );
}

class LicenseGate {
  LicenseGate._();

  /// قابل للاستبدال في الاختبارات
  static http.Client http_ = http.Client();

  static const _repoOwner = 'MoTechSys';
  static const _repoName = 'Flutter-Native-App-011';
  static const _fileName = 'license.json';

  static Uri get _apiUri => Uri.https(
    'api.github.com',
    '/repos/$_repoOwner/$_repoName/contents/$_fileName',
    {'ref': 'main'},
  );
  static Uri _rawUri() => Uri.https(
    'raw.githubusercontent.com',
    '/$_repoOwner/$_repoName/main/$_fileName',
    {'v': '${DateTime.now().microsecondsSinceEpoch}'},
  );

  // مفاتيح التخزين المحلي
  static const _pStatus = 'gate.status'; // index من LicenseStatus
  static const _pMessage = 'gate.message';
  static const _pRemoteCode = 'gate.remote_code';
  static const _pUnlockedWith = 'gate.unlocked_with';

  static const _timeout = Duration(seconds: 7);
  static const _headers = {
    'Cache-Control': 'no-cache, no-store, must-revalidate',
    'Pragma': 'no-cache',
  };

  // ------------------------------------------------------------------
  // الواجهة العامة
  // ------------------------------------------------------------------

  /// تُستدعى عند بدء التطبيق وعند "تحديث الحالة"
  static Future<LicenseGateResult> evaluate() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = await _download();

    // 1) تعذّر الاتصال -> آخر حالة معروفة
    if (payload == null) {
      final idx = prefs.getInt(_pStatus) ?? LicenseStatus.open.index;
      return LicenseGateResult(
        LicenseStatus.values[idx],
        message: prefs.getString(_pMessage) ?? '',
        fromCache: true,
      );
    }

    // 2) الملف محذوف -> إغلاق تام
    if (payload == _revoked) {
      const msg = 'تم إيقاف هذه النسخة نهائياً. تواصل مع المطوّر.';
      await _persist(prefs, LicenseStatus.revoked, msg, '');
      return const LicenseGateResult(LicenseStatus.revoked, message: msg);
    }

    // 3) مفعّل -> دخول مباشر (ويُلغى أي قفل سابق)
    if (payload.active) {
      await _persist(prefs, LicenseStatus.open, payload.message, payload.code);
      return LicenseGateResult(LicenseStatus.open, message: payload.message);
    }

    // 4) غير مفعّل -> هل فُتح سابقاً بنفس الكود الحالي؟
    final unlockedWith = prefs.getString(_pUnlockedWith) ?? '';
    final stillValid = payload.code.isNotEmpty && unlockedWith == payload.code;
    final status = stillValid ? LicenseStatus.open : LicenseStatus.needsCode;
    await _persist(prefs, status, payload.message, payload.code);
    return LicenseGateResult(status, message: payload.message);
  }

  /// محاولة فتح البوابة بكود؛ تُعيد true عند التطابق (ويُحفظ الكود)
  static Future<bool> unlock(String input) async {
    final prefs = await SharedPreferences.getInstance();
    final typed = input.trim().toUpperCase();
    if (typed.isEmpty) return false;

    // تحديث الكود المرجعي من الخادم إن أمكن
    final payload = await _download();
    if (payload == _revoked) return false;
    final reference = payload?.code ?? prefs.getString(_pRemoteCode) ?? '';
    if (reference.isEmpty || typed != reference) return false;

    await prefs.setString(_pUnlockedWith, reference);
    await prefs.setInt(_pStatus, LicenseStatus.open.index);
    return true;
  }

  // ------------------------------------------------------------------
  // داخلي
  // ------------------------------------------------------------------

  static const _revoked = _RemotePayload(false, '', '__revoked__');

  static Future<void> _persist(
    SharedPreferences p,
    LicenseStatus s,
    String msg,
    String code,
  ) async {
    await p.setInt(_pStatus, s.index);
    await p.setString(_pMessage, msg);
    await p.setString(_pRemoteCode, code);
  }

  /// يُعيد الحمولة، أو [_revoked] عند 404، أو null عند فشل الاتصال
  static Future<_RemotePayload?> _download() async {
    final viaApi = await _viaApi();
    if (viaApi != null) return viaApi;
    return _viaRaw();
  }

  static Future<_RemotePayload?> _viaApi() async {
    try {
      final r = await http_
          .get(
            _apiUri,
            headers: {..._headers, 'Accept': 'application/vnd.github+json'},
          )
          .timeout(_timeout);
      if (r.statusCode == 404) return _revoked;
      if (r.statusCode != 200) return null;
      final meta = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final encoded = (meta['content'] as String? ?? '').replaceAll(
        RegExp(r'\s'),
        '',
      );
      if (encoded.isEmpty) return null;
      final json = jsonDecode(utf8.decode(base64Decode(encoded)));
      return _RemotePayload.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<_RemotePayload?> _viaRaw() async {
    try {
      final r = await http_.get(_rawUri(), headers: _headers).timeout(_timeout);
      if (r.statusCode == 404) return _revoked;
      if (r.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(r.bodyBytes));
      return _RemotePayload.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
