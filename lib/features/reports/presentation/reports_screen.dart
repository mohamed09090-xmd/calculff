import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';




import '../../../core/localization/localized_text.dart';

import '../../../core/localization/app_translator.dart';


import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/models/report.dart';
import '../../../shared/providers/app_providers.dart';
import '../data/report_export_service.dart';
import 'report_providers.dart';

enum _ReportExportAction { share, save }

class _ReportExportRequest {
  const _ReportExportRequest({
    required this.format,
    required this.action,
  });

  final ReportExportFormat format;
  final _ReportExportAction action;
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  final ReportExportService _exportService = ReportExportService();
  ReportPeriod _period = ReportPeriod.last7Days;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(reportProvider(_period));
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;

    return AppShell(
      title: 'التقارير',
      actions: [
        IconButton(
          tooltip: AppTranslator.translate(context, 'مشاركة أو حفظ التقرير'),
          onPressed: _exporting || report.valueOrNull == null
              ? null
              : () => _openExportSheet(
                    report.valueOrNull!,
                    settings,
                  ),
          icon: _exporting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.ios_share_outlined),
        ),
        IconButton(
          tooltip: AppTranslator.translate(context, 'تحديث'),
          onPressed: () => ref.invalidate(reportProvider(_period)),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ReportPeriod.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final period = ReportPeriod.values[index];
                return ChoiceChip(
                  label: Text(period.label),
                  selected: period == _period,
                  onSelected: (_) => setState(() => _period = period),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AsyncStateView(
              value: report,
              onRetry: () => ref.invalidate(reportProvider(_period)),
              data: (data) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(reportProvider(_period));
                  await ref.read(reportProvider(_period).future);
                },
                child: _ReportContent(
                  report: data,
                  settings: settings,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openExportSheet(
    ReportSummary report,
    AppSettings settings,
  ) async {
    final request = await showModalBottomSheet<_ReportExportRequest>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _ReportExportSheet(),
    );
    if (request == null || !mounted) return;
    await _export(report, settings, request);
  }

  Future<void> _export(
    ReportSummary report,
    AppSettings settings,
    _ReportExportRequest request,
  ) async {
    final shareSubject = AppTranslator.translate(
      context,
      'تقرير ${report.period.label}',
    );
    final saveDialogTitle = AppTranslator.translate(
      context,
      'حفظ تقرير ${report.period.label}',
    );
    setState(() => _exporting = true);
    try {
      final result = await _exportService.create(
        format: request.format,
        report: report,
        settings: settings,
        context: context,
      );

      if (request.action == _ReportExportAction.share) {
        await Share.shareXFiles(
          [XFile(result.file.path, mimeType: result.format.mimeType)],
          subject: shareSubject,
          text: 'تقرير ${report.period.label} - '
              '${MoneyFormatter.format(report.current.profit, useThousands: settings.useThousands)} ربح',
        );
        return;
      }

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: saveDialogTitle,
        fileName: result.fileName,
        type: FileType.custom,
        allowedExtensions: [result.format.extension],
      );
      if (savedPath == null) return;
      await result.file.copy(savedPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ التقرير بصيغة ${result.format.label}.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تصدير التقرير: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _ReportExportSheet extends StatefulWidget {
  const _ReportExportSheet();

  @override
  State<_ReportExportSheet> createState() => _ReportExportSheetState();
}

class _ReportExportSheetState extends State<_ReportExportSheet> {
  ReportExportFormat _format = ReportExportFormat.pdf;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تصدير التقرير',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'اختر الصيغة، ثم شارك التقرير أو احفظ نسخة في الجهاز.',
            ),
            const SizedBox(height: 16),
            for (final format in ReportExportFormat.values) ...[
              _FormatTile(
                format: format,
                selected: _format == format,
                onTap: () => setState(() => _format = format),
              ),
              if (format != ReportExportFormat.values.last)
                const SizedBox(height: 8),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      _ReportExportRequest(
                        format: _format,
                        action: _ReportExportAction.save,
                      ),
                    ),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('حفظ في الجهاز'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      _ReportExportRequest(
                        format: _format,
                        action: _ReportExportAction.share,
                      ),
                    ),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('مشاركة'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.format,
    required this.selected,
    required this.onTap,
  });

  final ReportExportFormat format;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final description = switch (format) {
      ReportExportFormat.csv => 'ملف جداول قابل للفتح في Excel',
      ReportExportFormat.pdf => 'تقرير منظم على صفحات جاهزة للطباعة',
      ReportExportFormat.png => 'صورة طويلة واضحة للمشاركة السريعة',
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  selected ? scheme.primary : scheme.surfaceContainer,
              foregroundColor:
                  selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              child: Icon(format.icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    format.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? scheme.primary : scheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({
    required this.report,
    required this.settings,
  });

  final ReportSummary report;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    String money(num value) => MoneyFormatter.format(
          value,
          useThousands: settings.useThousands,
        );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SectionCard(
          title: report.period.label,
          icon: Icons.calendar_month_outlined,
          accent: Theme.of(context).colorScheme.secondary,
          child: Text(_periodDescription(report)),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.14,
          children: [
            _MetricCard(
              label: AppTranslator.translate(context, 'المبيعات'),
              value: money(report.current.sales),
              icon: Icons.payments_outlined,
              changePercent: report.salesChangePercent,
              emphasis: true,
            ),
            _MetricCard(
              label: AppTranslator.translate(context, 'الربح الصافي'),
              value: money(report.current.profit),
              icon: Icons.trending_up,
              changePercent: report.profitChangePercent,
              negative: report.current.profit < 0,
            ),
            _MetricCard(
              label: AppTranslator.translate(context, 'التكلفة'),
              value: money(report.current.cost),
              icon: Icons.shopping_cart_checkout_outlined,
            ),
            _MetricCard(
              label: AppTranslator.translate(context, 'العمليات'),
              value: '${report.current.transactionCount}',
              icon: Icons.receipt_long_outlined,
              changePercent: report.transactionChangePercent,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'ملخص تشغيلي',
          icon: Icons.insights_outlined,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CompactMetric(
                label: AppTranslator.translate(context, 'العملاء'),
                value: '${report.current.customerCount}',
              ),
              _CompactMetric(
                label: AppTranslator.translate(context, 'متوسط العملية'),
                value: money(report.current.averageSale),
              ),
              _CompactMetric(
                label: AppTranslator.translate(context, 'متوسط الربح'),
                value: money(report.current.averageProfit),
              ),
              _CompactMetric(
                label: AppTranslator.translate(context, 'الرصيد المطلوب'),
                value: '${report.current.requiredCredit}',
              ),
              _CompactMetric(
                label: AppTranslator.translate(context, 'الرصيد المشتَرى'),
                value: '${report.current.purchasedCredit}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'اتجاه المبيعات والربح',
          icon: Icons.stacked_bar_chart_outlined,
          child: report.points.isEmpty
              ? const Text('لا توجد بيانات كافية للرسم.')
              : _ReportBarChart(points: report.points, money: money),
        ),
        const SizedBox(height: 12),
        _RankingSection(
          title: 'أفضل المنتجات',
          icon: Icons.diamond_outlined,
          items: report.topProducts,
          money: money,
          emptyText: 'لا توجد منتجات ضمن هذه الفترة.',
        ),
        const SizedBox(height: 12),
        _RankingSection(
          title: 'أفضل العملاء',
          icon: Icons.people_alt_outlined,
          items: report.topCustomers,
          money: money,
          emptyText: 'لا توجد عمليات عملاء ضمن هذه الفترة.',
        ),
      ],
    );
  }

  String _periodDescription(ReportSummary report) {
    if (report.start == null) {
      return 'لا توجد عمليات محفوظة حتى الآن.';
    }
    final formatter = DateFormat('dd/MM/yyyy');
    final end = report.endExclusive?.subtract(const Duration(days: 1));
    if (end == null || _sameDay(report.start!, end)) {
      return formatter.format(report.start!);
    }
    return 'من ${formatter.format(report.start!)} إلى ${formatter.format(end)}';
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.changePercent,
    this.emphasis = false,
    this.negative = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final double? changePercent;
  final bool emphasis;
  final bool negative;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = emphasis
        ? scheme.onPrimaryContainer
        : negative
            ? scheme.error
            : scheme.onSurface;
    final change = changePercent;
    final positive = change != null && change >= 0;

    return Card(
      color: emphasis ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: foreground),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground),
              const Spacer(),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              if (change == null)
                Text(
                  'لا مقارنة متاحة',
                  style: TextStyle(
                    fontSize: 11,
                    color: emphasis
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                )
              else
                Row(
                  children: [
                    Icon(
                      positive ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 15,
                      color: emphasis
                          ? scheme.onPrimaryContainer
                          : positive
                              ? scheme.primary
                              : scheme.error,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        '${change.abs().toStringAsFixed(1)}٪ عن السابقة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: emphasis
                              ? scheme.onPrimaryContainer
                              : positive
                                  ? scheme.primary
                                  : scheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ReportBarChart extends StatelessWidget {
  const _ReportBarChart({required this.points, required this.money});

  final List<ReportPoint> points;
  final String Function(num value) money;

  @override
  Widget build(BuildContext context) {
    final maximum = points.fold<int>(1, (value, point) {
      return math.max(
        value,
        math.max(point.sales.abs(), point.profit.abs()),
      );
    });
    final itemWidth = points.length == 1 ? 180.0 : 58.0;
    final chartWidth = math.max(
      MediaQuery.sizeOf(context).width - 70,
      points.length * itemWidth,
    );
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Legend(color: scheme.primary, label: 'المبيعات'),
            const SizedBox(width: 16),
            _Legend(color: scheme.secondary, label: 'الربح'),
          ],
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: SizedBox(
            width: chartWidth,
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final point in points)
                  SizedBox(
                    width: itemWidth,
                    child: Tooltip(
                      message: '${point.label}\n'
                          'المبيعات: ${money(point.sales)}\n'
                          'الربح: ${money(point.profit)}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _Bar(
                                  value: point.sales,
                                  maximum: maximum,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 4),
                                _Bar(
                                  value: point.profit,
                                  maximum: maximum,
                                  color: point.profit < 0
                                      ? scheme.error
                                      : scheme.secondary,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            point.label,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.maximum,
    required this.color,
  });

  final int value;
  final int maximum;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = value.abs() / maximum;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: ratio),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, animatedRatio, child) => Container(
        width: 15,
        height: math.max(3, 142 * animatedRatio),
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(label),
      ],
    );
  }
}

class _RankingSection extends StatelessWidget {
  const _RankingSection({
    required this.title,
    required this.icon,
    required this.items,
    required this.money,
    required this.emptyText,
  });

  final String title;
  final IconData icon;
  final List<ReportRankingItem> items;
  final String Function(num value) money;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      icon: icon,
      child: items.isEmpty
          ? Text(emptyText)
          : Column(
              children: [
                for (var index = 0; index < items.length; index++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(
                      items[index].label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${items[index].transactionCount} عملية • '
                      'مبيعات ${money(items[index].sales)}',
                    ),
                    trailing: Text(
                      money(items[index].profit),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: items[index].profit < 0
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
