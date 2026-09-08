// ============================================================
// CarCare - شاشة التفعيل (تظهر عند إيقاف النسخة)
// ============================================================

import 'package:flutter/material.dart';
import '../services/license_service.dart';
import '../theme.dart';

class LicenseScreen extends StatefulWidget {
  final String message;
  final VoidCallback onActivated;
  const LicenseScreen(
      {super.key, required this.message, required this.onActivated});

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final _ctl = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _activate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await LicenseService.activate(_ctl.text);
    if (!mounted) return;
    if (ok) {
      widget.onActivated();
    } else {
      setState(() {
        _busy = false;
        _error = 'كود التفعيل غير صحيح';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline,
                      size: 64, color: AppColors.orange),
                ),
                const SizedBox(height: 24),
                const Text('النسخة تحتاج تفعيل',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(
                  widget.message.isNotEmpty
                      ? widget.message
                      : 'يرجى التواصل مع المطوّر للحصول على كود التفعيل.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textDim, height: 1.6),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _ctl,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(letterSpacing: 2, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'كود التفعيل',
                    errorText: _error,
                    prefixIcon: const Icon(Icons.vpn_key),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _activate,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: const Text('تفعيل'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
