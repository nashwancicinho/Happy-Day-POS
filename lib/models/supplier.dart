class SupplierModel {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final double balance; // Debt owed to supplier (المبلغ المستحق للمورد)
  final String? createdAt;

  const SupplierModel({
    this.id,
    required this.name,
    this.phone,
    this.address,
    this.notes,
    this.balance = 0.0,
    this.createdAt,
  });

  SupplierModel copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    String? notes,
    double? balance,
    String? createdAt,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'notes': notes,
      'balance': balance,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory SupplierModel.fromMap(Map<String, dynamic> map) {
    return SupplierModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? 'مورد غير معروف',
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'] as String?,
    );
  }
}
