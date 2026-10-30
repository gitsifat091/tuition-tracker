import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student.dart';
import '../utils/firestore_utils.dart';

class StudentProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  StreamSubscription? _sub;
  String? _tutorId;

  List<Student> _students = [];
  List<Student> get students => _students;

  bool loading = true;

  void updateTutorId(String? tutorId) {
    if (_tutorId == tutorId) return;
    _tutorId = tutorId;
    _sub?.cancel();

    if (tutorId == null) {
      _students = [];
      loading = false;
      notifyListeners();
      return;
    }

    loading = true;
    _sub = _db
        .collection('students')
        .where('tutorId', isEqualTo: tutorId)
        .snapshots()
        .listen((snap) {
      _students = snap.docs.map((d) => Student.fromJson(d.id, d.data())).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      loading = false;
      notifyListeners();
    });
  }

  Future<void> addStudent(Student student) async {
    if (_tutorId == null) return;
    student.tutorId = _tutorId!;
    student.inviteCode = generateInviteCode();
    await _db.collection('students').doc(student.id).set(student.toJson());
  }

  /// এডিট স্ক্রিন যে ফিল্ডগুলোর মালিক শুধু সেগুলোই লেখা হয়।
  ///
  /// আগে পুরো `toJson()` পাঠানো হতো, তাতে `inviteCode` আর `linkedUserId` ও
  /// থাকত। শিক্ষক এডিট স্ক্রিন খুলে রাখা অবস্থায় ছাত্র যদি ইনভাইট কোড দিয়ে
  /// অ্যাকাউন্ট লিংক করত, তাহলে সেভ করার সময় শিক্ষকের হাতে থাকা পুরনো কপি
  /// সেই লিংক মুছে দিত আর ব্যবহার হয়ে যাওয়া কোডটা ফিরিয়ে আনত।
  /// আর্কাইভের ফিল্ডগুলোরও নিজস্ব মেথড আছে, তাই এখানে নেই।
  Future<void> updateStudent(Student student) async {
    await _db.collection('students').doc(student.id).update({
      'name': student.name,
      'className': student.className,
      'subject': student.subject,
      'parentPhone': student.parentPhone,
      'monthlyFee': student.monthlyFee,
      'joinDate': student.joinDate,
      'lastModified': DateTime.now(),
      'classDays': student.classDays,
      'classTime': student.classTime,
    });
  }

  Future<void> deleteStudent(String id) async {
    // যুক্ত সব ডেটাও (attendance/fee/note/syllabus) একসাথে মুছে দেওয়া হয়,
    // যাতে database এ orphaned (কোনো ছাত্রের সাথে যুক্ত নেই এমন) রেকর্ড না থাকে।
    final collections = ['attendance', 'fees', 'notes', 'syllabus', 'exams'];
    final batch = _db.batch();

    for (final col in collections) {
      final snap = await _db.collection(col).where('studentId', isEqualTo: id).get();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
    }
    batch.delete(_db.collection('students').doc(id));
    await batch.commit();
  }

  Future<void> archiveStudent(String id) async {
    await _db.collection('students').doc(id).update({
      'isArchived': true,
      'archivedDate': DateTime.now(),
    });
  }

  Future<void> unarchiveStudent(String id) async {
    await _db.collection('students').doc(id).update({
      'isArchived': false,
      'archivedDate': null,
    });
  }

  List<Student> get activeStudents => _students.where((s) => !s.isArchived).toList();
  List<Student> get archivedStudents => _students.where((s) => s.isArchived).toList();

  Student? getById(String id) {
    try {
      return _students.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
