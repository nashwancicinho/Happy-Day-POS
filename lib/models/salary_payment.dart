class SalaryPaymentModel {
  final int? id;
  final int employeeId;
  final String? employeeName;
  final String monthYear; // e.g. '2026-08'
  final double baseSalary;
  final double totalAdvances;
  final double totalBonuses;
  final double totalDeductions;
  final double netSalary;
  final String paymentDate;
  final String paymentMethod; // 'CASH', 'CARD'
  final String? paidBy;
  final String? notes;
  final String createdAt;

  const SalaryPaymentModel({
    this.id,
    required this.employeeId,
    this.employeeName,
    required this.monthYear,
    required this.baseSalary,
    this.totalAdvances = 0.0,
    this.totalBonuses = 0.0,
    this.totalDeductions = 0.0,
    required this.netSalary,
    required this.paymentDate,
    this.paymentMethod = 'CASH',
    this.paidBy,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'employee_id': employeeId,
      'month_year': monthYear,
      'base_salary': baseSalary,
      'total_advances': totalAdvances,
      'total_bonuses': totalBonuses,
      'total_deductions': totalDeductions,
      'net_salary': netSalary,
      'payment_date': paymentDate,
      'payment_method': paymentMethod,
      'paid_by': paidBy,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory SalaryPaymentModel.fromMap(Map<String, dynamic> map, {String? employeeName}) {
    return SalaryPaymentModel(
      id: map['id'] as int?,
      employeeId: map['employee_id'] as int? ?? 0,
      employeeName: employeeName ?? map['employee_name'] as String?,
      monthYear: map['month_year'] as String? ?? '',
      baseSalary: (map['base_salary'] as num? ?? 0.0).toDouble(),
      totalAdvances: (map['total_advances'] as num? ?? 0.0).toDouble(),
      totalBonuses: (map['total_bonuses'] as num? ?? 0.0).toDouble(),
      totalDeductions: (map['total_deductions'] as num? ?? 0.0).toDouble(),
      netSalary: (map['net_salary'] as num? ?? 0.0).toDouble(),
      paymentDate: map['payment_date'] as String? ?? DateTime.now().toIso8601String().substring(0, 10),
      paymentMethod: map['payment_method'] as String? ?? 'CASH',
      paidBy: map['paid_by'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}
