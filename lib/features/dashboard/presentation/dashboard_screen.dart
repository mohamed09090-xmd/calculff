import 'package:flutter/material.dart';
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

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardProvider);
    final transactions = ref.watch(transactionsProvider);
    final settings = ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    String money(num value) => MoneyFormatter.format(
          value,
          useThousands: settings.useThousands,
        );

    return AppShell(
      title: AppStrings.dashboard,
      actions: [
        IconButton(
          tooltip: 'تحديث',
          onPressed: () {
            ref
              ..invalidate(dashboardProvider)
              ..invalidate(transactionsProvider)
              ..invalidate(inventoryProvider);
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/calculate'),
        icon: const Icon(Icons.add),
        label: const Text('عملية جديدة'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(dashboardProvider)
            ..invalidate(transactionsProvider);
          await ref.read(dashboardProvider.future);
        },
        child: AsyncStateView(
          value: summary,
          onRetry: () => ref.invalidate(dashboardProvider),
          data: (data) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SectionCard(
                title: 'نبض اليوم',
                icon: Icons.bolt_outlined,
                accent: Theme.of(context).colorScheme.secondary,
                child: SizedBox(
                  height: 132,
                  child: Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          label: 'مبيعات اليوم',
                          value: money(data.todaySales),
                          icon: Icons.payments_outlined,
                          emphasis: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MetricCard(
                          label: 'ربح اليوم',
                          value: money(data.todayProfit),
                          icon: Icons.trending_up,
                        ),
                      ),
                    ],
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
                  MetricCard(label: 'الرصيد الفعّال', value: '${data.activeCredit}', icon: Icons.account_balance_wallet_outlined),
                  MetricCard(label: 'قريب الانتهاء', value: '${data.expiringSoonCredit}', icon: Icons.timer_outlined),
                  MetricCard(label: 'إجمالي الربح', value: money(data.totalProfit), icon: Icons.show_chart),
                  MetricCard(label: 'عدد العمليات', value: '${data.transactionCount}', icon: Icons.receipt_long_outlined),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'آخر العمليات',
                icon: Icons.history,
                child: transactions.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Text(error.toString()),
                  data: (items) {
                    if (items.isEmpty) return const Text('لم تُحفظ أي عملية بعد.');
                    return Column(
                      children: [
                        for (final item in items.take(5))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.productNameSnapshot ?? 'حساب رصيد'),
                            subtitle: Text(AppDateUtils.format(item.createdAt)),
                            trailing: Text(
                              money(item.cashProfit),
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            onTap: () => context.push('/transactions/${item.id}'),
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
              const SizedBox(height: 88),
            ],
          ),
        ),
      ),
    );
  }
}
