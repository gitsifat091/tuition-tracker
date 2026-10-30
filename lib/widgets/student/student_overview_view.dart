import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_features.dart';
import '../../models/student.dart';
import '../../models/attendance.dart';
import '../../models/exam.dart';
import '../../models/fee_record.dart';
import '../../models/progress_note.dart';
import '../../models/syllabus_item.dart';
import '../../theme/app_theme.dart';
import '../../utils/bn.dart';
import '../common/ui_kit.dart';
import '../exam_tab.dart' show countdownLabel;

class StudentOverviewView extends StatelessWidget {
  final Student profile;
  const StudentOverviewView({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 40),
      children: [
        _ProfileHeader(profile: profile),
        const SizedBox(height: AppSpacing.xl),

        const SectionTitle(title: 'একাডেমিক অগ্রগতি'),

        // সিলেবাস
        _CollectionBuilder<SyllabusItem>(
          collection: 'syllabus',
          studentId: profile.id,
          parse: SyllabusItem.fromJson,
          builder: (items) {
            final done = items.where((i) => i.isDone).length;
            return _ProgressCard(
              icon: Icons.checklist_outlined,
              title: 'সিলেবাস সম্পন্ন',
              value: items.isEmpty
                  ? 'এখনো যোগ হয়নি'
                  : '${Bn.number(done)}/${Bn.number(items.length)} টপিক',
              progress: items.isEmpty ? null : done / items.length,
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),

        // এ মাসের উপস্থিতি
        _CollectionBuilder<AttendanceRecord>(
          collection: 'attendance',
          studentId: profile.id,
          parse: AttendanceRecord.fromJson,
          builder: (records) {
            final monthRecords = records
                .where((r) => r.date.year == now.year && r.date.month == now.month)
                .toList();
            final present =
                monthRecords.where((r) => r.status == AttendanceStatus.present).length;
            final total = monthRecords.length;
            return _ProgressCard(
              icon: Icons.event_available_outlined,
              title: 'এই মাসের উপস্থিতি',
              value: total == 0
                  ? 'এখনো কোনো ক্লাস হয়নি'
                  : '${Bn.number(present)}/${Bn.number(total)} দিন',
              progress: total == 0 ? null : present / total,
            );
          },
        ),
        if (AppFeatures.feesEnabled) const SizedBox(height: AppSpacing.md),

        // ফি
        if (AppFeatures.feesEnabled)
          _CollectionBuilder<FeeRecord>(
            collection: 'fees',
            studentId: profile.id,
            parse: FeeRecord.fromJson,
            builder: (raw) {
              // পুরনো ডুপ্লিকেট থাকলে "৭ মাসের ফি বাকি" দেখাত — ছেঁকে নেওয়া হচ্ছে।
              final records = dedupeFeeRecords(raw);
              final dueRecords = records.where((r) => r.status == FeeStatus.due).toList();
              final dueAmount = dueRecords.fold<double>(0, (total, r) => total + r.amount);
              final hasDue = dueRecords.isNotEmpty;

              return AppCard(
                color: hasDue ? AppColors.warningBg : AppColors.successBg,
                borderColor: (hasDue ? AppColors.warning : AppColors.success)
                    .withValues(alpha: 0.25),
                elevated: false,
                padding: const EdgeInsets.all(AppSpacing.md + 2),
                child: Row(
                  children: [
                    Icon(
                      hasDue ? Icons.payments_outlined : Icons.verified_outlined,
                      size: 20,
                      color: hasDue ? AppColors.warning : AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        hasDue
                            ? '${Bn.number(dueRecords.length)} মাসের ফি বাকি — ${Bn.taka(dueAmount)}'
                            : 'সব ফি পরিশোধিত',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.5,
                          color: hasDue ? AppColors.warning : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: AppSpacing.xl),

        const SectionTitle(title: 'পরবর্তী পরীক্ষা'),
        _CollectionBuilder<Exam>(
          collection: 'exams',
          studentId: profile.id,
          parse: Exam.fromJson,
          builder: (exams) {
            final upcoming = exams.where((e) => !e.isPast(now)).toList()
              ..sort((a, b) => a.date.compareTo(b.date));

            if (upcoming.isEmpty) {
              return const AppCard(
                padding: EdgeInsets.all(AppSpacing.md + 2),
                child: Text(
                  'সামনে কোনো পরীক্ষা নেই',
                  style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
                ),
              );
            }

            final next = upcoming.first;
            final soon = next.daysLeft(now) <= 3;
            final accent = soon ? AppColors.warning : AppColors.primary;

            return AppCard(
              padding: const EdgeInsets.all(AppSpacing.md + 2),
              color: soon ? AppColors.warningBg : AppColors.surface,
              borderColor: soon ? AppColors.warning.withValues(alpha: 0.28) : null,
              child: Row(
                children: [
                  Icon(Icons.event_note_outlined, size: 20, color: accent),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          next.subject,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                        Text(
                          [
                            Bn.dateShort(next.date),
                            if (next.timeLabel.isNotEmpty) next.timeLabel,
                          ].join('  ·  '),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusPill(
                    label: countdownLabel(next, now),
                    color: accent,
                    background: accent.withValues(alpha: 0.12),
                    fontSize: 11.5,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),

        const SectionTitle(title: 'সাম্প্রতিক CW/HW'),
        _CollectionBuilder<ProgressNote>(
          collection: 'notes',
          studentId: profile.id,
          parse: ProgressNote.fromJson,
          builder: (notes) {
            if (notes.isEmpty) {
              return const AppCard(
                padding: EdgeInsets.all(AppSpacing.md + 2),
                child: Text(
                  'এখনো কোনো নোট নেই',
                  style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
                ),
              );
            }
            final sorted = [...notes]..sort((a, b) => b.date.compareTo(a.date));
            final latest = sorted.first;

            return AppCard(
              padding: const EdgeInsets.all(AppSpacing.md + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Bn.date(latest.date),
                    style: const TextStyle(color: AppColors.inkFaint, fontSize: 11.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    latest.topic,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  if (latest.homework.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
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
                          child: Text(
                            latest.homework,
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: 12.5,
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
          },
        ),
      ],
    );
  }
}

/// `studentId` দিয়ে একটা কালেকশন পড়ার StreamBuilder — চারটা কার্ডে একই
/// প্যাটার্ন হাতে হাতে লেখা ছিল, এখন একটাই জায়গা।
class _CollectionBuilder<T> extends StatelessWidget {
  final String collection;
  final String studentId;
  final T Function(String id, Map<String, dynamic> json) parse;
  final Widget Function(List<T> items) builder;

  const _CollectionBuilder({
    required this.collection,
    required this.studentId,
    required this.parse,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('studentId', isEqualTo: studentId)
          .snapshots(),
      builder: (context, snap) {
        final items = snap.data?.docs.map((d) => parse(d.id, d.data())).toList() ?? <T>[];
        return builder(items);
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Student profile;
  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final schedule = [
      if (profile.classDays.isNotEmpty) profile.classDays.join(', '),
      if (profile.classTime != null && profile.classTime!.isNotEmpty) profile.classTime!,
    ].join('  ·  ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: AppRadius.xlAll,
        boxShadow: AppColors.liftedShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            alignment: Alignment.center,
            child: Text(
              profile.name.trim().isNotEmpty ? profile.name.trim()[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    height: 1.35,
                  ),
                ),
                Text(
                  '${profile.className}  ·  ${profile.subject}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
                if (schedule.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          schedule,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 11.5,
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

class _ProgressCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final double? progress;

  const _ProgressCard({
    required this.icon,
    required this.title,
    required this.value,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.md),
            ThinProgressBar(value: progress!),
          ],
        ],
      ),
    );
  }
}
