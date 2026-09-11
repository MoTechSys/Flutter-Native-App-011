// ============================================================
// CarCare - القائمة الجانبية (Drawer)
//   رأس بالمستخدم والسيارة · التنقل للتبويبات · الإعدادات · تبديل داكن/فاتح
//   · حول التطبيق · تسجيل الخروج
// ============================================================

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../screens/about_screen.dart';
import '../screens/settings_screen.dart';

class AppDrawer extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onNavigate;
  final VoidCallback onLogout;
  const AppDrawer({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
    required this.onLogout,
  });

  static const _destinations = [
    (Icons.dashboard_outlined, Icons.dashboard, 'الرئيسية'),
    (Icons.build_outlined, Icons.build, 'الصيانة'),
    (Icons.local_gas_station_outlined, Icons.local_gas_station, 'الوقود'),
    (Icons.history_outlined, Icons.history, 'الإصلاحات'),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (var i = 0; i < _destinations.length; i++)
                    ListTile(
                      leading: Icon(
                        i == currentIndex
                            ? _destinations[i].$2
                            : _destinations[i].$1,
                        color: i == currentIndex ? AppColors.orange : null,
                      ),
                      title: Text(
                        _destinations[i].$3,
                        style: TextStyle(
                          fontWeight: i == currentIndex
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: i == currentIndex ? AppColors.orange : null,
                        ),
                      ),
                      selected: i == currentIndex,
                      selectedTileColor: AppColors.orange.withValues(
                        alpha: 0.12,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        onNavigate(i);
                      },
                    ),
                  const Divider(),
                  AnimatedBuilder(
                    animation: settings,
                    builder: (context, _) {
                      final dark = settings.isDark(context);
                      return SwitchListTile(
                        key: const Key('drawer_dark_switch'),
                        secondary: Icon(
                          dark ? Icons.dark_mode : Icons.light_mode,
                          color: dark ? AppColors.teal : AppColors.yellow,
                        ),
                        title: const Text('الوضع الداكن'),
                        subtitle: Text(dark ? 'مفعّل' : 'الوضع الفاتح'),
                        value: dark,
                        onChanged: (_) => settings.toggleDark(context),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('الإعدادات'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(onLogout: onLogout),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('حول التطبيق'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.red),
              title: const Text(
                'تسجيل الخروج',
                style: TextStyle(color: AppColors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                confirmLogout(context, onLogout);
              },
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'CarCare 1.4.0 (build 8)',
                style: TextStyle(color: AppColors.textDim, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: StorageService.instance,
      builder: (context, _) {
        final car = StorageService.instance.car;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                AppColors.orange.withValues(alpha: 0.35),
                AppColors.card,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'CarCare',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FutureBuilder<String>(
                future: AuthService.currentName(),
                builder: (context, snap) => Text(
                  snap.data ?? '…',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${car.name} • ${fmtNum(car.odometer)} كم',
                style: TextStyle(color: AppColors.textDim, fontSize: 13),
              ),
            ],
          ),
        );
      },
    );
  }
}
