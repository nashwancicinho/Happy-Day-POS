class RawMaterialModel {
  final int? id;
  final String name;
  final String unit; // e.g. غرام, كغم, مل, لتر, قطعة
  final double costPerUnit; // كلفة الوحدة الواحدة
  final double stockQuantity; // الرصيد المتاح حالياً
  final double minStock; // حد التنبيه
  final String? createdAt;

  const RawMaterialModel({
    this.id,
    required this.name,
    this.unit = 'غرام',
    this.costPerUnit = 0.0,
    this.stockQuantity = 0.0,
    this.minStock = 100.0,
    this.createdAt,
  });

  bool get isLowStock => stockQuantity <= minStock;

  RawMaterialModel copyWith({
    int? id,
    String? name,
    String? unit,
    double? costPerUnit,
    double? stockQuantity,
    double? minStock,
    String? createdAt,
  }) {
    return RawMaterialModel(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minStock: minStock ?? this.minStock,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'unit': unit,
      'cost_per_unit': costPerUnit,
      'stock_quantity': stockQuantity,
      'min_stock': minStock,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory RawMaterialModel.fromMap(Map<String, dynamic> map) {
    return RawMaterialModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      unit: map['unit'] as String? ?? 'غرام',
      costPerUnit: (map['cost_per_unit'] as num? ?? 0.0).toDouble(),
      stockQuantity: (map['stock_quantity'] as num? ?? 0.0).toDouble(),
      minStock: (map['min_stock'] as num? ?? 100.0).toDouble(),
      createdAt: map['created_at'] as String?,
    );
  }
}
