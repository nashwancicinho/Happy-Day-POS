class CustomerModel {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String? email;
  final String? notes;
  final double balance; // Positive balance = customer owes debt to store

  const CustomerModel({
    this.id,
    required this.name,
    this.phone,
    this.address,
    this.email,
    this.notes,
    this.balance = 0.0,
  });

  CustomerModel copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    String? email,
    String? notes,
    double? balance,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      balance: balance ?? this.balance,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'email': email,
      'notes': notes,
      'balance': balance,
    };
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      email: map['email'] as String?,
      notes: map['notes'] as String?,
      balance: (map['balance'] as num? ?? 0.0).toDouble(),
    );
  }
}
