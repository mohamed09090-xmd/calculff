import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../models/calculation.dart';
import '../models/credit_package.dart';
import '../models/customer.dart';
import '../models/dashboard_summary.dart';
import '../models/inventory_lot.dart';
import '../models/product.dart';
import '../models/sales_transaction.dart';
import '../repositories/app_repository.dart';
import '../repositories/enhanced_app_repository.dart';

final appRepositoryProvider = Provider<AppRepository>(
  (ref) => EnhancedAppRepository(),
);

final initializationProvider = FutureProvider<void>((ref) async {
  await ref.read(appRepositoryProvider).initialize();
});

final packagesProvider = FutureProvider<List<CreditPackage>>((ref) async {
  return ref.read(appRepositoryProvider).getPackages();
});

final activePackagesProvider = FutureProvider<List<CreditPackage>>((ref) async {
  return ref.read(appRepositoryProvider).getPackages(activeOnly: true);
});

final productsProvider = FutureProvider<List<Product>>((ref) async {
  return ref.read(appRepositoryProvider).getProducts();
});

final activeProductsProvider = FutureProvider<List<Product>>((ref) async {
  return ref.read(appRepositoryProvider).getProducts(activeOnly: true);
});

final customersProvider = FutureProvider<List<Customer>>((ref) async {
  return ref.read(appRepositoryProvider).getCustomers();
});

final activeCustomersProvider = FutureProvider<List<Customer>>((ref) async {
  return ref.read(appRepositoryProvider).getCustomers(activeOnly: true);
});

final inventoryProvider = FutureProvider<List<InventoryLot>>((ref) async {
  return ref.read(appRepositoryProvider).getInventoryLots();
});

final transactionsProvider = FutureProvider<List<SalesTransaction>>((ref) async {
  return ref.read(appRepositoryProvider).getTransactions();
});

final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  return ref.read(appRepositoryProvider).getDashboardSummary();
});

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.read(appRepositoryProvider).getSettings();

  Future<void> save(AppSettings next) async {
    state = AsyncData(next);
    await ref.read(appRepositoryProvider).saveSettings(next);
    ref.invalidate(dashboardProvider);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class CalculationController extends Notifier<CalculationResult?> {
  @override
  CalculationResult? build() => null;

  Future<CalculationResult> calculate(CalculationRequest request) async {
    final result = await ref.read(appRepositoryProvider).calculate(request);
    state = result;
    return result;
  }

  void clear() => state = null;
}

final calculationProvider =
    NotifierProvider<CalculationController, CalculationResult?>(
  CalculationController.new,
);

void invalidateAppData(WidgetRef ref) {
  ref
    ..invalidate(packagesProvider)
    ..invalidate(activePackagesProvider)
    ..invalidate(productsProvider)
    ..invalidate(activeProductsProvider)
    ..invalidate(customersProvider)
    ..invalidate(activeCustomersProvider)
    ..invalidate(inventoryProvider)
    ..invalidate(transactionsProvider)
    ..invalidate(dashboardProvider)
    ..invalidate(settingsProvider);
}
