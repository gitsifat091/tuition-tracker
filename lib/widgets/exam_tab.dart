import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exam.dart';
import '../models/student.dart';
import '../providers/exam_provider.dart';
import '../theme/app_theme.dart';
import '../utils/bn.dart';
import '../utils/time_format.dart';
import 'common/ui_kit.dart';

class ExamTab extends StatelessWidget {
  final Student student;
  const ExamTab({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExamProvider>();

    if (!provider.loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final upcoming = provider.upcomingForStudent(student.id);
    final past = provider.pastForStudent(student.id);

    if (upcoming.isEmpty && past.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: EmptyState(
          icon: Icons.event_note_outlined,
          title: 'এখনো কোনো পরীক্ষা যোগ করা হয়নি',
          message: 'পরীক্ষার তারিখ আর সিলেবাস লিখে রাখলে ছাত্রও নিজের অ্যাপে দেখতে পাবে।',
          action: FilledButton.icon(
            onPressed: () => showExamForm(context, student),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('প্রথম পরীক্ষা যোগ করো'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 100),
        children: [
          if (upcoming.isNotEmpty) ...[
            _NextExamCard(exam: upcoming.first, totalUpcoming: upcoming.length),
            const SizedBox(height: AppSpacing.xl),
            SectionTitle(title: 'আসন্ন পরীক্ষা (${Bn.number(upcoming.length)})'),
            for (final exam in upcoming) ...[
              ExamCard(
                exam: exam,
                onTap: () => showExamForm(context, student, existing: exam),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
          if (past.isNotEmpty) ...[
            if (upcoming.isNotEmpty) const SizedBox(height: AppSpacing.md),
            SectionTitle(title: 'শেষ হয়েছে (${Bn.number(past.length)})'),
            for (final exam in past) ...[
              ExamCard(
                exam: exam,
                onTap: () => showExamForm(context, student, existing: exam),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showExamForm(context, student),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// সবচেয়ে কাছের পরীক্ষার হাইলাইট কার্ড।
class _NextExamCard extends StatelessWidget {
  final Exam exam;
  final int totalUpcoming;
  const _NextExamCard({required this.exam, required this.totalUpcoming});

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
                'পরবর্তী পরীক্ষা',
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
          if (totalUpcoming > 1) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'সব মিলিয়ে ${Bn.number(totalUpcoming)} টি পরীক্ষা বাকি',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "আজ" / "আগামীকাল" / "আর ৫ দিন" / "৩ দিন আগে"।
String countdownLabel(Exam exam, [DateTime? now]) {
  final days = exam.daysLeft(now);
  if (days == 0) return 'আজ';
  if (days == 1) return 'আগামীকাল';
  if (days > 1) return 'আর ${Bn.number(days)} দিন';
  if (days == -1) return 'গতকাল';
  return '${Bn.number(-days)} দিন আগে';
}

/// পরীক্ষার একটা সারি — শিক্ষক আর ছাত্র দুই দিকেই এটাই ব্যবহার হয়।
/// [onTap] না দিলে (ছাত্রের দিকে) কার্ডটা শুধু দেখার জন্যে।
class ExamCard extends StatelessWidget {
  final Exam exam;
  final VoidCallback? onTap;
  const ExamCard({super.key, required this.exam, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPast = exam.isPast();
    final days = exam.daysLeft();
    // তিন দিনের ভেতরে হলে চোখে পড়ার মতো করে দেখানো হয়।
    final isSoon = !isPast && days <= 3;

    final accent = isPast
        ? AppColors.inkFaint
        : (isSoon ? AppColors.warning : AppColors.primary);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      color: isPast ? AppColors.surfaceMuted : AppColors.surface,
      borderColor: isSoon ? AppColors.warning.withValues(alpha: 0.3) : null,
      elevated: !isPast,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // তারিখের ব্যাজ
              Container(
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: AppRadius.smAll,
                ),
                child: Column(
                  children: [
                    Text(
                      Bn.number(exam.date.day),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: accent,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      Bn.monthName(exam.date.month, short: true),
                      style: TextStyle(fontSize: 10, color: accent, height: 1.4),
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
                      exam.subject,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        height: 1.4,
                        color: isPast ? AppColors.inkMuted : AppColors.ink,
                      ),
                    ),
                    Text(
                      [
                        if (exam.examName.trim().isNotEmpty) exam.examName.trim(),
                        Bn.weekdayFull(exam.date),
                      ].join('  ·  '),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusPill(
                label: countdownLabel(exam),
                color: accent,
                background: accent.withValues(alpha: 0.1),
                fontSize: 11,
              ),
            ],
          ),
          if (exam.timeLabel.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _ExamLine(icon: Icons.access_time, text: exam.timeLabel, color: accent),
          ],
          if (exam.syllabus.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _ExamLine(
              icon: Icons.menu_book_outlined,
              text: exam.syllabus.trim(),
              color: AppColors.inkMuted,
            ),
          ],
        ],
      ),
    );
  }
}

class _ExamLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _ExamLine({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 12.5, height: 1.5),
          ),
        ),
      ],
    );
  }
}

/// পরীক্ষা যোগ / এডিট / ডিলিট করার শিট।
void showExamForm(BuildContext context, Student student, {Exam? existing}) {
  final subjectCtrl = TextEditingController(text: existing?.subject ?? '');
  final examNameCtrl = TextEditingController(text: existing?.examName ?? '');
  final syllabusCtrl = TextEditingController(text: existing?.syllabus ?? '');

  DateTime selectedDate = existing?.date ?? DateTime.now();
  TimeOfDay? startTime = parseTimeOfDay(existing?.startTime);
  TimeOfDay? endTime = parseTimeOfDay(existing?.endTime);
  String? error;
  // দুবার ট্যাপ করলে যেন দুটো রেকর্ড না বসে।
  bool saving = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.xs,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null ? 'নতুন পরীক্ষা' : 'পরীক্ষা এডিট করুন',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: subjectCtrl,
                autofocus: existing == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'বিষয়',
                  hintText: 'যেমন — গণিত',
                  prefixIcon: Icon(Icons.menu_book_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: examNameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'পরীক্ষার নাম (ঐচ্ছিক)',
                  hintText: 'যেমন — অর্ধবার্ষিক পরীক্ষা',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _PickerField(
                icon: Icons.calendar_today_outlined,
                label: 'তারিখ',
                value: Bn.date(selectedDate),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020, 1, 1),
                    lastDate: DateTime(2035, 12, 31),
                  );
                  if (picked != null) setSheetState(() => selectedDate = picked);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _PickerField(
                      icon: Icons.play_arrow_outlined,
                      label: 'শুরু',
                      value: formatTimeOfDay(startTime) ?? 'দাওনি',
                      muted: startTime == null,
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: startTime ?? const TimeOfDay(hour: 10, minute: 0),
                        );
                        if (picked != null) setSheetState(() => startTime = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _PickerField(
                      icon: Icons.stop_outlined,
                      label: 'শেষ',
                      value: formatTimeOfDay(endTime) ?? 'দাওনি',
                      muted: endTime == null,
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: endTime ??
                              startTime ??
                              const TimeOfDay(hour: 12, minute: 0),
                        );
                        if (picked != null) setSheetState(() => endTime = picked);
                      },
                    ),
                  ),
                ],
              ),
              if (startTime != null || endTime != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setSheetState(() {
                      startTime = null;
                      endTime = null;
                    }),
                    icon: const Icon(Icons.close, size: 15),
                    label: const Text('সময় মুছো'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.inkFaint),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: syllabusCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'সিলেবাস (ঐচ্ছিক)',
                  hintText: 'কোন অধ্যায় বা টপিক পড়তে হবে',
                  prefixIcon: Icon(Icons.checklist_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  if (existing != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final ok = await confirmDialog(
                                  ctx,
                                  title: 'পরীক্ষা ডিলিট করবে?',
                                  message: '"${existing.subject}" এর পরীক্ষাটা রুটিন '
                                      'থেকে মুছে যাবে।',
                                  confirmLabel: 'ডিলিট',
                                  destructive: true,
                                );
                                if (!ok || !ctx.mounted) return;
                                ctx.read<ExamProvider>().deleteExam(existing.id);
                                Navigator.pop(ctx);
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: const Text('ডিলিট'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (subjectCtrl.text.trim().isEmpty) {
                                setSheetState(() => error = 'বিষয়ের নাম দাও');
                                return;
                              }
                              // শুরুর সময় শেষের পরে হলে ধরিয়ে দেওয়া।
                              if (startTime != null && endTime != null) {
                                final startMinutes =
                                    startTime!.hour * 60 + startTime!.minute;
                                final endMinutes = endTime!.hour * 60 + endTime!.minute;
                                if (endMinutes <= startMinutes) {
                                  setSheetState(
                                    () => error = 'শেষের সময় শুরুর সময়ের পরে হতে হবে',
                                  );
                                  return;
                                }
                              }

                              setSheetState(() {
                                saving = true;
                                error = null;
                              });

                              final exam = Exam(
                                id: existing?.id,
                                tutorId: existing?.tutorId ?? '',
                                studentId: student.id,
                                subject: subjectCtrl.text.trim(),
                                examName: examNameCtrl.text.trim(),
                                date: selectedDate,
                                startTime: formatTimeOfDay(startTime),
                                endTime: formatTimeOfDay(endTime),
                                syllabus: syllabusCtrl.text.trim(),
                                createdAt: existing?.createdAt,
                              );

                              final provider = ctx.read<ExamProvider>();
                              try {
                                if (existing == null) {
                                  await provider.addExam(exam);
                                } else {
                                  await provider.updateExam(exam);
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                if (ctx.mounted) {
                                  setSheetState(() {
                                    saving = false;
                                    error = 'সেভ করা যায়নি: $e';
                                  });
                                }
                              }
                            },
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('সেভ করুন'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(() {
    subjectCtrl.dispose();
    examNameCtrl.dispose();
    syllabusCtrl.dispose();
  });
}

class _PickerField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool muted;
  final VoidCallback onTap;

  const _PickerField({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.inkFaint),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.inkFaint),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: muted ? AppColors.inkFaint : AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
