/// বাংলা সংখ্যা, মাস আর বারের নাম — এক জায়গায়।
///
/// আগে মাসের নামের তালিকা `fee_tab.dart`, `student_fee_view.dart` আর
/// `dashboard_screen.dart` — তিন জায়গায় আলাদা করে লেখা ছিল। এখন একটাই উৎস।
///
/// তারিখ ফরম্যাটের জন্যে `intl` এর locale data লোড করা হয়নি ইচ্ছে করেই —
/// `DateFormat('MMMM', 'bn')` চালাতে হলে `initializeDateFormatting()` লাগত,
/// আর সেটা না করলে চুপচাপ ইংরেজি নাম দেখাত। নিজেদের তালিকা রাখলে সেই ঝুঁকি নেই।
class Bn {
  Bn._();

  static const _digits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

  static const monthsFull = [
    '',
    'জানুয়ারি',
    'ফেব্রুয়ারি',
    'মার্চ',
    'এপ্রিল',
    'মে',
    'জুন',
    'জুলাই',
    'আগস্ট',
    'সেপ্টেম্বর',
    'অক্টোবর',
    'নভেম্বর',
    'ডিসেম্বর',
  ];

  static const monthsShort = [
    '',
    'জানু',
    'ফেব',
    'মার্চ',
    'এপ্রি',
    'মে',
    'জুন',
    'জুলা',
    'আগ',
    'সেপ্ট',
    'অক্টো',
    'নভে',
    'ডিসে',
  ];

  /// অ্যাপে ব্যবহৃত ছোট বারের নাম, সপ্তাহ শুরু শনিবার থেকে (বাংলাদেশের নিয়ম)।
  static const weekDaysShort = ['শনি', 'রবি', 'সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র'];

  /// `DateTime.weekday` (১ = সোমবার … ৭ = রবিবার) থেকে বাংলা নাম।
  static const _weekdayByIso = [
    '', // index 0 ব্যবহার হয় না
    'সোম',
    'মঙ্গল',
    'বুধ',
    'বৃহঃ',
    'শুক্র',
    'শনি',
    'রবি',
  ];

  static const _weekdayFullByIso = [
    '',
    'সোমবার',
    'মঙ্গলবার',
    'বুধবার',
    'বৃহস্পতিবার',
    'শুক্রবার',
    'শনিবার',
    'রবিবার',
  ];

  /// ইংরেজি অঙ্ক (0-9) কে বাংলা অঙ্কে বদলায়, বাকি অক্ষর অপরিবর্তিত।
  static String digits(String input) {
    final buffer = StringBuffer();
    for (final code in input.codeUnits) {
      if (code >= 48 && code <= 57) {
        buffer.write(_digits[code - 48]);
      } else {
        buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }

  /// বাংলা অঙ্ককে ইংরেজি অঙ্কে ফেরত আনে।
  ///
  /// ইনভাইট কোড Firestore এ ইংরেজি অঙ্কে জমা থাকে, কিন্তু বাংলা কিবোর্ডে টাইপ
  /// করলে "৪২৩৯৮১" আসে — তখন কোড মিলত না। ইনপুট এখানে দিয়ে নিলে দুটোই চলে।
  static String toAsciiDigits(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      // বাংলা ০-৯ ইউনিকোডে U+09E6 থেকে U+09EF।
      if (rune >= 0x09E6 && rune <= 0x09EF) {
        buffer.writeCharCode(48 + (rune - 0x09E6));
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// সংখ্যাকে দশমিক ছাড়া বাংলা অঙ্কে।
  static String number(num value) => digits(value.toStringAsFixed(0));

  /// টাকার অঙ্ক, যেমন `৳১২০০`।
  static String taka(num value) => '৳${number(value)}';

  static String monthName(int month, {bool short = false}) {
    if (month < 1 || month > 12) return '';
    return short ? monthsShort[month] : monthsFull[month];
  }

  static String weekdayShort(DateTime date) => _weekdayByIso[date.weekday];

  static String weekdayFull(DateTime date) => _weekdayFullByIso[date.weekday];

  /// `২৪ আগস্ট ২০২৬`
  static String date(DateTime d) => '${number(d.day)} ${monthsFull[d.month]} ${number(d.year)}';

  /// `২৪ আগ ২০২৬`
  static String dateShort(DateTime d) => '${number(d.day)} ${monthsShort[d.month]} ${number(d.year)}';

  /// `২৪ আগস্ট ২০২৬, সোমবার`
  static String dateWithWeekday(DateTime d) => '${date(d)}, ${weekdayFull(d)}';

  /// `"2026-08"` → `আগস্ট ২০২৬`.
  ///
  /// কী ভাঙা থাকলে ক্র্যাশ না করে কাঁচা স্ট্রিংটাই ফেরত দেয় — আগে
  /// `int.parse(parts[1])` সরাসরি চালানো হতো, একটা এলোমেলো ডকুমেন্ট থাকলেই
  /// পুরো ফি তালিকা RangeError দিয়ে ভেঙে যেত।
  static String monthKeyLabel(String monthKey, {bool short = false}) {
    final parts = monthKey.split('-');
    if (parts.length < 2) return monthKey;
    final month = int.tryParse(parts[1]);
    if (month == null || month < 1 || month > 12) return monthKey;
    final name = short ? monthsShort[month] : monthsFull[month];
    return '$name ${digits(parts[0])}';
  }

  /// `"2026-08"` → শুধু মাসের নাম, বছর ছাড়া।
  static String monthKeyMonthOnly(String monthKey, {bool short = false}) {
    final parts = monthKey.split('-');
    if (parts.length < 2) return monthKey;
    final month = int.tryParse(parts[1]);
    if (month == null || month < 1 || month > 12) return monthKey;
    return short ? monthsShort[month] : monthsFull[month];
  }

  /// `"2026-08"` → `2026` (বছরভিত্তিক গ্রুপ করার জন্যে), না পারলে `null`।
  static int? yearOfMonthKey(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.isEmpty) return null;
    return int.tryParse(parts[0]);
  }
}
