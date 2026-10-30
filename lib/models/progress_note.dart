import 'package:uuid/uuid.dart';
import '../utils/firestore_utils.dart';

class ProgressNote {
  final String id;
  final String tutorId;
  final String studentId;
  DateTime date;
  String topic;
  double? marks;
  double? outOf;
  String remarks;
  String homework;

  ProgressNote({
    String? id,
    this.tutorId = '',
    required this.studentId,
    required this.date,
    required this.topic,
    this.marks,
    this.outOf,
    this.remarks = '',
    this.homework = '',
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'tutorId': tutorId,
        'studentId': studentId,
        'date': date,
        'topic': topic,
        'marks': marks,
        'outOf': outOf,
        'remarks': remarks,
        'homework': homework,
      };

  factory ProgressNote.fromJson(String id, Map<String, dynamic> json) => ProgressNote(
        id: id,
        tutorId: json['tutorId'] as String? ?? '',
        studentId: json['studentId'] as String,
        date: parseFsDate(json['date']),
        topic: json['topic'] as String,
        marks: json['marks'] != null ? (json['marks'] as num).toDouble() : null,
        outOf: json['outOf'] != null ? (json['outOf'] as num).toDouble() : null,
        remarks: json['remarks'] as String? ?? '',
        homework: json['homework'] as String? ?? '',
      );
}
