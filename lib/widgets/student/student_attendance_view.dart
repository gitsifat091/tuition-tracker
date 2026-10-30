import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/student.dart';
import '../../models/attendance.dart';
import '../../models/progress_note.dart';
import '../../theme/app_theme.dart';
import '../../utils/bn.dart';
import '../attendance_tab.dart' show NoteDetailCard;
import '../common/attendance_calendar.dart';
import '../common/ui_kit.dart';

class StudentAttendanceView extends StatefulWidget {
  final Student profile;
  const StudentAttendanceView({super.key, required this.profile});

  @override
  State<StudentAttendanceView> createState() => _StudentAttendanceViewState();
}

class _StudentAttendanceViewState extends State<StudentAttendanceView> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('studentId', isEqualTo: widget.profile.id)
          .snapshots(),
      builder: (context, attendanceSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('notes')
              .where('studentId', isEqualTo: widget.profile.id)
              .snapshots(),
          builder: (context, notesSnap) {
            if (!attendanceSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // আগে এই তালিকাগুলো State এর field এ রাখা হতো আর build এর ভেতর
            // বসানো হতো — build কে side-effect মুক্ত রাখতে এখন লোকাল ভেরিয়েবল।
            final records = attendanceSnap.data!.docs
                .map((d) => AttendanceRecord.fromJson(d.id, d.data()))
                .toList();
            final notes = (notesSnap.data?.docs ?? [])
                .map((d) => ProgressNote.fromJson(d.id, d.data()))
                .toList();

            return _buildBody(records, notes);
          },
        );
      },
    );
  }

  AttendanceRecord? _recordFor(List<AttendanceRecord> records, DateTime day) {
    for (final r in records) {
      if (r.date.year == day.year && r.date.month == day.month && r.date.day == day.day) {
        return r;
      }
    }
    return null;
  }

  ProgressNote? _noteFor(List<ProgressNote> notes, DateTime day) {
    for (final n in notes) {
      if (n.date.year == day.year && n.date.month == day.month && n.date.day == day.day) {
        return n;
      }
    }
    return null;
  }

  Widget _buildBody(List<AttendanceRecord> records, List<ProgressNote> notes) {
    final monthRecords = records.where(
      (r) => r.date.year == _focusedDay.year && r.date.month == _focusedDay.month,
    );
    final present = monthRecords.where((r) => r.status == AttendanceStatus.present).length;
    final absent = monthRecords.where((r) => r.status == AttendanceStatus.absent).length;
    final total = present + absent;
    final rate = total == 0 ? null : present / total;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 40),
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
            _openDayDetail(selected, _noteFor(notes, selected));
          },
          statusFor: (day) => _recordFor(records, day)?.status,
          hasNote: (day) => _noteFor(notes, day) != null,
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionTitle(title: '${Bn.monthName(_focusedDay.month)} মাসের হিসাব'),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.check_circle_outline,
                value: Bn.number(present),
                label: 'উপস্থিত',
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatTile(
                icon: Icons.cancel_outlined,
                value: Bn.number(absent),
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
            'তারিখে ট্যাপ করলে সেদিনের CW/HW দেখা যাবে',
            style: TextStyle(color: AppColors.inkFaint, fontSize: 12),
          ),
        ),
      ],
    );
  }

  void _openDayDetail(DateTime date, ProgressNote? note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.xs,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Bn.dateWithWeekday(date),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.lg),
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
      ),
    );
  }
}
