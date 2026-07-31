class RestaurantTable {
  final int? id;
  final String name;
  final int capacity;
  final int status;
  final int sortOrder;
  final String shape;

  const RestaurantTable({
    this.id,
    required this.name,
    required this.capacity,
    this.status = 0,
    this.sortOrder = 0,
    this.shape = 'square',
  });

  RestaurantTable copyWith({
    int? id,
    String? name,
    int? capacity,
    int? status,
    int? sortOrder,
    String? shape,
  }) {
    return RestaurantTable(
      id: id ?? this.id,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      sortOrder: sortOrder ?? this.sortOrder,
      shape: shape ?? this.shape,
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
    );
  }
}
