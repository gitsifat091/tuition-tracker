import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AppUser? _user;
  AppUser? get user => _user;

  bool _loading = true;
  bool get loading => _loading;

  AuthProvider() {
    _authService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser == null) {
        _user = null;
      } else {
        _user = await _authService.fetchUserProfile(firebaseUser.uid);
      }
      _loading = false;
      notifyListeners();
    });
  }

  Future<String?> signUpTeacher({required String name, required String email, required String password}) async {
    try {
      _user = await _authService.signUpTeacher(name: name, email: email, password: password);
      notifyListeners();
      return null;
    } catch (e) {
      return _authService.friendlyError(e);
    }
  }

  Future<String?> signUpStudent({
    required String name,
    required String email,
    required String password,
    required String inviteCode,
  }) async {
    try {
      _user = await _authService.signUpStudent(
        name: name,
        email: email,
        password: password,
        inviteCode: inviteCode,
      );
      notifyListeners();
      return null;
    } catch (e) {
      return _authService.friendlyError(e);
    }
  }

  Future<String?> signIn({required String email, required String password}) async {
    try {
      final profile = await _authService.signIn(email: email, password: password);

      // Firebase Auth এ অ্যাকাউন্ট আছে কিন্তু users/{uid} ডকুমেন্ট নেই — আগে
      // এই অবস্থায় `_user = null` বসিয়ে "সফল" (null error) ফেরত দেওয়া হতো,
      // ফলে লগইন বাটনে চাপলে কোনো বার্তা ছাড়াই স্ক্রিন একই থাকত।
      if (profile == null) {
        await _authService.signOut();
        _user = null;
        notifyListeners();
        return 'এই অ্যাকাউন্টের প্রোফাইল পাওয়া যায়নি। নতুন করে অ্যাকাউন্ট বানাও '
            'অথবা টিউটরের সাথে যোগাযোগ করো।';
      }

      _user = profile;
      notifyListeners();
      return null;
    } catch (e) {
      return _authService.friendlyError(e);
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    notifyListeners();
  }
}
