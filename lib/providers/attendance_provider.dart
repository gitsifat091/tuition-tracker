import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance.dart';

class AttendanceProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  StreamSubscription? _sub;
  String? _tutorId;

  List<AttendanceRecord> _raw = [];

  /// প্রতি (ছাত্র + দিন) জোড়ায় একটাই রেকর্ড।
  List<AttendanceRecord> _records = [];
  List<AttendanceRecord> get records => _records;

  List<String> _duplicateIds = [];
  int get duplicateCount => _duplicateIds.length;

  bool _loaded = false;
  bool get loaded => _loaded;

  void updateTutorId(String? tutorId) {
    if (_tutorId == tutorId) return;
    _tutorId = tutorId;
    _sub?.cancel();

    if (tutorId == null) {
      _raw = [];
      _records = [];
      _duplicateIds = [];
      _loaded = false;
      notifyListeners();
      return;
    }

    _loaded = false;
    _sub = _db
        .collection('attendance')
        .where('tutorId', isEqualTo: tutorId)
        .snapshots()
        .listen((snap) {
      _raw = snap.docs.map((d) => AttendanceRecord.fromJson(d.id, d.data())).toList();
      _rebuildDeduped();
      _loaded = true;
      notifyListeners();
    });
  }

  static String dayKeyOf(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// একই (ছাত্র, দিন) সবসময় একই ডকুমেন্ট id পায়।
  ///
  /// আগে প্রতিবার `Uuid().v4()` হতো, তাই "উপস্থিত" বাটনে দ্রুত দুবার চাপ পড়লে
  /// Firestore এ একই দিনের দুটো রেকর্ড ঢুকে যেত — আর "ক্লিয়ার" চাপলে একটাই মুছত।
  static String docIdFor(String studentId, DateTime date) => '${studentId}_${dayKeyOf(date)}';

  void _rebuildDeduped() {
    final byKey = <String, List<AttendanceRecord>>{};
    for (final r in _raw) {
      byKey.putIfAbsent('${r.studentId}|${dayKeyOf(r.date)}', () => []).add(r);
    }

    final kept = <AttendanceRecord>[];
    final extras = <String>[];

    for (final group in byKey.values) {
      if (group.length == 1) {
        kept.add(group.first);
        continue;
      }
      final canonicalId = docIdFor(group.first.studentId, group.first.date);
      group.sort((a, b) {
        final canonical = (a.id == canonicalId ? 0 : 1).compareTo(b.id == canonicalId ? 0 : 1);
        if (canonical != 0) return canonical;
        return a.id.compareTo(b.id);
      });
      kept.add(group.first);
      extras.addAll(group.skip(1).map((r) => r.id));
    }

    _records = kept;
    _duplicateIds = extras;
  }

  List<AttendanceRecord> forStudent(String studentId) {
    return _records.where((r) => r.studentId == studentId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  AttendanceRecord? recordFor(String studentId, DateTime date) {
    final key = dayKeyOf(date);
    for (final r in _records) {
      if (r.studentId == studentId && dayKeyOf(r.date) == key) return r;
    }
    return null;
  }

  Future<void> setStatus(String studentId, DateTime date, AttendanceStatus status) async {
    if (_tutorId == null) return;
    final d = DateTime(date.year, date.month, date.day);
    final existing = recordFor(studentId, d);

    // পুরনো ডেটায় random id ওয়ালা রেকর্ড থাকলে সেটাই আপডেট হবে; নতুন হলে
    // নির্ধারিত id তে বসবে, তাই দুবার চাপলেও একটাই ডকুমেন্ট থাকবে।
    final id = existing?.id ?? docIdFor(studentId, d);
    final record = AttendanceRecord(
      id: id,
      tutorId: _tutorId!,
      studentId: studentId,
      date: d,
      status: status,
    );
    await _db.collection('attendance').doc(id).set(record.toJson());
  }

  Future<void> clearStatus(String studentId, DateTime date) async {
    final d = DateTime(date.year, date.month, date.day);
    final key = dayKeyOf(d);
    // ডুপ্লিকেট থেকে গেলেও সবগুলো মুছে দাও, নইলে ক্লিয়ার করার পরেও
    // পুরনো একটা রেকর্ড থেকে যেতে পারে।
    final ids = _raw
        .where((r) => r.studentId == studentId && dayKeyOf(r.date) == key)
        .map((r) => r.id)
        .toList();
    if (ids.isEmpty) return;

    final batch = _db.batch();
    for (final id in ids) {
      batch.delete(_db.collection('attendance').doc(id));
    }
    await batch.commit();
  }

  Map<String, int> monthlyStats(String studentId, int year, int month) {
    final monthRecords = _records.where(
      (r) => r.studentId == studentId && r.date.year == year && r.date.month == month,
    );
    final present = monthRecords.where((r) => r.status == AttendanceStatus.present).length;
    final absent = monthRecords.where((r) => r.status == AttendanceStatus.absent).length;
    return {'present': present, 'absent': absent, 'total': present + absent};
  }

  /// চলতি মাসে উপস্থিতির হার (০–১), কোনো ক্লাস না থাকলে `null`।
  double? presentRateForMonth(String studentId, DateTime month) {
    final stats = monthlyStats(studentId, month.year, month.month);
    final total = stats['total']!;
    if (total == 0) return null;
    return stats['present']! / total;
  }

  /// সব ছাত্র মিলিয়ে এক মাসের হিসাব — ড্যাশবোর্ডের জন্যে।
  ///
  /// [studentIds] দিলে শুধু ওই ছাত্রদের ধরা হয় (যেমন আর্কাইভ বাদ দিয়ে)।
  Map<String, int> statsForMonth(DateTime month, {Set<String>? studentIds}) {
    final monthRecords = _records.where((r) =>
        r.date.year == month.year &&
        r.date.month == month.month &&
        (studentIds == null || studentIds.contains(r.studentId)));

    final present = monthRecords.where((r) => r.status == AttendanceStatus.present).length;
    final absent = monthRecords.where((r) => r.status == AttendanceStatus.absent).length;
    return {'present': present, 'absent': absent, 'total': present + absent};
  }

  /// সব ছাত্র মিলিয়ে এক মাসের উপস্থিতির হার (০–১), ক্লাস না থাকলে `null`।
  double? presentRateForAll(DateTime month, {Set<String>? studentIds}) {
    final stats = statsForMonth(month, studentIds: studentIds);
    final total = stats['total']!;
    if (total == 0) return null;
    return stats['present']! / total;
  }

  /// পুরনো ডেটায় জমে থাকা একই দিনের বাড়তি রেকর্ড মুছে দেয়।
  Future<int> cleanupDuplicates() async {
    if (_duplicateIds.isEmpty) return 0;
    final ids = List<String>.from(_duplicateIds);
    for (var start = 0; start < ids.length; start += 400) {
      final chunk = ids.sublist(start, start + 400 > ids.length ? ids.length : start + 400);
      final batch = _db.batch();
      for (final id in chunk) {
        batch.delete(_db.collection('attendance').doc(id));
      }
      await batch.commit();
    }
    return ids.length;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
