import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/student.dart';
import '../../models/progress_note.dart';
import '../../theme/app_theme.dart';
import '../../utils/bn.dart';
import '../common/ui_kit.dart';

class StudentNotesView extends StatelessWidget {
  final Student profile;
  const StudentNotesView({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('notes')
          .where('studentId', isEqualTo: profile.id)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final notes = snap.data!.docs
            .map((d) => ProgressNote.fromJson(d.id, d.data()))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        if (notes.isEmpty) {
          return const EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'এখনো কোনো নোট নেই',
            message: 'টিউটর ক্লাসের CW/HW লিখলে এখানে দেখা যাবে।',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 40),
          itemCount: notes.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) => _StudentNoteCard(note: notes[index]),
        );
      },
    );
  }
}

class _StudentNoteCard extends StatelessWidget {
  final ProgressNote note;
  const _StudentNoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final hasMarks = note.marks != null && note.outOf != null && note.outOf! > 0;
    final percent = hasMarks ? note.marks! / note.outOf! : null;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: AppRadius.smAll,
                ),
                child: Column(
                  children: [
                    Text(
                      Bn.number(note.date.day),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.primary,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      Bn.monthName(note.date.month, short: true),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.primary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.topic,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        height: 1.4,
                      ),
                    ),
                    Text(
                      Bn.weekdayFull(note.date),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint),
                    ),
                  ],
                ),
              ),
              if (hasMarks) ...[
                const SizedBox(width: AppSpacing.sm),
                StatusPill(
                  label: '${Bn.number(note.marks!)}/${Bn.number(note.outOf!)}',
                  color: percent! >= 0.5 ? AppColors.success : AppColors.danger,
                  background: percent >= 0.5 ? AppColors.successBg : AppColors.dangerBg,
                  fontSize: 12,
                ),
              ],
            ],
          ),
          if (note.homework.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: AppRadius.smAll,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.assignment_outlined,
                      size: 15,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'হোমওয়ার্ক',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                            color: AppColors.warning,
                            height: 1.4,
                          ),
                        ),
                        Text(
                          note.homework,
                          style: const TextStyle(fontSize: 12.5, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (note.remarks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.chat_bubble_outline, size: 13, color: AppColors.inkFaint),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    note.remarks,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.inkMuted,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
