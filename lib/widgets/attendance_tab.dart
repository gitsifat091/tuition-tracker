import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../models/progress_note.dart';
import '../providers/attendance_provider.dart';
import '../providers/progress_note_provider.dart';
import '../theme/app_theme.dart';
import '../utils/bn.dart';
import 'common/attendance_calendar.dart';
import 'common/ui_kit.dart';
import 'progress_notes_tab.dart';

class AttendanceTab extends StatefulWidget {
  final Student student;
  const AttendanceTab({super.key, required this.student});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final noteProvider = context.watch<ProgressNoteProvider>();
    final stats = attendanceProvider.monthlyStats(
      widget.student.id,
      _focusedDay.year,
      _focusedDay.month,
    );
    final total = stats['total']!;
    final rate = total == 0 ? null : stats['present']! / total;

    // আগে এটা একটা সাধারণ `Column` ছিল — ছোট স্ক্রিনে ক্যালেন্ডার + পরিসংখ্যান
    // একসাথে না আঁটলে "RenderFlex overflowed" হলুদ-কালো দাগ দেখাত।
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
      children: [
        AttendanceCalendar(
          focusedDay: _focusedDay,
          selectedDay: _selectedDay,
          onFocusedDayChanged: (day) => setState(() => _focusedDay = day),
          onDaySelected: (selected, focused) {
            setState(() {
              _selectedDay = selected;
              _focusedDay = focused;
            });
            _openDayDetail(selected);
          },
          statusFor: (day) => attendanceProvider.recordFor(widget.student.id, day)?.status,
          hasNote: (day) => _noteForDate(noteProvider, day) != null,
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionTitle(title: '${Bn.monthName(_focusedDay.month)} মাসের হিসাব'),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.check_circle_outline,
                value: Bn.number(stats['present']!),
                label: 'উপস্থিত',
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatTile(
                icon: Icons.cancel_outlined,
                value: Bn.number(stats['absent']!),
                label: 'অনুপস্থিত',
                color: AppColors.danger,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatTile(
                icon: Icons.event_note_outlined,
                value: Bn.number(total),
                label: 'মোট ক্লাস',
                color: AppColors.info,
              ),
            ),
          ],
        ),
        if (rate != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'উপস্থিতির হার',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    Text(
                      '${Bn.number((rate * 100).round())}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: rate >= 0.75 ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                ThinProgressBar(
                  value: rate,
                  color: rate >= 0.75 ? AppColors.success : AppColors.warning,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        const Center(
          child: Text(
            'তারিখে ট্যাপ করলে উপস্থিতি দেওয়া যাবে আর সেদিনের CW/HW দেখা যাবে',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkFaint, fontSize: 12, height: 1.5),
          ),
        ),
      ],
    );
  }

  ProgressNote? _noteForDate(ProgressNoteProvider provider, DateTime date) {
    for (final n in provider.forStudent(widget.student.id)) {
      if (n.date.year == date.year && n.date.month == date.month && n.date.day == date.day) {
        return n;
      }
    }
    return null;
  }

  void _openDayDetail(DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _DayDetailSheet(student: widget.student, date: date),
    );
  }
}

class _DayDetailSheet extends StatelessWidget {
  final Student student;
  final DateTime date;
  const _DayDetailSheet({required this.student, required this.date});

  ProgressNote? _noteFor(ProgressNoteProvider provider) {
    for (final n in provider.forStudent(student.id)) {
      if (n.date.year == date.year && n.date.month == date.month && n.date.day == date.day) {
        return n;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final noteProvider = context.watch<ProgressNoteProvider>();
    final record = attendanceProvider.recordFor(student.id, date);
    final note = _noteFor(noteProvider);
    final isToday = DateUtils.isSameDay(date, DateTime.now());

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.xs,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    Bn.dateWithWeekday(date),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.4),
                  ),
                ),
                if (isToday)
                  const StatusPill(
                    label: 'আজ',
                    color: AppColors.primary,
                    background: Color(0x1A2D6A4F),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'উপস্থিতি',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            Row(
              children: [
                Expanded(
                  child: _AttendanceButton(
                    label: 'উপস্থিত',
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                    background: AppColors.successBg,
                    selected: record?.status == AttendanceStatus.present,
                    onTap: () => context.read<AttendanceProvider>().setStatus(
                          student.id,
                          date,
                          AttendanceStatus.present,
                        ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: _AttendanceButton(
                    label: 'অনুপস্থিত',
                    icon: Icons.cancel_outlined,
                    color: AppColors.danger,
                    background: AppColors.dangerBg,
                    selected: record?.status == AttendanceStatus.absent,
                    onTap: () => context.read<AttendanceProvider>().setStatus(
                          student.id,
                          date,
                          AttendanceStatus.absent,
                        ),
                  ),
                ),
                if (record != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    onPressed: () =>
                        context.read<AttendanceProvider>().clearStatus(student.id, date),
                    icon: const Icon(Icons.backspace_outlined, size: 19),
                    color: AppColors.inkFaint,
                    tooltip: 'ক্লিয়ার করো',
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xl + 4),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'CW / HW',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showNoteForm(context, student, existing: note, initialDate: date);
                  },
                  icon: Icon(note == null ? Icons.add : Icons.edit_outlined, size: 16),
                  label: Text(note == null ? 'নোট যোগ করো' : 'এডিট করো'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            if (note == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  'এই তারিখে কোনো নোট নেই',
                  style: TextStyle(color: AppColors.inkFaint, fontSize: 13),
                ),
              )
            else
              NoteDetailCard(note: note),
          ],
        ),
      ),
    );
  }
}

/// একদিনের CW/HW/মার্কস দেখানোর কার্ড — শিক্ষক আর ছাত্র দুই দিকেই ব্যবহার হয়।
class NoteDetailCard extends StatelessWidget {
  final ProgressNote note;
  const NoteDetailCard({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.045),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _NoteLabel(
            icon: Icons.menu_book_outlined,
            text: 'CW (ক্লাসে যা পড়ানো হয়েছে)',
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.xs + 1),
          Text(note.topic, style: const TextStyle(fontSize: 13.5, height: 1.5)),
          if (note.homework.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const _NoteLabel(
              icon: Icons.assignment_outlined,
              text: 'HW (হোমওয়ার্ক)',
              color: AppColors.warning,
            ),
            const SizedBox(height: AppSpacing.xs + 1),
            Text(note.homework, style: const TextStyle(fontSize: 13.5, height: 1.5)),
          ],
          if (note.remarks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const _NoteLabel(
              icon: Icons.chat_bubble_outline,
              text: 'মন্তব্য',
              color: AppColors.info,
            ),
            const SizedBox(height: AppSpacing.xs + 1),
            Text(note.remarks, style: const TextStyle(fontSize: 13.5, height: 1.5)),
          ],
          if (note.marks != null && note.outOf != null) ...[
            const SizedBox(height: AppSpacing.md),
            StatusPill(
              label: 'মার্কস ${Bn.number(note.marks!)}/${Bn.number(note.outOf!)}',
              color: AppColors.primary,
              background: AppColors.primary.withValues(alpha: 0.1),
              icon: Icons.star_outline_rounded,
              fontSize: 12,
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _NoteLabel({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}

class _AttendanceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color background;
  final bool selected;
  final VoidCallback onTap;

  const _AttendanceButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? background : AppColors.surface,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: selected ? color : AppColors.inkFaint),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? color : AppColors.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
