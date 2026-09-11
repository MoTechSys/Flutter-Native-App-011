// ============================================================
// CarCare - شاشة الإعدادات
//   المظهر (داكن / فاتح / حسب النظام) · العملة · حدّ التنبيه بالكيلومتر
//   · بيانات السيارة · الحساب (تغيير كلمة المرور، تسجيل الخروج)
// ============================================================

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'about_screen.dart';

class SettingsScreen extends StatelessWidget {
  final VoidCallback onLogout;
  const SettingsScreen({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: settings,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Section(
                title: 'المظهر',
                icon: Icons.palette_outlined,
                children: [
                  _ThemeModeTile(settings: settings),
                  const Divider(height: 1),
                  SwitchListTile(
                    key: const Key('dark_mode_switch'),
                    secondary: Icon(
                      settings.isDark(context)
                          ? Icons.dark_mode
                          : Icons.light_mode,
                      color: AppColors.orange,
                    ),
                    title: const Text('الوضع الداكن'),
                    subtitle: Text(
                      settings.themeMode == ThemeMode.system
                          ? 'يتبع إعداد النظام حالياً'
                          : (settings.isDark(context) ? 'مفعّل' : 'معطّل'),
                    ),
                    value: settings.isDark(context),
                    onChanged: (v) => settings.setThemeMode(
                      v ? ThemeMode.dark : ThemeMode.light,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'التفضيلات',
                icon: Icons.tune,
                children: [
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: const Text('العملة'),
                    subtitle: Text(settings.currency),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => _pickCurrency(context, settings),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: const Text('حدّ التنبيه "قريب"'),
                    subtitle: Text(
                      'قبل ${fmtNum(settings.reminderKm)} كم من موعد الصيانة',
                    ),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => _pickReminder(context, settings),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'السيارة',
                icon: Icons.directions_car_outlined,
                children: [
                  AnimatedBuilder(
                    animation: StorageService.instance,
                    builder: (context, _) {
                      final car = StorageService.instance.car;
                      return ListTile(
                        leading: const Icon(Icons.speed),
                        title: Text(car.name),
                        subtitle: Text('${fmtNum(car.odometer)} كم'),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _editCar(context),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'الحساب',
                icon: Icons.person_outline,
                children: [
                  FutureBuilder<String>(
                    future: AuthService.currentName(),
                    builder: (context, snap) => ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: const Text('المستخدم الحالي'),
                      subtitle: Text(snap.data ?? '…'),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_reset),
                    title: const Text('تغيير كلمة المرور'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => _changePassword(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.red),
                    title: const Text(
                      'تسجيل الخروج',
                      style: TextStyle(color: AppColors.red),
                    ),
                    onTap: () => confirmLogout(context, onLogout),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'عن التطبيق',
                icon: Icons.info_outline,
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('حول CarCare'),
                    subtitle: const Text('الإصدار 1.4.0 (build 8)'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ dialogs
  Future<void> _pickCurrency(BuildContext context, SettingsService s) async {
    const options = ['ر.س', 'ر.ي', 'د.إ', 'ج.م', 'د.ك', '\$'];
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('اختر العملة'),
        children: [
          for (final o in options)
            ListTile(
              leading: Icon(
                o == s.currency
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: o == s.currency ? AppColors.orange : null,
              ),
              title: Text(o),
              onTap: () => Navigator.pop(context, o),
            ),
        ],
      ),
    );
    if (picked != null) {
      await s.setCurrency(picked);
      StorageService.instance.refreshUi();
      if (context.mounted) showSnack(context, 'تم تغيير العملة إلى $picked');
    }
  }

  Future<void> _pickReminder(BuildContext context, SettingsService s) async {
    const options = [200, 500, 1000, 1500, 2000];
    final picked = await showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('حدّ التنبيه بالكيلومتر'),
        children: [
          for (final o in options)
            ListTile(
              leading: Icon(
                o == s.reminderKm
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: o == s.reminderKm ? AppColors.orange : null,
              ),
              title: Text('${fmtNum(o)} كم'),
              onTap: () => Navigator.pop(context, o),
            ),
        ],
      ),
    );
    if (picked != null) {
      await s.setReminderKm(picked);
      StorageService.instance.refreshUi();
      if (context.mounted) showSnack(context, 'تم تحديث حدّ التنبيه');
    }
  }

  Future<void> _editCar(BuildContext context) async {
    final car = StorageService.instance.car;
    final nameCtl = TextEditingController(text: car.name);
    final kmCtl = TextEditingController(text: car.odometer.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('بيانات السيارة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              decoration: const InputDecoration(labelText: 'اسم السيارة'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: kmCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'قراءة العداد (كم)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await StorageService.instance.saveCar(
        Car(
          name: nameCtl.text.trim().isEmpty ? 'سيارتي' : nameCtl.text.trim(),
          odometer: int.tryParse(kmCtl.text) ?? car.odometer,
        ),
      );
      if (context.mounted) showSnack(context, 'تم حفظ بيانات السيارة');
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final oldCtl = TextEditingController();
    final newCtl = TextEditingController();
    final confCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: oldCtl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور الحالية',
                ),
                validator: (v) => (v ?? '').isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newCtl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                ),
                validator: validatePassword,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confCtl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'تأكيد الجديدة'),
                validator: (v) =>
                    v != newCtl.text ? 'كلمتا المرور غير متطابقتين' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final email = await AuthService.currentEmail();
    final s = StorageService.instance;
    final user = email == null ? null : await s.login(email, oldCtl.text);
    if (!context.mounted) return;
    if (user == null) {
      showSnack(context, 'كلمة المرور الحالية غير صحيحة', error: true);
      return;
    }
    await s.resetPassword(email!, newCtl.text);
    if (context.mounted) showSnack(context, 'تم تغيير كلمة المرور بنجاح');
  }
}

/// اختيار وضع المظهر بثلاث شرائح
class _ThemeModeTile extends StatelessWidget {
  final SettingsService settings;
  const _ThemeModeTile({required this.settings});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('وضع المظهر', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SegmentedButton<ThemeMode>(
          key: const Key('theme_mode_segments'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text('داكن'),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text('فاتح'),
            ),
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.phone_android),
              label: Text('النظام'),
            ),
          ],
          selected: {settings.themeMode},
          onSelectionChanged: (s) => settings.setThemeMode(s.first),
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, right: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.orange),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.orange,
              ),
            ),
          ],
        ),
      ),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    ],
  );
}
