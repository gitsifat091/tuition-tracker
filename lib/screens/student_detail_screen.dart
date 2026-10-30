import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_features.dart';
import '../models/student.dart';
import '../providers/attendance_provider.dart';
import '../providers/fee_provider.dart';
import '../providers/student_provider.dart';
import '../providers/syllabus_provider.dart';
import '../theme/app_theme.dart';
import '../utils/bn.dart';
import '../widgets/attendance_tab.dart';
import '../widgets/common/ui_kit.dart';
import '../widgets/exam_tab.dart';
import '../widgets/fee_tab.dart';
import '../widgets/progress_notes_tab.dart';
import '../widgets/syllabus_tab.dart';
import 'add_student_screen.dart';

class StudentDetailScreen extends StatelessWidget {
  final String studentId;
  const StudentDetailScreen({super.key, required this.studentId});

  Future<void> _archive(BuildContext context, Student student) async {
    final provider = context.read<StudentProvider>();
    if (student.isArchived) {
      await provider.unarchiveStudent(student.id);
      if (context.mounted) showSnack(context, '${student.name} আবার সক্রিয় করা হয়েছে');
      return;
    }

    final ok = await confirmDialog(
      context,
      title: 'আর্কাইভ করবে?',
      message: '${student.name} কে সক্রিয় তালিকা থেকে সরানো হবে, কিন্তু সব ডেটা '
          '(attendance/fee/note/syllabus) থেকে যাবে। পরে চাইলে আবার সক্রিয় করা যাবে।',
      confirmLabel: 'আর্কাইভ',
    );
    if (!ok || !context.mounted) return;

    await provider.archiveStudent(student.id);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _delete(BuildContext context, Student student) async {
    final ok = await confirmDialog(
      context,
      title: 'স্থায়ীভাবে ডিলিট করবে?',
      message: '${student.name} এর প্রোফাইল সহ সব attendance/fee/note/syllabus ডেটা '
          'স্থায়ীভাবে মুছে যাবে, ফেরত আনা যাবে না। তুইশন ছেড়ে দিলে ডিলিটের বদলে '
          'আর্কাইভ করাই ভালো।',
      confirmLabel: 'ডিলিট',
      destructive: true,
    );
    if (!ok || !context.mounted) return;

    await context.read<StudentProvider>().deleteStudent(student.id);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<StudentProvider>().getById(studentId);

    if (student == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.person_off_outlined,
          title: 'ছাত্র পাওয়া যায়নি',
          message: 'হয়তো এই প্রোফাইলটা মুছে ফেলা হয়েছে।',
        ),
      );
    }

    // ট্যাবের নাম আর তার পর্দা একসাথে এক তালিকায় — আগে দুই জায়গায় আলাদা
    // লেখা ছিল আর `length: 5` হাতে বসানো ছিল, ফলে একটা ট্যাব লুকালেই
    // সংখ্যা না মিললে ক্র্যাশ করত।
    final tabs = <({String label, Widget view})>[
      (label: 'তথ্য', view: _InfoTab(student: student)),
      (label: 'উপস্থিতি', view: AttendanceTab(student: student)),
      if (AppFeatures.feesEnabled) (label: 'ফি', view: FeeTab(student: student)),
      (label: 'নোট', view: ProgressNotesTab(student: student)),
      (label: 'পরীক্ষা', view: ExamTab(student: student)),
      (label: 'সিলেবাস', view: SyllabusTab(student: student)),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(student.name, overflow: TextOverflow.ellipsis),
          actions: [
            // আগে তিনটা আলাদা আইকন বাটন ছিল, লম্বা নামের পাশে ভিড় করত।
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'আরও',
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddStudentScreen(existing: student)),
                    );
                  case 'archive':
                    _archive(context, student);
                  case 'delete':
                    _delete(context, student);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined, size: 19),
                    title: Text('তথ্য এডিট করো'),
                  ),
                ),
                PopupMenuItem(
                  value: 'archive',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      student.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                      size: 19,
                    ),
                    title: Text(student.isArchived ? 'আবার সক্রিয় করো' : 'আর্কাইভ করো'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline, size: 19, color: AppColors.danger),
                    title: Text('স্থায়ীভাবে ডিলিট', style: TextStyle(color: AppColors.danger)),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            tabs: [for (final tab in tabs) Tab(text: tab.label)],
          ),
        ),
        body: TabBarView(
          children: [for (final tab in tabs) tab.view],
        ),
      ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  final Student student;
  const _InfoTab({required this.student});

  @override
  Widget build(BuildContext context) {
    final feeProvider = context.watch<FeeProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();
    final syllabusProvider = context.watch<SyllabusProvider>();
    final now = DateTime.now();

    final dueTotal = feeProvider.totalDueForStudent(student.id);
    final rate = attendanceProvider.presentRateForMonth(student.id, now);
    final classCount =
        attendanceProvider.monthlyStats(student.id, now.year, now.month)['total']!;
    final syllabusItems = syllabusProvider.forStudent(student.id);
    final syllabusProgress = syllabusProvider.progressFor(student.id);

    final scheduleText =
        student.classDays.isNotEmpty ? student.classDays.join(', ') : 'দেওয়া হয়নি';

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 40),
      children: [
        // প্রোফাইল হেডার
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: AppRadius.xlAll,
            boxShadow: AppColors.liftedShadow,
          ),
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                alignment: Alignment.center,
                child: Text(
                  student.name.trim().isNotEmpty ? student.name.trim()[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 27,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                student.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  height: 1.35,
                ),
              ),
              Text(
                '${student.className}  ·  ${student.subject}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              if (student.isArchived) ...[
                const SizedBox(height: AppSpacing.sm),
                const StatusPill(
                  label: 'আর্কাইভ করা',
                  color: Colors.white,
                  background: Color(0x33FFFFFF),
                  icon: Icons.archive_outlined,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // এক নজরে
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.event_available_outlined,
                value: rate == null ? '—' : '${Bn.number((rate * 100).round())}%',
                label: 'এ মাসে উপস্থিত',
                color: rate == null
                    ? AppColors.inkMuted
                    : (rate >= 0.75 ? AppColors.success : AppColors.warning),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            if (AppFeatures.feesEnabled) ...[
              Expanded(
                child: StatTile(
                  icon: Icons.payments_outlined,
                  value: Bn.taka(dueTotal),
                  label: 'মোট বাকি',
                  color: dueTotal > 0 ? AppColors.warning : AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ] else ...[
              Expanded(
                child: StatTile(
                  icon: Icons.event_note_outlined,
                  value: Bn.number(classCount),
                  label: 'এ মাসে ক্লাস',
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: StatTile(
                icon: Icons.checklist_outlined,
                value: syllabusItems.isEmpty
                    ? '—'
                    : '${Bn.number((syllabusProgress * 100).round())}%',
                label: 'সিলেবাস শেষ',
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        const SectionTitle(title: 'বিস্তারিত'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              if (AppFeatures.feesEnabled) ...[
                InfoRow(
                  icon: Icons.payments_outlined,
                  label: 'মাসিক ফি',
                  value: Bn.taka(student.monthlyFee),
                ),
                const Divider(indent: 46),
              ],
              InfoRow(
                icon: Icons.phone_outlined,
                label: 'অভিভাবকের নম্বর',
                value: student.parentPhone?.trim().isNotEmpty == true
                    ? student.parentPhone!
                    : 'দেওয়া হয়নি',
                onTap: student.parentPhone?.trim().isNotEmpty == true
                    ? () => _call(context, student.parentPhone!)
                    : null,
              ),
              const Divider(indent: 46),
              InfoRow(
                icon: Icons.event_repeat,
                label: 'ক্লাসের দিন',
                value: scheduleText,
              ),
              const Divider(indent: 46),
              InfoRow(
                icon: Icons.access_time,
                label: 'ক্লাসের সময়',
                value: student.classTime?.trim().isNotEmpty == true
                    ? student.classTime!
                    : 'দেওয়া হয়নি',
              ),
              const Divider(indent: 46),
              InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'পড়ানো শুরু',
                value: Bn.date(student.joinDate),
              ),
              if (student.isArchived && student.archivedDate != null) ...[
                const Divider(indent: 46),
                InfoRow(
                  icon: Icons.event_busy_outlined,
                  label: 'তুইশন ছেড়েছে',
                  value: Bn.date(student.archivedDate!),
                  valueColor: AppColors.danger,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionTitle(title: 'ছাত্রের অ্যাপ অ্যাকসেস'),
        _InviteCard(student: student),
      ],
    );
  }

  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      showSnack(context, 'ফোন অ্যাপ খোলা যায়নি', isError: true);
    }
  }
}

class _InviteCard extends StatelessWidget {
  final Student student;
  const _InviteCard({required this.student});

  Future<void> _sendInvite(BuildContext context) async {
    final phone = student.parentPhone;
    if (phone == null || phone.trim().isEmpty) {
      showSnack(context, 'অভিভাবকের নম্বর দেওয়া নেই', isError: true);
      return;
    }
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final message = Uri.encodeComponent(
      'টিউশন ট্র্যাকার অ্যাপে ${student.name} এর জন্যে ইনভাইট কোড: ${student.inviteCode}\n'
      'অ্যাপে গিয়ে "ছাত্র/ছাত্রী" বেছে অ্যাকাউন্ট বানিয়ে এই কোডটা দাও।',
    );
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$message');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      showSnack(context, 'WhatsApp খোলা যায়নি', isError: true);
    }
  }

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: student.inviteCode!));
    showSnack(context, 'কোড কপি হয়েছে');
  }

  @override
  Widget build(BuildContext context) {
    final linked = student.linkedUserId != null;
    final code = student.inviteCode;

    if (linked) {
      return AppCard(
        color: AppColors.successBg,
        borderColor: AppColors.success.withValues(alpha: 0.25),
        elevated: false,
        child: const Row(
          children: [
            Icon(Icons.verified_outlined, color: AppColors.success, size: 20),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'ছাত্র/ছাত্রী নিজের অ্যাকাউন্ট দিয়ে অ্যাপে লিংক করে ফেলেছে',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      color: AppColors.primary.withValues(alpha: 0.04),
      borderColor: AppColors.primary.withValues(alpha: 0.15),
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.key_outlined, color: AppColors.primary, size: 18),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'স্টুডেন্ট ইনভাইট কোড',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'এই কোড দিয়ে ছাত্র নিজের অ্যাকাউন্ট বানিয়ে নিজের উপস্থিতি, ফি আর নোট দেখতে পারবে।',
            style: TextStyle(fontSize: 12, color: AppColors.inkMuted, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.smAll,
                    border: Border.all(color: AppColors.border),
                  ),
                  // কোডটা ইচ্ছে করেই ইংরেজি অঙ্কে — ছাত্র এটাই হুবহু টাইপ করবে।
                  child: Text(
                    code ?? '—',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 19,
                      letterSpacing: 5,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: code == null ? null : () => _copyCode(context),
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'কপি করো',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: code == null ? null : () => _sendInvite(context),
              icon: const Icon(Icons.send_outlined, size: 16),
              label: const Text('WhatsApp এ কোড পাঠাও'),
            ),
          ),
        ],
      ),
    );
  }
}
