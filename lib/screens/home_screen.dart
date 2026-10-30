import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_features.dart';
import '../models/student.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/fee_provider.dart';
import '../providers/student_provider.dart';
import '../theme/app_theme.dart';
import '../utils/auth_dialogs.dart';
import '../utils/bn.dart';
import '../widgets/common/ui_kit.dart';
import '../widgets/student_card.dart';
import 'add_student_screen.dart';
import 'student_detail_screen.dart';
import 'dashboard_screen.dart';
import 'archived_students_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _dayFilter; // null = সব দিন

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Student> _applyFilters(List<Student> students) {
    var result = students;
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      result = result
          .where((s) =>
              s.name.toLowerCase().contains(q) ||
              s.className.toLowerCase().contains(q) ||
              s.subject.toLowerCase().contains(q))
          .toList();
    }
    if (_dayFilter != null) {
      result = result.where((s) => s.classDays.contains(_dayFilter)).toList();
    }
    return result;
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _dayFilter = null;
    });
  }

  void _showQuickActions(Student student) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.sm),
              child: Text(
                student.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('আর্কাইভ করো'),
              subtitle: const Text('তুইশন ছেড়ে দিয়েছে, কিন্তু ডেটা থাকবে'),
              onTap: () async {
                Navigator.pop(ctx);
                await context.read<StudentProvider>().archiveStudent(student.id);
                if (mounted) showSnack(context, '${student.name} আর্কাইভ করা হয়েছে');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text(
                'স্থায়ীভাবে ডিলিট করো',
                style: TextStyle(color: AppColors.danger),
              ),
              subtitle: const Text('এই ছাত্রের সব ডেটা মুছে যাবে, ফেরত আনা যাবে না'),
              onTap: () async {
                Navigator.pop(ctx);
                if (!mounted) return;
                final ok = await confirmDialog(
                  context,
                  title: 'স্থায়ীভাবে ডিলিট করবে?',
                  message: '${student.name} এর প্রোফাইল সহ সব attendance/fee/note/syllabus '
                      'ডেটা স্থায়ীভাবে মুছে যাবে, ফেরত আনা যাবে না। আর্কাইভ করাই ভালো।',
                  confirmLabel: 'ডিলিট',
                  destructive: true,
                );
                if (ok && mounted) {
                  await context.read<StudentProvider>().deleteStudent(student.id);
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentProvider = context.watch<StudentProvider>();
    final feeProvider = context.watch<FeeProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();
    final teacherName = context.watch<AuthProvider>().user?.name ?? '';

    final allStudents = studentProvider.activeStudents;
    final students = _applyFilters(allStudents);
    final hasActiveFilter = _query.isNotEmpty || _dayFilter != null;
    final now = DateTime.now();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Hero(
                teacherName: teacherName,
                studentCount: allStudents.length,
                collected: feeProvider.totalCollectedForMonth(now),
                due: feeProvider.totalDueForMonth(now),
                classCount: attendanceProvider.statsForMonth(
                  now,
                  studentIds: allStudents.map((s) => s.id).toSet(),
                )['total']!,
                presentRate: attendanceProvider.presentRateForAll(
                  now,
                  studentIds: allStudents.map((s) => s.id).toSet(),
                ),
                onDashboard: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                ),
                onArchive: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ArchivedStudentsScreen()),
                ),
                onSignOut: () => confirmAndSignOut(context),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'নাম, ক্লাস বা বিষয় দিয়ে খুঁজুন',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                    isDense: true,
                  ),
                ),
              ),
            ),
            if (allStudents.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    children: [
                      _DayChip(
                        label: 'সব',
                        selected: _dayFilter == null,
                        onTap: () => setState(() => _dayFilter = null),
                      ),
                      for (final day in Bn.weekDaysShort)
                        _DayChip(
                          label: day,
                          selected: _dayFilter == day,
                          onTap: () => setState(
                            () => _dayFilter = _dayFilter == day ? null : day,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
            if (studentProvider.loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (allStudents.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.school_outlined,
                  title: 'এখনো কোনো ছাত্র যোগ করা হয়নি',
                  message: 'নিচের বাটনে ট্যাপ করে প্রথম ছাত্র যোগ করে শুরু করুন।',
                ),
              )
            else if (students.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.search_off,
                  title: 'কিছু পাওয়া যায়নি',
                  message: 'অন্য নাম বা দিন দিয়ে খুঁজে দেখো।',
                  action: hasActiveFilter
                      ? OutlinedButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
                          label: const Text('ফিল্টার মুছুন'),
                        )
                      : null,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 100),
                sliver: SliverList.separated(
                  itemCount: students.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return StudentCard(
                      student: student,
                      dueMonths: feeProvider.dueMonthCountForStudent(student.id),
                      presentRate: attendanceProvider.presentRateForMonth(student.id, now),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentDetailScreen(studentId: student.id),
                        ),
                      ),
                      onLongPress: () => _showQuickActions(student),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddStudentScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('ছাত্র যোগ করুন'),
      ),
    );
  }
}

/// উপরের সবুজ হেডার — শুভেচ্ছা, চলতি মাসের হিসাব আর মূল অ্যাকশনগুলো।
class _Hero extends StatelessWidget {
  final String teacherName;
  final int studentCount;
  final double collected;
  final double due;

  /// ফি লুকানো থাকলে আদায়/বাকির বদলে এই দুটো দেখানো হয়।
  final int classCount;
  final double? presentRate;

  final VoidCallback onDashboard;
  final VoidCallback onArchive;
  final VoidCallback onSignOut;

  const _Hero({
    required this.teacherName,
    required this.studentCount,
    required this.collected,
    required this.due,
    required this.classCount,
    required this.presentRate,
    required this.onDashboard,
    required this.onArchive,
    required this.onSignOut,
  });

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'শুভ রাত্রি';
    if (hour < 12) return 'শুভ সকাল';
    if (hour < 16) return 'শুভ দুপুর';
    if (hour < 19) return 'শুভ বিকাল';
    return 'শুভ সন্ধ্যা';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.md, AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: AppRadius.xlAll,
        boxShadow: AppColors.liftedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      teacherName.isEmpty ? 'টিউশন ট্র্যাকার' : teacherName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              _HeroAction(
                icon: Icons.bar_chart_rounded,
                tooltip: 'ড্যাশবোর্ড',
                onTap: onDashboard,
              ),
              _HeroAction(
                icon: Icons.archive_outlined,
                tooltip: 'আর্কাইভ',
                onTap: onArchive,
              ),
              _HeroAction(
                icon: Icons.logout_rounded,
                tooltip: 'লগআউট',
                onTap: onSignOut,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Row(
              children: [
                _HeroStat(
                  label: 'সক্রিয় ছাত্র',
                  value: Bn.number(studentCount),
                ),
                _HeroDivider(),
                if (AppFeatures.feesEnabled) ...[
                  _HeroStat(
                    label: '${Bn.monthName(now.month, short: true)} আদায়',
                    value: Bn.taka(collected),
                  ),
                  _HeroDivider(),
                  _HeroStat(
                    label: '${Bn.monthName(now.month, short: true)} বাকি',
                    value: Bn.taka(due),
                    highlight: due > 0,
                  ),
                ] else ...[
                  _HeroStat(
                    label: '${Bn.monthName(now.month, short: true)} এ ক্লাস',
                    value: Bn.number(classCount),
                  ),
                  _HeroDivider(),
                  _HeroStat(
                    label: 'গড় উপস্থিতি',
                    value: presentRate == null
                        ? '—'
                        : '${Bn.number((presentRate! * 100).round())}%',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeroAction({required this.icon, required this.tooltip, required this.onTap});

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
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.9)),
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _HeroStat({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: highlight ? const Color(0xFFFFD9A0) : Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      color: Colors.white.withValues(alpha: 0.18),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DayChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : AppColors.inkMuted,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
