// ============================================================
// CarCare - شاشة بوابة الترخيص (تظهر عند إيقاف النسخة عن بُعد)
// ============================================================

import 'package:flutter/material.dart';
import '../services/license_service.dart';
import '../theme.dart';

class LicenseScreen extends StatefulWidget {
  final LicenseGateResult gate;
  final VoidCallback onUnlocked;
  const LicenseScreen({
    super.key,
    required this.gate,
    required this.onUnlocked,
  });

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final _codeCtl = TextEditingController();
  bool _working = false;
  bool _refreshing = false;
  String? _hint;

  bool get _revoked => widget.gate.status == LicenseStatus.revoked;

  Future<void> _unlock() async {
    final code = _codeCtl.text.trim();
    if (code.isEmpty) {
      setState(() => _hint = 'الرجاء إدخال كود التفعيل');
      return;
    }
    setState(() {
      _working = true;
      _hint = null;
    });
    final ok = await LicenseGate.unlock(code);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _working = false;
      _hint = 'الكود غير صحيح';
    });
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final res = await LicenseGate.evaluate();
    if (!mounted) return;
    setState(() => _refreshing = false);
    if (res.canEnter) {
      widget.onUnlocked();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.fromCache
                ? 'تعذّر الاتصال بالخادم، تحقق من الإنترنت'
                : 'لم يتم تفعيل النسخة حتى الآن',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // شريط علوي: أيقونة السيارة + قفل
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: LinearGradient(
                              colors: [
                                AppColors.orange.withValues(alpha: 0.35),
                                AppColors.cardLight,
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.directions_car,
                            size: 48,
                            color: AppColors.orange,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _revoked ? Icons.block : Icons.lock,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _revoked ? 'النسخة موقوفة' : 'التطبيق مقفل',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.gate.message.isEmpty
                          ? 'للمتابعة أدخل كود التفعيل الذي حصلت عليه من المطوّر.'
                          : widget.gate.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textDim,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!_revoked) ...[
                      TextField(
                        controller: _codeCtl,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        onSubmitted: (_) => _unlock(),
                        style: const TextStyle(
                          fontSize: 18,
                          letterSpacing: 3,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: 'XXX-0000',
                          hintStyle: const TextStyle(
                            letterSpacing: 3,
                            color: AppColors.textDim,
                          ),
                          errorText: _hint,
                          prefixIcon: const Icon(Icons.key),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _working ? null : _unlock,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: _working
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.lock_open),
                          label: Text(
                            _working ? 'جارٍ التحقق...' : 'فتح التطبيق',
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    OutlinedButton.icon(
                      onPressed: _refreshing ? null : _refresh,
                      icon: _refreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: const Text('تحديث حالة الترخيص'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
