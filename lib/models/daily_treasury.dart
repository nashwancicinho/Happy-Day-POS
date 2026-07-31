class DailyTreasuryModel {
  final int? id;
  final String date;
  final double dailyIncome;
  final double dailyExpense;
  final double netIncome;
  final String? notes;
  final String? closedBy;
  final String createdAt;

  const DailyTreasuryModel({
    this.id,
    required this.date,
    required this.dailyIncome,
    required this.dailyExpense,
    required this.netIncome,
    this.notes,
    this.closedBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'daily_income': dailyIncome,
      'daily_expense': dailyExpense,
      'net_income': netIncome,
      'notes': notes,
      'closed_by': closedBy,
      'created_at': createdAt,
    };
  }

  factory DailyTreasuryModel.fromMap(Map<String, dynamic> map) {
    return DailyTreasuryModel(
      id: map['id'] as int?,
      date: map['date'] as String,
      dailyIncome: (map['daily_income'] as num).toDouble(),
      dailyExpense: (map['daily_expense'] as num).toDouble(),
      netIncome: (map['net_income'] as num).toDouble(),
      notes: map['notes'] as String?,
      closedBy: map['closed_by'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}
