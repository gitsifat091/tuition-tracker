import 'package:uuid/uuid.dart';
import '../utils/firestore_utils.dart';

/// একটা পরীক্ষার একটা বিষয় (paper)।
///
/// "অর্ধবার্ষিক পরীক্ষা" এর গণিত আর ইংরেজি — দুটো আলাদা রেকর্ড, দুটোরই
/// `examName` একই। এভাবে রাখায় প্রতিটা বিষয়ের নিজের তারিখ ও সময় থাকতে পারে,
/// আবার চাইলে নাম ধরে একসাথে দেখানোও যায়।
class Exam {
  final String id;
  final String tutorId;
  final String studentId;

  /// কোন বিষয়ের পরীক্ষা — যেমন "গণিত"।
  String subject;

  /// কোন পরীক্ষা — যেমন "অর্ধবার্ষিক পরীক্ষা"। ঐচ্ছিক।
  String examName;

  /// তারিখ (সময় ছাড়া — শুধু year/month/day)।
  DateTime date;

  /// "10:00 AM" ধাঁচে, ঐচ্ছিক।
  String? startTime;
  String? endTime;

  /// কী কী পড়তে হবে। ঐচ্ছিক।
  String syllabus;

  DateTime createdAt;

  Exam({
    String? id,
    this.tutorId = '',
    required this.studentId,
    required this.subject,
    this.examName = '',
    required DateTime date,
    this.startTime,
    this.endTime,
    this.syllabus = '',
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        date = DateTime(date.year, date.month, date.day),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'tutorId': tutorId,
        'studentId': studentId,
        'subject': subject,
        'examName': examName,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'syllabus': syllabus,
        'createdAt': createdAt,
      };

  factory Exam.fromJson(String id, Map<String, dynamic> json) => Exam(
        id: id,
        tutorId: json['tutorId'] as String? ?? '',
        studentId: json['studentId'] as String,
        subject: json['subject'] as String? ?? '',
        examName: json['examName'] as String? ?? '',
        date: parseFsDate(json['date']),
        startTime: json['startTime'] as String?,
        endTime: json['endTime'] as String?,
        syllabus: json['syllabus'] as String? ?? '',
        createdAt: parseFsDate(json['createdAt']),
      );

  /// আজকের দিনটাও "আসন্ন" ধরা হয় — পরীক্ষার দিন সকালে যেন তালিকা থেকে
  /// হারিয়ে না যায়।
  bool isPast([DateTime? now]) {
    final today = now ?? DateTime.now();
    return date.isBefore(DateTime(today.year, today.month, today.day));
  }

  /// আজ থেকে আর কত দিন বাকি। আজ হলে ০, পার হয়ে গেলে ঋণাত্মক।
  int daysLeft([DateTime? now]) {
    final today = now ?? DateTime.now();
    return date.difference(DateTime(today.year, today.month, today.day)).inDays;
  }

  /// "10:00 AM – 12:00 PM" / "10:00 AM" / খালি।
  String get timeLabel {
    final start = startTime?.trim() ?? '';
    final end = endTime?.trim() ?? '';
    if (start.isEmpty && end.isEmpty) return '';
    if (end.isEmpty) return start;
    if (start.isEmpty) return end;
    return '$start – $end';
  }
}
