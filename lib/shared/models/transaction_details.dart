import 'credit_package.dart';
import 'sales_transaction.dart';

class TransactionPackageItem {
  const TransactionPackageItem({
    required this.id,
    required this.transactionId,
    required this.packageId,
    required this.packageNameSnapshot,
    required this.creditSnapshot,
    required this.priceSnapshot,
    required this.validityHoursSnapshot,
    required this.quantity,
  });

  final String id;
  final String transactionId;
  final String packageId;
  final String packageNameSnapshot;
  final int creditSnapshot;
  final int priceSnapshot;
  final int validityHoursSnapshot;
  final int quantity;

  CreditPackage asPackage() => CreditPackage(
        id: packageId,
        name: packageNameSnapshot,
        priceDzd: priceSnapshot,
        credit: creditSnapshot,
        validityHours: validityHoursSnapshot,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'transaction_id': transactionId,
        'package_id': packageId,
        'package_name_snapshot': packageNameSnapshot,
        'credit_snapshot': creditSnapshot,
        'price_snapshot': priceSnapshot,
        'validity_hours_snapshot': validityHoursSnapshot,
        'quantity': quantity,
      };

  factory TransactionPackageItem.fromMap(Map<String, Object?> map) =>
      TransactionPackageItem(
        id: map['id']! as String,
        transactionId: map['transaction_id']! as String,
        packageId: map['package_id']! as String,
        packageNameSnapshot: map['package_name_snapshot']! as String,
        creditSnapshot: map['credit_snapshot']! as int,
        priceSnapshot: map['price_snapshot']! as int,
        validityHoursSnapshot: map['validity_hours_snapshot']! as int,
        quantity: map['quantity']! as int,
      );
}

class TransactionDetails {
  const TransactionDetails({required this.transaction, required this.items});
  final SalesTransaction transaction;
  final List<TransactionPackageItem> items;
}
