import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/exam.dart';
import '../../models/student.dart';
import '../../theme/app_theme.dart';
import '../../utils/bn.dart';
import '../common/ui_kit.dart';
import '../exam_tab.dart' show ExamCard, countdownLabel;

/// ছাত্রের পরীক্ষার রুটিন — শুধু দেখার, বদলানোর কিছু নেই।
/// কার্ডটা শিক্ষকের দিকের সাথে একই ([ExamCard]), তাই দুই পাশে চেহারা মেলে।
class StudentExamView extends StatelessWidget {
  final Student profile;
  const StudentExamView({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('exams')
          .where('studentId', isEqualTo: profile.id)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final exams = snap.data!.docs.map((d) => Exam.fromJson(d.id, d.data())).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

        if (exams.isEmpty) {
          return const EmptyState(
            icon: Icons.event_note_outlined,
            title: 'এখনো কোনো পরীক্ষার রুটিন নেই',
            message: 'টিউটর পরীক্ষার তারিখ যোগ করলে এখানে দেখা যাবে।',
          );
        }

        final upcoming = exams.where((e) => !e.isPast()).toList();
        final past = exams.where((e) => e.isPast()).toList().reversed.toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 40),
          children: [
            if (upcoming.isNotEmpty) ...[
              _NextExamBanner(exam: upcoming.first),
              const SizedBox(height: AppSpacing.xl),
              SectionTitle(title: 'আসন্ন পরীক্ষা (${Bn.number(upcoming.length)})'),
              for (final exam in upcoming) ...[
                ExamCard(exam: exam),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
            if (past.isNotEmpty) ...[
              if (upcoming.isNotEmpty) const SizedBox(height: AppSpacing.md),
              SectionTitle(title: 'শেষ হয়েছে (${Bn.number(past.length)})'),
              for (final exam in past) ...[
                ExamCard(exam: exam),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _NextExamBanner extends StatelessWidget {
  final Exam exam;
  const _NextExamBanner({required this.exam});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: AppRadius.xlAll,
        boxShadow: AppColors.liftedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_note_outlined,
                size: 16,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Text(
                'তোমার পরবর্তী পরীক্ষা',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                countdownLabel(exam),
                style: const TextStyle(
                  color: Color(0xFFFFD9A0),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            exam.subject,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            [
              Bn.dateWithWeekday(exam.date),
              if (exam.timeLabel.isNotEmpty) exam.timeLabel,
            ].join('  ·  '),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          if (exam.syllabus.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: AppRadius.smAll,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.checklist_outlined,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      exam.syllabus.trim(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
