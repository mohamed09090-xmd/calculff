import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Orders list architecture', () {
    test('production code is read-only and uses only the approved RPC', () {
      const forbidden = <String>[
        'package:sqflite',
        'databasehelper',
        'apprepository',
        'supabase.co',
        "select('*')",
        'select("*")',
        ".from('orders')",
        '.from("orders")',
        '.or(',
        '.insert(',
        '.update(',
        '.delete(',
        '.upsert(',
        '.stream(',
        'realtime',
        'admin_update_',
        'admin_accept_',
        'admin_reject_',
        'refund_order',
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

      final dataSource = File(
        'lib/features/admin_platform/infrastructure/orders/'
        'supabase_orders_data_source.dart',
      ).readAsStringSync();
      expect(dataSource, contains("'admin_list_orders'"));
      expect(RegExp(r'\.rpc\(').allMatches(dataSource), hasLength(1));
    });

    test('repository sends the complete typed parameter contract', () {
      final content = File(
        'lib/features/admin_platform/infrastructure/orders/'
        'supabase_customer_orders_repository.dart',
      ).readAsStringSync();

      for (final parameter in <String>[
        'p_order_status',
        'p_payment_status',
        'p_payment_method',
        'p_game_id',
        'p_date_from',
        'p_date_to_exclusive',
        'p_search_text',
        'p_cursor_created_at',
        'p_cursor_id',
        'p_limit',
      ]) {
        expect(content, contains("'$parameter'"));
      }
      expect(content, contains('.wireValue'));
      expect(content, contains('.toIso8601String()'));
      expect(content, contains('cursor?.id'));
      expect(content, isNot(contains('displayId')));
      expect(content, isNot(contains('shortId')));
    });

    test('list fixtures and domain do not depend on proof paths or PII', () {
      final files = <File>[
        File(
          'lib/features/admin_platform/domain/orders/'
          'customer_order_summary.dart',
        ),
        File(
          'lib/features/admin_platform/domain/orders/'
          'order_page.dart',
        ),
        File(
          'test/features/admin_platform/orders/'
          'supabase_customer_orders_repository_test.dart',
        ),
      ];
      for (final file in files) {
        final content = file.readAsStringSync().toLowerCase();
        expect(content, isNot(contains('payment_proof_path')));
        expect(content, isNot(contains('customer_email')));
        expect(content, isNot(contains('customer_phone')));
        expect(content, isNot(contains('client_request_id')));
        expect(content, isNot(contains('changed_by')));
      }
    });

    test(
      'orders are connected once while other destinations remain intact',
      () {
        final content = File(
          'lib/features/admin_platform/presentation/'
          'customer_platform_shell.dart',
        ).readAsStringSync();

        expect(
          RegExp(
            r'builder:\s*\(_\)\s*=>\s*const CustomerOrdersScreen\(\)',
          ).allMatches(content),
          hasLength(1),
        );
        expect(
          RegExp(
            r'builder:\s*\(_\)\s*=>\s*const OffersScreen\(\)',
          ).allMatches(content),
          hasLength(1),
        );
        expect(
          RegExp(
            r'builder:\s*\(_\)\s*=>\s*const GamesScreen\(\)',
          ).allMatches(content),
          hasLength(1),
        );
      },
    );

    test('implementation tests contain no hosted credentials', () {
      const forbidden = <String>[
        'supabase.co',
        'service_role',
        'sb_secret_',
        'github_pat_',
        '-----begin private key-----',
      ];
      for (final file in _testFiles()) {
        final content = file.readAsStringSync().toLowerCase();
        for (final value in forbidden) {
          expect(content, isNot(contains(value)));
        }
      }
    });
  });
}

List<File> _productionFiles() {
  return <File>[
    File(
      'lib/features/admin_platform/infrastructure/orders/'
      'supabase_orders_data_source.dart',
    ),
    File(
      'lib/features/admin_platform/infrastructure/orders/'
      'supabase_customer_orders_repository.dart',
    ),
    File(
      'lib/features/admin_platform/application/orders/orders_controller.dart',
    ),
    File(
      'lib/features/admin_platform/application/orders/orders_providers.dart',
    ),
    File(
      'lib/features/admin_platform/presentation/orders/'
      'customer_orders_screen.dart',
    ),
    File(
      'lib/features/admin_platform/presentation/orders/'
      'order_filters_sheet.dart',
    ),
    File('lib/features/admin_platform/presentation/orders/order_widgets.dart'),
  ];
}

List<File> _testFiles() {
  return <File>[
    File(
      'test/features/admin_platform/orders/'
      'supabase_customer_orders_repository_test.dart',
    ),
    File('test/features/admin_platform/orders/orders_controller_test.dart'),
  ];
}
