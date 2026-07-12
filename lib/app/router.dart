import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/backup/presentation/backup_restore_screen.dart';
import '../features/calculator/presentation/calculation_result_screen.dart';
import '../features/calculator/presentation/calculator_screen.dart';
import '../features/calculator/presentation/confirm_transaction_screen.dart';
import '../features/customers/presentation/customers_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/dashboard/presentation/splash_screen.dart';
import '../features/inventory/presentation/inventory_screen.dart';
import '../features/packages/presentation/packages_screen.dart';
import '../features/products/presentation/products_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/transactions/presentation/transaction_details_screen.dart';
import '../features/transactions/presentation/transaction_edit_screen.dart';
import '../features/transactions/presentation/transactions_screen.dart';

CustomTransitionPage<void> _animatedPage(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    child: RepaintBoundary(child: child),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;

      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final opacity = Tween<double>(begin: 0.84, end: 1).animate(curved);
      final position = Tween<Offset>(
        begin: const Offset(-0.05, 0),
        end: Offset.zero,
      ).animate(curved);
      final scale = Tween<double>(begin: 0.992, end: 1).animate(curved);

      return FadeTransition(
        opacity: opacity,
        child: SlideTransition(
          position: position,
          child: ScaleTransition(scale: scale, child: child),
        ),
      );
    },
  );
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/dashboard',
      pageBuilder: (context, state) =>
          _animatedPage(state, const DashboardScreen()),
    ),
    GoRoute(
      path: '/calculate',
      pageBuilder: (context, state) =>
          _animatedPage(state, const CalculatorScreen()),
      routes: [
        GoRoute(
          path: 'result',
          pageBuilder: (context, state) =>
              _animatedPage(state, const CalculationResultScreen()),
        ),
        GoRoute(
          path: 'confirm',
          pageBuilder: (context, state) =>
              _animatedPage(state, const ConfirmTransactionScreen()),
        ),
      ],
    ),
    GoRoute(
      path: '/customers',
      pageBuilder: (context, state) =>
          _animatedPage(state, const CustomersScreen()),
    ),
    GoRoute(
      path: '/products',
      pageBuilder: (context, state) =>
          _animatedPage(state, const ProductsScreen()),
    ),
    GoRoute(
      path: '/packages',
      pageBuilder: (context, state) =>
          _animatedPage(state, const PackagesScreen()),
    ),
    GoRoute(
      path: '/inventory',
      pageBuilder: (context, state) =>
          _animatedPage(state, const InventoryScreen()),
    ),
    GoRoute(
      path: '/transactions',
      pageBuilder: (context, state) =>
          _animatedPage(state, const TransactionsScreen()),
      routes: [
        GoRoute(
          path: ':id',
          pageBuilder: (context, state) => _animatedPage(
            state,
            TransactionDetailsScreen(
              transactionId: state.pathParameters['id']!,
              showUndo: state.uri.queryParameters['undo'] == '1',
            ),
          ),
          routes: [
            GoRoute(
              path: 'edit',
              pageBuilder: (context, state) => _animatedPage(
                state,
                TransactionEditScreen(
                  transactionId: state.pathParameters['id']!,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) =>
          _animatedPage(state, const SettingsScreen()),
    ),
    GoRoute(
      path: '/backup',
      pageBuilder: (context, state) =>
          _animatedPage(state, const BackupRestoreScreen()),
    ),
  ],
);
