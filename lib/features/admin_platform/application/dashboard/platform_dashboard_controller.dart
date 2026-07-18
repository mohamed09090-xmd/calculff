import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/common/platform_failure.dart';
import '../../domain/dashboard/platform_dashboard_repository.dart';
import '../../domain/dashboard/platform_dashboard_summary.dart';

enum PlatformDashboardStatus { loading, data, offline, error }

class PlatformDashboardState {
  const PlatformDashboardState({
    required this.status,
    this.summary,
    this.isRefreshing = false,
    this.isStale = false,
    this.failureCode,
  });

  const PlatformDashboardState.loading()
    : status = PlatformDashboardStatus.loading,
      summary = null,
      isRefreshing = false,
      isStale = false,
      failureCode = null;

  final PlatformDashboardStatus status;
  final PlatformDashboardSummary? summary;
  final bool isRefreshing;
  final bool isStale;
  final PlatformFailureCode? failureCode;
}

class PlatformDashboardController
    extends StateNotifier<PlatformDashboardState> {
  PlatformDashboardController({
    required PlatformDashboardRepository? repository,
  }) : _repository = repository,
       super(const PlatformDashboardState.loading());

  final PlatformDashboardRepository? _repository;
  int _generation = 0;
  bool _requestInFlight = false;

  Future<void> load() => _load(preserveExisting: false);

  Future<void> refresh() => _load(preserveExisting: true);

  void invalidate() {
    _generation += 1;
    _requestInFlight = false;
    state = const PlatformDashboardState.loading();
  }

  Future<void> _load({required bool preserveExisting}) async {
    if (_requestInFlight) {
      return;
    }
    final repository = _repository;
    final existing = preserveExisting ? state.summary : null;
    final requestGeneration = ++_generation;
    _requestInFlight = true;
    state = existing == null
        ? const PlatformDashboardState.loading()
        : PlatformDashboardState(
            status: PlatformDashboardStatus.data,
            summary: existing,
            isRefreshing: true,
            isStale: state.isStale,
          );
    try {
      if (repository == null) {
        throw const PlatformFailure(
          PlatformFailureCode.temporarilyUnavailable,
        );
      }
      final summary = await repository.loadDashboardSummary();
      if (requestGeneration != _generation) {
        return;
      }
      state = PlatformDashboardState(
        status: PlatformDashboardStatus.data,
        summary: summary,
      );
    } catch (error) {
      if (requestGeneration != _generation) {
        return;
      }
      final failure = error is PlatformFailure
          ? error
          : const PlatformFailure(PlatformFailureCode.unknown);
      if (existing != null) {
        state = PlatformDashboardState(
          status: PlatformDashboardStatus.data,
          summary: existing,
          isStale: true,
          failureCode: failure.code,
        );
      } else {
        state = PlatformDashboardState(
          status: failure.code == PlatformFailureCode.networkUnavailable
              ? PlatformDashboardStatus.offline
              : PlatformDashboardStatus.error,
          failureCode: failure.code,
        );
      }
    } finally {
      if (requestGeneration == _generation) {
        _requestInFlight = false;
      }
    }
  }
}
