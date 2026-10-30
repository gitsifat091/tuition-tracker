import 'package:uuid/uuid.dart';
import '../utils/firestore_utils.dart';

enum AttendanceStatus { present, absent }

class AttendanceRecord {
  final String id;
  final String tutorId;
  final String studentId;
  final DateTime date; // stored as date-only (year/month/day)
  AttendanceStatus status;

  AttendanceRecord({
    String? id,
    this.tutorId = '',
    required this.studentId,
    required this.date,
    required this.status,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'tutorId': tutorId,
        'studentId': studentId,
        'date': date,
        'status': status.name,
      };

  factory AttendanceRecord.fromJson(String id, Map<String, dynamic> json) => AttendanceRecord(
        id: id,
        tutorId: json['tutorId'] as String? ?? '',
        studentId: json['studentId'] as String,
        date: parseFsDate(json['date']),
        status: AttendanceStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => AttendanceStatus.present,
        ),
      );
}
