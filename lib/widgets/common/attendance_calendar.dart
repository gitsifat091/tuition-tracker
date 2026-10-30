import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/attendance.dart';
import '../../theme/app_theme.dart';
import '../../utils/bn.dart';

/// উপস্থিতির ক্যালেন্ডার — শিক্ষক আর ছাত্র দুই দিকেই এটাই ব্যবহার হয়।
///
/// ### সপ্তাহের নাম কেটে যাওয়ার বাগ
/// `TableCalendar` এর `daysOfWeekHeight` এর ডিফল্ট মান **16.0** — খুবই কম।
/// লাতিন "Mon/Tue" তে কোনোরকমে চলে যায়, কিন্তু "বৃহঃ" বা "মঙ্গল" এর মতো
/// বাংলা যুক্তাক্ষরের ascender/descender ওই ১৬ পিক্সেলে আঁটে না, তাই উপর-নিচ
/// কেটে যেত। এখানে তিনটা কাজ একসাথে করা হয়েছে:
///
/// 1. `daysOfWeekHeight` স্পষ্ট করে ৩৪ এ তোলা হয়েছে।
/// 2. নিজের `dowBuilder` দেওয়া হয়েছে — ডিফল্টটা `DateFormat.E()` ব্যবহার করে,
///    locale data লোড করা না থাকলে যেটা চুপচাপ ইংরেজি নাম দেখায়।
/// 3. অ্যাপের ফন্ট বাংলা-সমর্থিত ফন্টে বদলানো হয়েছে (দেখো `AppTheme`) —
///    আগের Inter এ বাংলা glyph ছিল না, তাই লেখা fallback ফন্টে যেত আর তার
///    উচ্চতা Flutter এর হিসাবের সাথে মিলত না।
class AttendanceCalendar extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onFocusedDayChanged;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;

  /// ওই দিনের উপস্থিতি — কিছু না থাকলে `null`।
  final AttendanceStatus? Function(DateTime day) statusFor;

  /// ওই দিনে CW/HW নোট আছে কি না।
  final bool Function(DateTime day) hasNote;

  const AttendanceCalendar({
    super.key,
    required this.focusedDay,
    required this.onFocusedDayChanged,
    required this.onDaySelected,
    required this.statusFor,
    required this.hasNote,
    this.selectedDay,
  });

  static final _firstDay = DateTime(2020, 1, 1);
  static final _lastDay = DateTime(2035, 12, 31);

  DateTime _clamp(DateTime d) {
    if (d.isBefore(_firstDay)) return _firstDay;
    if (d.isAfter(_lastDay)) return _lastDay;
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = focusedDay.year == now.year && focusedDay.month == now.month;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
      child: Column(
        children: [
          _Header(
            focusedDay: focusedDay,
            showTodayButton: !isCurrentMonth,
            onPrev: () => onFocusedDayChanged(
              _clamp(DateTime(focusedDay.year, focusedDay.month - 1, 1)),
            ),
            onNext: () => onFocusedDayChanged(
              _clamp(DateTime(focusedDay.year, focusedDay.month + 1, 1)),
            ),
            onToday: () => onFocusedDayChanged(DateTime(now.year, now.month, now.day)),
          ),
          const SizedBox(height: AppSpacing.sm),
          TableCalendar(
            firstDay: _firstDay,
            lastDay: _lastDay,
            focusedDay: _clamp(focusedDay),
            calendarFormat: CalendarFormat.month,
            // বাংলাদেশে সপ্তাহ শনিবার থেকে শুরু।
            startingDayOfWeek: StartingDayOfWeek.saturday,
            headerVisible: false,
            // বাংলা যুক্তাক্ষরের জন্যে ডিফল্ট ১৬ পিক্সেল যথেষ্ট নয়।
            daysOfWeekHeight: 34,
            rowHeight: 46,
            availableGestures: AvailableGestures.horizontalSwipe,
            selectedDayPredicate: (day) => selectedDay != null && isSameDay(selectedDay, day),
            onPageChanged: onFocusedDayChanged,
            onDaySelected: onDaySelected,
            calendarStyle: const CalendarStyle(outsideDaysVisible: true),
            daysOfWeekStyle: const DaysOfWeekStyle(
              decoration: BoxDecoration(),
            ),
            calendarBuilders: CalendarBuilders(
              dowBuilder: (context, day) {
                final isHoliday = day.weekday == DateTime.friday;
                return Center(
                  child: Text(
                    Bn.weekdayShort(day),
                    maxLines: 1,
                    // বাংলা লেখা কখনো clip না হয়ে বরং ছোট হয়ে বসুক।
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: isHoliday ? AppColors.danger : AppColors.inkMuted,
                    ),
                  ),
                );
              },
              defaultBuilder: (context, day, _) => _DayCell(
                day: day,
                status: statusFor(day),
                hasNote: hasNote(day),
              ),
              todayBuilder: (context, day, _) => _DayCell(
                day: day,
                status: statusFor(day),
                hasNote: hasNote(day),
                isToday: true,
              ),
              selectedBuilder: (context, day, _) => _DayCell(
                day: day,
                status: statusFor(day),
                hasNote: hasNote(day),
                isSelected: true,
                isToday: isSameDay(day, DateTime.now()),
              ),
              // আগে outside/disabled builder দেওয়া ছিল না, তাই আগের-পরের মাসের
              // দিনগুলো ডিফল্ট স্টাইলে আসত আর ওদের উপস্থিতির রঙ দেখা যেত না।
              outsideBuilder: (context, day, _) => _DayCell(
                day: day,
                status: statusFor(day),
                hasNote: hasNote(day),
                isOutside: true,
              ),
              disabledBuilder: (context, day, _) => _DayCell(
                day: day,
                status: null,
                hasNote: false,
                isOutside: true,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _Legend(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final DateTime focusedDay;
  final bool showTodayButton;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _Header({
    required this.focusedDay,
    required this.showTodayButton,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _NavButton(icon: Icons.chevron_left_rounded, onTap: onPrev, tooltip: 'আগের মাস'),
        Expanded(
          child: Column(
            children: [
              Text(
                Bn.monthName(focusedDay.month),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  height: 1.3,
                ),
              ),
              Text(
                Bn.number(focusedDay.year),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.inkFaint,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        if (showTodayButton)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: GestureDetector(
              onTap: onToday,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: AppRadius.smAll,
                ),
                child: const Text(
                  'আজ',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        _NavButton(icon: Icons.chevron_right_rounded, onTap: onNext, tooltip: 'পরের মাস'),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _NavButton({required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 24, color: AppColors.inkMuted),
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final AttendanceStatus? status;
  final bool hasNote;
  final bool isToday;
  final bool isSelected;
  final bool isOutside;

  const _DayCell({
    required this.day,
    required this.status,
    required this.hasNote,
    this.isToday = false,
    this.isSelected = false,
    this.isOutside = false,
  });

  @override
  Widget build(BuildContext context) {
    Color? bg;
    Color fg = isOutside ? AppColors.inkFaint.withValues(alpha: 0.55) : AppColors.ink;
    Color? ring;

    switch (status) {
      case AttendanceStatus.present:
        bg = AppColors.successBg;
        fg = AppColors.success;
      case AttendanceStatus.absent:
        bg = AppColors.dangerBg;
        fg = AppColors.danger;
      case null:
        break;
    }

    if (isOutside && bg != null) {
      bg = bg.withValues(alpha: 0.45);
      fg = fg.withValues(alpha: 0.55);
    }

    if (isSelected) {
      ring = AppColors.primary;
    } else if (isToday) {
      ring = AppColors.primary.withValues(alpha: 0.55);
    }

    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: ring == null ? null : Border.all(color: ring, width: isSelected ? 2 : 1.4),
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Text(
            Bn.number(day.day),
            style: TextStyle(
              color: fg,
              fontSize: 13.5,
              height: 1.1,
              fontWeight: status != null || isToday || isSelected
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
          if (hasNote)
            Positioned(
              bottom: -1,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: isOutside ? AppColors.warning.withValues(alpha: 0.5) : AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      children: [
        _LegendItem(color: AppColors.successBg, ring: AppColors.success, label: 'উপস্থিত'),
        _LegendItem(color: AppColors.dangerBg, ring: AppColors.danger, label: 'অনুপস্থিত'),
        _LegendItem(color: AppColors.warning, ring: AppColors.warning, label: 'CW/HW আছে', isDot: true),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final Color ring;
  final String label;
  final bool isDot;
  const _LegendItem({
    required this.color,
    required this.ring,
    required this.label,
    this.isDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isDot ? 6 : 12,
          height: isDot ? 6 : 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: isDot ? null : Border.all(color: ring.withValues(alpha: 0.45)),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.inkFaint, height: 1.4),
        ),
      ],
    );
  }
}
