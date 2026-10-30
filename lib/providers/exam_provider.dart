import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exam.dart';

class ExamProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  StreamSubscription? _sub;
  String? _tutorId;

  List<Exam> _exams = [];
  List<Exam> get exams => _exams;

  bool _loaded = false;
  bool get loaded => _loaded;

  void updateTutorId(String? tutorId) {
    if (_tutorId == tutorId) return;
    _tutorId = tutorId;
    _sub?.cancel();

    if (tutorId == null) {
      _exams = [];
      _loaded = false;
      notifyListeners();
      return;
    }

    _loaded = false;
    _sub = _db
        .collection('exams')
        .where('tutorId', isEqualTo: tutorId)
        .snapshots()
        .listen((snap) {
      _exams = snap.docs.map((d) => Exam.fromJson(d.id, d.data())).toList();
      _loaded = true;
      notifyListeners();
    });
  }

  /// একজন ছাত্রের সব পরীক্ষা — কাছের তারিখ আগে।
  List<Exam> forStudent(String studentId) {
    return _exams.where((e) => e.studentId == studentId).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// আসন্ন পরীক্ষা (আজকেরটাসহ), কাছেরটা আগে।
  List<Exam> upcomingForStudent(String studentId, [DateTime? now]) =>
      forStudent(studentId).where((e) => !e.isPast(now)).toList();

  /// শেষ হয়ে যাওয়া পরীক্ষা, সাম্প্রতিকটা আগে।
  List<Exam> pastForStudent(String studentId, [DateTime? now]) =>
      forStudent(studentId).where((e) => e.isPast(now)).toList().reversed.toList();

  /// সবচেয়ে কাছের আসন্ন পরীক্ষা, না থাকলে `null`।
  Exam? nextForStudent(String studentId, [DateTime? now]) {
    final upcoming = upcomingForStudent(studentId, now);
    return upcoming.isEmpty ? null : upcoming.first;
  }

  Future<void> addExam(Exam exam) async {
    if (_tutorId == null) return;
    final data = exam.toJson()..['tutorId'] = _tutorId;
    await _db.collection('exams').doc(exam.id).set(data);
  }

  Future<void> updateExam(Exam exam) async {
    // `update()` এর বদলে merge-set — ডকুমেন্ট কোনো কারণে না থাকলেও ব্যর্থ হবে না।
    final data = exam.toJson()
      ..['tutorId'] = exam.tutorId.isNotEmpty ? exam.tutorId : _tutorId;
    await _db.collection('exams').doc(exam.id).set(data, SetOptions(merge: true));
  }

  Future<void> deleteExam(String id) async {
    await _db.collection('exams').doc(id).delete();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
