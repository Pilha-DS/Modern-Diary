enum UserRole {
  admin,
  moderator,
  user;

  static UserRole fromApi(String value) {
    return switch (value) {
      'ADMIN' => UserRole.admin,
      'MODERATOR' => UserRole.moderator,
      _ => UserRole.user,
    };
  }

  String get apiValue {
    return switch (this) {
      UserRole.admin => 'ADMIN',
      UserRole.moderator => 'MODERATOR',
      UserRole.user => 'USER',
    };
  }
}

class User {
  const User({
    required this.id,
    required this.username,
    required this.role,
    required this.createdAt,
  });

  final int id;
  final String username;
  final UserRole role;
  final DateTime createdAt;

  bool get isAdmin => role == UserRole.admin;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      role: UserRole.fromApi(json['role'] as String? ?? ''),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role.apiValue,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
