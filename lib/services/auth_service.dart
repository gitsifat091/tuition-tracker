import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<AppUser?> fetchUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromJson(uid, doc.data()!);
  }

  /// Sign up as a TEACHER. Creates the Auth account + users/{uid} doc.
  Future<AppUser> signUpTeacher({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;
    final user = AppUser(uid: uid, name: name, email: email, role: UserRole.teacher);
    await _db.collection('users').doc(uid).set(user.toJson());
    return user;
  }

  /// Sign up as a STUDENT using an invite code from a teacher.
  /// Creates the account first (so Firestore rules can verify auth),
  /// then looks up the matching students/{id} doc and links it.
  /// Rolls back the auth account if the code doesn't match anything.
  Future<AppUser> signUpStudent({
    required String name,
    required String email,
    required String password,
    required String inviteCode,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;

    try {
      final query = await _db
          .collection('students')
          .where('inviteCode', isEqualTo: inviteCode.trim())
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception('ইনভাইট কোড সঠিক নয়। টিউটরের সাথে যোগাযোগ করো।');
      }

      final user = AppUser(uid: uid, name: name, email: email, role: UserRole.student);
      await _db.collection('users').doc(uid).set(user.toJson());

      await query.docs.first.reference.update({
        'linkedUserId': uid,
        'inviteCode': FieldValue.delete(), // consumed — can't be reused
      });

      return user;
    } catch (e) {
      // Roll back the orphaned auth account so the email can be reused.
      await cred.user!.delete();
      rethrow;
    }
  }

  Future<AppUser?> signIn({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return fetchUserProfile(cred.user!.uid);
  }

  Future<void> signOut() => _auth.signOut();

  String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'এই ইমেইল দিয়ে আগেই একটা অ্যাকাউন্ট আছে।';
        case 'invalid-email':
          return 'ইমেইল সঠিক ফরম্যাটে দাও।';
        case 'weak-password':
          return 'পাসওয়ার্ড অন্তত ৬ ক্যারেক্টার হতে হবে।';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'ইমেইল বা পাসওয়ার্ড ভুল।';
        default:
          return e.message ?? 'কিছু একটা সমস্যা হয়েছে, আবার চেষ্টা করো।';
      }
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}
