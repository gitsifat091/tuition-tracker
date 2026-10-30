// অ্যাপের বিশুদ্ধ (Firebase ছাড়া) অংশগুলোর টেস্ট।
//
// আগে এখানে Flutter এর ডিফল্ট counter টেস্ট ছিল, যেটা `MyApp` খুঁজত —
// এই অ্যাপে সেই ক্লাস নেই, তাই `flutter analyze` সবসময় একটা error দিত।
// পুরো অ্যাপ চালাতে হলে Firebase initialize লাগে, তাই তার বদলে যে যুক্তিগুলোতে
// আসল বাগ ছিল সেগুলোই পরীক্ষা করা হচ্ছে।

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuition_tracker/models/exam.dart';
import 'package:tuition_tracker/utils/time_format.dart';
import 'package:tuition_tracker/models/fee_record.dart';
import 'package:tuition_tracker/models/student.dart';
import 'package:tuition_tracker/providers/attendance_provider.dart';
import 'package:tuition_tracker/providers/fee_provider.dart';
import 'package:tuition_tracker/utils/bn.dart';
import 'package:tuition_tracker/utils/launcher.dart';

void main() {
  group('Bn — বাংলা ফরম্যাট', () {
    test('অঙ্ক বাংলায় বদলায়', () {
      expect(Bn.number(1250), '১২৫০');
      expect(Bn.taka(0), '৳০');
    });

    test('বাংলা অঙ্ক আবার ইংরেজিতে ফেরে', () {
      expect(Bn.toAsciiDigits('৪২৩৯৮১'), '423981');
      expect(Bn.toAsciiDigits('423981'), '423981');
    });

    test('month key ঠিকভাবে পড়ে', () {
      expect(Bn.monthKeyLabel('2026-08'), 'আগস্ট ২০২৬');
      expect(Bn.yearOfMonthKey('2026-08'), 2026);
    });

    test('ভাঙা month key তে ক্র্যাশ করে না', () {
      // আগে `int.parse(parts[1])` সরাসরি চালানো হতো, তাই RangeError হতো।
      expect(Bn.monthKeyLabel('2026'), '2026');
      expect(Bn.monthKeyLabel(''), '');
      expect(Bn.monthKeyLabel('2026-99'), '2026-99');
    });
  });

  group('ফি রেকর্ডের ডুপ্লিকেট', () {
    FeeRecord make(String id, String month, FeeStatus status) => FeeRecord(
          id: id,
          studentId: 's1',
          month: month,
          amount: 1000,
          status: status,
        );

    test('একই মাসের একাধিক রেকর্ড থেকে একটাই থাকে', () {
      final raw = [
        make('a', '2026-08', FeeStatus.due),
        make('b', '2026-08', FeeStatus.due),
        make('c', '2026-07', FeeStatus.due),
      ];
      final extras = <String>[];
      final result = dedupeFeeRecords(raw, extrasOut: extras);

      expect(result.length, 2);
      expect(extras.length, 1);
    });

    test('পরিশোধিত রেকর্ডটাই রাখা হয়, টাকার হিসাব যেন না হারায়', () {
      final raw = [
        make('a', '2026-08', FeeStatus.due),
        make('b', '2026-08', FeeStatus.paid),
        make('c', '2026-08', FeeStatus.due),
      ];
      final result = dedupeFeeRecords(raw);

      expect(result.length, 1);
      expect(result.single.status, FeeStatus.paid);
      expect(result.single.id, 'b');
    });

    test('ডুপ্লিকেট থাকলেও মোট অঙ্ক কয়েকগুণ হয় না', () {
      final raw = List.generate(7, (i) => make('dup$i', '2026-08', FeeStatus.due));
      final result = dedupeFeeRecords(raw);
      final total = result.fold<double>(0, (sum, r) => sum + r.amount);

      expect(total, 1000);
    });

    test('নির্ধারিত doc id একই ছাত্র+মাসে সবসময় একই', () {
      expect(FeeProvider.docIdFor('s1', '2026-08'), FeeProvider.docIdFor('s1', '2026-08'));
      expect(
        FeeProvider.docIdFor('s1', '2026-08') == FeeProvider.docIdFor('s1', '2026-09'),
        isFalse,
      );
    });
  });

  group('উপস্থিতির doc id', () {
    test('একই ছাত্র + একই দিন = একই id', () {
      final a = AttendanceProvider.docIdFor('s1', DateTime(2026, 8, 24, 9));
      final b = AttendanceProvider.docIdFor('s1', DateTime(2026, 8, 24, 21));
      expect(a, b);
    });

    test('আলাদা দিনে আলাদা id', () {
      final a = AttendanceProvider.docIdFor('s1', DateTime(2026, 8, 24));
      final b = AttendanceProvider.docIdFor('s1', DateTime(2026, 8, 25));
      expect(a == b, isFalse);
    });
  });

  group('পরীক্ষার রুটিন', () {
    final today = DateTime(2026, 9, 4);

    Exam exam(DateTime date, {String subject = 'গণিত'}) =>
        Exam(studentId: 's1', subject: subject, date: date);

    test('তারিখে সময় থাকলেও দিন-মাত্র হিসেবে জমা হয়', () {
      final e = exam(DateTime(2026, 9, 10, 14, 30));
      expect(e.date, DateTime(2026, 9, 10));
    });

    test('আজকের পরীক্ষা এখনো "আসন্ন"', () {
      // পরীক্ষার দিন সকালে তালিকা থেকে হারিয়ে গেলে চলবে না।
      expect(exam(today).isPast(today), isFalse);
      expect(exam(today).daysLeft(today), 0);
    });

    test('গতকালের পরীক্ষা শেষ হয়ে গেছে', () {
      final yesterday = DateTime(2026, 9, 3);
      expect(exam(yesterday).isPast(today), isTrue);
      expect(exam(yesterday).daysLeft(today), -1);
    });

    test('কত দিন বাকি ঠিকভাবে গোনে', () {
      expect(exam(DateTime(2026, 9, 9)).daysLeft(today), 5);
    });

    test('সময়ের লেবেল', () {
      final e = exam(today)
        ..startTime = '10:00 AM'
        ..endTime = '12:00 PM';
      expect(e.timeLabel, '10:00 AM – 12:00 PM');

      e.endTime = null;
      expect(e.timeLabel, '10:00 AM');

      e.startTime = null;
      expect(e.timeLabel, '');
    });

    test('JSON এ গিয়ে ফিরে এলেও সব ঠিক থাকে', () {
      final original = Exam(
        studentId: 's1',
        tutorId: 't1',
        subject: 'পদার্থবিজ্ঞান',
        examName: 'অর্ধবার্ষিক পরীক্ষা',
        date: DateTime(2026, 9, 10),
        startTime: '10:00 AM',
        endTime: '12:00 PM',
        syllabus: 'অধ্যায় ৩, ৪',
      );
      final restored = Exam.fromJson(original.id, original.toJson());

      expect(restored.subject, original.subject);
      expect(restored.examName, original.examName);
      expect(restored.date, original.date);
      expect(restored.startTime, original.startTime);
      expect(restored.syllabus, original.syllabus);
    });
  });

  group('সময় parse / format', () {
    test('দুদিকেই একই মান ফেরে', () {
      for (final text in ['5:00 PM', '12:00 AM', '12:30 PM', '9:05 AM']) {
        expect(formatTimeOfDay(parseTimeOfDay(text)), text, reason: text);
      }
    });

    test('দুপুর/মধ্যরাত ঠিকভাবে বোঝে', () {
      expect(parseTimeOfDay('12:00 AM'), const TimeOfDay(hour: 0, minute: 0));
      expect(parseTimeOfDay('12:00 PM'), const TimeOfDay(hour: 12, minute: 0));
      expect(parseTimeOfDay('5:00 PM'), const TimeOfDay(hour: 17, minute: 0));
    });

    test('ভাঙা লেখায় null', () {
      expect(parseTimeOfDay(null), isNull);
      expect(parseTimeOfDay('সকাল ১০টা'), isNull);
      expect(parseTimeOfDay('25:00 PM'), isNull);
    });
  });

  group('Student.copyWith', () {
    Student base() => Student(
          name: 'রাহুল',
          className: 'ক্লাস ৯',
          subject: 'গণিত',
          monthlyFee: 1500,
          parentPhone: '01700000000',
          classTime: '5:00 PM',
        );

    test('না দিলে পুরনো মান থাকে', () {
      final updated = base().copyWith(name: 'রাহুল দাস');
      expect(updated.name, 'রাহুল দাস');
      expect(updated.parentPhone, '01700000000');
      expect(updated.classTime, '5:00 PM');
    });

    test('null দিলে ফোন নম্বর/সময় সত্যিই মুছে যায়', () {
      // আগে `parentPhone ?? this.parentPhone` লেখা ছিল, তাই মোছা যেত না।
      final updated = base().copyWith(parentPhone: null, classTime: null);
      expect(updated.parentPhone, isNull);
      expect(updated.classTime, isNull);
    });
  });

  group('WhatsApp নম্বর', () {
    test('লোকাল বাংলাদেশি নম্বরে দেশের কোড বসে', () {
      expect(whatsAppNumber('01712345678'), '8801712345678');
      expect(whatsAppNumber('017-1234 5678'), '8801712345678');
    });

    test('আগে থেকে দেশের কোড থাকলে বদলায় না', () {
      expect(whatsAppNumber('+8801712345678'), '8801712345678');
      expect(whatsAppNumber('8801712345678'), '8801712345678');
      expect(whatsAppNumber('008801712345678'), '8801712345678');
    });

    test('বাংলা অঙ্কে লেখা নম্বরও কাজ করে', () {
      expect(whatsAppNumber('০১৭১২৩৪৫৬৭৮'), '8801712345678');
    });
  });
}
