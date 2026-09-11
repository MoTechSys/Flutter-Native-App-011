// ============================================================
// CarCare - إنشاء حساب بمرحلتين (Form + Validation + تأكيد البريد)
//
//   [1] البيانات : الاسم/البريد/كلمة المرور/التأكيد
//   [2] التحقق   : رمز 6 أرقام يُرسل إلى البريد (صالح 10 دقائق)
//   ← الحساب لا يُكتب في قاعدة البيانات إلا بعد نجاح التحقق.
// ============================================================

import 'package:flutter/material.dart';

import '../../services/otp_service.dart';
import '../../services/storage_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/otp_verify_panel.dart';

enum _Stage { details, verify }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  bool _hide = true;
  bool _busy = false;

  _Stage _stage = _Stage.details;
  OtpIssueResult? _otp;

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _passCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ actions
  /// المرحلة 1: التحقق من النموذج + التأكد أن البريد غير مسجّل + إرسال الرمز.
  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final email = _emailCtl.text.trim();
    final taken = await StorageService.instance.emailExists(email);
    if (!mounted) return;
    if (taken) {
      setState(() => _busy = false);
      showSnack(context, 'البريد الإلكتروني مسجّل مسبقاً', error: true);
      return;
    }
    final r = await OtpService.issueAndSend(
      email,
      OtpPurpose.signUp,
      recipientName: _nameCtl.text.trim(),
    );
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
      _emailCtl.text.trim(),
      OtpPurpose.signUp,
      recipientName: _nameCtl.text.trim(),
    );
    if (!mounted) return;
    if (!r.delivered && r.error != null) {
      showSnack(context, r.error!, error: true);
      return;
    }
    setState(() => _otp = r);
    showSnack(context, r.delivered ? 'تم إرسال رمز جديد' : 'تم توليد رمز جديد');
  }

  /// المرحلة 2: بعد نجاح التحقق فقط يُنشأ الحساب فعلياً.
  Future<void> _createAccount() async {
    setState(() => _busy = true);
    final err = await StorageService.instance.register(
      _nameCtl.text.trim(),
      _emailCtl.text.trim(),
      _passCtl.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showSnack(context, err, error: true);
      return;
    }
    showSnack(context, 'تم تأكيد بريدك وإنشاء الحساب بنجاح، سجّل الدخول الآن');
    Navigator.pop(context);
  }

  void _backToDetails() => setState(() {
    _stage = _Stage.details;
    _otp = null;
  });

  // ------------------------------------------------------------ UI
  @override
  Widget build(BuildContext context) {
    return KeyboardResumeFix(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _stage == _Stage.details ? 'إنشاء حساب جديد' : 'تأكيد البريد',
          ),
          leading: _stage == _Stage.verify
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'رجوع لتعديل البيانات',
                  onPressed: _busy ? null : _backToDetails,
                )
              : null,
        ),
        body: SafeArea(
          child: Column(
            children: [
              _StepHeader(step: _stage.index),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, if (current != null) current],
                  ),
                  child: SingleChildScrollView(
                    key: ValueKey(_stage),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: _stage == _Stage.details
                        ? _detailsStage()
                        : _verifyStage(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailsStage() => Form(
    key: _formKey,
    child: Column(
      children: [
        const Icon(Icons.person_add_alt_1, size: 64, color: AppColors.teal),
        const SizedBox(height: 6),
        const Text(
          'سنرسل رمز تحقق إلى بريدك قبل تفعيل الحساب',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textDim, fontSize: 13),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _nameCtl,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          decoration: const InputDecoration(
            labelText: 'الاسم الكامل',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (v) => (v ?? '').trim().length < 3
              ? 'الاسم يجب أن يكون 3 أحرف على الأقل'
              : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _emailCtl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            labelText: 'البريد الإلكتروني',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: validateEmail,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _passCtl,
          obscureText: _hide,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: 'كلمة المرور',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_hide ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
          validator: validatePassword,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _confirmCtl,
          obscureText: _hide,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _busy ? null : _sendCode(),
          decoration: const InputDecoration(
            labelText: 'تأكيد كلمة المرور',
            prefixIcon: Icon(Icons.lock_reset),
          ),
          validator: (v) =>
              v != _passCtl.text ? 'كلمتا المرور غير متطابقتين' : null,
        ),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: _busy ? null : _sendCode,
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
        const SizedBox(height: 6),
        const Text(
          'أدخل الرمز لإكمال إنشاء الحساب',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        OtpVerifyPanel(
          key: ValueKey(otp.session.issuedAt),
          session: otp.session,
          delivered: otp.delivered,
          busy: _busy,
          verifyLabel: 'تأكيد وإنشاء الحساب',
          onVerified: _createAccount,
          onResend: _resend,
          onLocked: _backToDetails,
        ),
        TextButton(
          onPressed: _busy ? null : _backToDetails,
          child: const Text('رجوع لتعديل البيانات'),
        ),
      ],
    );
  }
}

/// رأس المرحلتين (البيانات → التحقق)
class _StepHeader extends StatelessWidget {
  final int step;
  const _StepHeader({required this.step});

  @override
  Widget build(BuildContext context) {
    const labels = ['البيانات', 'تأكيد البريد'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: List.generate(labels.length, (i) {
          final done = i < step;
          final current = i == step;
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
