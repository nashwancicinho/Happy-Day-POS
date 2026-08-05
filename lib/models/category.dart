class CategoryModel {
  final int? id;
  final String name;
  final String? color;
  final String? image;

  const CategoryModel({
    this.id,
    required this.name,
    this.color,
    this.image,
  });

  CategoryModel copyWith({
    int? id,
    String? name,
    String? color,
    bool clearColor = false,
    String? image,
    bool clearImage = false,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      color: clearColor ? null : (color ?? this.color),
      image: clearImage ? null : (image ?? this.image),
    );
  }


  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'color': color,
      'image': image,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: map['color'] as String?,
      image: map['image'] as String?,
    );
  }
}

