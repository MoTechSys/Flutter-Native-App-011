// ============================================================
// CarCare - لوحة إدخال رمز التحقق (تُستخدم في إنشاء الحساب والاستعادة)
//
// - حقل 6 أرقام مع تركيز تلقائي، زر "لصق" من الحافظة، عدّاد تنازلي،
//   إعادة إرسال بعد تهدئة، وعرض المحاولات المتبقية.
// - في وضع المعاينة (لا يوجد بريد فعلي) يُعرض الرمز داخل التطبيق مع زر نسخ.
// - إصلاح الكيبورد: عند العودة إلى التطبيق (من تطبيق البريد مثلاً) يُعاد
//   طلب التركيز وإظهار لوحة المفاتيح صراحةً.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/otp_service.dart';
import '../theme.dart';
import 'common.dart';

class OtpVerifyPanel extends StatefulWidget {
  final OtpSession session;

  /// true إذا أُرسل الرمز بالبريد فعلاً؛ false يعني وضع المعاينة (يُعرض الرمز).
  final bool delivered;
  final bool busy;
  final String verifyLabel;
  final VoidCallback onVerified;
  final Future<void> Function() onResend;

  /// يُستدعى عند قفل الرمز (تجاوز المحاولات) — مثلاً للعودة لمرحلة البريد.
  final VoidCallback? onLocked;

  const OtpVerifyPanel({
    super.key,
    required this.session,
    required this.delivered,
    required this.onVerified,
    required this.onResend,
    this.onLocked,
    this.busy = false,
    this.verifyLabel = 'تأكيد الرمز',
  });

  @override
  State<OtpVerifyPanel> createState() => _OtpVerifyPanelState();
}

class _OtpVerifyPanelState extends State<OtpVerifyPanel>
    with WidgetsBindingObserver {
  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _ticker;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _showKeyboard());
  }

  @override
  void didUpdateWidget(covariant OtpVerifyPanel old) {
    super.didUpdateWidget(old);
    if (old.session != widget.session) _code.clear();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// عند العودة من الخلفية (بعد فتح البريد) يُعاد إظهار لوحة المفاتيح.
  /// (الغلاف العام KeyboardResumeFix يعالج الحقل المركَّز؛ هنا نعالج حالة
  /// فقدان التركيز كلياً فنعيده إلى حقل الرمز.)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        final f = FocusManager.instance.primaryFocus;
        if (f == null || f is FocusScopeNode) _showKeyboard();
      });
    }
  }

  void _showKeyboard() {
    if (!mounted || widget.busy) return;
    if (_code.text.length >= OtpSession.codeLength) return;
    FocusScope.of(context).requestFocus(_focus);
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  // ------------------------------------------------------------ actions
  void _verify() {
    final s = widget.session;
    final typed = _code.text.trim();
    if (typed.length != OtpSession.codeLength) {
      showSnack(
        context,
        'الرمز مكوّن من ${OtpSession.codeLength} أرقام',
        error: true,
      );
      _showKeyboard();
      return;
    }
    switch (s.verify(typed)) {
      case OtpCheck.ok:
        _focus.unfocus();
        widget.onVerified();
      case OtpCheck.expired:
        showSnack(
          context,
          'انتهت صلاحية الرمز، اطلب رمزاً جديداً',
          error: true,
        );
        setState(() {});
      case OtpCheck.wrong:
        showSnack(
          context,
          'فشلت العملية: الرمز غير صحيح (بقي ${s.attemptsLeft} محاولة)',
          error: true,
        );
        _code.clear();
        setState(() {});
        _showKeyboard();
      case OtpCheck.locked:
        showSnack(
          context,
          'فشلت العملية: تم إلغاء الرمز بعد ${OtpSession.maxAttempts} محاولات خاطئة',
          error: true,
        );
        _code.clear();
        setState(() {});
        widget.onLocked?.call();
      case OtpCheck.none:
        break;
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final digits = (data?.text ?? '').replaceAll(RegExp(r'\D'), '');
    if (!mounted) return;
    if (digits.length < OtpSession.codeLength) {
      showSnack(context, 'لا يوجد رمز صالح في الحافظة', error: true);
      return;
    }
    _code.text = digits.substring(0, OtpSession.codeLength);
    _code.selection = TextSelection.collapsed(offset: _code.text.length);
    setState(() {});
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.session.code));
    if (mounted) showSnack(context, 'تم نسخ الرمز إلى الحافظة');
  }

  Future<void> _resend() async {
    if (_resending || !widget.session.canResend) return;
    setState(() => _resending = true);
    await widget.onResend();
    if (mounted) {
      setState(() => _resending = false);
      _code.clear();
      _showKeyboard();
    }
  }

  // ------------------------------------------------------------ UI
  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final expired = s.isExpired;
    final locked = s.isLocked;
    final disabled = widget.busy || expired || locked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusCard(session: s, delivered: widget.delivered, onCopy: _copy),
        const SizedBox(height: 18),
        TextField(
          key: const Key('otp_field'),
          controller: _code,
          focusNode: _focus,
          enabled: !disabled,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLength: OtpSession.codeLength,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) {
            setState(() {});
            if (v.length == OtpSession.codeLength) _verify();
          },
          onSubmitted: (_) => _verify(),
          style: const TextStyle(
            fontSize: 24,
            letterSpacing: 12,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            labelText: 'رمز التحقق (${OtpSession.codeLength} أرقام)',
            counterText: '',
            prefixIcon: const Icon(Icons.dialpad),
            suffixIcon: IconButton(
              tooltip: 'لصق من الحافظة',
              onPressed: disabled ? null : _paste,
              icon: const Icon(Icons.content_paste_go),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hourglass_bottom,
                  size: 15,
                  color: expired ? AppColors.red : AppColors.textDim,
                ),
                const SizedBox(width: 4),
                Text(
                  expired
                      ? 'انتهت صلاحية الرمز'
                      : 'ينتهي خلال ${_fmt(s.remaining)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: expired ? AppColors.red : AppColors.textDim,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: (s.canResend && !_resending && !widget.busy)
                  ? _resend
                  : null,
              icon: _resending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.autorenew, size: 16),
              label: Text(
                s.canResend
                    ? 'إعادة الإرسال'
                    : 'إعادة الإرسال بعد ${_fmt(s.resendIn)}',
              ),
            ),
          ],
        ),
        if (!locked && s.attemptsLeft < OtpSession.maxAttempts)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'المحاولات المتبقية: ${s.attemptsLeft}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.yellow, fontSize: 12),
            ),
          ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: disabled ? null : _verify,
          style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
          icon: widget.busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.verified_user),
          label: Text(widget.busy ? 'جارٍ التحقق...' : widget.verifyLabel),
        ),
      ],
    );
  }
}

/// بطاقة الحالة: "أُرسل إلى بريدك" أو عرض الرمز في وضع المعاينة مع زر نسخ.
class _StatusCard extends StatelessWidget {
  final OtpSession session;
  final bool delivered;
  final VoidCallback onCopy;
  const _StatusCard({
    required this.session,
    required this.delivered,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final accent = delivered ? AppColors.green : AppColors.yellow;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                delivered ? Icons.mark_email_read_outlined : Icons.preview,
                color: accent,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivered
                          ? 'تم إرسال رمز التحقق إلى بريدك'
                          : 'وضع المعاينة — الرمز معروض هنا',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: accent,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      session.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(color: AppColors.textDim, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (delivered)
            Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'افتح بريدك، انسخ الرمز المكوّن من 6 أرقام ثم عد إلى التطبيق '
                'واضغط زر اللصق أو اكتبه يدوياً. تحقّق من مجلد الرسائل غير '
                'المرغوبة إن لم يصلك خلال دقيقة.',
                style: TextStyle(
                  color: AppColors.textDim,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            )
          else ...[
            const SizedBox(height: 12),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  OtpSession.codeLength,
                  (i) => Container(
                    width: 40,
                    height: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.cardLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      session.code[i],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.teal,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.content_copy, size: 16),
                label: const Text('نسخ الرمز'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
