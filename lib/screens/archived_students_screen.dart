import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/student_provider.dart';
import '../theme/app_theme.dart';
import '../utils/bn.dart';
import '../widgets/common/ui_kit.dart';
import 'student_detail_screen.dart';

class ArchivedStudentsScreen extends StatelessWidget {
  const ArchivedStudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final archived = context.watch<StudentProvider>().archivedStudents;

    return Scaffold(
      appBar: AppBar(title: const Text('আর্কাইভ করা ছাত্ররা')),
      body: archived.isEmpty
          ? const EmptyState(
              icon: Icons.archive_outlined,
              title: 'কোনো ছাত্র আর্কাইভ করা নেই',
              message: 'কেউ তুইশন ছেড়ে দিলে তাকে আর্কাইভ করে রাখলে ডেটা থেকে যাবে।',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                40,
              ),
              itemCount: archived.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final student = archived[index];
                return AppCard(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentDetailScreen(studentId: student.id),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: AppRadius.smAll,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          student.name.trim().isNotEmpty
                              ? student.name.trim()[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: AppColors.inkFaint,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                color: AppColors.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              student.archivedDate != null
                                  ? '${student.className}  ·  ছেড়েছে ${Bn.dateShort(student.archivedDate!)}'
                                  : '${student.className}  ·  ${student.subject}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.inkFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onSelected: (value) async {
                          final provider = context.read<StudentProvider>();
                          if (value == 'restore') {
                            await provider.unarchiveStudent(student.id);
                            if (context.mounted) {
                              showSnack(context, '${student.name} আবার সক্রিয় করা হয়েছে');
                            }
                          } else if (value == 'delete') {
                            final ok = await confirmDialog(
                              context,
                              title: 'স্থায়ীভাবে ডিলিট করবে?',
                              message: '${student.name} এর প্রোফাইল সহ সব '
                                  'attendance/fee/note/syllabus ডেটা স্থায়ীভাবে মুছে যাবে, '
                                  'ফেরত আনা যাবে না।',
                              confirmLabel: 'ডিলিট',
                              destructive: true,
                            );
                            if (ok) await provider.deleteStudent(student.id);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'restore',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.restore, size: 19, color: AppColors.primary),
                              title: Text('আবার সক্রিয় করো'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.delete_outline,
                                size: 19,
                                color: AppColors.danger,
                              ),
                              title: Text(
                                'স্থায়ীভাবে ডিলিট',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
