import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/common/platform_session_coordinator.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_models.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_failure.dart';

void main() {
  group('PlatformSessionCoordinator', () {
    test('authorized session executes one read without refresh', () async {
      final session = FakePlatformSessionAccess(
        state: const AdminAuthState.authorized(),
      );
      final scope = FakePlatformDataScopeSink();
      final coordinator = _coordinator(session: session, scope: scope);
      var readCalls = 0;

      final result = await coordinator.runRead(() async {
        readCalls += 1;
        return 'ok';
      });

      expect(result, 'ok');
      expect(readCalls, 1);
      expect(session.refreshCalls, 0);
      expect(scope.markAuthorizedCalls, 1);
      expect(scope.invalidations, isEmpty);
    });

    test('expired first read refreshes once and retries once', () async {
      final session = FakePlatformSessionAccess(
        state: const AdminAuthState.authorized(),
        stateAfterRefresh: const AdminAuthState.authorized(),
      );
      final scope = FakePlatformDataScopeSink();
      final coordinator = _coordinator(session: session, scope: scope);
      var readCalls = 0;

      final result = await coordinator.runRead(() async {
        readCalls += 1;
        if (readCalls == 1) {
          throw const PlatformFailure(PlatformFailureCode.sessionExpired);
        }
        return 42;
      });

      expect(result, 42);
      expect(readCalls, 2);
      expect(session.refreshCalls, 1);
      expect(scope.markAuthorizedCalls, 1);
      expect(scope.invalidations, <PlatformFailureCode>[
        PlatformFailureCode.sessionExpired,
      ]);
    });

    test('expired twice performs only two reads and one refresh', () async {
      final session = FakePlatformSessionAccess(
        state: const AdminAuthState.authorized(),
        stateAfterRefresh: const AdminAuthState.authorized(),
      );
      final scope = FakePlatformDataScopeSink();
      final coordinator = _coordinator(session: session, scope: scope);
      var readCalls = 0;

      await expectLater(
        coordinator.runRead<void>(() async {
          readCalls += 1;
          throw const PlatformFailure(PlatformFailureCode.sessionExpired);
        }),
        throwsA(_failureCode(PlatformFailureCode.sessionExpired)),
      );

      expect(readCalls, 2);
      expect(session.refreshCalls, 1);
      expect(scope.invalidations.length, 2);
    });

    test('refresh failure stops without an unbounded retry', () async {
      final session = FakePlatformSessionAccess(
        state: const AdminAuthState.authorized(),
        refreshFailure: const PlatformFailure(
          PlatformFailureCode.networkUnavailable,
        ),
      );
      final coordinator = _coordinator(
        session: session,
        scope: FakePlatformDataScopeSink(),
      );
      var readCalls = 0;

      await expectLater(
        coordinator.runRead<void>(() async {
          readCalls += 1;
          throw const PlatformFailure(PlatformFailureCode.sessionExpired);
        }),
        throwsA(_failureCode(PlatformFailureCode.networkUnavailable)),
      );

      expect(readCalls, 1);
      expect(session.refreshCalls, 1);
    });

    test('non-admin session does not execute a read', () async {
      final session = FakePlatformSessionAccess(
        state: const AdminAuthState.unauthorized(),
      );
      final coordinator = _coordinator(
        session: session,
        scope: FakePlatformDataScopeSink(),
      );
      var readCalls = 0;

      await expectLater(
        coordinator.runRead<void>(() async {
          readCalls += 1;
        }),
        throwsA(_failureCode(PlatformFailureCode.unauthorized)),
      );

      expect(readCalls, 0);
      expect(session.refreshCalls, 0);
    });

    test('lost admin claim after refresh prevents the retry', () async {
      final session = FakePlatformSessionAccess(
        state: const AdminAuthState.authorized(),
        stateAfterRefresh: const AdminAuthState.unauthorized(),
      );
      final scope = FakePlatformDataScopeSink();
      final coordinator = _coordinator(session: session, scope: scope);
      var readCalls = 0;

      await expectLater(
        coordinator.runRead<void>(() async {
          readCalls += 1;
          throw const PlatformFailure(PlatformFailureCode.sessionExpired);
        }),
        throwsA(_failureCode(PlatformFailureCode.unauthorized)),
      );

      expect(readCalls, 1);
      expect(session.refreshCalls, 1);
      expect(scope.invalidations.last, PlatformFailureCode.unauthorized);
    });

    test('network failure does not refresh the session', () async {
      final session = FakePlatformSessionAccess(
        state: const AdminAuthState.authorized(),
      );
      final coordinator = _coordinator(
        session: session,
        scope: FakePlatformDataScopeSink(),
      );
      var readCalls = 0;

      await expectLater(
        coordinator.runRead<void>(() async {
          readCalls += 1;
          throw const PlatformFailure(PlatformFailureCode.networkUnavailable);
        }),
        throwsA(_failureCode(PlatformFailureCode.networkUnavailable)),
      );

      expect(readCalls, 1);
      expect(session.refreshCalls, 0);
    });

    test('malformed response does not refresh the session', () async {
      final session = FakePlatformSessionAccess(
        state: const AdminAuthState.authorized(),
      );
      final coordinator = _coordinator(
        session: session,
        scope: FakePlatformDataScopeSink(),
      );
      var readCalls = 0;

      await expectLater(
        coordinator.runRead<void>(() async {
          readCalls += 1;
          throw const PlatformFailure(PlatformFailureCode.malformedResponse);
        }),
        throwsA(_failureCode(PlatformFailureCode.malformedResponse)),
      );

      expect(readCalls, 1);
      expect(session.refreshCalls, 0);
    });

    test(
      'successful retry returns the operation result exactly once',
      () async {
        final expectedResult = Object();
        final session = FakePlatformSessionAccess(
          state: const AdminAuthState.authorized(),
          stateAfterRefresh: const AdminAuthState.authorized(),
        );
        final coordinator = _coordinator(
          session: session,
          scope: FakePlatformDataScopeSink(),
        );
        var readCalls = 0;
        var resultCreations = 0;

        final result = await coordinator.runRead(() async {
          readCalls += 1;
          if (readCalls == 1) {
            throw const PlatformFailure(PlatformFailureCode.sessionExpired);
          }
          resultCreations += 1;
          return expectedResult;
        });

        expect(identical(result, expectedResult), isTrue);
        expect(readCalls, 2);
        expect(resultCreations, 1);
        expect(session.refreshCalls, 1);
      },
    );
  });
}

PlatformSessionCoordinator _coordinator({
  required FakePlatformSessionAccess session,
  required FakePlatformDataScopeSink scope,
}) {
  return PlatformSessionCoordinator(
    sessionAccess: session,
    mapError: (error) {
      if (error is PlatformFailure) {
        return error;
      }
      return const PlatformFailure(PlatformFailureCode.unknown);
    },
    dataScope: scope,
  );
}

Matcher _failureCode(PlatformFailureCode code) {
  return isA<PlatformFailure>().having((failure) => failure.code, 'code', code);
}

class FakePlatformSessionAccess implements PlatformSessionAccess {
  FakePlatformSessionAccess({
    required this.state,
    this.stateAfterRefresh,
    this.refreshFailure,
  });

  AdminAuthState state;
  final AdminAuthState? stateAfterRefresh;
  final Object? refreshFailure;
  int refreshCalls = 0;

  @override
  AdminAuthState get currentState => state;

  @override
  Future<void> refresh() async {
    refreshCalls += 1;
    final failure = refreshFailure;
    if (failure != null) {
      throw failure;
    }
    final nextState = stateAfterRefresh;
    if (nextState != null) {
      state = nextState;
    }
  }
}

class FakePlatformDataScopeSink implements PlatformDataScopeSink {
  int markAuthorizedCalls = 0;
  final List<PlatformFailureCode> invalidations = <PlatformFailureCode>[];

  @override
  void invalidate(PlatformFailureCode reason) {
    invalidations.add(reason);
  }

  @override
  void markAuthorized() {
    markAuthorizedCalls += 1;
  }
}
