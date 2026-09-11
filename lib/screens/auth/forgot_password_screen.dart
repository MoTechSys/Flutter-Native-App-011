// ============================================================
// CarCare - استعادة كلمة المرور عبر رمز تحقق (OTP)
//
// المراحل:
//   [1] البريد      : التأكد أن الحساب موجود
//   [2] رمز التحقق  : رمز 6 أرقام يُرسل إلى بريد المستخدم (صالح 10 دقائق)
//                     النظام يفحص: الرمز المدخل == المُرسل؟
//   [3] كلمة جديدة  : تُفتح فقط إذا تطابق الرمز؛ وإلا تظهر رسالة فشل
// ============================================================

import 'package:flutter/material.dart';

import '../../services/otp_service.dart';
import '../../services/storage_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/otp_verify_panel.dart';

enum _Stage { email, verify, reset }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass1 = TextEditingController();
  final _pass2 = TextEditingController();

  _Stage _stage = _Stage.email;
  OtpIssueResult? _otp;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _pass1.dispose();
    _pass2.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ actions
  /// الخطوة 1+2: التأكد أن البريد مسجّل ثم إرسال رمز OTP إليه.
  Future<void> _submitEmail() async {
    if (!_emailForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final email = _email.text.trim();
    final ok = await StorageService.instance.emailExists(email);
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      showSnack(context, 'هذا البريد غير مسجّل لدينا', error: true);
      return;
    }
    final r = await OtpService.issueAndSend(email, OtpPurpose.resetPassword);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.delivered && r.error != null) {
      showSnack(context, r.error!, error: true);
      return;
    }
    setState(() {
      _otp = r;
      _stage = _Stage.verify;
    });
    showSnack(
      context,
      r.delivered
          ? 'تم إرسال رمز التحقق إلى $email'
          : 'وضع المعاينة: الرمز معروض داخل التطبيق',
    );
  }

  Future<void> _resend() async {
    final r = await OtpService.issueAndSend(
      _email.text.trim(),
      OtpPurpose.resetPassword,
    );
    if (!mounted) return;
    if (!r.delivered && r.error != null) {
      showSnack(context, r.error!, error: true);
      return;
    }
    setState(() => _otp = r);
    showSnack(context, r.delivered ? 'تم إرسال رمز جديد' : 'تم توليد رمز جديد');
  }

  /// الخطوة 5: الرمز مطابق → الانتقال لكتابة كلمة مرور جديدة.
  void _onVerified() {
    setState(() => _stage = _Stage.reset);
    showSnack(context, 'تم التحقق بنجاح، أدخل كلمة المرور الجديدة');
  }

  void _backToEmail() => setState(() {
    _stage = _Stage.email;
    _otp = null;
  });

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

  // ------------------------------------------------------------ UI
  @override
  Widget build(BuildContext context) {
    return KeyboardResumeFix(
      child: Scaffold(
        appBar: AppBar(title: const Text('استعادة كلمة المرور')),
        body: SafeArea(
          child: Column(
            children: [
              _StageHeader(stage: _stage),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, if (current != null) current],
                  ),
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
          body: 'أدخل البريد المرتبط بحسابك وسنرسل إليه رمز تحقق من 6 أرقام.',
        ),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          onFieldSubmitted: (_) => _busy ? null : _submitEmail(),
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
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send),
          label: Text(_busy ? 'جارٍ الإرسال...' : 'إرسال رمز التحقق'),
        ),
      ],
    ),
  );

  Widget _verifyStage() {
    final otp = _otp!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Intro(
          icon: Icons.mark_email_unread_outlined,
          title: 'رمز التحقق',
          body:
              'أدخل الرمز الذي وصلك على بريدك. إن كان مطابقاً نُكمل إلى '
              'كلمة المرور الجديدة، وإلا تظهر رسالة فشل.',
        ),
        OtpVerifyPanel(
          key: ValueKey(otp.session.issuedAt),
          session: otp.session,
          delivered: otp.delivered,
          busy: _busy,
          onVerified: _onVerified,
          onResend: _resend,
          onLocked: _backToEmail,
        ),
        TextButton(
          onPressed: _busy ? null : _backToEmail,
          child: const Text('رجوع لتعديل البريد'),
        ),
      ],
    );
  }

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
                style: TextStyle(
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
