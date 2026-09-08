// ============================================================
// CarCare - شاشة تاريخ الإصلاحات
// ============================================================

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class RepairsScreen extends StatelessWidget {
  const RepairsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StorageService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('تاريخ الإصلاحات')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: s,
          builder: (context, _) {
            final list = s.repairs;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GradientCard(
                    color: AppColors.red,
                    child: Row(
                      children: [
                        const Icon(Icons.handyman,
                            size: 36, color: AppColors.red),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fmtMoney(s.totalRepairCost),
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900)),
                              Text('إجمالي تكلفة الإصلاحات (${list.length} إصلاح)',
                                  style: const TextStyle(
                                      color: AppColors.textDim,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? const EmptyState(
                          icon: Icons.build, text: 'لا توجد إصلاحات مسجلة')
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                          itemCount: list.length,
                          itemBuilder: (_, i) => _TimelineItem(
                            record: list[i],
                            isLast: i == list.length - 1,
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
        label: const Text('إصلاح'),
      ),
    );
  }

  Future<void> _showAdd(BuildContext context) async {
    final s = StorageService.instance;
    var date = DateTime.now();
    final titleCtl = TextEditingController();
    final shopCtl = TextEditingController();
    final kmCtl = TextEditingController(text: s.car.odometer.toString());
    final costCtl = TextEditingController();
    final notesCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('إضافة إصلاح',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: titleCtl,
                    decoration: const InputDecoration(
                        labelText: 'نوع الإصلاح (مثال: تغيير فحمات الفرامل)'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  DateField(
                      value: date,
                      onChanged: (d) => setState(() => date = d)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: kmCtl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'العداد (كم)'),
                        validator: (v) =>
                            int.tryParse(v ?? '') == null ? 'رقم' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: costCtl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'التكلفة (ر.س)'),
                        validator: (v) =>
                            double.tryParse(v ?? '') == null ? 'رقم' : null,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: shopCtl,
                    decoration:
                        const InputDecoration(labelText: 'الورشة (اختياري)'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtl,
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ'),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      await s.addRepair(RepairRecord(
                        id: '',
                        date: date,
                        odometer: int.parse(kmCtl.text),
                        title: titleCtl.text.trim(),
                        workshop: shopCtl.text.trim(),
                        cost: double.parse(costCtl.text),
                        notes: notesCtl.text.trim(),
                      ));
                      if (ctx.mounted) Navigator.pop(ctx);
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

/// عنصر في الخط الزمني
class _TimelineItem extends StatelessWidget {
  final RepairRecord record;
  final bool isLast;
  const _TimelineItem({required this.record, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                    color: AppColors.orange, shape: BoxShape.circle),
              ),
              if (!isLast)
                Expanded(
                    child: Container(width: 2, color: Colors.white12)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(record.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ),
                          Text(fmtMoney(record.cost),
                              style: const TextStyle(
                                  color: AppColors.teal,
                                  fontWeight: FontWeight.bold)),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.red, size: 20),
                            onPressed: () async {
                              if (await confirmDelete(context)) {
                                StorageService.instance
                                    .deleteRepair(record.id);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${fmtDate(record.date)} • ${fmtNum(record.odometer)} كم${record.workshop.isNotEmpty ? ' • ${record.workshop}' : ''}',
                        style: const TextStyle(
                            color: AppColors.textDim, fontSize: 12),
                      ),
                      if (record.notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(record.notes,
                              style: const TextStyle(fontSize: 13)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
