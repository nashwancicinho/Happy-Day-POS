class EmployeeModel {
  final int? id;
  final String name;
  final String role; // 'موظف', 'كاشير', 'شيف', 'صالة', 'مدير', 'عامل'
  final String? phone;
  final double baseSalary;
  final String? hireDate;
  final bool isActive;
  final String? notes;

  const EmployeeModel({
    this.id,
    required this.name,
    this.role = 'موظف',
    this.phone,
    this.baseSalary = 0.0,
    this.hireDate,
    this.isActive = true,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'role': role,
      'phone': phone,
      'base_salary': baseSalary,
      'hire_date': hireDate,
      'is_active': isActive ? 1 : 0,
      'notes': notes,
    };
  }

  factory EmployeeModel.fromMap(Map<String, dynamic> map) {
    return EmployeeModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      role: map['role'] as String? ?? 'موظف',
      phone: map['phone'] as String?,
      baseSalary: (map['base_salary'] as num? ?? 0.0).toDouble(),
      hireDate: map['hire_date'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      notes: map['notes'] as String?,
    );
  }

  EmployeeModel copyWith({
    int? id,
    String? name,
    String? role,
    String? phone,
    double? baseSalary,
    String? hireDate,
    bool? isActive,
    String? notes,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      baseSalary: baseSalary ?? this.baseSalary,
      hireDate: hireDate ?? this.hireDate,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
    );
  }
}
