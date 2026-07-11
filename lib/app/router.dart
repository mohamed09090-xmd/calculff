import 'package:go_router/go_router.dart';

import '../features/backup/presentation/backup_restore_screen.dart';
import '../features/calculator/presentation/calculation_result_screen.dart';
import '../features/calculator/presentation/calculator_screen.dart';
import '../features/calculator/presentation/confirm_transaction_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/dashboard/presentation/splash_screen.dart';
import '../features/inventory/presentation/inventory_screen.dart';
import '../features/packages/presentation/packages_screen.dart';
import '../features/products/presentation/products_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/transactions/presentation/transaction_details_screen.dart';
import '../features/transactions/presentation/transactions_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
    GoRoute(
      path: '/calculate',
      builder: (context, state) => const CalculatorScreen(),
      routes: [
        GoRoute(path: 'result', builder: (context, state) => const CalculationResultScreen()),
        GoRoute(path: 'confirm', builder: (context, state) => const ConfirmTransactionScreen()),
      ],
    ),
    GoRoute(path: '/products', builder: (context, state) => const ProductsScreen()),
    GoRoute(path: '/packages', builder: (context, state) => const PackagesScreen()),
    GoRoute(path: '/inventory', builder: (context, state) => const InventoryScreen()),
    GoRoute(
      path: '/transactions',
      builder: (context, state) => const TransactionsScreen(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (context, state) => TransactionDetailsScreen(
            transactionId: state.pathParameters['id']!,
          ),
        ),
      ],
    ),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(path: '/backup', builder: (context, state) => const BackupRestoreScreen()),
  ],
);
