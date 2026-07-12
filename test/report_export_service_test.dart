import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/reports/data/report_export_service.dart';
import 'package:game_credit_profit_manager/shared/models/report.dart';

void main() {
  final report = ReportSummary(
    period: ReportPeriod.last7Days,
    generatedAt: DateTime(2026, 7, 12, 21, 30),
    start: DateTime(2026, 7, 6),
    endExclusive: DateTime(2026, 7, 13),
    current: const ReportTotals(
      sales: 3500,
      cost: 2400,
      profit: 1100,
      transactionCount: 5,
      customerCount: 3,
      requiredCredit: 2400,
      purchasedCredit: 2600,
    ),
    previous: null,
    points: const [
      ReportPoint(
        key: '2026-07-12',
        label: '12/7',
        sales: 3500,
        profit: 1100,
      ),
    ],
    topProducts: const [
      ReportRankingItem(
        label: 'منتج "مميز"',
        transactionCount: 3,
        sales: 2100,
        profit: 700,
      ),
    ],
    topCustomers: const [
      ReportRankingItem(
        label: 'محمد',
        transactionCount: 2,
        sales: 1400,
        profit: 400,
      ),
    ],
  );

  test('يبني CSV كاملًا مع حماية علامات الاقتباس', () {
    final csv = ReportExportService.buildCsv(report);

    expect(csv, contains('تقرير مدير رصيد الألعاب'));
    expect(csv, contains('المبيعات,3500'));
    expect(csv, contains('التكلفة,2400'));
    expect(csv, contains('الربح,1100'));
    expect(csv, contains('"منتج ""مميز"""'));
    expect(csv, contains('محمد'));
  });

  test('يحدد الامتداد ونوع MIME لكل صيغة', () {
    expect(ReportExportFormat.csv.extension, 'csv');
    expect(ReportExportFormat.csv.mimeType, 'text/csv');
    expect(ReportExportFormat.pdf.extension, 'pdf');
    expect(ReportExportFormat.pdf.mimeType, 'application/pdf');
    expect(ReportExportFormat.png.extension, 'png');
    expect(ReportExportFormat.png.mimeType, 'image/png');
  });
}
