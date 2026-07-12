class BackupPreview {
  const BackupPreview({
    required this.version,
    required this.exportedAt,
    required this.packageCount,
    required this.productCount,
    required this.customerCount,
    required this.transactionCount,
    required this.inventoryLotCount,
    required this.isLegacy,
  });

  final int version;
  final DateTime? exportedAt;
  final int packageCount;
  final int productCount;
  final int customerCount;
  final int transactionCount;
  final int inventoryLotCount;
  final bool isLegacy;

  int get totalRecords =>
      packageCount +
      productCount +
      customerCount +
      transactionCount +
      inventoryLotCount;
}
