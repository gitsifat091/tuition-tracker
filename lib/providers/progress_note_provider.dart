import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/progress_note.dart';

class ProgressNoteProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  StreamSubscription? _sub;
  String? _tutorId;

  List<ProgressNote> _notes = [];
  List<ProgressNote> get notes => _notes;

  void updateTutorId(String? tutorId) {
    if (_tutorId == tutorId) return;
    _tutorId = tutorId;
    _sub?.cancel();

    if (tutorId == null) {
      _notes = [];
      notifyListeners();
      return;
    }

    _sub = _db.collection('notes').where('tutorId', isEqualTo: tutorId).snapshots().listen((snap) {
      _notes = snap.docs.map((d) => ProgressNote.fromJson(d.id, d.data())).toList();
      notifyListeners();
    });
  }

  List<ProgressNote> forStudent(String studentId) {
    return _notes.where((n) => n.studentId == studentId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> addNote(ProgressNote note) async {
    if (_tutorId == null) return;
    final data = note.toJson()..['tutorId'] = _tutorId;
    await _db.collection('notes').doc(note.id).set(data);
  }

  Future<void> updateNote(ProgressNote note) async {
    final data = note.toJson()..['tutorId'] = note.tutorId.isNotEmpty ? note.tutorId : _tutorId;
    await _db.collection('notes').doc(note.id).update(data);
  }

  Future<void> deleteNote(String id) async {
    await _db.collection('notes').doc(id).delete();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
