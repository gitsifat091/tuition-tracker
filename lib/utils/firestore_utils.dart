import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

DateTime parseFsDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.now();
}

DateTime? parseFsDateOrNull(dynamic value) {
  if (value == null) return null;
  return parseFsDate(value);
}

final _random = Random.secure();

/// ছাত্রকে দেওয়ার ৬ অঙ্কের ইনভাইট কোড।
///
/// আগে `DateTime.now().microsecondsSinceEpoch % 900000` দিয়ে বানানো হতো —
/// পরপর দুটো ছাত্র যোগ করলে কাছাকাছি (এমনকি একই) কোড পড়ার সম্ভাবনা ছিল, আর
/// signup এর সময় `.limit(1)` দিয়ে খোঁজা হয় বলে ভুল ছাত্রের সাথে লিংক হয়ে
/// যেতে পারত। এখন cryptographic random।
String generateInviteCode() {
  return (100000 + _random.nextInt(900000)).toString();
}
