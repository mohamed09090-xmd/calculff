enum ProductType { gems, direct }

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.type,
    required this.gemsPerUnit,
    required this.creditPerUnit,
    required this.salePriceDzd,
    this.description,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final ProductType type;
  final int gemsPerUnit;
  final int creditPerUnit;
  final int salePriceDzd;
  final String? description;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isGemProduct => type == ProductType.gems;
  bool get isDirectProduct => type == ProductType.direct;

  Product copyWith({
    String? name,
    ProductType? type,
    int? gemsPerUnit,
    int? creditPerUnit,
    int? salePriceDzd,
    String? description,
    bool clearDescription = false,
    bool? isActive,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        gemsPerUnit: gemsPerUnit ?? this.gemsPerUnit,
        creditPerUnit: creditPerUnit ?? this.creditPerUnit,
        salePriceDzd: salePriceDzd ?? this.salePriceDzd,
        description:
            clearDescription ? null : description ?? this.description,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'product_type': type.name,
        'gems_per_unit': gemsPerUnit,
        'credit_per_unit': creditPerUnit,
        'sale_price_dzd': salePriceDzd,
        'description': description,
        'is_active': isActive ? 1 : 0,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
        'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  factory Product.fromMap(Map<String, Object?> map) {
    final rawType = map['product_type'] as String?;
    return Product(
      id: map['id']! as String,
      name: map['name']! as String,
      type: rawType == null
          ? ProductType.gems
          : ProductType.values.byName(rawType),
      gemsPerUnit: (map['gems_per_unit'] as num?)?.toInt() ?? 0,
      creditPerUnit: (map['credit_per_unit'] as num).toInt(),
      salePriceDzd: (map['sale_price_dzd'] as num?)?.toInt() ?? 0,
      description: map['description'] as String?,
      isActive: (map['is_active']! as int) == 1,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? ''),
    );
  }
}
