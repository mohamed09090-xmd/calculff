class Product {
  const Product({
    required this.id,
    required this.name,
    required this.gemsPerUnit,
    required this.creditPerUnit,
    required this.salePriceDzd,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final int gemsPerUnit;
  final int creditPerUnit;
  final int salePriceDzd;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product copyWith({
    String? name,
    int? gemsPerUnit,
    int? creditPerUnit,
    int? salePriceDzd,
    bool? isActive,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        gemsPerUnit: gemsPerUnit ?? this.gemsPerUnit,
        creditPerUnit: creditPerUnit ?? this.creditPerUnit,
        salePriceDzd: salePriceDzd ?? this.salePriceDzd,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'gems_per_unit': gemsPerUnit,
        'credit_per_unit': creditPerUnit,
        'sale_price_dzd': salePriceDzd,
        'is_active': isActive ? 1 : 0,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
        'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  factory Product.fromMap(Map<String, Object?> map) => Product(
        id: map['id']! as String,
        name: map['name']! as String,
        gemsPerUnit: map['gems_per_unit']! as int,
        creditPerUnit: map['credit_per_unit']! as int,
        salePriceDzd: map['sale_price_dzd']! as int,
        isActive: (map['is_active']! as int) == 1,
        createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
        updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? ''),
      );
}
