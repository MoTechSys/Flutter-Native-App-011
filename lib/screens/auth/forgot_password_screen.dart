// ============================================================
// CarCare - استعادة كلمة المرور عبر رمز تحقق (OTP)
//
// المراحل:
//   [1] البريد      : التأكد أن الحساب موجود
//   [2] رمز التحقق  : توليد رمز من 4 أرقام (صالح 3 دقائق) مع نسخ/تجديد
//   [3] كلمة جديدة  : بعد نجاح التحقق فقط
// ============================================================

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/storage_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

enum _Stage { email, verify, reset }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _codeLength = 4;
  static const _validity = Duration(minutes: 3);
  static const _maxTries = 3;

  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _pass1 = TextEditingController();
  final _pass2 = TextEditingController();

  _Stage _stage = _Stage.email;
  String _issued = '';
  DateTime? _expiresAt;
  int _tries = 0;
  bool _busy = false;
  bool _obscure = true;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------ OTP
  Duration get _remaining {
    final e = _expiresAt;
    if (e == null) return Duration.zero;
    final d = e.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  bool get _expired => _remaining == Duration.zero;

  void _issueCode() {
    final rnd = Random.secure();
    _issued = List.generate(_codeLength, (_) => rnd.nextInt(10)).join();
    _expiresAt = DateTime.now().add(_validity);
    _tries = 0;
    _code.clear();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  // ------------------------------------------------------------ actions
  Future<void> _submitEmail() async {
    if (!_emailForm.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await StorageService.instance.emailExists(_email.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      showSnack(context, 'هذا البريد غير مسجّل لدينا', error: true);
      return;
    }
    setState(() {
      _issueCode();
      _stage = _Stage.verify;
    });
    showSnack(context, 'تم توليد رمز التحقق');
  }

  void _verify() {
    final typed = _code.text.trim();
    if (typed.length != _codeLength) {
      showSnack(context, 'الرمز مكوّن من $_codeLength أرقام', error: true);
      return;
    }
    if (_expired) {
      showSnack(context, 'انتهت مدة الرمز، اضغط "رمز جديد"', error: true);
      return;
    }
    if (typed != _issued) {
      _tries++;
      if (_tries >= _maxTries) {
        setState(() {
          _issued = '';
          _expiresAt = null;
        });
        showSnack(
          context,
          'تم إلغاء الرمز بعد $_maxTries محاولات خاطئة',
          error: true,
        );
      } else {
        showSnack(
          context,
          'رمز غير صحيح، بقي ${_maxTries - _tries} محاولة',
          error: true,
        );
      }
      return;
    }
    _ticker?.cancel();
    setState(() => _stage = _Stage.reset);
    showSnack(context, 'تم التحقق، أدخل كلمة المرور الجديدة');
  }

  Future<void> _saveNewPassword() async {
    if (!_resetForm.currentState!.validate()) return;
    setState(() => _busy = true);
    await StorageService.instance.resetPassword(
      _email.text.trim(),
      _pass1.text,
    );
    if (!mounted) return;
    showSnack(context, 'تم تحديث كلمة المرور، يمكنك الدخول الآن');
    Navigator.pop(context);
  }

  Future<void> _copy() async {
    if (_issued.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _issued));
    if (mounted) showSnack(context, 'تم نسخ الرمز إلى الحافظة');
  }

  // ------------------------------------------------------------ UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استعادة كلمة المرور')),
      body: SafeArea(
        child: Column(
          children: [
            _StageHeader(stage: _stage),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: SingleChildScrollView(
                  key: ValueKey(_stage),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: switch (_stage) {
                    _Stage.email => _emailStage(),
                    _Stage.verify => _verifyStage(),
                    _Stage.reset => _resetStage(),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emailStage() => Form(
    key: _emailForm,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Intro(
          icon: Icons.alternate_email,
          title: 'ما بريدك الإلكتروني؟',
          body: 'أدخل البريد المرتبط بحسابك حتى نُنشئ لك رمز تحقق.',
        ),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            labelText: 'البريد الإلكتروني',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: validateEmail,
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: _busy ? null : _submitEmail,
          style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
          icon: const Icon(Icons.send),
          label: const Text('إرسال رمز التحقق'),
        ),
      ],
    ),
  );

  Widget _verifyStage() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Intro(
        icon: Icons.sms_outlined,
        title: 'رمز التحقق',
        body: 'انسخ الرمز الظاهر بالأسفل وأدخله في الحقل للمتابعة.',
      ),
      // الرمز في خانات
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.teal.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Text(
              _email.text.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: AppColors.textDim, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _codeLength,
                  (i) => Container(
                    width: 46,
                    height: 54,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.cardLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _issued.isEmpty ? '•' : _issued[i],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.teal,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                Icon(
                  Icons.hourglass_bottom,
                  size: 15,
                  color: _expired ? AppColors.red : AppColors.textDim,
                ),
                Text(
                  _expired ? 'انتهت المدة' : 'ينتهي خلال ${_fmt(_remaining)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _expired ? AppColors.red : AppColors.textDim,
                  ),
                ),
                TextButton.icon(
                  onPressed: _issued.isEmpty ? null : _copy,
                  icon: const Icon(Icons.content_copy, size: 16),
                  label: const Text('نسخ'),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(_issueCode);
                    showSnack(context, 'تم توليد رمز جديد');
                  },
                  icon: const Icon(Icons.autorenew, size: 16),
                  label: const Text('رمز جديد'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      TextField(
        key: const Key('otp_field'),
        controller: _code,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLength: _codeLength,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onSubmitted: (_) => _verify(),
        style: const TextStyle(fontSize: 22, letterSpacing: 10),
        decoration: const InputDecoration(
          labelText: 'الرمز',
          counterText: '',
          prefixIcon: Icon(Icons.dialpad),
        ),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: _verify,
        style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
        icon: const Icon(Icons.verified_user),
        label: const Text('تأكيد الرمز'),
      ),
      TextButton(
        onPressed: () => setState(() {
          _ticker?.cancel();
          _stage = _Stage.email;
        }),
        child: const Text('رجوع لتعديل البريد'),
      ),
    ],
  );

  Widget _resetStage() => Form(
    key: _resetForm,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Intro(
          icon: Icons.lock_reset,
          title: 'كلمة مرور جديدة',
          body: 'اختر كلمة مرور قوية (6 أحرف على الأقل) ثم أكّدها.',
        ),
        TextFormField(
          controller: _pass1,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: 'كلمة المرور الجديدة',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: validatePassword,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _pass2,
          obscureText: _obscure,
          decoration: const InputDecoration(
            labelText: 'إعادة كلمة المرور',
            prefixIcon: Icon(Icons.lock_person_outlined),
          ),
          validator: (v) =>
              v != _pass1.text ? 'كلمتا المرور غير متطابقتين' : null,
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: _busy ? null : _saveNewPassword,
          style: FilledButton.styleFrom(backgroundColor: AppColors.green),
          icon: const Icon(Icons.save_alt),
          label: const Text('تحديث كلمة المرور'),
        ),
      ],
    ),
  );
}

/// رأس المراحل: ثلاث شرائح (Chips) بأسماء المراحل
class _StageHeader extends StatelessWidget {
  final _Stage stage;
  const _StageHeader({required this.stage});

  @override
  Widget build(BuildContext context) {
    const labels = ['البريد', 'التحقق', 'كلمة جديدة'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: List.generate(labels.length, (i) {
          final done = i < stage.index;
          final current = i == stage.index;
          final color = done
              ? AppColors.green
              : current
              ? AppColors.orange
              : AppColors.cardLight;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: done || current ? 0.18 : 1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: done || current ? color : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    done ? Icons.check_circle : Icons.circle,
                    size: 12,
                    color: done || current ? color : AppColors.textDim,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: current
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: done || current ? color : AppColors.textDim,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  final IconData icon;
  final String title, body;
  const _Intro({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 22),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.orange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.orange, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(
                  color: AppColors.textDim,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
