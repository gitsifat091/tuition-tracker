import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_features.dart';
import '../../models/student.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/auth_dialogs.dart';
import '../../widgets/common/ui_kit.dart';
import '../../widgets/student/student_overview_view.dart';
import '../../widgets/student/student_attendance_view.dart';
import '../../widgets/student/student_fee_view.dart';
import '../../widgets/student/student_exam_view.dart';
import '../../widgets/student/student_notes_view.dart';
import '../../widgets/student/student_syllabus_view.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authUser = context.watch<AuthProvider>().user;

    if (authUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ট্যাবের নাম আর তার পর্দা একসাথে — ফি লুকালে সংখ্যা নিজেই মিলে যায়।
    // এখানে view গুলো profile পাওয়ার পর বানাতে হয়, তাই শুধু লেবেল আগে।
    final tabLabels = <String>[
      'ওভারভিউ',
      'উপস্থিতি',
      if (AppFeatures.feesEnabled) 'ফি',
      'নোট',
      'পরীক্ষা',
      'সিলেবাস',
    ];

    return DefaultTabController(
      length: tabLabels.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(authUser.name.isEmpty ? 'আমার ড্যাশবোর্ড' : authUser.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'লগআউট',
              onPressed: () => confirmAndSignOut(context),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            tabs: [for (final label in tabLabels) Tab(text: label)],
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('students')
              .where('linkedUserId', isEqualTo: authUser.uid)
              .limit(1)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'ডেটা আনা যায়নি',
                message: 'ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করো।\n${snap.error}',
              );
            }
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const _NotLinkedState();
            }

            final doc = snap.data!.docs.first;
            final profile = Student.fromJson(doc.id, doc.data());

            return TabBarView(
              children: [
                StudentOverviewView(profile: profile),
                StudentAttendanceView(profile: profile),
                if (AppFeatures.feesEnabled) StudentFeeView(profile: profile),
                StudentNotesView(profile: profile),
                StudentExamView(profile: profile),
                StudentSyllabusView(profile: profile),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NotLinkedState extends StatelessWidget {
  const _NotLinkedState();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.link_off,
      title: 'কোনো প্রোফাইলের সাথে লিংক হয়নি',
      message: 'তোমার টিউটরের কাছ থেকে ইনভাইট কোড নিয়ে সাইনআপের সময় সঠিকভাবে দিতে হবে। '
          'কোড ভুল হলে বা এই অ্যাকাউন্ট আগে কোনো প্রোফাইলে ব্যবহার না হলে এই বার্তা দেখাবে।',
    );
  }
}
