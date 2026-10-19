class TreasuryTransactionModel {
  final int? id;
  final String type; // 'IN' (إدخال مبلغ) or 'OUT' (إخراج مبلغ)
  final double amount;
  final String reason; // البيان / سبب العملية
  final String? notes; // ملاحظات إضافية
  final String? createdBy; // المستخدم المنفذ
  final int isClosed; // 0 for active current session, 1 for closed session
  final String createdAt; // تاريخ ووقت الحركة ISO 8601

  TreasuryTransactionModel({
    this.id,
    required this.type,
    required this.amount,
    required this.reason,
    this.notes,
    this.createdBy,
    this.isClosed = 0,
    required this.createdAt,
  });

  bool get isDeposit => type.toUpperCase() == 'IN';
  bool get isWithdrawal => type.toUpperCase() == 'OUT';
  bool get isClosedSession => isClosed == 1;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type,
      'amount': amount,
      'reason': reason,
      'notes': notes,
      'created_by': createdBy,
      'is_closed': isClosed,
      'created_at': createdAt,
    };
  }

  factory TreasuryTransactionModel.fromMap(Map<String, dynamic> map) {
    return TreasuryTransactionModel(
      id: map['id'] as int?,
      type: map['type'] as String? ?? 'IN',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      reason: map['reason'] as String? ?? '',
      notes: map['notes'] as String?,
      createdBy: map['created_by'] as String?,
      isClosed: (map['is_closed'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  TreasuryTransactionModel copyWith({
    int? id,
    String? type,
    double? amount,
    String? reason,
    String? notes,
    String? createdBy,
    int? isClosed,
    String? createdAt,
  }) {
    return TreasuryTransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      isClosed: isClosed ?? this.isClosed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
