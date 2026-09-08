// ============================================================
// CarCare - صفحة تفاصيل سجل (تستقبل البيانات من الصفحة السابقة)
// ============================================================

import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/common.dart';

class RecordDetailsScreen extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final Map<String, String> fields;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  const RecordDetailsScreen({
    super.key,
    required this.title,
    required this.color,
    required this.icon,
    required this.fields,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل السجل')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // رأس الصفحة باستخدام Stack
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.5), AppColors.card],
                    ),
                  ),
                ),
                Column(
                  children: [
                    Icon(icon, size: 56, color: color),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              child: Column(
                children: [
                  for (final e in fields.entries) ...[
                    ListTile(
                      title: Text(
                        e.key,
                        style: const TextStyle(
                          color: AppColors.textDim,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        e.value,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (e.key != fields.keys.last)
                      const Divider(height: 1, color: Colors.white12),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onEdit();
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('تعديل'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                    ),
                    onPressed: () async {
                      if (await confirmDelete(context)) {
                        await onDelete();
                        if (context.mounted) {
                          Navigator.pop(context);
                          showSnack(context, 'تم حذف السجل');
                        }
                      }
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('حذف'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
