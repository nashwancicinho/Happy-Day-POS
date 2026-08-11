class ProductModel {
  final int? id;
  final int? categoryId;
  final String name;
  final String? barcode;
  final double buyPrice;
  final double price; // Sell price
  final String unit; // e.g. قطعة, كغم, غم, لتر, علبة
  final bool isWeighted; // Sold by weight
  final bool allowPriceChange; // Allow price editing at POS
  final double stockQuantity;
  final bool trackStock;
  final double minStock;
  final double taxRate;
  final String? image;
  final String? color;
  final bool isAvailable;
  final bool printToKitchen; // Send item to kitchen printer KOT
  final String? kitchenPrinter; // Specific target kitchen printer name
  final String displayLocation; // 'BOTH', 'MAIN_ONLY', 'CATEGORY_ONLY'

  const ProductModel({
    this.id,
    this.categoryId,
    required this.name,
    this.barcode,
    this.buyPrice = 0.0,
    required this.price,
    this.unit = 'قطعة',
    this.isWeighted = false,
    this.allowPriceChange = false,
    this.stockQuantity = 100.0,
    this.trackStock = true,
    this.minStock = 5.0,
    this.taxRate = 0.0,
    this.image,
    this.color,
    this.isAvailable = true,
    this.printToKitchen = false,
    this.kitchenPrinter,
    this.displayLocation = 'CATEGORY_ONLY',
  });

  bool get isLowStock => trackStock && stockQuantity <= minStock;
  double get profitMargin => price - buyPrice;

  ProductModel copyWith({
    int? id,
    int? categoryId,
    String? name,
    String? barcode,
    double? buyPrice,
    double? price,
    String? unit,
    bool? isWeighted,
    bool? allowPriceChange,
    double? stockQuantity,
    bool? trackStock,
    double? minStock,
    double? taxRate,
    String? image,
    bool clearImage = false,
    String? color,
    bool clearColor = false,
    bool? isAvailable,
    bool? printToKitchen,
    String? kitchenPrinter,
    String? displayLocation,
  }) {
    return ProductModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      buyPrice: buyPrice ?? this.buyPrice,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      isWeighted: isWeighted ?? this.isWeighted,
      allowPriceChange: allowPriceChange ?? this.allowPriceChange,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      trackStock: trackStock ?? this.trackStock,
      minStock: minStock ?? this.minStock,
      taxRate: taxRate ?? this.taxRate,
      image: clearImage ? null : (image ?? this.image),
      color: clearColor ? null : (color ?? this.color),
      isAvailable: isAvailable ?? this.isAvailable,
      printToKitchen: printToKitchen ?? this.printToKitchen,
      kitchenPrinter: kitchenPrinter ?? this.kitchenPrinter,
      displayLocation: displayLocation ?? this.displayLocation,
    );
  }


  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category_id': categoryId,
      'name': name,
      'barcode': barcode,
      'buy_price': buyPrice,
      'price': price,
      'unit': unit,
      'is_weighted': isWeighted ? 1 : 0,
      'allow_price_change': allowPriceChange ? 1 : 0,
      'stock_quantity': stockQuantity,
      'track_stock': trackStock ? 1 : 0,
      'min_stock': minStock,
      'tax_rate': taxRate,
      'image': image,
      'color': color,
      'is_available': isAvailable ? 1 : 0,
      'print_to_kitchen': printToKitchen ? 1 : 0,
      'kitchen_printer': kitchenPrinter,
      'display_location': displayLocation,
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as int?,
      categoryId: map['category_id'] as int?,
      name: map['name'] as String,
      barcode: map['barcode'] as String?,
      buyPrice: (map['buy_price'] as num? ?? 0.0).toDouble(),
      price: (map['price'] as num).toDouble(),
      unit: map['unit'] as String? ?? 'قطعة',
      isWeighted: (map['is_weighted'] as int? ?? 0) == 1,
      allowPriceChange: (map['allow_price_change'] as int? ?? 0) == 1,
      stockQuantity: (map['stock_quantity'] as num? ?? 100.0).toDouble(),
      trackStock: (map['track_stock'] as int? ?? 1) == 1,
      minStock: (map['min_stock'] as num? ?? 5.0).toDouble(),
      taxRate: (map['tax_rate'] as num? ?? 0.0).toDouble(),
      image: map['image'] as String?,
      color: map['color'] as String?,
      isAvailable: (map['is_available'] as int? ?? 1) == 1,
      printToKitchen: (map['print_to_kitchen'] as int? ?? 0) == 1,
      kitchenPrinter: map['kitchen_printer'] as String?,
      displayLocation: map['display_location'] as String? ?? 'CATEGORY_ONLY',
    );
  }

}
