import '../../application/common/platform_session_coordinator.dart';
import '../../domain/dashboard/platform_dashboard_repository.dart';
import '../../domain/dashboard/platform_dashboard_summary.dart';
import '../common/supabase_platform_error_mapper.dart';
import 'supabase_platform_dashboard_data_source.dart';

class SupabasePlatformDashboardRepository
    implements PlatformDashboardRepository {
  const SupabasePlatformDashboardRepository({
    required PlatformDashboardDataSource dataSource,
    required PlatformReadCoordinator readCoordinator,
    required SupabasePlatformErrorMapper errorMapper,
    DateTime Function()? now,
  }) : _dataSource = dataSource,
       _readCoordinator = readCoordinator,
       _errorMapper = errorMapper,
       _now = now ?? DateTime.now;

  final PlatformDashboardDataSource _dataSource;
  final PlatformReadCoordinator _readCoordinator;
  final SupabasePlatformErrorMapper _errorMapper;
  final DateTime Function() _now;

  @override
  Future<PlatformDashboardSummary> loadDashboardSummary() {
    return _readCoordinator.runRead(() async {
      try {
        final counts = await Future.wait<int>([
          _dataSource.countNewOrders(),
          _dataSource.countProcessingOrders(),
          _dataSource.countPaymentsUnderReview(),
          _dataSource.countCompletedOrders(),
          _dataSource.countPublishedOffers(),
          _dataSource.countActiveGames(),
        ]);
        return PlatformDashboardSummary(
          newOrdersCount: counts[0],
          processingOrdersCount: counts[1],
          paymentsUnderReviewCount: counts[2],
          completedOrdersCount: counts[3],
          publishedOffersCount: counts[4],
          activeGamesCount: counts[5],
          refreshedAt: _now(),
        );
      } catch (error) {
        throw _errorMapper.map(error);
      }
    });
  }
}
