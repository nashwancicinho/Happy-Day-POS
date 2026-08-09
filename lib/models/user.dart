import 'dart:convert';

class UserModel {
  final int? id;
  final String username;
  final String password;
  final String role; // 'مدير' or 'كاشير'
  final bool isActive;
  final String? createdAt;
  final Map<String, bool>? permissions;

  const UserModel({
    this.id,
    required this.username,
    required this.password,
    this.role = 'كاشير',
    this.isActive = true,
    this.createdAt,
    this.permissions,
  });

  bool get isOwner => role == 'مالك البرنامج';
  bool get isManager => role == 'مدير' || role == 'مالك البرنامج';

  UserModel copyWith({
    int? id,
    String? username,
    String? password,
    String? role,
    bool? isActive,
    String? createdAt,
    Map<String, bool>? permissions,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      permissions: permissions ?? this.permissions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'username': username,
      'password': password,
      'role': role,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'permissions': permissions != null ? jsonEncode(permissions) : null,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    Map<String, bool>? parsedPerms;
    if (map['permissions'] != null && (map['permissions'] as String).isNotEmpty) {
      try {
        final decoded = jsonDecode(map['permissions'] as String);
        if (decoded is Map) {
          parsedPerms = decoded.map((k, v) => MapEntry(k.toString(), v == true || v.toString().toLowerCase() == 'true'));
        }
      } catch (_) {}
    }

    return UserModel(
      id: map['id'] as int?,
      username: map['username'] as String,
      password: map['password'] as String,
      role: map['role'] as String? ?? 'كاشير',
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String?,
      permissions: parsedPerms,
    );
  }
}

