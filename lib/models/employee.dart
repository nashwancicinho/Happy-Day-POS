class EmployeeModel {
  final int? id;
  final String name;
  final String role; // 'موظف', 'كاشير', 'شيف', 'صالة', 'مدير', 'عامل'
  final String? phone;
  final double baseSalary;
  final String salaryType; // 'MONTHLY', 'DAILY'
  final String? hireDate;
  final bool isActive;
  final String? notes;

  const EmployeeModel({
    this.id,
    required this.name,
    this.role = 'موظف',
    this.phone,
    this.baseSalary = 0.0,
    this.salaryType = 'MONTHLY',
    this.hireDate,
    this.isActive = true,
    this.notes,
  });

  bool get isDaily => salaryType == 'DAILY';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'role': role,
      'phone': phone,
      'base_salary': baseSalary,
      'salary_type': salaryType,
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
      salaryType: map['salary_type'] as String? ?? 'MONTHLY',
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
    String? salaryType,
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
      salaryType: salaryType ?? this.salaryType,
      hireDate: hireDate ?? this.hireDate,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
    );
  }
}
