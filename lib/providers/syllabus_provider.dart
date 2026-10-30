import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/syllabus_item.dart';

class SyllabusProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  StreamSubscription? _sub;
  String? _tutorId;

  List<SyllabusItem> _items = [];
  List<SyllabusItem> get items => _items;

  void updateTutorId(String? tutorId) {
    if (_tutorId == tutorId) return;
    _tutorId = tutorId;
    _sub?.cancel();

    if (tutorId == null) {
      _items = [];
      notifyListeners();
      return;
    }

    _sub = _db.collection('syllabus').where('tutorId', isEqualTo: tutorId).snapshots().listen((snap) {
      _items = snap.docs.map((d) => SyllabusItem.fromJson(d.id, d.data())).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      notifyListeners();
    });
  }

  List<SyllabusItem> forStudent(String studentId) {
    return _items.where((i) => i.studentId == studentId).toList();
  }

  Future<void> addItem(SyllabusItem item) async {
    if (_tutorId == null) return;
    final data = item.toJson()..['tutorId'] = _tutorId;
    await _db.collection('syllabus').doc(item.id).set(data);
  }

  Future<void> updateItem(SyllabusItem item) async {
    final data = item.toJson()..['tutorId'] = item.tutorId.isNotEmpty ? item.tutorId : _tutorId;
    await _db.collection('syllabus').doc(item.id).update(data);
  }

  Future<void> toggleDone(SyllabusItem item) async {
    await _db.collection('syllabus').doc(item.id).update({'isDone': !item.isDone});
  }

  Future<void> deleteItem(String id) async {
    await _db.collection('syllabus').doc(id).delete();
  }

  double progressFor(String studentId) {
    final list = forStudent(studentId);
    if (list.isEmpty) return 0;
    final done = list.where((i) => i.isDone).length;
    return done / list.length;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
