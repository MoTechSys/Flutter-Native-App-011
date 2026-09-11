// ============================================================
// CarCare - شاشة الصيانة (زيت / إطارات / بطارية / دورية)
// ============================================================

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'record_details_screen.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});
  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: MaintenanceType.values.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: const Text('الصيانة'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: false,
          labelStyle: const TextStyle(fontSize: 12),
          tabs: MaintenanceType.values
              .map((t) => Tab(text: t.label, icon: Icon(typeIcon(t), size: 18)))
              .toList(),
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tab,
          children: MaintenanceType.values
              .map((t) => _TypeTab(type: t))
              .toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            showAddMaintenance(context, MaintenanceType.values[_tab.index]),
        icon: const Icon(Icons.add),
        label: const Text('إضافة'),
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  final MaintenanceType type;
  const _TypeTab({required this.type});

  @override
  Widget build(BuildContext context) {
    final s = StorageService.instance;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        final list = s.maintenanceOf(type);
        final last = s.lastOf(type);
        final color = typeColor(type);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            // كارت الحالة الحالية
            GradientCard(
              color: color,
              child: Row(
                children: [
                  ProgressRing(
                    progress: s.progressOf(type),
                    color: color,
                    icon: typeIcon(type),
                    size: 70,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: last == null
                        ? Text(
                            'لا يوجد سجل بعد.\nأضف أول صيانة للبدء.',
                            style: TextStyle(color: AppColors.textDim),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الحالة: ${statusLabel(s.statusOf(type))}',
                                style: TextStyle(
                                  color: statusColor(s.statusOf(type)),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'آخر مرة: ${fmtDate(last.date)} عند ${fmtNum(last.odometer)} كم',
                                style: const TextStyle(fontSize: 13),
                              ),
                              Text(
                                'القادمة: ${fmtNum(last.nextKm)} كم أو ${fmtDate(last.nextDate)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textDim,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'السجل (${list.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (list.isEmpty)
              const SizedBox(
                height: 200,
                child: EmptyState(icon: Icons.history, text: 'لا توجد سجلات'),
              ),
            ...list.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecordDetailsScreen(
                          title: type.label,
                          color: color,
                          icon: typeIcon(type),
                          fields: {
                            'التاريخ': fmtDate(r.date),
                            'قراءة العداد': '${fmtNum(r.odometer)} كم',
                            'تتكرر كل':
                                '${fmtNum(r.intervalKm)} كم / ${r.intervalDays} يوم',
                            'الصيانة القادمة':
                                '${fmtNum(r.nextKm)} كم أو ${fmtDate(r.nextDate)}',
                            'التكلفة': fmtMoney(r.cost),
                            'ملاحظات': r.notes.isEmpty ? '—' : r.notes,
                          },
                          onEdit: () =>
                              showAddMaintenance(context, type, existing: r),
                          onDelete: () => s.deleteMaintenance(r.id),
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.2),
                            child: Icon(typeIcon(type), color: color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${fmtDate(r.date)} • ${fmtNum(r.odometer)} كم',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'كل ${fmtNum(r.intervalKm)} كم / ${r.intervalDays} يوم',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textDim,
                                  ),
                                ),
                                if (r.notes.isNotEmpty)
                                  Text(
                                    r.notes,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                fmtMoney(r.cost),
                                style: const TextStyle(
                                  color: AppColors.teal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'تعديل',
                                    onPressed: () => showAddMaintenance(
                                      context,
                                      type,
                                      existing: r,
                                    ),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      color: AppColors.teal,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'حذف',
                                    onPressed: () async {
                                      if (await confirmDelete(context)) {
                                        await s.deleteMaintenance(r.id);
                                        if (context.mounted) {
                                          showSnack(context, 'تم حذف السجل');
                                        }
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: AppColors.red,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// نموذج إضافة صيانة (Bottom Sheet)
Future<void> showAddMaintenance(
  BuildContext context,
  MaintenanceType initial, {
  MaintenanceRecord? existing,
}) async {
  final s = StorageService.instance;
  final isEdit = existing != null;
  var type = existing?.type ?? initial;
  var date = existing?.date ?? DateTime.now();
  final kmCtl = TextEditingController(
    text: (existing?.odometer ?? s.car.odometer).toString(),
  );
  final intKmCtl = TextEditingController(
    text: (existing?.intervalKm ?? initial.defaultIntervalKm).toString(),
  );
  final intDaysCtl = TextEditingController(
    text: (existing?.intervalDays ?? initial.defaultIntervalDays).toString(),
  );
  final costCtl = TextEditingController(
    text: existing == null ? '' : existing.cost.toString(),
  );
  final notesCtl = TextEditingController(text: existing?.notes ?? '');
  final formKey = GlobalKey<FormState>();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
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
                  isEdit ? 'تعديل سجل صيانة' : 'إضافة سجل صيانة',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<MaintenanceType>(
                  initialValue: type,
                  dropdownColor: AppColors.cardLight,
                  decoration: const InputDecoration(labelText: 'النوع'),
                  items: MaintenanceType.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Row(
                            children: [
                              Icon(typeIcon(t), color: typeColor(t), size: 18),
                              const SizedBox(width: 8),
                              Text(t.label),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      type = v;
                      intKmCtl.text = v.defaultIntervalKm.toString();
                      intDaysCtl.text = v.defaultIntervalDays.toString();
                    });
                  },
                ),
                const SizedBox(height: 12),
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
                        controller: intKmCtl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'تتكرر كل (كم)',
                        ),
                        validator: (v) =>
                            int.tryParse(v ?? '') == null ? 'رقم' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: intDaysCtl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'تتكرر كل (يوم)',
                        ),
                        validator: (v) =>
                            int.tryParse(v ?? '') == null ? 'رقم' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: costCtl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'التكلفة (ر.س)'),
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
                    final rec = MaintenanceRecord(
                      id: existing?.id ?? '',
                      type: type,
                      date: date,
                      odometer: int.parse(kmCtl.text),
                      intervalKm: int.parse(intKmCtl.text),
                      intervalDays: int.parse(intDaysCtl.text),
                      cost: double.tryParse(costCtl.text) ?? 0,
                      notes: notesCtl.text.trim(),
                    );
                    if (isEdit) {
                      await s.updateMaintenance(rec);
                    } else {
                      await s.addMaintenance(rec);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      showSnack(
                        context,
                        isEdit ? 'تم تعديل السجل بنجاح' : 'تمت الإضافة بنجاح',
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
