import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/student_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/exam_provider.dart';
import 'providers/fee_provider.dart';
import 'providers/progress_note_provider.dart';
import 'providers/syllabus_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TuitionTrackerApp());
}

class TuitionTrackerApp extends StatelessWidget {
  const TuitionTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, StudentProvider>(
          create: (_) => StudentProvider(),
          update: (_, auth, previous) =>
              (previous ?? StudentProvider())..updateTutorId(auth.user?.uid),
        ),
        ChangeNotifierProxyProvider<AuthProvider, AttendanceProvider>(
          create: (_) => AttendanceProvider(),
          update: (_, auth, previous) =>
              (previous ?? AttendanceProvider())..updateTutorId(auth.user?.uid),
        ),
        ChangeNotifierProxyProvider<AuthProvider, FeeProvider>(
          create: (_) => FeeProvider(),
          update: (_, auth, previous) =>
              (previous ?? FeeProvider())..updateTutorId(auth.user?.uid),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ProgressNoteProvider>(
          create: (_) => ProgressNoteProvider(),
          update: (_, auth, previous) =>
              (previous ?? ProgressNoteProvider())..updateTutorId(auth.user?.uid),
        ),
        ChangeNotifierProxyProvider<AuthProvider, SyllabusProvider>(
          create: (_) => SyllabusProvider(),
          update: (_, auth, previous) =>
              (previous ?? SyllabusProvider())..updateTutorId(auth.user?.uid),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ExamProvider>(
          create: (_) => ExamProvider(),
          update: (_, auth, previous) =>
              (previous ?? ExamProvider())..updateTutorId(auth.user?.uid),
        ),
      ],
      child: MaterialApp(
        title: 'টিউশন ট্র্যাকার',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // date/time picker সহ Material এর নিজস্ব লেখাগুলোও বাংলায় আসবে।
        locale: const Locale('bn'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('bn'), Locale('en')],
        home: const AuthGate(),
      ),
    );
  }
}
