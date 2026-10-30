import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fee_record.dart';

class FeeProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  StreamSubscription? _sub;
  String? _tutorId;

  /// Firestore থেকে আসা কাঁচা তালিকা — এতে পুরনো ডুপ্লিকেটও থাকতে পারে।
  List<FeeRecord> _raw = [];

  /// প্রতি (ছাত্র + মাস) জোড়ায় ঠিক একটা রেকর্ড। UI আর হিসাব — সব এটাই ব্যবহার করে।
  List<FeeRecord> _records = [];
  List<FeeRecord> get records => _records;

  /// পুরনো ডেটায় থেকে যাওয়া বাড়তি ডকুমেন্টগুলোর id, মোছার জন্যে জমা রাখা।
  List<String> _duplicateIds = [];
  int get duplicateCount => _duplicateIds.length;

  /// প্রথম snapshot আসার আগে `false`.
  ///
  /// এটাই ডুপ্লিকেট ফি বাগের অর্ধেক সমাধান: `ensureMonthRecord` আগে খালি
  /// তালিকার উপর "এই মাস আছে কি?" পরীক্ষা করত, তাই অ্যাপ চালু হওয়ার সাথে
  /// সাথে চললে সব মাসকেই "নেই" ভাবত আর নতুন করে বানাত।
  bool _loaded = false;
  bool get loaded => _loaded;

  /// একই মাসের জন্যে একসাথে দুটো লেখা ঠেকাতে (দ্রুত ট্যাব বদল ইত্যাদি)।
  final Set<String> _inFlight = {};

  void updateTutorId(String? tutorId) {
    if (_tutorId == tutorId) return;
    _tutorId = tutorId;
    _sub?.cancel();
    _inFlight.clear();

    if (tutorId == null) {
      _raw = [];
      _records = [];
      _duplicateIds = [];
      _loaded = false;
      notifyListeners();
      return;
    }

    _loaded = false;
    _sub = _db.collection('fees').where('tutorId', isEqualTo: tutorId).snapshots().listen((snap) {
      _raw = snap.docs.map((d) => FeeRecord.fromJson(d.id, d.data())).toList();
      _rebuildDeduped();
      _loaded = true;
      notifyListeners();
    });
  }

  static String monthKeyOf(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  /// একই (ছাত্র, মাস) সবসময় একই ডকুমেন্ট id পায়, তাই `set()` বারবার চললেও
  /// নতুন ডকুমেন্ট তৈরি হয় না — আগের `Uuid().v4()` প্রতিবার নতুন id দিত।
  static String docIdFor(String studentId, String monthKey) => '${studentId}_$monthKey';

  void _rebuildDeduped() {
    final extras = <String>[];
    _records = dedupeFeeRecords(_raw, canonicalIdOf: docIdFor, extrasOut: extras);
    _duplicateIds = extras;
  }

  List<FeeRecord> forStudent(String studentId) {
    return _records.where((r) => r.studentId == studentId).toList()
      ..sort((a, b) => b.month.compareTo(a.month));
  }

  FeeRecord? recordFor(String studentId, String monthKey) {
    for (final r in _records) {
      if (r.studentId == studentId && r.month == monthKey) return r;
    }
    return null;
  }

  /// একটা মাসের রেকর্ড না থাকলে বানায়। প্রথম snapshot আসার আগে কিছুই করে না।
  Future<void> ensureMonthRecord(String studentId, double monthlyFee, DateTime forMonth) async {
    if (_tutorId == null || !_loaded) return;

    final key = monthKeyOf(forMonth);
    final guard = '$studentId|$key';
    if (_inFlight.contains(guard)) return;
    if (recordFor(studentId, key) != null) return;

    _inFlight.add(guard);
    try {
      final id = docIdFor(studentId, key);
      final record = FeeRecord(
        id: id,
        tutorId: _tutorId!,
        studentId: studentId,
        month: key,
        amount: monthlyFee,
      );
      // একই id তে set() — একই মাসের জন্যে দ্বিতীয়বার চললেও শুধু ওভাররাইট হবে,
      // নতুন ডকুমেন্ট বানাবে না।
      await _db.collection('fees').doc(id).set(record.toJson());
    } finally {
      _inFlight.remove(guard);
    }
  }

  /// চলতি মাস থেকে পেছনে [monthCount] মাসের রেকর্ড নিশ্চিত করে।
  ///
  /// [notBefore] দিলে (সাধারণত ছাত্রের ভর্তির তারিখ) তার আগের কোনো মাসের ফি
  /// বানানো হয় না — আগে ছাত্র গত মাসে ভর্তি হলেও ৬ মাসের বকেয়া দেখাত।
  Future<void> ensureRecentMonths(
    String studentId,
    double monthlyFee, {
    int monthCount = 6,
    DateTime? from,
    DateTime? notBefore,
  }) async {
    if (!_loaded) return;
    final now = from ?? DateTime.now();
    final floor = notBefore == null ? null : DateTime(notBefore.year, notBefore.month, 1);

    for (int i = 0; i < monthCount; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      if (floor != null && month.isBefore(floor)) break;
      // ধারাবাহিকভাবে await — একসাথে ছাড়লে সব কটাই "নেই" দেখে বসে থাকত।
      await ensureMonthRecord(studentId, monthlyFee, month);
    }
  }

  Future<void> markPaid(String recordId) async {
    await _db.collection('fees').doc(recordId).update({
      'status': FeeStatus.paid.name,
      'paidDate': DateTime.now(),
    });
  }

  Future<void> markDue(String recordId) async {
    await _db.collection('fees').doc(recordId).update({
      'status': FeeStatus.due.name,
      'paidDate': null,
    });
  }

  /// কোনো এক মাসের অঙ্ক আলাদা করে ঠিক করা (ছুটি, অগ্রিম, বাড়তি ক্লাস ইত্যাদি)।
  Future<void> updateAmount(String recordId, double amount) async {
    await _db.collection('fees').doc(recordId).update({'amount': amount});
  }

  Future<void> deleteRecord(String recordId) async {
    await _db.collection('fees').doc(recordId).delete();
  }

  /// পুরনো ডেটায় জমে থাকা বাড়তি ডকুমেন্টগুলো একবারে মুছে দেয়।
  /// প্রতি (ছাত্র, মাস) জোড়ায় রাখা রেকর্ডটা ছোঁয়া হয় না। মোছা সংখ্যা ফেরত দেয়।
  Future<int> cleanupDuplicates() async {
    if (_duplicateIds.isEmpty) return 0;

    final ids = List<String>.from(_duplicateIds);
    // Firestore এক batch এ সর্বোচ্চ ৫০০টা লেখা নেয়।
    for (var start = 0; start < ids.length; start += 400) {
      final chunk = ids.sublist(start, start + 400 > ids.length ? ids.length : start + 400);
      final batch = _db.batch();
      for (final id in chunk) {
        batch.delete(_db.collection('fees').doc(id));
      }
      await batch.commit();
    }
    return ids.length;
  }

  double totalCollectedForMonth(DateTime month) {
    final key = monthKeyOf(month);
    return _records
        .where((r) => r.month == key && r.status == FeeStatus.paid)
        .fold(0.0, (total, r) => total + r.amount);
  }

  double totalDueForMonth(DateTime month) {
    final key = monthKeyOf(month);
    return _records
        .where((r) => r.month == key && r.status == FeeStatus.due)
        .fold(0.0, (total, r) => total + r.amount);
  }

  /// একজন ছাত্রের চলতি মাসের অবস্থা — হোম স্ক্রিনের কার্ডে দেখানোর জন্যে।
  FeeStatus? statusForMonth(String studentId, DateTime month) =>
      recordFor(studentId, monthKeyOf(month))?.status;

  /// একজন ছাত্রের মোট বকেয়া (সব মাস মিলিয়ে)।
  double totalDueForStudent(String studentId) => _records
      .where((r) => r.studentId == studentId && r.status == FeeStatus.due)
      .fold(0.0, (total, r) => total + r.amount);

  int dueMonthCountForStudent(String studentId) =>
      _records.where((r) => r.studentId == studentId && r.status == FeeStatus.due).length;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
