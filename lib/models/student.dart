import 'package:uuid/uuid.dart';
import '../utils/firestore_utils.dart';

class Student {
  final String id;
  String tutorId;
  String name;
  String className;
  String subject;
  String? parentPhone;
  double monthlyFee;
  DateTime joinDate;
  DateTime lastModified;
  List<String> classDays; // e.g. ['শনি', 'সোম', 'বুধ']
  String? classTime; // e.g. "বিকাল ৫:০০"
  String? inviteCode; // consumed (set to null) once a student links their account
  String? linkedUserId; // uid of the student's own account, once linked
  bool isArchived; // true = তুইশন ছেড়ে দিয়েছে, তালিকা থেকে সরানো কিন্তু ডেটা থাকবে
  DateTime? archivedDate; // কবে তুইশন ছেড়েছে (archive করার তারিখ)

  Student({
    String? id,
    this.tutorId = '',
    required this.name,
    required this.className,
    required this.subject,
    this.parentPhone,
    required this.monthlyFee,
    DateTime? joinDate,
    DateTime? lastModified,
    List<String>? classDays,
    this.classTime,
    this.inviteCode,
    this.linkedUserId,
    this.isArchived = false,
    this.archivedDate,
  })  : id = id ?? const Uuid().v4(),
        joinDate = joinDate ?? DateTime.now(),
        lastModified = lastModified ?? DateTime.now(),
        classDays = classDays ?? [];

  Map<String, dynamic> toJson() => {
        'tutorId': tutorId,
        'name': name,
        'className': className,
        'subject': subject,
        'parentPhone': parentPhone,
        'monthlyFee': monthlyFee,
        'joinDate': joinDate,
        'lastModified': lastModified,
        'classDays': classDays,
        'classTime': classTime,
        'inviteCode': inviteCode,
        'linkedUserId': linkedUserId,
        'isArchived': isArchived,
        'archivedDate': archivedDate,
      };

  factory Student.fromJson(String id, Map<String, dynamic> json) => Student(
        id: id,
        tutorId: json['tutorId'] as String? ?? '',
        name: json['name'] as String,
        className: json['className'] as String,
        subject: json['subject'] as String,
        parentPhone: json['parentPhone'] as String?,
        monthlyFee: (json['monthlyFee'] as num).toDouble(),
        joinDate: parseFsDate(json['joinDate']),
        lastModified: parseFsDate(json['lastModified']),
        classDays: json['classDays'] != null ? List<String>.from(json['classDays'] as List) : [],
        classTime: json['classTime'] as String?,
        inviteCode: json['inviteCode'] as String?,
        linkedUserId: json['linkedUserId'] as String?,
        isArchived: json['isArchived'] as bool? ?? false,
        archivedDate: parseFsDateOrNull(json['archivedDate']),
      );

  /// "দেওয়া হয়নি" আর "বদলাতে বলা হয়নি" — এই দুটো আলাদা করার জন্যে।
  ///
  /// আগে `parentPhone ?? this.parentPhone` লেখা ছিল, তাই এডিট স্ক্রিনে ফোন
  /// নম্বর বা ক্লাসের সময় মুছে সেভ করলে পুরনো মানটাই থেকে যেত — মোছা যেত না।
  static const _unset = Object();

  Student copyWith({
    String? name,
    String? className,
    String? subject,
    Object? parentPhone = _unset,
    double? monthlyFee,
    List<String>? classDays,
    Object? classTime = _unset,
    DateTime? joinDate,
  }) {
    return Student(
      id: id,
      tutorId: tutorId,
      name: name ?? this.name,
      className: className ?? this.className,
      subject: subject ?? this.subject,
      parentPhone:
          identical(parentPhone, _unset) ? this.parentPhone : parentPhone as String?,
      monthlyFee: monthlyFee ?? this.monthlyFee,
      joinDate: joinDate ?? this.joinDate,
      lastModified: DateTime.now(),
      classDays: classDays ?? this.classDays,
      classTime: identical(classTime, _unset) ? this.classTime : classTime as String?,
      inviteCode: inviteCode,
      linkedUserId: linkedUserId,
      isArchived: isArchived,
      archivedDate: archivedDate,
    );
  }
}
