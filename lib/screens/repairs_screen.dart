// ============================================================
// CarCare - شاشة تاريخ الإصلاحات
// ============================================================

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'record_details_screen.dart';

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
                        const Icon(
                          Icons.handyman,
                          size: 36,
                          color: AppColors.red,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fmtMoney(s.totalRepairCost),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'إجمالي تكلفة الإصلاحات (${list.length} إصلاح)',
                                style: const TextStyle(
                                  color: AppColors.textDim,
                                  fontSize: 12,
                                ),
                              ),
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
                          icon: Icons.build,
                          text: 'لا توجد إصلاحات مسجلة',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                          itemCount: list.length,
                          itemBuilder: (_, i) => _TimelineItem(
                            record: list[i],
                            isLast: i == list.length - 1,
                            onEdit: () => _showAdd(context, existing: list[i]),
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

  Future<void> _showAdd(BuildContext context, {RepairRecord? existing}) async {
    final s = StorageService.instance;
    final isEdit = existing != null;
    var date = existing?.date ?? DateTime.now();
    final titleCtl = TextEditingController(text: existing?.title ?? '');
    final shopCtl = TextEditingController(text: existing?.workshop ?? '');
    final kmCtl = TextEditingController(
      text: (existing?.odometer ?? s.car.odometer).toString(),
    );
    final costCtl = TextEditingController(
      text: existing?.cost.toString() ?? '',
    );
    final notesCtl = TextEditingController(text: existing?.notes ?? '');
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
                    isEdit ? 'تعديل إصلاح' : 'إضافة إصلاح',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: titleCtl,
                    decoration: const InputDecoration(
                      labelText: 'نوع الإصلاح (مثال: تغيير فحمات الفرامل)',
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  DateField(
                    value: date,
                    onChanged: (d) => setState(() => date = d),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: kmCtl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'العداد (كم)',
                          ),
                          validator: (v) =>
                              int.tryParse(v ?? '') == null ? 'رقم' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: costCtl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'التكلفة (ر.س)',
                          ),
                          validator: (v) =>
                              double.tryParse(v ?? '') == null ? 'رقم' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: shopCtl,
                    decoration: const InputDecoration(
                      labelText: 'الورشة (اختياري)',
                    ),
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
                      final rec = RepairRecord(
                        id: existing?.id ?? '',
                        date: date,
                        odometer: int.parse(kmCtl.text),
                        title: titleCtl.text.trim(),
                        workshop: shopCtl.text.trim(),
                        cost: double.parse(costCtl.text),
                        notes: notesCtl.text.trim(),
                      );
                      if (isEdit) {
                        await s.updateRepair(rec);
                      } else {
                        await s.addRepair(rec);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        showSnack(
                          context,
                          isEdit ? 'تم تعديل الإصلاح' : 'تمت إضافة الإصلاح',
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

/// عنصر في الخط الزمني
class _TimelineItem extends StatelessWidget {
  final RepairRecord record;
  final bool isLast;
  final VoidCallback onEdit;
  const _TimelineItem({
    required this.record,
    required this.isLast,
    required this.onEdit,
  });

  void _openDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecordDetailsScreen(
          title: record.title,
          color: AppColors.orange,
          icon: Icons.build,
          fields: {
            'التاريخ': fmtDate(record.date),
            'قراءة العداد': '${fmtNum(record.odometer)} كم',
            'الورشة': record.workshop.isEmpty ? '—' : record.workshop,
            'التكلفة': fmtMoney(record.cost),
            'ملاحظات': record.notes.isEmpty ? '—' : record.notes,
          },
          onEdit: onEdit,
          onDelete: () => StorageService.instance.deleteRepair(record.id),
        ),
      ),
    );
  }

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
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: Colors.white12)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(
                child: InkWell(
                  onTap: () => _openDetails(context),
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                fmtMoney(record.cost),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.teal,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'تعديل',
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: AppColors.teal,
                                size: 20,
                              ),
                              onPressed: onEdit,
                            ),
                            const SizedBox(width: 14),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'حذف',
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.red,
                                size: 20,
                              ),
                              onPressed: () async {
                                if (await confirmDelete(context)) {
                                  await StorageService.instance.deleteRepair(
                                    record.id,
                                  );
                                  if (context.mounted) {
                                    showSnack(context, 'تم حذف الإصلاح');
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${fmtDate(record.date)} • ${fmtNum(record.odometer)} كم${record.workshop.isNotEmpty ? ' • ${record.workshop}' : ''}',
                          style: const TextStyle(
                            color: AppColors.textDim,
                            fontSize: 12,
                          ),
                        ),
                        if (record.notes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              record.notes,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                      ],
                    ),
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
