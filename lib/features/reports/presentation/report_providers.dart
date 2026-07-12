import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/report.dart';
import '../data/report_repository.dart';

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(),
);

final reportProvider = FutureProvider.family<ReportSummary, ReportPeriod>(
  (ref, period) => ref.read(reportRepositoryProvider).getReport(period),
);
