class RestaurantTable {
  final int? id;
  final String name;
  final int capacity;
  final int status;
  final int sortOrder;
  final String shape; // 'square', 'round', 'rectangle'
  final double posX;
  final double posY;
  final double width;
  final double height;

  const RestaurantTable({
    this.id,
    required this.name,
    required this.capacity,
    this.status = 0,
    this.sortOrder = 0,
    this.shape = 'square',
    this.posX = -1.0,
    this.posY = -1.0,
    this.width = 120.0,
    this.height = 120.0,
  });

  RestaurantTable copyWith({
    int? id,
    String? name,
    int? capacity,
    int? status,
    int? sortOrder,
    String? shape,
    double? posX,
    double? posY,
    double? width,
    double? height,
  }) {
    return RestaurantTable(
      id: id ?? this.id,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      sortOrder: sortOrder ?? this.sortOrder,
      shape: shape ?? this.shape,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'capacity': capacity,
      'status': status,
      'sort_order': sortOrder,
      'shape': shape,
      'pos_x': posX,
      'pos_y': posY,
      'width': width,
      'height': height,
    };
  }

  factory RestaurantTable.fromMap(Map<String, dynamic> map) {
    return RestaurantTable(
      id: map['id'] as int?,
      name: map['name'] as String,
      capacity: map['capacity'] as int,
      status: map['status'] as int? ?? 0,
      sortOrder: map['sort_order'] as int? ?? 0,
      shape: map['shape'] as String? ?? 'square',
      posX: (map['pos_x'] as num?)?.toDouble() ?? -1.0,
      posY: (map['pos_y'] as num?)?.toDouble() ?? -1.0,
      width: (map['width'] as num?)?.toDouble() ?? 120.0,
      height: (map['height'] as num?)?.toDouble() ?? 120.0,
    );
  }
}
