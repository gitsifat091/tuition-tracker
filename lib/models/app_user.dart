enum UserRole { teacher, student }

class AppUser {
  final String uid;
  final String name;
  final String email;
  final UserRole role;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'role': role.name,
        'createdAt': DateTime.now().toIso8601String(),
      };

  factory AppUser.fromJson(String uid, Map<String, dynamic> json) => AppUser(
        uid: uid,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: (json['role'] as String?) == 'student' ? UserRole.student : UserRole.teacher,
      );
}
