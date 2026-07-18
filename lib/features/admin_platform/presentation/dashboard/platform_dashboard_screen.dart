import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dashboard/platform_dashboard_controller.dart';
import '../../application/dashboard/platform_dashboard_providers.dart';
import '../../domain/common/platform_failure.dart';
import '../../domain/dashboard/platform_dashboard_summary.dart';
import '../platform_ui_text.dart';

class PlatformDashboardScreen extends ConsumerWidget {
  const PlatformDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(platformDashboardControllerProvider);
    final controller = ref.read(platformDashboardControllerProvider.notifier);
    return RefreshIndicator(
      key: const Key('platform-dashboard-refresh-indicator'),
      onRefresh: controller.refresh,
      child: ListView(
        key: const Key('platform-dashboard-list-view'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _DashboardHeader(
            isRefreshing: state.isRefreshing,
            onRefresh: controller.refresh,
          ),
          const SizedBox(height: 16),
          if (state.isStale) ...[
            _StaleBanner(failureCode: state.failureCode),
            const SizedBox(height: 12),
          ],
          if (state.status == PlatformDashboardStatus.loading)
            const _LoadingState()
          else if (state.status == PlatformDashboardStatus.offline)
            _FailureState(
              icon: Icons.cloud_off_outlined,
              title: platformText(context, 'لا يوجد اتصال بالمنصة.'),
              failureCode: state.failureCode,
              onRetry: controller.refresh,
            )
          else if (state.status == PlatformDashboardStatus.error)
            _FailureState(
              icon: Icons.error_outline,
              title: platformText(context, 'تعذر تحميل لوحة المنصة.'),
              failureCode: state.failureCode,
              onRetry: controller.refresh,
            )
          else if (state.summary case final summary?)
            _DashboardContent(summary: summary),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.isRefreshing, required this.onRefresh});

  final bool isRefreshing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                platformText(context, 'لوحة المنصة'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(platformText(context, 'ملخص مباشر لحالة منصة الزبائن.')),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: platformText(context, 'تحديث لوحة المنصة'),
          child: IconButton.filledTonal(
            key: const Key('platform-dashboard-refresh-button'),
            tooltip: platformText(context, 'تحديث لوحة المنصة'),
            onPressed: isRefreshing ? null : onRefresh,
            icon: isRefreshing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ),
      ],
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.summary});

  final PlatformDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('الطلبات الجديدة', summary.newOrdersCount, Icons.fiber_new_outlined),
      ('قيد المعالجة', summary.processingOrdersCount, Icons.sync_outlined),
      (
        'مراجعة الدفع',
        summary.paymentsUnderReviewCount,
        Icons.fact_check_outlined,
      ),
      ('المكتملة', summary.completedOrdersCount, Icons.task_alt_outlined),
      ('العروض المنشورة', summary.publishedOffersCount, Icons.campaign_outlined),
      ('الألعاب النشطة', summary.activeGamesCount, Icons.sports_esports_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 720 ? 3 : width >= 360 ? 2 : 1;
        final spacing = 12.0;
        final cardWidth = (width - spacing * (columns - 1)) / columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final metric in metrics)
                  SizedBox(
                    width: cardWidth,
                    child: _MetricCard(
                      label: platformText(context, metric.$1),
                      value: metric.$2,
                      icon: metric.$3,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Semantics(
              label: platformText(context, 'آخر تحديث محلي'),
              value: _formattedRefreshTime(context, summary.refreshedAt),
              child: Text(
                '${platformText(context, 'آخر تحديث محلي')}: '
                '${_formattedRefreshTime(context, summary.refreshedAt)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      value: '$value',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 12),
              Text(
                '$value',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: platformText(context, 'جارٍ تحميل لوحة المنصة.'),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({
    required this.icon,
    required this.title,
    required this.failureCode,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final PlatformFailureCode? failureCode;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = PlatformFailure(failureCode ?? PlatformFailureCode.unknown);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(icon, size: 48),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  platformDataFailureText(context, failure),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  key: const Key('platform-dashboard-retry-button'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(platformText(context, 'إعادة المحاولة')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.failureCode});

  final PlatformFailureCode? failureCode;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(platformText(context, 'البيانات المعروضة قديمة.')),
          subtitle: Text(
            platformDataFailureText(
              context,
              PlatformFailure(failureCode ?? PlatformFailureCode.unknown),
            ),
          ),
        ),
      ),
    );
  }
}

String _formattedRefreshTime(BuildContext context, DateTime refreshedAt) {
  final local = refreshedAt.toLocal();
  final date = MaterialLocalizations.of(context).formatCompactDate(local);
  final time = MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
  );
  return '$date، $time';
}
