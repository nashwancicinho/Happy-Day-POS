class CashTransactionModel {
  final int? id;
  final int shiftId;
  final String type; // 'IN' (إيداع) or 'OUT' (سحب/مصروفات)
  final double amount;
  final String reason;
  final String createdAt;

  const CashTransactionModel({
    this.id,
    required this.shiftId,
    required this.type,
    required this.amount,
    required this.reason,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'shift_id': shiftId,
      'type': type,
      'amount': amount,
      'reason': reason,
      'created_at': createdAt,
    };
  }

  factory CashTransactionModel.fromMap(Map<String, dynamic> map) {
    return CashTransactionModel(
      id: map['id'] as int?,
      shiftId: map['shift_id'] as int,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      reason: map['reason'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}
