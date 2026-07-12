import 'package:flutter/material.dart' hide Text;

import '../../../core/localization/localized_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/providers/app_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _refreshController;
  bool _entranceScheduled = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    );
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  void _scheduleEntrance() {
    if (_entranceScheduled) return;
    _entranceScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _entranceController.value = 1;
      } else {
        _entranceController.forward(from: 0);
      }
    });
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    if (!MediaQuery.disableAnimationsOf(context)) {
      _refreshController.repeat();
    }

    ref
      ..invalidate(dashboardProvider)
      ..invalidate(transactionsProvider)
      ..invalidate(inventoryProvider);

    try {
      await Future.wait<dynamic>([
        ref.read(dashboardProvider.future),
        ref.read(transactionsProvider.future),
        ref.read(inventoryProvider.future),
        Future<void>.delayed(const Duration(milliseconds: 620)),
      ]);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر التحديث: $error')),
        );
      }
    } finally {
      _refreshController
        ..stop()
        ..reset();
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(dashboardProvider);
    final transactions = ref.watch(transactionsProvider);
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    String money(num value) => MoneyFormatter.format(
          value,
          useThousands: settings.useThousands,
        );

    return AppShell(
      title: AppStrings.dashboard,
      actions: [
        IconButton(
          tooltip: 'تحديث',
          onPressed: _refreshing ? null : _refresh,
          icon: RotationTransition(
            turns: _refreshController,
            child: const Icon(Icons.refresh),
          ),
        ),
      ],
      floatingActionButton: _DashboardEntrance(
        animation: _entranceController,
        begin: 0.66,
        end: 1,
        offset: const Offset(0, 0.34),
        child: FloatingActionButton.extended(
          onPressed: () => context.go('/calculate'),
          icon: const Icon(Icons.add),
          label: const Text('عملية جديدة'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: AsyncStateView(
          value: summary,
          onRetry: () => ref.invalidate(dashboardProvider),
          data: (data) {
            _scheduleEntrance();
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _DashboardEntrance(
                  animation: _entranceController,
                  begin: 0,
                  end: 0.42,
                  offset: const Offset(0, -0.18),
                  child: SectionCard(
                    title: 'نبض اليوم',
                    icon: Icons.bolt_outlined,
                    accent: Theme.of(context).colorScheme.secondary,
                    child: SizedBox(
                      height: 132,
                      child: Row(
                        children: [
                          Expanded(
                            child: _DashboardEntrance(
                              animation: _entranceController,
                              begin: 0.13,
                              end: 0.52,
                              offset: const Offset(0.2, 0),
                              child: MetricCard(
                                label: 'مبيعات اليوم',
                                value: money(data.todaySales),
                                icon: Icons.payments_outlined,
                                emphasis: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DashboardEntrance(
                              animation: _entranceController,
                              begin: 0.2,
                              end: 0.59,
                              offset: const Offset(-0.2, 0),
                              child: MetricCard(
                                label: 'ربح اليوم',
                                value: money(data.todayProfit),
                                icon: Icons.trending_up,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.3,
                  children: [
                    _DashboardEntrance(
                      animation: _entranceController,
                      begin: 0.27,
                      end: 0.65,
                      offset: const Offset(0.22, 0),
                      child: MetricCard(
                        label: 'الرصيد الفعّال',
                        value: '${data.activeCredit}',
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                    _DashboardEntrance(
                      animation: _entranceController,
                      begin: 0.33,
                      end: 0.71,
                      offset: const Offset(-0.22, 0),
                      child: MetricCard(
                        label: 'قريب الانتهاء',
                        value: '${data.expiringSoonCredit}',
                        icon: Icons.timer_outlined,
                      ),
                    ),
                    _DashboardEntrance(
                      animation: _entranceController,
                      begin: 0.4,
                      end: 0.78,
                      offset: const Offset(0.22, 0),
                      child: MetricCard(
                        label: 'إجمالي الربح',
                        value: money(data.totalProfit),
                        icon: Icons.show_chart,
                      ),
                    ),
                    _DashboardEntrance(
                      animation: _entranceController,
                      begin: 0.46,
                      end: 0.84,
                      offset: const Offset(-0.22, 0),
                      child: MetricCard(
                        label: 'عدد العمليات',
                        value: '${data.transactionCount}',
                        icon: Icons.receipt_long_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DashboardEntrance(
                  animation: _entranceController,
                  begin: 0.57,
                  end: 1,
                  offset: const Offset(0, 0.2),
                  child: SectionCard(
                    title: 'آخر العمليات',
                    icon: Icons.history,
                    child: transactions.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => Text(error.toString()),
                      data: (items) {
                        if (items.isEmpty) {
                          return const Text('لم تُحفظ أي عملية بعد.');
                        }
                        return Column(
                          children: [
                            for (final item in items.take(5))
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  child: Text(
                                    item.customerName.substring(0, 1),
                                  ),
                                ),
                                title: Text(
                                  item.customerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                subtitle: Text(
                                  '${item.productNameSnapshot ?? 'حساب رصيد'} • '
                                  '${AppDateUtils.format(item.createdAt)}',
                                ),
                                trailing: Text(
                                  money(item.cashProfit),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                onTap: () => context.push(
                                  '/transactions/${item.id}',
                                ),
                              ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () => context.go('/transactions'),
                                child: const Text('فتح السجل الكامل'),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 88),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardEntrance extends StatelessWidget {
  const _DashboardEntrance({
    required this.animation,
    required this.begin,
    required this.end,
    required this.offset,
    required this.child,
  });

  final Animation<double> animation;
  final double begin;
  final double end;
  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    final slide = Tween<Offset>(
      begin: offset,
      end: Offset.zero,
    ).animate(curved);
    final scale = Tween<double>(begin: 0.985, end: 1).animate(curved);

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: slide,
        child: ScaleTransition(
          scale: scale,
          child: RepaintBoundary(child: child),
        ),
      ),
    );
  }
}
