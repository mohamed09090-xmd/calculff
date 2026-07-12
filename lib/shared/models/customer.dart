class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.notes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.transactionCount = 0,
    this.totalSpent = 0,
    this.totalProfit = 0,
    this.lastTransactionAt,
  });

  final String id;
  final String name;
  final String? phone;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int transactionCount;
  final int totalSpent;
  final int totalProfit;
  final DateTime? lastTransactionAt;

  Customer copyWith({
    String? name,
    String? phone,
    String? notes,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      transactionCount: transactionCount,
      totalSpent: totalSpent,
      totalProfit: totalProfit,
      lastTransactionAt: lastTransactionAt,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'phone': _nullableText(phone),
    'notes': _nullableText(notes),
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Customer.fromMap(Map<String, Object?> map) {
    final lastTransaction = map['last_transaction_at'] as String?;
    return Customer(
      id: map['id']! as String,
      name: (map['name']! as String).trim(),
      phone: _nullableText(map['phone'] as String?),
      notes: _nullableText(map['notes'] as String?),
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
      transactionCount: (map['transaction_count'] as num?)?.toInt() ?? 0,
      totalSpent: (map['total_spent'] as num?)?.toInt() ?? 0,
      totalProfit: (map['total_profit'] as num?)?.toInt() ?? 0,
      lastTransactionAt: lastTransaction == null
          ? null
          : DateTime.tryParse(lastTransaction),
    );
  }

  static String? _nullableText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
