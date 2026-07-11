class CreditPackage {
  const CreditPackage({
    required this.id,
    required this.name,
    required this.priceDzd,
    required this.credit,
    required this.validityHours,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final int priceDzd;
  final int credit;
  final int validityHours;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CreditPackage copyWith({
    String? name,
    int? priceDzd,
    int? credit,
    int? validityHours,
    bool? isActive,
  }) =>
      CreditPackage(
        id: id,
        name: name ?? this.name,
        priceDzd: priceDzd ?? this.priceDzd,
        credit: credit ?? this.credit,
        validityHours: validityHours ?? this.validityHours,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'price_dzd': priceDzd,
        'credit': credit,
        'validity_hours': validityHours,
        'is_active': isActive ? 1 : 0,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
        'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  factory CreditPackage.fromMap(Map<String, Object?> map) => CreditPackage(
        id: map['id']! as String,
        name: map['name']! as String,
        priceDzd: map['price_dzd']! as int,
        credit: map['credit']! as int,
        validityHours: map['validity_hours']! as int,
        isActive: (map['is_active']! as int) == 1,
        createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
        updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? ''),
      );
}
