class RestaurantFloor {
  final int? id;
  final String name;
  final int sortOrder;

  const RestaurantFloor({
    this.id,
    required this.name,
    this.sortOrder = 0,
  });

  RestaurantFloor copyWith({
    int? id,
    String? name,
    int? sortOrder,
  }) {
    return RestaurantFloor(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'sort_order': sortOrder,
    };
  }

  factory RestaurantFloor.fromMap(Map<String, dynamic> map) {
    return RestaurantFloor(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }
}
