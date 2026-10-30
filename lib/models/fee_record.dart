import 'package:uuid/uuid.dart';
import '../utils/firestore_utils.dart';

enum FeeStatus { paid, due }

class FeeRecord {
  final String id;
  final String tutorId;
  final String studentId;
  final String month; // format: "2026-08"
  double amount;
  FeeStatus status;
  DateTime? paidDate;

  FeeRecord({
    String? id,
    this.tutorId = '',
    required this.studentId,
    required this.month,
    required this.amount,
    this.status = FeeStatus.due,
    this.paidDate,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'tutorId': tutorId,
        'studentId': studentId,
        'month': month,
        'amount': amount,
        'status': status.name,
        'paidDate': paidDate,
      };

  factory FeeRecord.fromJson(String id, Map<String, dynamic> json) => FeeRecord(
        id: id,
        tutorId: json['tutorId'] as String? ?? '',
        studentId: json['studentId'] as String,
        month: json['month'] as String,
        amount: (json['amount'] as num).toDouble(),
        status: FeeStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => FeeStatus.due,
        ),
        paidDate: parseFsDateOrNull(json['paidDate']),
      );
}

/// একই (ছাত্র, মাস) জোড়ার একাধিক রেকর্ড থেকে একটাই রাখে।
///
/// বাগ ধরা পড়ার আগে Firestore এ যে ডুপ্লিকেটগুলো জমেছে সেগুলো এখনো আছে।
/// শিক্ষকের দিকে `FeeProvider` আর ছাত্রের দিকে `StudentFeeView` — দুই জায়গাতেই
/// একই নিয়মে ছাঁকা হয়, নইলে দুই পাশে দুই রকম হিসাব দেখাত।
///
/// নিয়ম: ১) "পরিশোধিত" আগে (কারো দেওয়া টাকা যেন না হারায়),
/// ২) তারপর নির্ধারিত id ওয়ালাটা, ৩) শেষে id অনুসারে — ফল সবসময় একই থাকে।
List<FeeRecord> dedupeFeeRecords(
  List<FeeRecord> raw, {
  String Function(String studentId, String monthKey)? canonicalIdOf,
  List<String>? extrasOut,
}) {
  final byKey = <String, List<FeeRecord>>{};
  for (final r in raw) {
    byKey.putIfAbsent('${r.studentId}|${r.month}', () => []).add(r);
  }

  final kept = <FeeRecord>[];
  for (final group in byKey.values) {
    if (group.length == 1) {
      kept.add(group.first);
      continue;
    }

    final canonicalId = canonicalIdOf?.call(group.first.studentId, group.first.month);
    group.sort((a, b) {
      final paid = (a.status == FeeStatus.paid ? 0 : 1)
          .compareTo(b.status == FeeStatus.paid ? 0 : 1);
      if (paid != 0) return paid;
      if (canonicalId != null) {
        final canonical =
            (a.id == canonicalId ? 0 : 1).compareTo(b.id == canonicalId ? 0 : 1);
        if (canonical != 0) return canonical;
      }
      return a.id.compareTo(b.id);
    });

    kept.add(group.first);
    extrasOut?.addAll(group.skip(1).map((r) => r.id));
  }
  return kept;
}
