class ShiftModel {
  final int? id;
  final String? userName;
  final String openedAt;
  final String? closedAt;
  final double openingCash;
  final double closingCashExpected;
  final double closingCashActual;
  final String status; // 'OPEN', 'CLOSED'

  const ShiftModel({
    this.id,
    this.userName = 'الكاشير',
    required this.openedAt,
    this.closedAt,
    required this.openingCash,
    this.closingCashExpected = 0.0,
    this.closingCashActual = 0.0,
    this.status = 'OPEN',
  });

  bool get isOpen => status == 'OPEN';
  double get variance => closingCashActual - closingCashExpected;

  ShiftModel copyWith({
    int? id,
    String? userName,
    String? openedAt,
    String? closedAt,
    double? openingCash,
    double? closingCashExpected,
    double? closingCashActual,
    String? status,
  }) {
    return ShiftModel(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      openingCash: openingCash ?? this.openingCash,
      closingCashExpected: closingCashExpected ?? this.closingCashExpected,
      closingCashActual: closingCashActual ?? this.closingCashActual,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_name': userName,
      'opened_at': openedAt,
      'closed_at': closedAt,
      'opening_cash': openingCash,
      'closing_cash_expected': closingCashExpected,
      'closing_cash_actual': closingCashActual,
      'status': status,
    };
  }

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    return ShiftModel(
      id: map['id'] as int?,
      userName: map['user_name'] as String? ?? 'الكاشير',
      openedAt: map['opened_at'] as String,
      closedAt: map['closed_at'] as String?,
      openingCash: (map['opening_cash'] as num? ?? 0.0).toDouble(),
      closingCashExpected: (map['closing_cash_expected'] as num? ?? 0.0).toDouble(),
      closingCashActual: (map['closing_cash_actual'] as num? ?? 0.0).toDouble(),
      status: map['status'] as String? ?? 'OPEN',
    );
  }
}
