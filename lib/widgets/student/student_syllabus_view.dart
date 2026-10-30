import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/student.dart';
import '../../models/syllabus_item.dart';
import '../../theme/app_theme.dart';
import '../../utils/bn.dart';
import '../common/ui_kit.dart';

class StudentSyllabusView extends StatelessWidget {
  final Student profile;
  const StudentSyllabusView({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('syllabus')
          .where('studentId', isEqualTo: profile.id)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data!.docs
            .map((d) => SyllabusItem.fromJson(d.id, d.data()))
            .toList()
          ..sort((a, b) {
            if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
            return a.createdAt.compareTo(b.createdAt);
          });

        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.checklist_outlined,
            title: 'এখনো কোনো টপিক যোগ করা হয়নি',
            message: 'টিউটর সিলেবাস যোগ করলে অগ্রগতি এখানে দেখা যাবে।',
          );
        }

        final done = items.where((i) => i.isDone).length;
        final progress = done / items.length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 40),
          children: [
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'সিলেবাস অগ্রগতি',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                      ),
                      Text(
                        '${Bn.number(done)} / ${Bn.number(items.length)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ThinProgressBar(value: progress, height: 8),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    progress >= 1
                        ? 'সব টপিক শেষ 🎉'
                        : '${Bn.number((progress * 100).round())}% সম্পন্ন, '
                            'বাকি ${Bn.number(items.length - done)} টি',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            for (final item in items) ...[
              _StudentSyllabusCard(item: item),
              const SizedBox(height: AppSpacing.sm + 2),
            ],
          ],
        );
      },
    );
  }
}

class _StudentSyllabusCard extends StatelessWidget {
  final SyllabusItem item;
  const _StudentSyllabusCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: item.isDone ? AppColors.surfaceMuted : AppColors.surface,
      elevated: !item.isDone,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.isDone ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: item.isDone ? AppColors.primary : AppColors.inkFaint,
                  width: 1.8,
                ),
              ),
              child: item.isDone
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.4,
                    decoration: item.isDone ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.inkFaint,
                    color: item.isDone ? AppColors.inkFaint : AppColors.ink,
                  ),
                ),
                if (item.materialNote.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.link, size: 13, color: AppColors.inkFaint),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          item.materialNote,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkFaint,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
