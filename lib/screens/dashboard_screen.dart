import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/app_features.dart';
import '../models/student.dart';
import '../providers/attendance_provider.dart';
import '../providers/student_provider.dart';
import '../providers/fee_provider.dart';
import '../theme/app_theme.dart';
import '../utils/bn.dart';
import '../widgets/common/ui_kit.dart';
import 'student_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final studentProvider = context.watch<StudentProvider>();
    final feeProvider = context.watch<FeeProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();

    final now = DateTime.now();
    final thisMonthCollected = feeProvider.totalCollectedForMonth(now);
    final thisMonthDue = feeProvider.totalDueForMonth(now);

    // আগে `studentProvider.students.length` লেখা ছিল — সেটা আর্কাইভ করা
    // ছাত্রদেরও গুনত, তাই তুইশন ছেড়ে দেওয়ার পরেও সংখ্যা কমত না।
    final activeStudents = studentProvider.activeStudents;
    final activeIds = activeStudents.map((s) => s.id).toSet();

    final months = List.generate(6, (i) => DateTime(now.year, now.month - (5 - i), 1));

    // যাদের ফি বাকি, বেশি বাকি আগে।
    final dueStudents = activeStudents
        .map((s) => (student: s, due: feeProvider.totalDueForStudent(s.id)))
        .where((e) => e.due > 0)
        .toList()
      ..sort((a, b) => b.due.compareTo(a.due));

    final monthStats = attendanceProvider.statsForMonth(now, studentIds: activeIds);
    final presentRate = attendanceProvider.presentRateForAll(now, studentIds: activeIds);

    return Scaffold(
      appBar: AppBar(title: const Text('ড্যাশবোর্ড')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 40),
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.people_outline,
                  value: Bn.number(activeStudents.length),
                  label: 'সক্রিয় ছাত্র',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppFeatures.feesEnabled
                    ? StatTile(
                        icon: Icons.check_circle_outline,
                        value: Bn.taka(thisMonthCollected),
                        label: 'এই মাসে আদায়',
                        color: AppColors.success,
                      )
                    : StatTile(
                        icon: Icons.event_note_outlined,
                        value: Bn.number(monthStats['total']!),
                        label: 'এই মাসে ক্লাস',
                        color: AppColors.info,
                      ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppFeatures.feesEnabled
                    ? StatTile(
                        icon: Icons.schedule,
                        value: Bn.taka(thisMonthDue),
                        label: 'এই মাসে বাকি',
                        color: thisMonthDue > 0 ? AppColors.warning : AppColors.inkMuted,
                      )
                    : StatTile(
                        icon: Icons.check_circle_outline,
                        value: Bn.number(monthStats['present']!),
                        label: 'মোট উপস্থিত',
                        color: AppColors.success,
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppFeatures.feesEnabled
                    ? StatTile(
                        icon: Icons.summarize_outlined,
                        value: Bn.taka(thisMonthCollected + thisMonthDue),
                        label: 'মোট প্রত্যাশিত',
                        color: AppColors.info,
                      )
                    : StatTile(
                        icon: Icons.percent_rounded,
                        value: presentRate == null
                            ? '—'
                            : '${Bn.number((presentRate * 100).round())}%',
                        label: 'গড় উপস্থিতি',
                        color: presentRate == null || presentRate >= 0.75
                            ? AppColors.primary
                            : AppColors.warning,
                      ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          const SectionTitle(
            title: AppFeatures.feesEnabled
                ? 'গত ৬ মাসের আদায় বনাম বাকি'
                : 'গত ৬ মাসের উপস্থিতি',
          ),
          AppCard(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 210,
                  child: AppFeatures.feesEnabled
                      ? _IncomeChart(months: months, feeProvider: feeProvider)
                      : _AttendanceChart(
                          months: months,
                          attendanceProvider: attendanceProvider,
                          studentIds: activeIds,
                        ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: AppFeatures.feesEnabled
                      ? [
                          _LegendDot(color: AppColors.success, label: 'আদায়'),
                          SizedBox(width: AppSpacing.xl),
                          _LegendDot(color: AppColors.warning, label: 'বাকি'),
                        ]
                      : [
                          _LegendDot(color: AppColors.success, label: 'উপস্থিত'),
                          SizedBox(width: AppSpacing.xl),
                          _LegendDot(color: AppColors.danger, label: 'অনুপস্থিত'),
                        ],
                ),
              ],
            ),
          ),

          if (AppFeatures.feesEnabled) ...[
            const SizedBox(height: AppSpacing.xl),
            SectionTitle(
              title: dueStudents.isEmpty ? 'ফি বকেয়া' : 'ফি বাকি আছে যাদের',
            ),
            if (dueStudents.isEmpty)
              AppCard(
                color: AppColors.successBg,
                borderColor: AppColors.success.withValues(alpha: 0.25),
                elevated: false,
                child: const Row(
                  children: [
                    Icon(Icons.celebration_outlined, color: AppColors.success, size: 20),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'সবার ফি পরিশোধিত — কারো কিছু বাকি নেই।',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final entry in dueStudents) ...[
                _DueStudentRow(student: entry.student, due: entry.due),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ],
      ),
    );
  }
}

/// ফি লুকানো থাকলে ড্যাশবোর্ডে এই চার্টটা বসে — গত ৬ মাসে সব ছাত্র মিলিয়ে
/// কত দিন উপস্থিত আর কত দিন অনুপস্থিত।
class _AttendanceChart extends StatelessWidget {
  final List<DateTime> months;
  final AttendanceProvider attendanceProvider;
  final Set<String> studentIds;

  const _AttendanceChart({
    required this.months,
    required this.attendanceProvider,
    required this.studentIds,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      for (final m in months)
        attendanceProvider.statsForMonth(m, studentIds: studentIds),
    ];

    double maxValue = 0;
    for (final s in stats) {
      if (s['present']! > maxValue) maxValue = s['present']!.toDouble();
      if (s['absent']! > maxValue) maxValue = s['absent']!.toDouble();
    }
    final maxY = maxValue == 0 ? 4.0 : (maxValue * 1.2).ceilToDouble();
    final interval = maxY / 4;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > maxY) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    Bn.number(value),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 10, color: AppColors.inkFaint),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= months.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    Bn.monthName(months[index].month, short: true),
                    style: const TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.border,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.ink,
            tooltipRoundedRadius: AppRadius.sm,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${Bn.monthName(months[group.x].month)}\n'
              '${rodIndex == 0 ? 'উপস্থিত' : 'অনুপস্থিত'} ${Bn.number(rod.toY)} দিন',
              const TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
            ),
          ),
        ),
        barGroups: List.generate(months.length, (i) {
          return BarChartGroupData(
            x: i,
            barsSpace: 4,
            barRods: [
              _bar(stats[i]['present']!.toDouble(), AppColors.success, maxY),
              _bar(stats[i]['absent']!.toDouble(), AppColors.danger, maxY),
            ],
          );
        }),
      ),
    );
  }

  static BarChartRodData _bar(double value, Color color, double maxY) => BarChartRodData(
        toY: value,
        color: color,
        width: 10,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        backDrawRodData: BackgroundBarChartRodData(
          show: true,
          toY: maxY,
          color: color.withValues(alpha: 0.07),
        ),
      );
}

class _IncomeChart extends StatelessWidget {
  final List<DateTime> months;
  final FeeProvider feeProvider;
  const _IncomeChart({required this.months, required this.feeProvider});

  @override
  Widget build(BuildContext context) {
    double maxValue = 0;
    for (final m in months) {
      final c = feeProvider.totalCollectedForMonth(m);
      final d = feeProvider.totalDueForMonth(m);
      if (c > maxValue) maxValue = c;
      if (d > maxValue) maxValue = d;
    }
    // উপরে একটু ফাঁকা জায়গা রেখে সুন্দর গোল সংখ্যায় নেওয়া।
    final maxY = maxValue == 0 ? 1000.0 : _roundUpNicely(maxValue * 1.15);
    final interval = maxY / 4;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > maxY) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    Bn.number(value),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 10, color: AppColors.inkFaint),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= months.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    Bn.monthName(months[index].month, short: true),
                    style: const TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.border,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.ink,
            tooltipRoundedRadius: AppRadius.sm,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${Bn.monthName(months[group.x].month)}\n'
              '${rodIndex == 0 ? 'আদায়' : 'বাকি'} ${Bn.taka(rod.toY)}',
              const TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
            ),
          ),
        ),
        barGroups: List.generate(months.length, (i) {
          final collected = feeProvider.totalCollectedForMonth(months[i]);
          final due = feeProvider.totalDueForMonth(months[i]);
          return BarChartGroupData(
            x: i,
            barsSpace: 4,
            barRods: [
              _rod(collected, AppColors.success, maxY),
              _rod(due, AppColors.warning, maxY),
            ],
          );
        }),
      ),
    );
  }

  static BarChartRodData _rod(double value, Color color, double maxY) => BarChartRodData(
        toY: value,
        color: color,
        width: 10,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        backDrawRodData: BackgroundBarChartRodData(
          show: true,
          toY: maxY,
          color: color.withValues(alpha: 0.07),
        ),
      );

  /// ৪৩২১ → ৫০০০ এর মতো পড়তে সহজ সংখ্যায় গোল করে।
  static double _roundUpNicely(double value) {
    if (value <= 0) return 1000;
    final magnitude = _pow10((value.abs()).floor().toString().length - 1);
    final step = magnitude / 2;
    return (value / step).ceil() * step;
  }

  static double _pow10(int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }
}

class _DueStudentRow extends StatelessWidget {
  final Student student;
  final double due;
  const _DueStudentRow({required this.student, required this.due});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StudentDetailScreen(studentId: student.id)),
      ),
      child: Row(
        children: [
          GradientAvatar(name: student.name, size: 38, radius: AppRadius.sm, fontSize: 15),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                Text(
                  '${student.className}  ·  ${student.subject}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusPill(
            label: Bn.taka(due),
            color: AppColors.warning,
            background: AppColors.warningBg,
            fontSize: 12.5,
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
      ],
    );
  }
}
