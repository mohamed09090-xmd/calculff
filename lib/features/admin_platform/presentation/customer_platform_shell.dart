import 'package:flutter/material.dart';

import 'dashboard/platform_dashboard_screen.dart';
import 'games/games_screen.dart';
import 'offers/offers_screen.dart';
import 'orders/customer_orders_screen.dart';
import 'platform_ui_text.dart';

class CustomerPlatformShell extends StatefulWidget {
  const CustomerPlatformShell({super.key, required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  State<CustomerPlatformShell> createState() => _CustomerPlatformShellState();
}

class _CustomerPlatformShellState extends State<CustomerPlatformShell> {
  static const _wideBreakpoint = 720.0;

  int _selectedIndex = 0;

  List<_PlatformDestination> _destinations(BuildContext context) => [
    _PlatformDestination(
      label: platformText(context, 'لوحة المنصة'),
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard,
      builder: (_) => const PlatformDashboardScreen(),
    ),
    _PlatformDestination(
      label: platformText(context, 'الطلبات'),
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      builder: (_) => const CustomerOrdersScreen(),
    ),
    _PlatformDestination(
      label: platformText(context, 'العروض العامة'),
      icon: Icons.campaign_outlined,
      selectedIcon: Icons.campaign,
      builder: (_) => const OffersScreen(),
    ),
    _PlatformDestination(
      label: platformText(context, 'الألعاب'),
      icon: Icons.sports_esports_outlined,
      selectedIcon: Icons.sports_esports,
      builder: (_) => const GamesScreen(),
    ),
  ];

  Future<void> _openAdminAccount() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  platformText(sheetContext, 'حساب المدير'),
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text(
                    platformText(sheetContext, 'الجلسة الحالية إدارية.'),
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  button: true,
                  label: platformText(sheetContext, 'خروج'),
                  child: FilledButton.tonalIcon(
                    key: const Key('platform-sign-out-button'),
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await widget.onSignOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: Text(platformText(sheetContext, 'خروج')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations(context);
    final content = destinations[_selectedIndex].builder(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(platformText(context, 'منصة الزبائن')),
        actions: [
          Semantics(
            button: true,
            label: platformText(context, 'حساب المدير'),
            child: IconButton(
              key: const Key('platform-admin-account-button'),
              tooltip: platformText(context, 'حساب المدير'),
              onPressed: _openAdminAccount,
              icon: const Icon(Icons.account_circle_outlined),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < _wideBreakpoint) {
              return content;
            }
            return Row(
              children: [
                NavigationRail(
                  key: const Key('platform-navigation-rail'),
                  selectedIndex: _selectedIndex,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedIndex = index),
                  destinations: [
                    for (final destination in destinations)
                      NavigationRailDestination(
                        icon: Semantics(
                          label: destination.label,
                          button: true,
                          child: Icon(destination.icon),
                        ),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: Text(destination.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < _wideBreakpoint
          ? NavigationBar(
              key: const Key('platform-navigation-bar'),
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              destinations: [
                for (final destination in destinations)
                  NavigationDestination(
                    icon: Semantics(
                      label: destination.label,
                      button: true,
                      child: Icon(destination.icon),
                    ),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
            )
          : null,
    );
  }
}

class _PlatformDestination {
  const _PlatformDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
}
