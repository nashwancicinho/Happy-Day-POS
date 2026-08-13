class OtherExpenseModel {
  final int? id;
  final String title;
  final double amount;
  final String category;
  final String? notes;
  final String? createdBy;
  final String createdAt;

  OtherExpenseModel({
    this.id,
    required this.title,
    required this.amount,
    this.category = 'عام',
    this.notes,
    this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt,
    };
  }

  factory OtherExpenseModel.fromMap(Map<String, dynamic> map) {
    return OtherExpenseModel(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num? ?? 0.0).toDouble(),
      category: map['category'] as String? ?? 'عام',
      notes: map['notes'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}
