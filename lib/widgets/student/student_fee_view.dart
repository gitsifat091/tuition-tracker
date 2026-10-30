import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/student.dart';
import '../../models/fee_record.dart';
import '../../theme/app_theme.dart';
import '../../utils/bn.dart';
import '../common/ui_kit.dart';

class StudentFeeView extends StatelessWidget {
  final Student profile;
  const StudentFeeView({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('fees')
          .where('studentId', isEqualTo: profile.id)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // শিক্ষকের দিকের মতোই ছাঁকা — নইলে পুরনো ডুপ্লিকেটগুলোর জন্যে ছাত্র
        // একই মাস কয়েকবার আর বাকির অঙ্ক কয়েকগুণ বেশি দেখত।
        final records = dedupeFeeRecords(
          snap.data!.docs.map((d) => FeeRecord.fromJson(d.id, d.data())).toList(),
        )..sort((a, b) => b.month.compareTo(a.month));

        if (records.isEmpty) {
          return const EmptyState(
            icon: Icons.payments_outlined,
            title: 'এখনো কোনো ফি রেকর্ড নেই',
            message: 'টিউটর ফি যোগ করলে এখানে দেখা যাবে।',
          );
        }

        final paidTotal = records
            .where((r) => r.status == FeeStatus.paid)
            .fold<double>(0, (total, r) => total + r.amount);
        final dueTotal = records
            .where((r) => r.status == FeeStatus.due)
            .fold<double>(0, (total, r) => total + r.amount);

        final grouped = <int, List<FeeRecord>>{};
        for (final r in records) {
          grouped.putIfAbsent(Bn.yearOfMonthKey(r.month) ?? 0, () => []).add(r);
        }
        final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 40),
          children: [
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.check_circle_outline,
                    value: Bn.taka(paidTotal),
                    label: 'মোট পরিশোধিত',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    icon: Icons.schedule,
                    value: Bn.taka(dueTotal),
                    label: 'মোট বাকি',
                    color: dueTotal > 0 ? AppColors.warning : AppColors.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            for (final year in years) ...[
              SectionTitle(title: Bn.number(year)),
              for (final record in grouped[year]!) ...[
                _StudentFeeRow(record: record),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}

class _StudentFeeRow extends StatelessWidget {
  final FeeRecord record;
  const _StudentFeeRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final isPaid = record.status == FeeStatus.paid;
    final accent = isPaid ? AppColors.success : AppColors.warning;
    final accentBg = isPaid ? AppColors.successBg : AppColors.warningBg;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: isPaid ? AppColors.border : AppColors.warning.withValues(alpha: 0.28),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: accentBg, borderRadius: AppRadius.smAll),
            alignment: Alignment.center,
            child: Icon(
              isPaid ? Icons.check_rounded : Icons.schedule,
              size: 20,
              color: accent,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Bn.monthKeyMonthOnly(record.month),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
                const SizedBox(height: 2),
                Text(
                  isPaid && record.paidDate != null
                      ? '${Bn.taka(record.amount)}  ·  ${Bn.dateShort(record.paidDate!)}'
                      : Bn.taka(record.amount),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusPill(
            label: isPaid ? 'পরিশোধিত' : 'বাকি',
            color: accent,
            background: accentBg,
            fontSize: 12,
          ),
        ],
      ),
    );
  }
}
