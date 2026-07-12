import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:screenshot/screenshot.dart';

import '../../../core/utils/money_formatter.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/models/report.dart';

enum ReportExportFormat { csv, pdf, png }

extension ReportExportFormatX on ReportExportFormat {
  String get label => switch (this) {
        ReportExportFormat.csv => 'CSV',
        ReportExportFormat.pdf => 'PDF',
        ReportExportFormat.png => 'صورة PNG',
      };

  String get extension => switch (this) {
        ReportExportFormat.csv => 'csv',
        ReportExportFormat.pdf => 'pdf',
        ReportExportFormat.png => 'png',
      };

  String get mimeType => switch (this) {
        ReportExportFormat.csv => 'text/csv',
        ReportExportFormat.pdf => 'application/pdf',
        ReportExportFormat.png => 'image/png',
      };

  IconData get icon => switch (this) {
        ReportExportFormat.csv => Icons.table_chart_outlined,
        ReportExportFormat.pdf => Icons.picture_as_pdf_outlined,
        ReportExportFormat.png => Icons.image_outlined,
      };
}

class ReportExportResult {
  const ReportExportResult({
    required this.file,
    required this.format,
  });

  final File file;
  final ReportExportFormat format;

  String get fileName => file.uri.pathSegments.last;
}

class ReportExportService {
  ReportExportService({ScreenshotController? screenshotController})
      : _screenshotController = screenshotController ?? ScreenshotController();

  final ScreenshotController _screenshotController;

  Future<ReportExportResult> create({
    required ReportExportFormat format,
    required ReportSummary report,
    required AppSettings settings,
    BuildContext? context,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyy-MM-dd-HH-mm').format(DateTime.now());
    final fileName =
        'game-credit-report-${report.period.name}-$timestamp.${format.extension}';
    final file = File('${directory.path}/$fileName');

    switch (format) {
      case ReportExportFormat.csv:
        await file.writeAsString(
          '\uFEFF${buildCsv(report)}',
          flush: true,
        );
        break;
      case ReportExportFormat.png:
        if (context == null) {
          throw StateError('سياق الواجهة مطلوب لإنشاء صورة التقرير');
        }
        final bytes = await _captureReport(
          context: context,
          report: report,
          settings: settings,
        );
        await file.writeAsBytes(bytes, flush: true);
        break;
      case ReportExportFormat.pdf:
        if (context == null) {
          throw StateError('سياق الواجهة مطلوب لإنشاء PDF');
        }
        final imageBytes = await _captureReport(
          context: context,
          report: report,
          settings: settings,
        );
        final pdfBytes = await _buildPdf(imageBytes);
        await file.writeAsBytes(pdfBytes, flush: true);
        break;
    }

    return ReportExportResult(file: file, format: format);
  }

  static String buildCsv(ReportSummary report) {
    final buffer = StringBuffer()
      ..writeln('تقرير مدير رصيد الألعاب')
      ..writeln('الفترة,${_csv(report.period.label)}')
      ..writeln('تم الإنشاء,${report.generatedAt.toIso8601String()}')
      ..writeln()
      ..writeln('المؤشر,القيمة')
      ..writeln('المبيعات,${report.current.sales}')
      ..writeln('التكلفة,${report.current.cost}')
      ..writeln('الربح,${report.current.profit}')
      ..writeln('عدد العمليات,${report.current.transactionCount}')
      ..writeln('عدد العملاء,${report.current.customerCount}')
      ..writeln('متوسط العملية,${report.current.averageSale}')
      ..writeln('الرصيد المطلوب,${report.current.requiredCredit}')
      ..writeln('الرصيد المشتَرى,${report.current.purchasedCredit}')
      ..writeln()
      ..writeln('الاتجاه الزمني')
      ..writeln('الفترة,المبيعات,الربح');

    for (final point in report.points) {
      buffer.writeln(
        '${_csv(point.label)},${point.sales},${point.profit}',
      );
    }

    buffer
      ..writeln()
      ..writeln('أفضل المنتجات')
      ..writeln('المنتج,العمليات,المبيعات,الربح');
    for (final item in report.topProducts) {
      buffer.writeln(
        '${_csv(item.label)},${item.transactionCount},${item.sales},${item.profit}',
      );
    }

    buffer
      ..writeln()
      ..writeln('أفضل العملاء')
      ..writeln('العميل,العمليات,المبيعات,الربح');
    for (final item in report.topCustomers) {
      buffer.writeln(
        '${_csv(item.label)},${item.transactionCount},${item.sales},${item.profit}',
      );
    }

    return buffer.toString();
  }

  static String _csv(String value) => '"${value.replaceAll('"', '""')}"';

  Future<Uint8List> _captureReport({
    required BuildContext context,
    required ReportSummary report,
    required AppSettings settings,
  }) {
    final exportTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF21453B),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F1E7),
    );

    final widget = InheritedTheme.captureAll(
      context,
      MediaQuery(
        data: const MediaQueryData(
          size: Size(900, 1600),
          devicePixelRatio: 1,
          textScaler: TextScaler.noScaling,
        ),
        child: Theme(
          data: exportTheme,
          child: Material(
            color: const Color(0xFFF5F1E7),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: _ReportExportDocument(
                report: report,
                settings: settings,
              ),
            ),
          ),
        ),
      ),
    );

    return _screenshotController.captureFromLongWidget(
      widget,
      context: context,
      delay: const Duration(milliseconds: 100),
      constraints: const BoxConstraints(maxWidth: 900),
    );
  }

  Future<Uint8List> _buildPdf(Uint8List imageBytes) async {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final source = frame.image;
    final document = pw.Document(
      title: 'تقرير مدير رصيد الألعاب',
      author: 'مدير رصيد الألعاب',
    );

    const margin = 18.0;
    final usablePdfWidth = PdfPageFormat.a4.width - (margin * 2);
    final usablePdfHeight = PdfPageFormat.a4.height - (margin * 2);
    final sourceHeightPerPage = math.max(
      1,
      (source.width * usablePdfHeight / usablePdfWidth).floor(),
    );

    for (var offsetY = 0;
        offsetY < source.height;
        offsetY += sourceHeightPerPage) {
      final sliceHeight = math.min(
        sourceHeightPerPage,
        source.height - offsetY,
      );
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        source,
        ui.Rect.fromLTWH(
          0,
          offsetY.toDouble(),
          source.width.toDouble(),
          sliceHeight.toDouble(),
        ),
        ui.Rect.fromLTWH(
          0,
          0,
          source.width.toDouble(),
          sliceHeight.toDouble(),
        ),
        ui.Paint(),
      );
      final picture = recorder.endRecording();
      final pageImage = await picture.toImage(source.width, sliceHeight);
      final data = await pageImage.toByteData(format: ui.ImageByteFormat.png);
      pageImage.dispose();
      if (data == null) {
        source.dispose();
        codec.dispose();
        throw StateError('تعذر تقسيم صورة التقرير إلى صفحات PDF');
      }
      final bytes = data.buffer.asUint8List();
      final memoryImage = pw.MemoryImage(bytes);
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(margin),
          build: (_) => pw.Center(
            child: pw.Image(memoryImage, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    source.dispose();
    codec.dispose();
    return document.save();
  }
}

class _ReportExportDocument extends StatelessWidget {
  const _ReportExportDocument({
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
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 900,
      color: const Color(0xFFF5F1E7),
      padding: const EdgeInsets.all(34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF21453B),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تقرير مدير رصيد الألعاب',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${report.period.label} • ${_periodDescription(report)}',
                  style: const TextStyle(
                    color: Color(0xFFDCE7E1),
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'تم الإنشاء: ${DateFormat('dd/MM/yyyy • HH:mm').format(report.generatedAt)}',
                  style: const TextStyle(
                    color: Color(0xFFBFD0C7),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _ExportMetricCard(
                width: 408,
                label: 'المبيعات',
                value: money(report.current.sales),
                accent: scheme.primary,
              ),
              _ExportMetricCard(
                width: 408,
                label: 'الربح الصافي',
                value: money(report.current.profit),
                accent:
                    report.current.profit < 0 ? scheme.error : scheme.secondary,
              ),
              _ExportMetricCard(
                width: 408,
                label: 'التكلفة',
                value: money(report.current.cost),
                accent: scheme.tertiary,
              ),
              _ExportMetricCard(
                width: 408,
                label: 'عدد العمليات',
                value: '${report.current.transactionCount}',
                accent: scheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 22),
          _ExportSection(
            title: 'ملخص تشغيلي',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ExportCompactMetric(
                  label: 'العملاء',
                  value: '${report.current.customerCount}',
                ),
                _ExportCompactMetric(
                  label: 'متوسط العملية',
                  value: money(report.current.averageSale),
                ),
                _ExportCompactMetric(
                  label: 'متوسط الربح',
                  value: money(report.current.averageProfit),
                ),
                _ExportCompactMetric(
                  label: 'الرصيد المطلوب',
                  value: '${report.current.requiredCredit}',
                ),
                _ExportCompactMetric(
                  label: 'الرصيد المشتَرى',
                  value: '${report.current.purchasedCredit}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _ExportSection(
            title: 'اتجاه المبيعات والربح',
            child: report.points.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(child: Text('لا توجد بيانات كافية للرسم.')),
                  )
                : SizedBox(
                    height: 260,
                    child: CustomPaint(
                      painter: _ExportChartPainter(
                        points: report.points.length > 12
                            ? report.points.sublist(report.points.length - 12)
                            : report.points,
                        salesColor: scheme.primary,
                        profitColor: scheme.secondary,
                        lossColor: scheme.error,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 22),
          _ExportRankingSection(
            title: 'أفضل المنتجات',
            items: report.topProducts,
            money: money,
          ),
          const SizedBox(height: 22),
          _ExportRankingSection(
            title: 'أفضل العملاء',
            items: report.topCustomers,
            money: money,
          ),
          const SizedBox(height: 24),
          Text(
            'تقرير محلي تم إنشاؤه من بيانات التطبيق - لا يتضمن بيانات دخول أو معلومات سرية.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  static String _periodDescription(ReportSummary report) {
    if (report.start == null) return 'لا توجد عمليات محفوظة';
    final formatter = DateFormat('dd/MM/yyyy');
    final end = report.endExclusive?.subtract(const Duration(days: 1));
    if (end == null ||
        (report.start!.year == end.year &&
            report.start!.month == end.month &&
            report.start!.day == end.day)) {
      return formatter.format(report.start!);
    }
    return 'من ${formatter.format(report.start!)} إلى ${formatter.format(end)}';
  }
}

class _ExportMetricCard extends StatelessWidget {
  const _ExportMetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.accent,
  });

  final double width;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border(right: BorderSide(color: accent, width: 7)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportSection extends StatelessWidget {
  const _ExportSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _ExportCompactMetric extends StatelessWidget {
  const _ExportCompactMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ExportRankingSection extends StatelessWidget {
  const _ExportRankingSection({
    required this.title,
    required this.items,
    required this.money,
  });

  final String title;
  final List<ReportRankingItem> items;
  final String Function(num value) money;

  @override
  Widget build(BuildContext context) {
    return _ExportSection(
      title: title,
      child: items.isEmpty
          ? const Text('لا توجد بيانات ضمن هذه الفترة.')
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          child: Text('${index + 1}'),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 420,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                items[index].label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${items[index].transactionCount} عملية • مبيعات ${money(items[index].sales)}',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 210,
                          child: Text(
                            money(items[index].profit),
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: items[index].profit < 0
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index != items.length - 1) const Divider(height: 1),
                ],
              ],
            ),
    );
  }
}

class _ExportChartPainter extends CustomPainter {
  const _ExportChartPainter({
    required this.points,
    required this.salesColor,
    required this.profitColor,
    required this.lossColor,
  });

  final List<ReportPoint> points;
  final Color salesColor;
  final Color profitColor;
  final Color lossColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final maximum = points.fold<int>(1, (value, point) {
      return math.max(value, math.max(point.sales.abs(), point.profit.abs()));
    });
    const labelHeight = 34.0;
    final chartHeight = size.height - labelHeight;
    final slotWidth = size.width / points.length;
    final barWidth = math.min(18.0, slotWidth * 0.24);
    final textStyle = TextStyle(
      color: Colors.grey.shade700,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final centerX = slotWidth * index + slotWidth / 2;
      final salesHeight = chartHeight * (point.sales.abs() / maximum);
      final profitHeight = chartHeight * (point.profit.abs() / maximum);
      final salesRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - barWidth - 2,
          chartHeight - salesHeight,
          barWidth,
          math.max(3, salesHeight),
        ),
        const Radius.circular(6),
      );
      final profitRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX + 2,
          chartHeight - profitHeight,
          barWidth,
          math.max(3, profitHeight),
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(salesRect, Paint()..color = salesColor);
      canvas.drawRRect(
        profitRect,
        Paint()..color = point.profit < 0 ? lossColor : profitColor,
      );

      final painter = TextPainter(
        text: TextSpan(text: point.label, style: textStyle),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: slotWidth - 4);
      painter.paint(
        canvas,
        Offset(centerX - painter.width / 2, chartHeight + 10),
      );
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant _ExportChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.salesColor != salesColor ||
      oldDelegate.profitColor != profitColor ||
      oldDelegate.lossColor != lossColor;
}
