import 'platform_dashboard_summary.dart';

abstract interface class PlatformDashboardRepository {
  Future<PlatformDashboardSummary> loadDashboardSummary();
}
