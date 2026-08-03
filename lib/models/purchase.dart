class PurchaseItemModel {
  final int? id;
  final int? purchaseId;
  final int? productId;
  final String itemName;
  final double unitPrice;
  final double quantity;
  final double subtotal;

  const PurchaseItemModel({
    this.id,
    this.purchaseId,
    this.productId,
    required this.itemName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
  });

  Map<String, dynamic> toMap([int? pId]) {
    return {
      'id': id,
      'purchase_id': purchaseId ?? pId,
      'product_id': productId,
      'item_name': itemName,
      'unit_price': unitPrice,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }

  factory PurchaseItemModel.fromMap(Map<String, dynamic> map) {
    return PurchaseItemModel(
      id: map['id'] as int?,
      purchaseId: map['purchase_id'] as int?,
      productId: map['product_id'] as int?,
      itemName: map['item_name'] as String? ?? 'مادة',
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PurchaseInvoiceModel {
  final int? id;
  final int supplierId;
  final String supplierName;
  final String invoiceNumber;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final String paymentStatus; // 'PAID', 'PARTIAL', 'UNPAID'
  final String paymentMethod; // 'CASH', 'BANK'
  final String? notes;
  final String createdAt;
  final List<PurchaseItemModel> items;

  const PurchaseInvoiceModel({
    this.id,
    required this.supplierId,
    required this.supplierName,
    required this.invoiceNumber,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.paymentStatus,
    this.paymentMethod = 'CASH',
    this.notes,
    required this.createdAt,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'invoice_number': invoiceNumber,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'remaining_amount': remainingAmount,
      'payment_status': paymentStatus,
      'payment_method': paymentMethod,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory PurchaseInvoiceModel.fromMap(Map<String, dynamic> map, {List<PurchaseItemModel> items = const []}) {
    return PurchaseInvoiceModel(
      id: map['id'] as int?,
      supplierId: map['supplier_id'] as int? ?? 0,
      supplierName: map['supplier_name'] as String? ?? 'مورد غير معروف',
      invoiceNumber: map['invoice_number'] as String? ?? '',
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (map['remaining_amount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: map['payment_status'] as String? ?? 'PAID',
      paymentMethod: map['payment_method'] as String? ?? 'CASH',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      items: items,
    );
  }
}
