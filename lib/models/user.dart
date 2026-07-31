class UserModel {
  final int? id;
  final String username;
  final String password;
  final String role; // 'مدير' or 'كاشير'
  final bool isActive;
  final String? createdAt;

  const UserModel({
    this.id,
    required this.username,
    required this.password,
    this.role = 'كاشير',
    this.isActive = true,
    this.createdAt,
  });

  bool get isManager => role == 'مدير';

  UserModel copyWith({
    int? id,
    String? username,
    String? password,
    String? role,
    bool? isActive,
    String? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
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
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      username: map['username'] as String,
      password: map['password'] as String,
      role: map['role'] as String? ?? 'كاشير',
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String?,
    );
  }
}
