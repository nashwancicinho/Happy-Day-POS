class EmployeeAdvanceModel {
  final int? id;
  final int employeeId;
  final String? employeeName;
  final String type; // 'ADVANCE', 'BONUS', 'DEDUCTION'
  final double amount;
  final String date;
  final String? notes;
  final String status; // 'PENDING', 'SETTLED'
  final String createdAt;

  const EmployeeAdvanceModel({
    this.id,
    required this.employeeId,
    this.employeeName,
    required this.type,
    required this.amount,
    required this.date,
    this.notes,
    this.status = 'PENDING',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'employee_id': employeeId,
      'type': type,
      'amount': amount,
      'date': date,
      'notes': notes,
      'status': status,
      'created_at': createdAt,
    };
  }

  factory EmployeeAdvanceModel.fromMap(Map<String, dynamic> map, {String? employeeName}) {
    return EmployeeAdvanceModel(
      id: map['id'] as int?,
      employeeId: map['employee_id'] as int? ?? 0,
      employeeName: employeeName ?? map['employee_name'] as String?,
      type: map['type'] as String? ?? 'ADVANCE',
      amount: (map['amount'] as num? ?? 0.0).toDouble(),
      date: map['date'] as String? ?? DateTime.now().toIso8601String().substring(0, 10),
      notes: map['notes'] as String?,
      status: map['status'] as String? ?? 'PENDING',
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  EmployeeAdvanceModel copyWith({
    int? id,
    int? employeeId,
    String? employeeName,
    String? type,
    double? amount,
    String? date,
    String? notes,
    String? status,
    String? createdAt,
  }) {
    return EmployeeAdvanceModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
