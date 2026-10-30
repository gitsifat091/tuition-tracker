import 'package:uuid/uuid.dart';
import '../utils/firestore_utils.dart';

class SyllabusItem {
  final String id;
  final String tutorId;
  final String studentId;
  String title;
  bool isDone;
  String materialNote;
  DateTime createdAt;

  SyllabusItem({
    String? id,
    this.tutorId = '',
    required this.studentId,
    required this.title,
    this.isDone = false,
    this.materialNote = '',
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'tutorId': tutorId,
        'studentId': studentId,
        'title': title,
        'isDone': isDone,
        'materialNote': materialNote,
        'createdAt': createdAt,
      };

  factory SyllabusItem.fromJson(String id, Map<String, dynamic> json) => SyllabusItem(
        id: id,
        tutorId: json['tutorId'] as String? ?? '',
        studentId: json['studentId'] as String,
        title: json['title'] as String,
        isDone: json['isDone'] as bool? ?? false,
        materialNote: json['materialNote'] as String? ?? '',
        createdAt: parseFsDate(json['createdAt']),
      );
}
