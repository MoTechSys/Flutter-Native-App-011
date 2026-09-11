// ============================================================
// CarCare - سجل السيارة الذكي
// إدارة تغيير الزيت، الإطارات، البطارية، الصيانة الدورية،
// استهلاك الوقود وتاريخ الإصلاحات
//
// إعداد الطالب: عبد الجبار رمزي
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/auth/login_screen.dart';
import 'screens/fuel_screen.dart';
import 'screens/home_screen.dart';
import 'screens/license_screen.dart';
import 'screens/maintenance_screen.dart';
import 'screens/repairs_screen.dart';
import 'services/auth_service.dart';
import 'services/license_service.dart';
import 'services/settings_service.dart';
import 'services/storage_service.dart';
import 'theme.dart';
import 'widgets/app_drawer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.load();
  await StorageService.instance.init();
  SettingsService.instance.onThemeChanged = StorageService.instance.refreshUi;
  runApp(const CarCareApp());
}

class CarCareApp extends StatelessWidget {
  const CarCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        // نحسم الوضع الفعلي هنا (داكن/فاتح/النظام) ونبني ثيماً واحداً مطابقاً
        // حتى تتفق ألوان AppColors مع ThemeData في كل إعادة بناء.
        final dark = settings.isDark(context);
        return MaterialApp(
          title: 'CarCare - سجل السيارة',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(dark: dark),
          darkTheme: buildTheme(dark: dark),
          themeMode: ThemeMode.light,
          // اللغة العربية و RTL
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: const _Gate(),
        );
      },
    );
  }
}

/// بوابة التحقق من الترخيص قبل فتح التطبيق
class _Gate extends StatefulWidget {
  const _Gate();
  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  LicenseGateResult? _gate;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final gate = await LicenseGate.evaluate();
    final logged = await AuthService.isLoggedIn();
    if (mounted) {
      setState(() {
        _gate = gate;
        _loggedIn = logged;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_gate == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_car, size: 72, color: AppColors.orange),
              SizedBox(height: 16),
              Text(
                'CarCare',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(color: AppColors.orange),
            ],
          ),
        ),
      );
    }
    if (!_gate!.canEnter) {
      return LicenseScreen(
        gate: _gate!,
        onUnlocked: () =>
            setState(() => _gate = const LicenseGateResult(LicenseStatus.open)),
      );
    }
    if (!_loggedIn) {
      return LoginScreen(onLoggedIn: () => setState(() => _loggedIn = true));
    }
    return MainShell(onLogout: () => setState(() => _loggedIn = false));
  }
}

/// الهيكل الرئيسي مع شريط التنقل السفلي
class MainShell extends StatefulWidget {
  final VoidCallback onLogout;
  const MainShell({super.key, required this.onLogout});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onNavigate: (i) => setState(() => _index = i),
        onLogout: widget.onLogout,
      ),
      const MaintenanceScreen(),
      const FuelScreen(),
      const RepairsScreen(),
    ];
    return Scaffold(
      drawer: AppDrawer(
        currentIndex: _index,
        onNavigate: (i) => setState(() => _index = i),
        onLogout: widget.onLogout,
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'الصيانة',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_gas_station_outlined),
            selectedIcon: Icon(Icons.local_gas_station),
            label: 'الوقود',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'الإصلاحات',
          ),
        ],
      ),
    );
  }
}
