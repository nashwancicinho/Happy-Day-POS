class OrderModel {
  final int? id;
  final int? shiftId;
  final int? tableId;
  final int? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? cashierName;
  final String orderType; // 'DINE_IN', 'TAKEAWAY', 'DELIVERY'
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double total;
  final String paymentMethod; // 'CASH', 'CARD', 'CREDIT', 'SPLIT'
  final String status; // 'OPEN', 'COMPLETED', 'SUSPENDED', 'CANCELLED'
  final String? notes;
  final String createdAt;
  final String? businessDate;

  const OrderModel({
    this.id,
    this.shiftId,
    this.tableId,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.cashierName,
    this.orderType = 'DINE_IN',
    this.subtotal = 0.0,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    this.total = 0.0,
    this.paymentMethod = 'CASH',
    this.status = 'OPEN',
    this.notes,
    required this.createdAt,
    this.businessDate,
  });

  String get effectiveDate => (businessDate != null && businessDate!.isNotEmpty) ? businessDate! : createdAt.substring(0, 10);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'shift_id': shiftId,
      'table_id': tableId,
      'customer_id': customerId,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
      'cashier_name': cashierName,
      'order_type': orderType,
      'subtotal': subtotal,
      'discount_amount': discountAmount,
      'tax_amount': taxAmount,
      'total': total,
      'payment_method': paymentMethod,
      'status': status,
      'notes': notes,
      'created_at': createdAt,
      'business_date': businessDate,
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, {String? customerName}) {
    return OrderModel(
      id: map['id'] as int?,
      shiftId: map['shift_id'] as int?,
      tableId: map['table_id'] as int?,
      customerId: map['customer_id'] as int?,
      customerName: customerName ?? map['customer_name'] as String?,
      customerPhone: map['customer_phone'] as String?,
      customerAddress: map['customer_address'] as String?,
      cashierName: map['cashier_name'] as String?,
      orderType: map['order_type'] as String? ?? 'DINE_IN',
      subtotal: (map['subtotal'] as num? ?? map['total'] as num? ?? 0.0).toDouble(),
      discountAmount: (map['discount_amount'] as num? ?? 0.0).toDouble(),
      taxAmount: (map['tax_amount'] as num? ?? 0.0).toDouble(),
      total: (map['total'] as num? ?? 0.0).toDouble(),
      paymentMethod: map['payment_method'] as String? ?? 'CASH',
      status: map['status'] as String? ?? 'OPEN',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      businessDate: map['business_date'] as String?,
    );
  }

  OrderModel copyWith({
    int? id,
    int? shiftId,
    int? tableId,
    int? customerId,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? cashierName,
    String? orderType,
    double? subtotal,
    double? discountAmount,
    double? taxAmount,
    double? total,
    String? paymentMethod,
    String? status,
    String? notes,
    String? createdAt,
    String? businessDate,
  }) {
    return OrderModel(
      id: id ?? this.id,
      shiftId: shiftId ?? this.shiftId,
      tableId: tableId ?? this.tableId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      cashierName: cashierName ?? this.cashierName,
      orderType: orderType ?? this.orderType,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      businessDate: businessDate ?? this.businessDate,
    );
  }
}
