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
    _checkedInvites.clear();
    _sub = _db
        .collection('students')
        .where('tutorId', isEqualTo: tutorId)
        .snapshots()
        .listen((snap) {
      _students = snap.docs.map((d) => Student.fromJson(d.id, d.data())).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      loading = false;
      notifyListeners();
      _ensureInvites();
    });
  }

  /// এই সেশনে যে কোডগুলোর invites ডকুমেন্ট আছে বলে নিশ্চিত হওয়া গেছে।
  final Set<String> _checkedInvites = {};

  /// পুরনো ছাত্রদের (invites collection আসার আগে যোগ করা) কোডের জন্যে
  /// invites/{code} বানিয়ে দেয়, নইলে নতুন rules এ তারা signup করতে পারবে না।
  Future<void> _ensureInvites() async {
    final tutorId = _tutorId;
    if (tutorId == null) return;
    for (final s in _students) {
      final code = s.inviteCode;
      if (code == null || s.linkedUserId != null || _checkedInvites.contains(code)) continue;
      _checkedInvites.add(code);
      try {
        final ref = _db.collection('invites').doc(code);
        if (!(await ref.get()).exists) {
          await ref.set(_inviteData(s.id, tutorId));
        }
      } catch (e) {
        // অফলাইন বা কোড অন্য কারো — পরের বার অ্যাপ খুললে আবার চেষ্টা হবে।
        _checkedInvites.remove(code);
        debugPrint('invite sync failed for ${s.id}: $e');
      }
    }
  }

  Map<String, dynamic> _inviteData(String studentId, String tutorId) => {
        'studentId': studentId,
        'tutorId': tutorId,
        'createdAt': DateTime.now(),
      };

  Future<void> addStudent(Student student) async {
    if (_tutorId == null) return;
    student.tutorId = _tutorId!;

    // invites/{code} শুধু create করা যায়, তাই কোড কোনোভাবে আগে থেকে
    // থাকলে batch ব্যর্থ হয় — তখন নতুন কোড নিয়ে আবার চেষ্টা।
    for (var attempt = 0;; attempt++) {
      student.inviteCode = generateInviteCode();
      final batch = _db.batch()
        ..set(_db.collection('students').doc(student.id), student.toJson())
        ..set(_db.collection('invites').doc(student.inviteCode), _inviteData(student.id, _tutorId!));
      try {
        await batch.commit();
        _checkedInvites.add(student.inviteCode!);
        return;
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied' || attempt >= 2) rethrow;
      }
    }
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
    if (_tutorId == null) return;
    // যুক্ত সব ডেটাও (attendance/fee/note/syllabus) একসাথে মুছে দেওয়া হয়,
    // যাতে database এ orphaned (কোনো ছাত্রের সাথে যুক্ত নেই এমন) রেকর্ড না থাকে।
    //
    // tutorId ফিল্টার দরকার — rules শুধু নিজের রেকর্ড পড়তে দেয়, তাই শুধু
    // studentId দিয়ে query করলে পুরো query টাই permission-denied হয়।
    final collections = ['attendance', 'fees', 'notes', 'syllabus', 'exams'];
    final refs = <DocumentReference>[];

    for (final col in collections) {
      final snap = await _db
          .collection(col)
          .where('tutorId', isEqualTo: _tutorId)
          .where('studentId', isEqualTo: id)
          .get();
      refs.addAll(snap.docs.map((d) => d.reference));
    }

    // Firestore এক batch এ সর্বোচ্চ ৫০০টা লেখা নেয় — কয়েক বছরের উপস্থিতি
    // থাকলে এক batch এ সব ধরত না। ছাত্রের ডকুমেন্ট সবার শেষে মোছা হয়,
    // যাতে মাঝপথে ব্যর্থ হলেও আবার মুছতে চাইলে ছাত্রটা তালিকায় থাকে।
    for (var start = 0; start < refs.length; start += 400) {
      final end = start + 400 > refs.length ? refs.length : start + 400;
      final batch = _db.batch();
      for (final ref in refs.sublist(start, end)) {
        batch.delete(ref);
      }
      await batch.commit();
    }

    // আলাদা করে, ব্যর্থ হলেও থামে না — পুরনো ছাত্রের invites ডকুমেন্ট হয়তো
    // কখনো বানানোই হয়নি, আর না-থাকা ডকুমেন্ট মোছা rules এ আটকে যায়।
    final inviteCode = getById(id)?.inviteCode;
    if (inviteCode != null) {
      try {
        await _db.collection('invites').doc(inviteCode).delete();
      } catch (e) {
        debugPrint('invite delete failed for $id: $e');
      }
    }

    await _db.collection('students').doc(id).delete();
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
