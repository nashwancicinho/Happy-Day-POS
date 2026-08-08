class ProductRecipeItemModel {
  final int? id;
  final int productId;
  final int rawMaterialId;
  final String rawMaterialName;
  final String rawMaterialUnit;
  final double costPerUnit;
  final double quantityRequired;

  const ProductRecipeItemModel({
    this.id,
    required this.productId,
    required this.rawMaterialId,
    required this.rawMaterialName,
    this.rawMaterialUnit = 'غرام',
    this.costPerUnit = 0.0,
    required this.quantityRequired,
  });

  double get totalCost => costPerUnit * quantityRequired;

  ProductRecipeItemModel copyWith({
    int? id,
    int? productId,
    int? rawMaterialId,
    String? rawMaterialName,
    String? rawMaterialUnit,
    double? costPerUnit,
    double? quantityRequired,
  }) {
    return ProductRecipeItemModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      rawMaterialId: rawMaterialId ?? this.rawMaterialId,
      rawMaterialName: rawMaterialName ?? this.rawMaterialName,
      rawMaterialUnit: rawMaterialUnit ?? this.rawMaterialUnit,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      quantityRequired: quantityRequired ?? this.quantityRequired,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'product_id': productId,
      'raw_material_id': rawMaterialId,
      'quantity_required': quantityRequired,
    };
  }

  factory ProductRecipeItemModel.fromMap(Map<String, dynamic> map) {
    return ProductRecipeItemModel(
      id: map['id'] as int?,
      productId: (map['product_id'] as num).toInt(),
      rawMaterialId: (map['raw_material_id'] as num).toInt(),
      rawMaterialName: (map['raw_material_name'] as String? ?? ''),
      rawMaterialUnit: (map['raw_material_unit'] as String? ?? 'غرام'),
      costPerUnit: (map['cost_per_unit'] as num? ?? 0.0).toDouble(),
      quantityRequired: (map['quantity_required'] as num? ?? 0.0).toDouble(),
    );
  }
}
