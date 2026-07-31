class OrderItemModel {
  final int? id;
  final int? orderId;
  final int productId;
  final String? productName;
  final double buyPrice;
  final double quantity;
  final double price; // Unit price
  final double discount; // Discount per item or line
  final String? notes;
  final bool printToKitchen;

  const OrderItemModel({
    this.id,
    this.orderId,
    required this.productId,
    this.productName,
    this.buyPrice = 0.0,
    required this.quantity,
    required this.price,
    this.discount = 0.0,
    this.notes,
    this.printToKitchen = true,
  });

  double get subtotal => (price * quantity) - discount;

  String get formattedQuantity {
    if (quantity % 1 == 0) {
      return quantity.toInt().toString();
    }
    return quantity.toStringAsFixed(3).replaceAll(RegExp(r'([.]*0)(?!.*\d)'), '');
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'order_id': orderId,
      'product_id': productId,
      'buy_price': buyPrice,
      'quantity': quantity,
      'price': price,
      'discount': discount,
      'notes': notes,
      'print_to_kitchen': printToKitchen ? 1 : 0,
    };
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> map, {String? productName, bool? printToKitchen}) {
    return OrderItemModel(
      id: map['id'] as int?,
      orderId: map['order_id'] as int?,
      productId: map['product_id'] as int,
      productName: productName,
      buyPrice: (map['buy_price'] as num? ?? 0.0).toDouble(),
      quantity: (map['quantity'] as num? ?? 1.0).toDouble(),
      price: (map['price'] as num).toDouble(),
      discount: (map['discount'] as num? ?? 0.0).toDouble(),
      notes: map['notes'] as String?,
      printToKitchen: printToKitchen ?? ((map['print_to_kitchen'] as int? ?? 1) == 1),
    );
  }

  OrderItemModel copyWith({
    int? id,
    int? orderId,
    int? productId,
    String? productName,
    double? buyPrice,
    double? quantity,
    double? price,
    double? discount,
    String? notes,
    bool? printToKitchen,
  }) {
    return OrderItemModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      buyPrice: buyPrice ?? this.buyPrice,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      discount: discount ?? this.discount,
      notes: notes ?? this.notes,
      printToKitchen: printToKitchen ?? this.printToKitchen,
    );
  }
}
