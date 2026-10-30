import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/fee_record.dart';
import '../models/student.dart';
import '../providers/fee_provider.dart';
import '../theme/app_theme.dart';
import '../utils/bn.dart';
import 'common/ui_kit.dart';

class FeeTab extends StatefulWidget {
  final Student student;
  const FeeTab({super.key, required this.student});

  @override
  State<FeeTab> createState() => _FeeTabState();
}

class _FeeTabState extends State<FeeTab> {
  /// প্রথম snapshot আসার পর একবারই পেছনের মাসগুলো ভরাট করা হবে।
  bool _backfillStarted = false;

  /// প্রথম snapshot আসার *আগে* পেছনের ৬ মাস "নেই" ধরে নিয়ে বানানোর চেষ্টা করাই
  /// ছিল একই মাস বারবার দেখানোর মূল কারণ। তাই `loaded` না হওয়া পর্যন্ত অপেক্ষা।
  void _backfillIfReady(FeeProvider provider) {
    if (_backfillStarted || !provider.loaded) return;
    _backfillStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      provider.ensureRecentMonths(
        widget.student.id,
        widget.student.monthlyFee,
        notBefore: widget.student.joinDate,
      );
    });
  }

  Future<void> _sendReminder(FeeRecord record) async {
    final phone = widget.student.parentPhone;
    if (phone == null || phone.trim().isEmpty) {
      showSnack(context, 'অভিভাবকের নম্বর দেওয়া নেই', isError: true);
      return;
    }
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final message = Uri.encodeComponent(
      '${widget.student.name} এর ${Bn.monthKeyLabel(record.month)} মাসের টিউশন ফি '
      '${Bn.taka(record.amount)} বাকি আছে। দয়া করে পরিশোধ করুন।',
    );
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$message');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      showSnack(context, 'WhatsApp খোলা যায়নি', isError: true);
    }
  }

  Future<void> _editAmount(FeeRecord record) async {
    final controller = TextEditingController(text: record.amount.toStringAsFixed(0));
    final newAmount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.sm,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${Bn.monthKeyLabel(record.month)} এর ফি',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'ছুটি, বাড়তি ক্লাস বা ছাড় থাকলে এই মাসের অঙ্ক আলাদা করে দাও।',
              style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted, height: 1.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'পরিমাণ (৳)',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('বাতিল'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      final value = double.tryParse(controller.text.trim());
                      if (value == null || value < 0) return;
                      Navigator.pop(ctx, value);
                    },
                    child: const Text('সেভ করুন'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    controller.dispose();

    if (newAmount != null && mounted) {
      await context.read<FeeProvider>().updateAmount(record.id, newAmount);
    }
  }

  /// তালিকার সবচেয়ে পুরনো মাসের আগের আরও ৬ মাস যোগ করে।
  Future<void> _loadOlderMonths(List<FeeRecord> records) async {
    final provider = context.read<FeeProvider>();

    // তালিকা খালি হলে চলতি মাস থেকেই শুরু করতে হবে। আগের-মাস থেকে শুরু করলে
    // এই মাসে ভর্তি হওয়া ছাত্রের ক্ষেত্রে `notBefore` এ আটকে গিয়ে বাটনটা
    // কিছুই না করে বসে থাকত।
    final from = records.isEmpty
        ? DateTime.now()
        : () {
            final oldest = _monthKeyToDate(records.last.month);
            return DateTime(oldest.year, oldest.month - 1, 1);
          }();

    await provider.ensureRecentMonths(
      widget.student.id,
      widget.student.monthlyFee,
      from: from,
      notBefore: widget.student.joinDate,
    );
    if (mounted) setState(() {});
  }

  static DateTime _monthKeyToDate(String key) {
    final parts = key.split('-');
    if (parts.length < 2) return DateTime.now();
    return DateTime(int.tryParse(parts[0]) ?? DateTime.now().year, int.tryParse(parts[1]) ?? 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final feeProvider = context.watch<FeeProvider>();
    _backfillIfReady(feeProvider);

    if (!feeProvider.loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final records = feeProvider.forStudent(widget.student.id);
    final paidTotal = records
        .where((r) => r.status == FeeStatus.paid)
        .fold<double>(0, (total, r) => total + r.amount);
    final dueTotal = records
        .where((r) => r.status == FeeStatus.due)
        .fold<double>(0, (total, r) => total + r.amount);

    if (records.isEmpty) {
      return EmptyState(
        icon: Icons.payments_outlined,
        title: 'এখনো কোনো ফি রেকর্ড নেই',
        message: 'নিচের বাটনে চাপ দিয়ে মাসগুলো যোগ করে নাও।',
        action: FilledButton.icon(
          onPressed: () => _loadOlderMonths(records),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('মাস যোগ করো'),
        ),
      );
    }

    // বছর ধরে ভাগ করা, যাতে অনেক মাস জমলেও তালিকা পড়তে সুবিধা হয়।
    final grouped = <int, List<FeeRecord>>{};
    for (final r in records) {
      grouped.putIfAbsent(Bn.yearOfMonthKey(r.month) ?? 0, () => []).add(r);
    }
    final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
      children: [
        if (feeProvider.duplicateCount > 0) ...[
          _DuplicateBanner(count: feeProvider.duplicateCount),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.check_circle_outline,
                value: Bn.taka(paidTotal),
                label: 'মোট আদায়',
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
            _FeeRow(
              record: record,
              onToggle: (paid) => paid
                  ? feeProvider.markPaid(record.id)
                  : feeProvider.markDue(record.id),
              onRemind: () => _sendReminder(record),
              onEditAmount: () => _editAmount(record),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
        Center(
          child: TextButton.icon(
            onPressed: () => _loadOlderMonths(records),
            icon: const Icon(Icons.history, size: 17),
            label: const Text('আরও আগের মাস দেখাও'),
          ),
        ),
      ],
    );
  }
}

class _FeeRow extends StatelessWidget {
  final FeeRecord record;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemind;
  final VoidCallback onEditAmount;

  const _FeeRow({
    required this.record,
    required this.onToggle,
    required this.onRemind,
    required this.onEditAmount,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = record.status == FeeStatus.paid;
    final accent = isPaid ? AppColors.success : AppColors.warning;
    final accentBg = isPaid ? AppColors.successBg : AppColors.warningBg;

    return AppCard(
      onTap: onEditAmount,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
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
                Row(
                  children: [
                    Text(
                      Bn.taka(record.amount),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isPaid && record.paidDate != null) ...[
                      const Text(
                        '  ·  ',
                        style: TextStyle(fontSize: 13, color: AppColors.inkFaint),
                      ),
                      Flexible(
                        child: Text(
                          Bn.dateShort(record.paidDate!),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.inkFaint),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!isPaid)
            IconButton(
              onPressed: onRemind,
              icon: const Icon(Icons.notifications_active_outlined, size: 20),
              color: AppColors.warning,
              tooltip: 'WhatsApp এ রিমাইন্ডার',
              visualDensity: VisualDensity.compact,
            ),
          Switch(
            value: isPaid,
            onChanged: onToggle,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

/// পুরনো ডেটায় একই মাসের একাধিক রেকর্ড থাকলে দেখানো হয়।
///
/// নতুন কোডে ডুপ্লিকেট আর তৈরি হয় না, কিন্তু বাগ ধরা পড়ার আগে Firestore এ
/// যেগুলো জমেছে সেগুলো থেকেই যাবে — এই ব্যানার থেকে একবারে মুছে ফেলা যায়।
class _DuplicateBanner extends StatefulWidget {
  final int count;
  const _DuplicateBanner({required this.count});

  @override
  State<_DuplicateBanner> createState() => _DuplicateBannerState();
}

class _DuplicateBannerState extends State<_DuplicateBanner> {
  bool _busy = false;

  Future<void> _cleanup() async {
    final ok = await confirmDialog(
      context,
      title: 'বাড়তি রেকর্ড মুছবে?',
      message: 'একই মাসের ${Bn.number(widget.count)} টি বাড়তি রেকর্ড মুছে যাবে। '
          'প্রতি মাসের একটি রেকর্ড থাকবে — পরিশোধিত থাকলে সেটাই রাখা হবে।',
      confirmLabel: 'মুছে ফেলো',
      destructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final removed = await context.read<FeeProvider>().cleanupDuplicates();
      if (mounted) showSnack(context, '${Bn.number(removed)} টি বাড়তি রেকর্ড মুছে ফেলা হয়েছে');
    } catch (e) {
      if (mounted) showSnack(context, 'মোছা যায়নি: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.warningBg,
      borderColor: AppColors.warning.withValues(alpha: 0.3),
      elevated: false,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Row(
        children: [
          const Icon(Icons.cleaning_services_outlined, size: 20, color: AppColors.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'পুরনো ডুপ্লিকেট রেকর্ড আছে',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'সব ছাত্র মিলিয়ে একই মাসের ${Bn.number(widget.count)} টি বাড়তি রেকর্ড '
                  'পাওয়া গেছে। হিসাবে এগুলো আর ধরা হচ্ছে না, চাইলে একবারে মুছে ফেলো।',
                  style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  onPressed: _cleanup,
                  style: TextButton.styleFrom(foregroundColor: AppColors.warning),
                  child: const Text('মুছো'),
                ),
        ],
      ),
    );
  }
}
