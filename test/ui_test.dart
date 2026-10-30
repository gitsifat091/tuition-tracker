// UI regression টেস্ট — যে দুটো বাগ রিপোর্ট করা হয়েছিল সেগুলো যেন ফিরে না আসে।
//
// এই widget গুলো Firebase ছাড়াই আঁকা যায়, তাই টেস্টে চালানো সম্ভব।
// Flutter এর টেস্টে RenderFlex overflow হলে টেস্ট নিজেই ফেল করে — অর্থাৎ
// "লেখা কেটে যাচ্ছে / বক্সের বাইরে যাচ্ছে" ধরা পড়বে।

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:tuition_tracker/config/app_features.dart';
import 'package:tuition_tracker/models/attendance.dart';
import 'package:tuition_tracker/models/exam.dart';
import 'package:tuition_tracker/models/student.dart';
import 'package:tuition_tracker/widgets/exam_tab.dart';
import 'package:tuition_tracker/theme/app_theme.dart';
import 'package:tuition_tracker/utils/bn.dart';
import 'package:tuition_tracker/widgets/common/attendance_calendar.dart';
import 'package:tuition_tracker/widgets/common/ui_kit.dart';
import 'package:tuition_tracker/widgets/student_card.dart';

void main() {
  setUpAll(() {
    // টেস্টে ফন্ট ডাউনলোড করতে দেওয়া হয় না — নইলে HTTP কল করার চেষ্টা করবে।
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child, {Size size = const Size(390, 844)}) {
    return MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  Widget calendar() => AttendanceCalendar(
        focusedDay: DateTime(2026, 8, 24),
        selectedDay: DateTime(2026, 8, 24),
        onFocusedDayChanged: (_) {},
        onDaySelected: (_, __) {},
        statusFor: (day) => day.day.isEven ? AttendanceStatus.present : null,
        hasNote: (day) => day.day % 5 == 0,
      );

  group('ক্যালেন্ডার — সপ্তাহের নাম', () {
    testWidgets('সাতটা বারের নামই বাংলায় দেখায়', (tester) async {
      await tester.pumpWidget(wrap(calendar()));
      await tester.pumpAndSettle();

      for (final day in Bn.weekDaysShort) {
        expect(
          find.text(day),
          findsWidgets,
          reason: '"$day" ক্যালেন্ডারের হেডারে থাকা উচিত',
        );
      }
    });

    testWidgets('বারের নামের জন্যে বরাদ্দ উচ্চতা লেখার চেয়ে বেশি — কাটবে না', (tester) async {
      await tester.pumpWidget(wrap(calendar()));
      await tester.pumpAndSettle();

      final table = tester.widget<TableCalendar>(find.byType(TableCalendar));

      // table_calendar এর ডিফল্ট ১৬.০ — বাংলা যুক্তাক্ষরের জন্যে যথেষ্ট নয়,
      // এটাই "সপ্তাহের নাম কেটে দেখাচ্ছে" বাগের কারণ ছিল।
      expect(
        table.daysOfWeekHeight,
        greaterThanOrEqualTo(24.0),
        reason: 'বাংলা বারের নামের জন্যে অন্তত ২৪ পিক্সেল দরকার',
      );

      // সবচেয়ে লম্বা নামটা ("বৃহঃ") আসলেই বরাদ্দ জায়গায় আঁটছে কি না।
      final textHeight = tester.getSize(find.text('বৃহঃ').first).height;
      expect(
        textHeight,
        lessThanOrEqualTo(table.daysOfWeekHeight),
        reason: 'লেখার উচ্চতা বরাদ্দ উচ্চতার বেশি হলে উপর-নিচ কেটে যাবে',
      );
    });

    testWidgets('সপ্তাহ শনিবার থেকে শুরু', (tester) async {
      await tester.pumpWidget(wrap(calendar()));
      await tester.pumpAndSettle();

      final table = tester.widget<TableCalendar>(find.byType(TableCalendar));
      expect(table.startingDayOfWeek, StartingDayOfWeek.saturday);
    });

    testWidgets('ছোট স্ক্রিনেও overflow হয় না', (tester) async {
      // ছোট ফোন (320dp চওড়া) — এখানেই আগে হলুদ-কালো overflow দাগ উঠত।
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(calendar(), size: const Size(320, 640)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('ছাত্রের কার্ড', () {
    Student student({String name = 'আব্দুস সামাদ সিফাত'}) => Student(
          name: name,
          className: 'ক্লাস ৯',
          subject: 'উচ্চতর গণিত',
          monthlyFee: 2500,
          classDays: const ['শনি', 'সোম', 'বুধ'],
          classTime: '5:00 PM',
        );

    Future<void> pumpCard(WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          Padding(
            padding: const EdgeInsets.all(16),
            child: StudentCard(
              student: student(),
              dueMonths: 3,
              presentRate: 0.6,
              onTap: () {},
            ),
          ),
          size: const Size(320, 640),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('লম্বা নাম আর সব ব্যাজ থাকলেও overflow হয় না', (tester) async {
      await pumpCard(tester);

      expect(tester.takeException(), isNull);
      // ফি লুকানো থাকুক বা না থাকুক, বাকি তথ্য সবসময় থাকবে।
      expect(find.text('৬০% উপস্থিত'), findsOneWidget);
    });

    testWidgets('ফি এর অংশ AppFeatures.feesEnabled মেনে চলে', (tester) async {
      await pumpCard(tester);

      final feeChip = find.text('৳২৫০০');
      final dueBadge = find.text('৩ মাস বাকি');

      if (AppFeatures.feesEnabled) {
        expect(feeChip, findsOneWidget);
        expect(dueBadge, findsOneWidget);
      } else {
        // flag বন্ধ — dueMonths পাঠানো হলেও কার্ডে ফি এর কিছু দেখা যাবে না।
        expect(feeChip, findsNothing);
        expect(dueBadge, findsNothing);
      }
    });
  });

  group('পরীক্ষার কার্ড', () {
    Exam exam({int daysFromNow = 5, String syllabus = ''}) {
      final now = DateTime.now();
      return Exam(
        studentId: 's1',
        subject: 'উচ্চতর গণিত ২য় পত্র',
        examName: 'অর্ধবার্ষিক পরীক্ষা',
        date: DateTime(now.year, now.month, now.day).add(Duration(days: daysFromNow)),
        startTime: '10:00 AM',
        endTime: '12:00 PM',
        syllabus: syllabus,
      );
    }

    testWidgets('লম্বা বিষয় ও সিলেবাস থাকলেও ছোট স্ক্রিনে overflow হয় না',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          Padding(
            padding: const EdgeInsets.all(16),
            child: ExamCard(
              exam: exam(syllabus: 'অধ্যায় ৩, ৪, ৭ — সব উদাহরণ ও অনুশীলনী সহ'),
            ),
          ),
          size: const Size(320, 640),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('উচ্চতর গণিত ২য় পত্র'), findsOneWidget);
      expect(find.text('10:00 AM – 12:00 PM'), findsOneWidget);
    });

    testWidgets('কাউন্টডাউন বাংলায় ঠিকভাবে দেখায়', (tester) async {
      await tester.pumpWidget(
        wrap(
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ExamCard(exam: exam(daysFromNow: 0)),
                ExamCard(exam: exam(daysFromNow: 1)),
                ExamCard(exam: exam(daysFromNow: 5)),
                ExamCard(exam: exam(daysFromNow: -2)),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('আজ'), findsOneWidget);
      expect(find.text('আগামীকাল'), findsOneWidget);
      expect(find.text('আর ৫ দিন'), findsOneWidget);
      expect(find.text('২ দিন আগে'), findsOneWidget);
    });
  });

  group('UI kit', () {
    testWidgets('StatTile বড় অঙ্কেও ভাঙে না', (tester) async {
      await tester.pumpWidget(
        wrap(
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.payments_outlined,
                    value: '৳১২৩৪৫৬৭',
                    label: 'মোট প্রত্যাশিত',
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    icon: Icons.people_outline,
                    value: '৳৯৮৭৬৫',
                    label: 'এই মাসে আদায়',
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          size: const Size(320, 640),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
