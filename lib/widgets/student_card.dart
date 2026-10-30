import 'package:flutter/material.dart';
import '../config/app_features.dart';
import '../models/student.dart';
import '../theme/app_theme.dart';
import '../utils/bn.dart';
import 'common/ui_kit.dart';

class StudentCard extends StatelessWidget {
  final Student student;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// কত মাসের ফি বাকি — ০ হলে ব্যাজ দেখানো হয় না।
  final int dueMonths;

  /// চলতি মাসে উপস্থিতির হার (০–১), কোনো ক্লাস না থাকলে `null`।
  final double? presentRate;

  const StudentCard({
    super.key,
    required this.student,
    required this.onTap,
    this.onLongPress,
    this.dueMonths = 0,
    this.presentRate,
  });

  @override
  Widget build(BuildContext context) {
    final schedule = [
      if (student.classDays.isNotEmpty) student.classDays.join(', '),
      if (student.classTime != null && student.classTime!.isNotEmpty) student.classTime!,
    ].join('  ·  ');

    return AppCard(
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GradientAvatar(name: student.name),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        height: 1.35,
                      ),
                    ),
                    Text(
                      '${student.className}  ·  ${student.subject}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (AppFeatures.feesEnabled) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Text(
                    Bn.taka(student.monthlyFee),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.primary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (schedule.isNotEmpty ||
              presentRate != null ||
              (AppFeatures.feesEnabled && dueMonths > 0)) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (schedule.isNotEmpty)
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 13,
                          color: AppColors.primary.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            schedule,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.primary.withValues(alpha: 0.9),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Spacer(),
                if (presentRate != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  StatusPill(
                    label: '${Bn.number((presentRate! * 100).round())}% উপস্থিত',
                    icon: Icons.event_available_outlined,
                    color: presentRate! >= 0.75 ? AppColors.success : AppColors.warning,
                    background: presentRate! >= 0.75
                        ? AppColors.successBg
                        : AppColors.warningBg,
                    fontSize: 10.5,
                  ),
                ],
                if (AppFeatures.feesEnabled && dueMonths > 0) ...[
                  const SizedBox(width: AppSpacing.sm),
                  StatusPill(
                    label: '${Bn.number(dueMonths)} মাস বাকি',
                    icon: Icons.error_outline,
                    color: AppColors.warning,
                    background: AppColors.warningBg,
                    fontSize: 10.5,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
