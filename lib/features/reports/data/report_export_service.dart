import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text;

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:screenshot/screenshot.dart';

import '../../../core/localization/localized_text.dart';

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
    String? textContent;
    Uint8List? binaryContent;

    switch (format) {
      case ReportExportFormat.csv:
        textContent = '\uFEFF${buildCsv(report)}';
        break;
      case ReportExportFormat.png:
        if (context == null) {
          throw StateError('سياق الواجهة مطلوب لإنشاء صورة التقرير');
        }
        binaryContent = await _captureReport(
          context: context,
          report: report,
          settings: settings,
        );
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
        binaryContent = await _buildPdf(imageBytes);
        break;
    }

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyy-MM-dd-HH-mm').format(DateTime.now());
    final fileName =
        'game-credit-report-${report.period.name}-$timestamp.${format.extension}';
    final file = File('${directory.path}/$fileName');

    if (textContent != null) {
      await file.writeAsString(textContent, flush: true);
    } else {
      await file.writeAsBytes(binaryContent!, flush: true);
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
              textDirection: ui.TextDirection.rtl,
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
      final memoryImage = pw.MemoryImage(data.buffer.asUint8List());
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
          _ExportHeader(report: report),
          const SizedBox(height: 22),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _Metric(
                label: 'المبيعات',
                value: money(report.current.sales),
                accent: scheme.primary,
              ),
              _Metric(
                label: 'الربح الصافي',
                value: money(report.current.profit),
                accent:
                    report.current.profit < 0 ? scheme.error : scheme.secondary,
              ),
              _Metric(
                label: 'التكلفة',
                value: money(report.current.cost),
                accent: scheme.tertiary,
              ),
              _Metric(
                label: 'عدد العمليات',
                value: '${report.current.transactionCount}',
                accent: scheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 22),
          _Section(
            title: 'ملخص تشغيلي',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _CompactMetric(
                  label: 'العملاء',
                  value: '${report.current.customerCount}',
                ),
                _CompactMetric(
                  label: 'متوسط العملية',
                  value: money(report.current.averageSale),
                ),
                _CompactMetric(
                  label: 'متوسط الربح',
                  value: money(report.current.averageProfit),
                ),
                _CompactMetric(
                  label: 'الرصيد المطلوب',
                  value: '${report.current.requiredCredit}',
                ),
                _CompactMetric(
                  label: 'الرصيد المشتَرى',
                  value: '${report.current.purchasedCredit}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _TrendSection(points: report.points, money: money),
          const SizedBox(height: 22),
          _RankingSection(
            title: 'أفضل المنتجات',
            items: report.topProducts,
            money: money,
          ),
          const SizedBox(height: 22),
          _RankingSection(
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
}

class _ExportHeader extends StatelessWidget {
  const _ExportHeader({required this.report});

  final ReportSummary report;

  @override
  Widget build(BuildContext context) {
    return Container(
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

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 408,
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

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

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({required this.label, required this.value});

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

class _TrendSection extends StatelessWidget {
  const _TrendSection({required this.points, required this.money});

  final List<ReportPoint> points;
  final String Function(num value) money;

  @override
  Widget build(BuildContext context) {
    final visiblePoints = points.length > 30
        ? points.sublist(points.length - 30)
        : points;
    return _Section(
      title: 'اتجاه المبيعات والربح',
      child: visiblePoints.isEmpty
          ? const Text('لا توجد بيانات كافية ضمن هذه الفترة.')
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _TableHeader(
                  first: 'الفترة',
                  second: 'المبيعات',
                  third: 'الربح',
                ),
                for (final point in visiblePoints)
                  _TableRow(
                    first: point.label,
                    second: money(point.sales),
                    third: money(point.profit),
                    negative: point.profit < 0,
                  ),
              ],
            ),
    );
  }
}

class _RankingSection extends StatelessWidget {
  const _RankingSection({
    required this.title,
    required this.items,
    required this.money,
  });

  final String title;
  final List<ReportRankingItem> items;
  final String Function(num value) money;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: title,
      child: items.isEmpty
          ? const Text('لا توجد بيانات ضمن هذه الفترة.')
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _TableHeader(
                  first: 'الاسم',
                  second: 'المبيعات',
                  third: 'الربح',
                ),
                for (final item in items)
                  _TableRow(
                    first: '${item.label} (${item.transactionCount})',
                    second: money(item.sales),
                    third: money(item.profit),
                    negative: item.profit < 0,
                  ),
              ],
            ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.first,
    required this.second,
    required this.third,
  });

  final String first;
  final String second;
  final String third;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(first)),
          Expanded(flex: 3, child: Text(second)),
          Expanded(flex: 3, child: Text(third)),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.first,
    required this.second,
    required this.third,
    this.negative = false,
  });

  final String first;
  final String second;
  final String third;
  final bool negative;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE1E3E1))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              first,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(flex: 3, child: Text(second)),
          Expanded(
            flex: 3,
            child: Text(
              third,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: negative
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
