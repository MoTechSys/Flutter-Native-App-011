// ============================================================
// CarCare - شاشة استهلاك الوقود
// ============================================================

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'record_details_screen.dart';

class FuelScreen extends StatelessWidget {
  const FuelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StorageService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('استهلاك الوقود')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: s,
          builder: (context, _) {
            final list = s.fuel;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                // كارت الإحصائيات
                GradientCard(
                  color: AppColors.purple,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.local_gas_station,
                        size: 40,
                        color: AppColors.purple,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.avgKmPerLiter > 0
                            ? s.avgKmPerLiter.toStringAsFixed(1)
                            : '—',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: AppColors.purple,
                        ),
                      ),
                      const Text(
                        'كم / لتر (متوسط الاستهلاك)',
                        style: TextStyle(color: AppColors.textDim),
                      ),
                      if (list.length < 2)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'أضف تعبئتين على الأقل لحساب المعدل',
                            style: TextStyle(
                              color: AppColors.yellow,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const Divider(height: 28, color: Colors.white12),
                      Row(
                        children: [
                          _Stat('هذا الشهر', fmtMoney(s.thisMonthFuelCost)),
                          _Stat('الإجمالي', fmtMoney(s.totalFuelCost)),
                          _Stat('التعبئات', '${list.length}'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'سجل التعبئات',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                if (list.isEmpty)
                  const SizedBox(
                    height: 200,
                    child: EmptyState(
                      icon: Icons.local_gas_station,
                      text: 'لا توجد تعبئات مسجلة',
                    ),
                  ),
                ...list.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecordDetailsScreen(
                              title: 'تعبئة وقود',
                              color: AppColors.purple,
                              icon: Icons.local_gas_station,
                              fields: {
                                'التاريخ': fmtDate(r.date),
                                'قراءة العداد': '${fmtNum(r.odometer)} كم',
                                'الكمية': '${r.liters.toStringAsFixed(1)} لتر',
                                'المبلغ الكلي': fmtMoney(r.totalPrice),
                                'سعر اللتر':
                                    '${r.pricePerLiter.toStringAsFixed(2)} ر.س',
                              },
                              onEdit: () => _showAdd(context, existing: r),
                              onDelete: () => s.deleteFuel(r.id),
                            ),
                          ),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.purple.withValues(
                            alpha: 0.2,
                          ),
                          child: const Icon(
                            Icons.local_gas_station,
                            color: AppColors.purple,
                            size: 20,
                          ),
                        ),
                        contentPadding: const EdgeInsetsDirectional.only(
                          start: 12,
                          end: 4,
                        ),
                        title: Text(
                          '${r.liters.toStringAsFixed(1)} لتر • ${fmtMoney(r.totalPrice)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${fmtDate(r.date)} • ${fmtNum(r.odometer)} كم\n${r.pricePerLiter.toStringAsFixed(2)} ر.س/لتر',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textDim,
                          ),
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: AppColors.teal,
                              ),
                              onPressed: () => _showAdd(context, existing: r),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.red,
                              ),
                              onPressed: () async {
                                if (await confirmDelete(context)) {
                                  await s.deleteFuel(r.id);
                                  if (context.mounted) {
                                    showSnack(context, 'تم حذف التعبئة');
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAdd(context),
        icon: const Icon(Icons.add),
        label: const Text('تعبئة'),
      ),
    );
  }

  Future<void> _showAdd(BuildContext context, {FuelRecord? existing}) async {
    final s = StorageService.instance;
    final isEdit = existing != null;
    var date = existing?.date ?? DateTime.now();
    final kmCtl = TextEditingController(
      text: (existing?.odometer ?? s.car.odometer).toString(),
    );
    final litersCtl = TextEditingController(
      text: existing?.liters.toString() ?? '',
    );
    final priceCtl = TextEditingController(
      text: existing?.totalPrice.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEdit ? 'تعديل تعبئة وقود' : 'إضافة تعبئة وقود',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DateField(
                    value: date,
                    onChanged: (d) => setState(() => date = d),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: kmCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'قراءة العداد (كم)',
                    ),
                    validator: (v) => int.tryParse(v ?? '') == null
                        ? 'أدخل رقماً صحيحاً'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: litersCtl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'اللترات',
                          ),
                          validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                              ? 'رقم'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: priceCtl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'المبلغ الكلي (ر.س)',
                          ),
                          validator: (v) =>
                              double.tryParse(v ?? '') == null ? 'رقم' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ'),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final rec = FuelRecord(
                        id: existing?.id ?? '',
                        date: date,
                        odometer: int.parse(kmCtl.text),
                        liters: double.parse(litersCtl.text),
                        totalPrice: double.parse(priceCtl.text),
                      );
                      if (isEdit) {
                        await s.updateFuel(rec);
                      } else {
                        await s.addFuel(rec);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        showSnack(
                          context,
                          isEdit ? 'تم تعديل التعبئة' : 'تمت إضافة التعبئة',
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.textDim, fontSize: 11),
        ),
      ],
    ),
  );
}
