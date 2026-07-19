import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Order details architecture', () {
    test(
      'production implementation is read-only and contains no private fields',
      () {
        const forbidden = <String>[
          'package:sqflite',
          'databasehelper',
          'flutter_secure_storage',
          'payment_proof_path',
          'changed_by',
          'internal_note',
          'internal notes',
          'client_request_id',
          'service_role',
          'sb_secret_',
          'txxokpovdbvsvnkpbrrp',
          'zegjqwsvsaprnguvxuwk',
          'supabase.co',
          "select('*')",
          'select("*")',
          ".from('orders')",
          '.from("orders")',
          ".from('order_status_history')",
          '.from("order_status_history")',
          '.insert(',
          '.update(',
          '.delete(',
          '.upsert(',
          '.stream(',
          'realtime',
          'timer.periodic',
          'admin_update_',
          'admin_accept_',
          'admin_reject_',
          'refund_order',
          'signedurl',
        ];

        for (final file in _productionFiles()) {
          final content = file.readAsStringSync().toLowerCase();
          for (final value in forbidden) {
            expect(
              content,
              isNot(contains(value)),
              reason: '${file.path} must not contain $value',
            );
          }
        }
      },
    );

    test('widgets do not import Supabase or local persistence', () {
      for (final file in _presentationFiles()) {
        final content = file.readAsStringSync().toLowerCase();
        expect(content, isNot(contains('supabase')));
        expect(content, isNot(contains('sqflite')));
        expect(content, isNot(contains('sqlite')));
      }
    });

    test('data source uses only the approved read RPC contracts', () {
      final content = File(
        'lib/features/admin_platform/infrastructure/orders/'
        'supabase_orders_data_source.dart',
      ).readAsStringSync();

      expect(content, contains("'admin_get_order_details'"));
      expect(content, contains("'admin_get_order_timeline'"));
      expect(content, contains("'p_order_id': orderId"));
      expect(content, isNot(contains("select('*')")));
      expect(content, isNot(contains('.from(')));
      expect(RegExp(r'\.rpc\(').allMatches(content), hasLength(1));
    });

    test('details provider is family scoped and auto disposed', () {
      final content = File(
        'lib/features/admin_platform/application/orders/'
        'order_details_providers.dart',
      ).readAsStringSync();

      expect(content, contains('StateNotifierProvider.autoDispose.family'));
      expect(content, contains('platformDataScopeProvider.select'));
      expect(content, contains('value.generation'));
      expect(content, isNot(contains('keepAlive')));
    });

    test(
      'detail fixtures contain no hosted configuration or real credentials',
      () {
        const forbidden = <String>[
          'supabase.co',
          'service_role',
          'sb_secret_',
          'github_pat_',
          'txxokpovdbvsvnkpbrrp',
          'zegjqwsvsaprnguvxuwk',
          '-----begin private key-----',
        ];
        for (final file in _testFiles()) {
          final content = file.readAsStringSync().toLowerCase();
          for (final value in forbidden) {
            expect(content, isNot(contains(value)), reason: file.path);
          }
        }
      },
    );
  });
}

List<File> _productionFiles() {
  return <File>[
    File(
      'lib/features/admin_platform/domain/orders/customer_order_details.dart',
    ),
    File('lib/features/admin_platform/domain/orders/order_timeline_event.dart'),
    File(
      'lib/features/admin_platform/infrastructure/orders/'
      'customer_order_details_dto.dart',
    ),
    File(
      'lib/features/admin_platform/infrastructure/orders/'
      'order_timeline_event_dto.dart',
    ),
    File(
      'lib/features/admin_platform/infrastructure/orders/'
      'supabase_orders_data_source.dart',
    ),
    File(
      'lib/features/admin_platform/infrastructure/orders/'
      'supabase_customer_orders_repository.dart',
    ),
    File(
      'lib/features/admin_platform/application/orders/'
      'order_details_controller.dart',
    ),
    File(
      'lib/features/admin_platform/application/orders/'
      'order_details_providers.dart',
    ),
    ..._presentationFiles(),
  ];
}

List<File> _presentationFiles() {
  return <File>[
    File(
      'lib/features/admin_platform/presentation/orders/'
      'customer_orders_screen.dart',
    ),
    File(
      'lib/features/admin_platform/presentation/orders/'
      'order_details_screen.dart',
    ),
    File('lib/features/admin_platform/presentation/orders/order_widgets.dart'),
  ];
}

List<File> _testFiles() {
  return <File>[
    File(
      'test/features/admin_platform/infrastructure/'
      'customer_order_dto_test.dart',
    ),
    File(
      'test/features/admin_platform/infrastructure/'
      'order_timeline_event_dto_test.dart',
    ),
    File(
      'test/features/admin_platform/orders/'
      'supabase_orders_data_source_test.dart',
    ),
    File(
      'test/features/admin_platform/orders/'
      'supabase_customer_orders_repository_test.dart',
    ),
    File(
      'test/features/admin_platform/orders/'
      'orders_session_retry_test.dart',
    ),
    File(
      'test/features/admin_platform/orders/'
      'order_details_controller_test.dart',
    ),
    File(
      'test/features/admin_platform/orders/'
      'order_details_screen_widget_test.dart',
    ),
  ];
}
