import 'package:flutter/material.dart';

/// ক্লাসের সময় আর পরীক্ষার সময় — দুটোই "10:00 AM" ধাঁচে জমা থাকে।
///
/// আগে এই দুটো ফাংশন `add_student_screen.dart` এর ভেতরে private ছিল; পরীক্ষার
/// ফর্মেও একই জিনিস দরকার হওয়ায় এখানে সরানো হলো।

final _timePattern = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false);

/// `"5:00 PM"` → `TimeOfDay(17, 0)`. না মিললে `null`।
TimeOfDay? parseTimeOfDay(String? text) {
  if (text == null) return null;
  final match = _timePattern.firstMatch(text);
  if (match == null) return null;

  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour < 1 || hour > 12 || minute > 59) return null;

  final isPm = match.group(3)!.toUpperCase() == 'PM';
  if (isPm && hour != 12) hour += 12;
  if (!isPm && hour == 12) hour = 0;

  return TimeOfDay(hour: hour, minute: minute);
}

/// `TimeOfDay(17, 0)` → `"5:00 PM"`. `null` দিলে `null`।
String? formatTimeOfDay(TimeOfDay? time) {
  if (time == null) return null;
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
}
