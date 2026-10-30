import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/progress_note.dart';
import '../models/student.dart';
import '../providers/progress_note_provider.dart';
import '../theme/app_theme.dart';
import '../utils/bn.dart';
import 'common/ui_kit.dart';

class ProgressNotesTab extends StatelessWidget {
  final Student student;
  const ProgressNotesTab({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<ProgressNoteProvider>().forStudent(student.id);

    final markedNotes = notes
        .where((n) => n.marks != null && n.outOf != null && n.outOf! > 0)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: notes.isEmpty
          ? EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'এখনো কোনো নোট যোগ করা হয়নি',
              message: 'প্রতিদিনের CW/HW আর পরীক্ষার নম্বর এখানে জমা থাকবে।',
              action: FilledButton.icon(
                onPressed: () => showNoteForm(context, student),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('প্রথম নোট যোগ করো'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                100,
              ),
              children: [
                if (markedNotes.length >= 2) ...[
                  const SectionTitle(title: 'মার্কস ট্রেন্ড (%)'),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: SizedBox(
                      height: 150,
                      child: _MarksTrendChart(notes: markedNotes),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                SectionTitle(title: 'সব নোট (${Bn.number(notes.length)})'),
                for (final note in notes) ...[
                  _NoteCard(note: note, student: student),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
      floatingActionButton: notes.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => showNoteForm(context, student),
              child: const Icon(Icons.add),
            ),
    );
  }
}

void showNoteForm(
  BuildContext context,
  Student student, {
  ProgressNote? existing,
  DateTime? initialDate,
}) {
  final topicCtrl = TextEditingController(text: existing?.topic ?? '');
  final marksCtrl = TextEditingController(text: existing?.marks?.toStringAsFixed(0) ?? '');
  final outOfCtrl = TextEditingController(text: existing?.outOf?.toStringAsFixed(0) ?? '');
  final remarksCtrl = TextEditingController(text: existing?.remarks ?? '');
  final homeworkCtrl = TextEditingController(text: existing?.homework ?? '');
  DateTime selectedDate = existing?.date ?? initialDate ?? DateTime.now();
  String? error;

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
                existing == null ? 'নতুন নোট' : 'নোট এডিট করুন',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SheetField(
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
              TextField(
                controller: topicCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'টপিক / পরীক্ষার নাম',
                  prefixIcon: Icon(Icons.menu_book_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: marksCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'প্রাপ্ত নম্বর'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: outOfCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'পূর্ণমান'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: homeworkCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'হোমওয়ার্ক (ঐচ্ছিক)',
                  hintText: 'পরের ক্লাসের আগে কী করে আসতে হবে',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: remarksCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'মন্তব্য (ঐচ্ছিক)',
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
                        onPressed: () async {
                          final ok = await confirmDialog(
                            ctx,
                            title: 'নোট ডিলিট করবে?',
                            message: 'এই নোটটা মুছে যাবে, ফেরত আনা যাবে না।',
                            confirmLabel: 'ডিলিট',
                            destructive: true,
                          );
                          if (!ok || !ctx.mounted) return;
                          ctx.read<ProgressNoteProvider>().deleteNote(existing.id);
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
                      onPressed: () {
                        if (topicCtrl.text.trim().isEmpty) {
                          setSheetState(() => error = 'টপিক বা পরীক্ষার নাম দাও');
                          return;
                        }
                        final marks = double.tryParse(marksCtrl.text.trim());
                        final outOf = double.tryParse(outOfCtrl.text.trim());
                        // অর্ধেক নম্বর দিলে চার্টে ভুল হিসাব যেত, তাই দুটোই চাই।
                        if ((marks == null) != (outOf == null)) {
                          setSheetState(
                            () => error = 'নম্বর দিলে প্রাপ্ত নম্বর আর পূর্ণমান — দুটোই দাও',
                          );
                          return;
                        }
                        if (outOf != null && outOf <= 0) {
                          setSheetState(() => error = 'পূর্ণমান শূন্যের বেশি হতে হবে');
                          return;
                        }
                        if (marks != null && outOf != null && marks > outOf) {
                          setSheetState(() => error = 'প্রাপ্ত নম্বর পূর্ণমানের বেশি হতে পারে না');
                          return;
                        }

                        final note = ProgressNote(
                          id: existing?.id,
                          tutorId: existing?.tutorId ?? '',
                          studentId: student.id,
                          date: selectedDate,
                          topic: topicCtrl.text.trim(),
                          marks: marks,
                          outOf: outOf,
                          remarks: remarksCtrl.text.trim(),
                          homework: homeworkCtrl.text.trim(),
                        );
                        final provider = ctx.read<ProgressNoteProvider>();
                        if (existing == null) {
                          provider.addNote(note);
                        } else {
                          provider.updateNote(note);
                        }
                        Navigator.pop(ctx);
                      },
                      child: const Text('সেভ করুন'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    // শিট বন্ধ হলে কন্ট্রোলারগুলো ছেড়ে দেওয়া — আগে এগুলো dispose হতো না।
  ).whenComplete(() {
    topicCtrl.dispose();
    marksCtrl.dispose();
    outOfCtrl.dispose();
    remarksCtrl.dispose();
    homeworkCtrl.dispose();
  });
}

class _SheetField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _SheetField({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.inkFaint),
            const SizedBox(width: AppSpacing.md),
            Text(label, style: const TextStyle(fontSize: 14, color: AppColors.inkMuted)),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final ProgressNote note;
  final Student student;
  const _NoteCard({required this.note, required this.student});

  @override
  Widget build(BuildContext context) {
    final hasMarks = note.marks != null && note.outOf != null && note.outOf! > 0;
    final percent = hasMarks ? (note.marks! / note.outOf!) : null;

    return AppCard(
      onTap: () => showNoteForm(context, student, existing: note),
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
            _NoteLine(
              icon: Icons.assignment_outlined,
              color: AppColors.warning,
              text: note.homework,
            ),
          ],
          if (note.remarks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _NoteLine(
              icon: Icons.chat_bubble_outline,
              color: AppColors.inkFaint,
              text: note.remarks,
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _NoteLine({required this.icon, required this.color, required this.text});

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
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 12.5, height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _MarksTrendChart extends StatelessWidget {
  final List<ProgressNote> notes;
  const _MarksTrendChart({required this.notes});

  @override
  Widget build(BuildContext context) {
    final spots = notes.asMap().entries.map((e) {
      final percent = ((e.value.marks! / e.value.outOf!) * 100).clamp(0.0, 100.0);
      return FlSpot(e.key.toDouble(), percent);
    }).toList();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.border,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: 25,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  Bn.number(value),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 10, color: AppColors.inkFaint),
                ),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.ink,
            tooltipRoundedRadius: AppRadius.sm,
            getTooltipItems: (touched) => touched.map((spot) {
              final note = notes[spot.spotIndex];
              return LineTooltipItem(
                '${note.topic}\n${Bn.number(spot.y)}%',
                const TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: AppColors.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3.5,
                color: AppColors.surface,
                strokeWidth: 2,
                strokeColor: AppColors.primary,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.18),
                  AppColors.primary.withValues(alpha: 0.01),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
