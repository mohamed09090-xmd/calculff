import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_strings.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      drawer: const _AppDrawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: body,
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    final items = <({String label, IconData icon, String route})>[
      (label: AppStrings.dashboard, icon: Icons.space_dashboard_outlined, route: '/dashboard'),
      (label: AppStrings.newCalculation, icon: Icons.calculate_outlined, route: '/calculate'),
      (label: AppStrings.products, icon: Icons.diamond_outlined, route: '/products'),
      (label: AppStrings.packages, icon: Icons.inventory_2_outlined, route: '/packages'),
      (label: AppStrings.inventory, icon: Icons.hourglass_bottom_outlined, route: '/inventory'),
      (label: AppStrings.transactions, icon: Icons.receipt_long_outlined, route: '/transactions'),
      (label: AppStrings.settings, icon: Icons.tune_outlined, route: '/settings'),
      (label: AppStrings.backup, icon: Icons.sd_storage_outlined, route: '/backup'),
    ];
    return NavigationDrawer(
      children: [
        DrawerHeader(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.stacked_line_chart, size: 36, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(height: 10),
              const Text(AppStrings.appName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const Text('حساب • مخزون • ربح', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        for (final item in items)
          ListTile(
            leading: Icon(item.icon),
            title: Text(item.label),
            onTap: () {
              Navigator.of(context).pop();
              context.go(item.route);
            },
          ),
      ],
    );
  }
}
