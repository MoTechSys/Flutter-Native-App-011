// ============================================================
// CarCare - نسيت كلمة المرور (خطوتان: البريد ثم كلمة جديدة)
// ============================================================

import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  int _step = 0; // 0 = إدخال البريد، 1 = كلمة مرور جديدة

  Future<void> _next() async {
    if (!_formKey.currentState!.validate()) return;
    final s = StorageService.instance;
    if (_step == 0) {
      final exists = await s.emailExists(_emailCtl.text.trim());
      if (!mounted) return;
      if (!exists) {
        showSnack(context, 'لا يوجد حساب بهذا البريد الإلكتروني', error: true);
        return;
      }
      setState(() => _step = 1);
    } else {
      await s.resetPassword(_emailCtl.text.trim(), _passCtl.text);
      if (!mounted) return;
      showSnack(context, 'تم تغيير كلمة المرور بنجاح');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استعادة كلمة المرور')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Icon(
                  _step == 0 ? Icons.mark_email_read : Icons.password,
                  size: 72,
                  color: AppColors.orange,
                ),
                const SizedBox(height: 16),
                Text(
                  _step == 0
                      ? 'أدخل بريدك الإلكتروني المسجّل للتحقق'
                      : 'أدخل كلمة المرور الجديدة',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textDim),
                ),
                const SizedBox(height: 24),
                // مؤشر الخطوات
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dot(true),
                    Container(width: 40, height: 2, color: AppColors.textDim),
                    _dot(_step == 1),
                  ],
                ),
                const SizedBox(height: 24),
                if (_step == 0)
                  TextFormField(
                    controller: _emailCtl,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: validateEmail,
                  )
                else ...[
                  TextFormField(
                    controller: _passCtl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: validatePassword,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmCtl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'تأكيد كلمة المرور',
                      prefixIcon: Icon(Icons.lock_reset),
                    ),
                    validator: (v) => v != _passCtl.text
                        ? 'كلمتا المرور غير متطابقتين'
                        : null,
                  ),
                ],
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: _next,
                  icon: Icon(_step == 0 ? Icons.arrow_back : Icons.check),
                  label: Text(_step == 0 ? 'التالي' : 'حفظ كلمة المرور'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot(bool active) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: active ? AppColors.orange : AppColors.textDim,
    ),
  );
}
