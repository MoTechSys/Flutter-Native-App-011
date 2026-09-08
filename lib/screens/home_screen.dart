// ============================================================
// CarCare - الشاشة الرئيسية (لوحة القيادة)
// ============================================================

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'about_screen.dart';

class HomeScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final s = StorageService.instance;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        final car = s.car;
        return Scaffold(
          appBar: AppBar(
            title: const Text('CarCare - سجل السيارة'),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AboutScreen())),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _CarCard(car: car),
                const SizedBox(height: 20),
                const _SectionTitle('حالة السيارة'),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.05,
                  children: [
                    for (final t in MaintenanceType.values)
                      _StatusCard(type: t, onTap: () => onNavigate(1)),
                  ],
                ),
                const SizedBox(height: 20),
                const _SectionTitle('ملخص سريع'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.local_gas_station,
                        color: AppColors.purple,
                        label: 'معدل الاستهلاك',
                        value: s.avgKmPerLiter > 0
                            ? '${s.avgKmPerLiter.toStringAsFixed(1)} كم/لتر'
                            : '—',
                        onTap: () => onNavigate(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.handyman,
                        color: AppColors.red,
                        label: 'تكلفة الإصلاحات',
                        value: fmtMoney(s.totalRepairCost),
                        onTap: () => onNavigate(3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _SectionTitle('آخر الإصلاحات'),
                const SizedBox(height: 12),
                if (s.repairs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text('لا توجد إصلاحات مسجلة',
                          style: TextStyle(color: AppColors.textDim)),
                    ),
                  )
                else
                  ...s.repairs.take(3).map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: ListTile(
                            leading: const Icon(Icons.build,
                                color: AppColors.orange),
                            title: Text(r.title),
                            subtitle: Text(
                                '${fmtDate(r.date)} • ${fmtNum(r.odometer)} كم'),
                            trailing: Text(fmtMoney(r.cost),
                                style: const TextStyle(
                                    color: AppColors.teal,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      )),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold));
}

/// كارت بيانات السيارة مع تعديل العداد
class _CarCard extends StatelessWidget {
  final Car car;
  const _CarCard({required this.car});

  Future<void> _edit(BuildContext context) async {
    final nameCtl = TextEditingController(text: car.name);
    final kmCtl = TextEditingController(text: car.odometer.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('بيانات السيارة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtl,
                decoration: const InputDecoration(labelText: 'اسم السيارة')),
            const SizedBox(height: 12),
            TextField(
                controller: kmCtl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'قراءة العداد (كم)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true) {
      await StorageService.instance.saveCar(Car(
        name: nameCtl.text.trim().isEmpty ? 'سيارتي' : nameCtl.text.trim(),
        odometer: int.tryParse(kmCtl.text) ?? car.odometer,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      color: AppColors.teal,
      onTap: () => _edit(context),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.directions_car,
                size: 40, color: AppColors.teal),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(car.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('${fmtNum(car.odometer)} كم',
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.teal)),
                const Text('قراءة العداد الحالية',
                    style:
                        TextStyle(color: AppColors.textDim, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.edit, color: AppColors.textDim, size: 20),
        ],
      ),
    );
  }
}

/// كارت حالة (زيت / إطارات / بطارية / دورية) بحلقة تقدّم
class _StatusCard extends StatelessWidget {
  final MaintenanceType type;
  final VoidCallback onTap;
  const _StatusCard({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = StorageService.instance;
    final status = s.statusOf(type);
    final last = s.lastOf(type);
    final color = typeColor(type);
    String sub;
    if (last == null) {
      sub = 'لم يُسجّل بعد';
    } else {
      final left = last.nextKm - s.car.odometer;
      sub = left > 0 ? 'متبقي ${fmtNum(left)} كم' : 'متأخر ${fmtNum(-left)} كم';
    }
    return GradientCard(
      color: color,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ProgressRing(
                  progress: s.progressOf(type),
                  color: color,
                  icon: typeIcon(type),
                  size: 52),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor(status).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statusLabel(status),
                    style: TextStyle(
                        color: statusColor(status),
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Spacer(),
          Text(type.label,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 2),
          Text(sub,
              style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _MiniStat(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      color: color,
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(label,
              style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
        ],
      ),
    );
  }
}
