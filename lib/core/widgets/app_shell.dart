import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_strings.dart';

class AppShell extends StatefulWidget {
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
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  final _drawerKey = GlobalKey<_AppDrawerState>();
  late final AnimationController _contentController;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    final curve = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOutCubic,
    );
    _contentOpacity = Tween<double>(begin: 0, end: 1).animate(curve);
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.025),
      end: Offset.zero,
    ).animate(curve);
    _contentController.forward();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _handleDrawerChanged(bool isOpened) {
    if (!isOpened) {
      _drawerKey.currentState?.reset();
      return;
    }

    final drawerState = _drawerKey.currentState;
    if (drawerState != null) {
      drawerState.play();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _drawerKey.currentState?.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: widget.body,
      ),
    );
    final animatedContent = MediaQuery.disableAnimationsOf(context)
        ? content
        : FadeTransition(
            opacity: _contentOpacity,
            child: SlideTransition(
              position: _contentSlide,
              child: RepaintBoundary(child: content),
            ),
          );

    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: widget.actions),
      drawer: _AppDrawer(key: _drawerKey),
      onDrawerChanged: _handleDrawerChanged,
      body: animatedContent,
      floatingActionButton: widget.floatingActionButton,
    );
  }
}

class _AppDrawer extends StatefulWidget {
  const _AppDrawer({super.key});

  @override
  State<_AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<_AppDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: 1,
    );
  }

  void play() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    _controller.forward(from: 0);
  }

  void reset() => _controller.reset();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = <({String label, IconData icon, String route})>[
      (
        label: AppStrings.dashboard,
        icon: Icons.space_dashboard_outlined,
        route: '/dashboard',
      ),
      (
        label: AppStrings.newCalculation,
        icon: Icons.calculate_outlined,
        route: '/calculate',
      ),
      (
        label: AppStrings.customers,
        icon: Icons.people_alt_outlined,
        route: '/customers',
      ),
      (
        label: AppStrings.products,
        icon: Icons.diamond_outlined,
        route: '/products',
      ),
      (
        label: AppStrings.packages,
        icon: Icons.inventory_2_outlined,
        route: '/packages',
      ),
      (
        label: AppStrings.inventory,
        icon: Icons.hourglass_bottom_outlined,
        route: '/inventory',
      ),
      (
        label: AppStrings.transactions,
        icon: Icons.receipt_long_outlined,
        route: '/transactions',
      ),
      (
        label: AppStrings.settings,
        icon: Icons.tune_outlined,
        route: '/settings',
      ),
      (
        label: AppStrings.backup,
        icon: Icons.sd_storage_outlined,
        route: '/backup',
      ),
    ];

    final headerAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.48, curve: Curves.easeOutBack),
    );

    return NavigationDrawer(
      children: [
        AnimatedBuilder(
          animation: headerAnimation,
          builder: (context, child) {
            final value = headerAnimation.value;
            return Opacity(
              opacity: value.clamp(0, 1),
              child: Transform.translate(
                offset: Offset(22 * (1 - value), 0),
                child: Transform.scale(
                  alignment: Alignment.centerRight,
                  scale: 0.94 + (0.06 * value),
                  child: child,
                ),
              ),
            );
          },
          child: DrawerHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.stacked_line_chart,
                  size: 36,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(height: 10),
                const Text(
                  AppStrings.appName,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const Text(
                  'حساب • مخزون • ربح',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        for (var index = 0; index < items.length; index++)
          _AnimatedDrawerTile(
            label: items[index].label,
            icon: items[index].icon,
            route: items[index].route,
            animation: CurvedAnimation(
              parent: _controller,
              curve: Interval(
                0.14 + (index * 0.058),
                (0.5 + (index * 0.055)).clamp(0.0, 1.0),
                curve: Curves.easeOutCubic,
              ),
            ),
          ),
      ],
    );
  }
}

class _AnimatedDrawerTile extends StatefulWidget {
  const _AnimatedDrawerTile({
    required this.label,
    required this.icon,
    required this.route,
    required this.animation,
  });

  final String label;
  final IconData icon;
  final String route;
  final Animation<double> animation;

  @override
  State<_AnimatedDrawerTile> createState() => _AnimatedDrawerTileState();
}

class _AnimatedDrawerTileState extends State<_AnimatedDrawerTile> {
  bool _pressed = false;
  bool _navigating = false;

  void _navigate() {
    if (_navigating) return;
    _navigating = true;
    setState(() => _pressed = true);
    final router = GoRouter.of(context);

    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      setState(() => _pressed = false);
      Navigator.of(context).pop();
      Future<void>.delayed(
        const Duration(milliseconds: 130),
        () => router.go(widget.route),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final value = widget.animation.value;
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(26 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _navigate,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Icon(widget.icon),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.chevron_left_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
