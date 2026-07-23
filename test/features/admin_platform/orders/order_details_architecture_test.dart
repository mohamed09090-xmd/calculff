import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Order details architecture', () {
    test(
      'details state and presentation contain no raw backend private fields',
      () {
        const forbidden = <String>[
          'package:sqflite',
          'databasehelper',
          'flutter_secure_storage',
          'shared_preferences',
          'package:hive',
          'payment_proof_path',
          'signed_url',
          'changed_by',
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
          'admin_add_order_internal_note',
          'admin_set_order_status',
          'admin_set_payment_status',
          'admin_mark_refunded',
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

    test('raw proof path is confined to the Supabase data source', () {
      final files = <File>[
        File(
          'lib/features/admin_platform/domain/orders/'
          'order_payment_proof.dart',
        ),
        File(
          'lib/features/admin_platform/domain/orders/'
          'order_payment_proof_repository.dart',
        ),
        File(
          'lib/features/admin_platform/application/orders/'
          'order_payment_proof_provider.dart',
        ),
        File(
          'lib/features/admin_platform/infrastructure/orders/'
          'supabase_order_payment_proof_repository.dart',
        ),
        File(
          'lib/features/admin_platform/presentation/orders/'
          'order_details_screen.dart',
        ),
      ];
      for (final file in files) {
        final content = file.readAsStringSync().toLowerCase();
        expect(content, isNot(contains('payment_proof_path')));
        expect(content, isNot(contains('print(')));
        expect(content, isNot(contains('debugprint(')));
      }
    });

    test(
      'data source uses only the approved order RPC and proof contracts',
      () {
        final content = File(
          'lib/features/admin_platform/infrastructure/orders/'
          'supabase_orders_data_source.dart',
        ).readAsStringSync();

        expect(content, contains("'admin_get_order_details'"));
        expect(content, contains("'admin_get_order_timeline'"));
        expect(content, contains("'admin_list_order_internal_notes'"));
        expect(content, contains("'admin_get_order_payment_proof_path'"));
        expect(content, contains("'admin_accept_order'"));
        expect(content, contains("'admin_reject_order'"));
        expect(content, contains('paymentProofSignedUrlLifetimeSeconds = 60'));
        expect(content, contains("'p_order_id': orderId"));
        expect(content, isNot(contains("select('*')")));
        expect(content, isNot(contains('_client.from(')));
        expect(content, contains('_client.storage.from(bucket)'));
        expect(RegExp(r'\.rpc\(').allMatches(content), hasLength(1));
        expect(
          RegExp(r'\.createSignedUrl\(').allMatches(content),
          hasLength(1),
        );
      },
    );

    test('list and public timeline models remain free of internal notes', () {
      final files = <File>[
        File(
          'lib/features/admin_platform/domain/orders/'
          'customer_order_summary.dart',
        ),
        File(
          'lib/features/admin_platform/domain/orders/'
          'customer_order_details.dart',
        ),
        File(
          'lib/features/admin_platform/domain/orders/'
          'order_timeline_event.dart',
        ),
        File(
          'lib/features/admin_platform/infrastructure/orders/'
          'customer_order_summary_dto.dart',
        ),
        File(
          'lib/features/admin_platform/infrastructure/orders/'
          'customer_order_details_dto.dart',
        ),
        File(
          'lib/features/admin_platform/infrastructure/orders/'
          'order_timeline_event_dto.dart',
        ),
        File(
          'lib/features/admin_platform/presentation/orders/'
          'customer_orders_screen.dart',
        ),
        File(
          'lib/features/admin_platform/presentation/orders/order_widgets.dart',
        ),
      ];

      for (final file in files) {
        final content = file.readAsStringSync().toLowerCase();
        expect(content, isNot(contains('internal_note')), reason: file.path);
        expect(content, isNot(contains('internal note')), reason: file.path);
        expect(content, isNot(contains('internalnote')), reason: file.path);
      }
    });

    test('application state imports no data client or local persistence', () {
      for (final path in <String>[
        'order_details_controller.dart',
        'order_details_providers.dart',
      ]) {
        final content = File(
          'lib/features/admin_platform/application/orders/$path',
        ).readAsStringSync().toLowerCase();
        for (final forbidden in <String>[
          'package:supabase_flutter',
          'package:sqflite',
          'shared_preferences',
          'package:hive',
          'flutter_secure_storage',
        ]) {
          expect(content, isNot(contains(forbidden)), reason: path);
        }
      }
    });

    test('details provider is family scoped and auto disposed', () {
      final content = File(
        'lib/features/admin_platform/application/orders/'
        'order_details_providers.dart',
      ).readAsStringSync();

      expect(
        content,
        matches(
          RegExp(
            r'StateNotifierProvider\.autoDispose\s*\.family',
            multiLine: true,
          ),
        ),
      );
      expect(content, contains('platformDataScopeProvider.select'));
      expect(content, contains('value.generation'));
      expect(content, contains('orderInternalNotesProvider'));
      expect(
        RegExp(
          r'FutureProvider\.autoDispose\s*\.family',
          multiLine: true,
        ).hasMatch(content),
        isTrue,
      );
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
    File('lib/features/admin_platform/domain/orders/order_internal_note.dart'),
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
      'order_internal_note_dto.dart',
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
      'test/features/admin_platform/infrastructure/'
      'order_internal_note_dto_test.dart',
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
      'order_internal_notes_provider_test.dart',
    ),
    File(
      'test/features/admin_platform/orders/'
      'order_details_screen_widget_test.dart',
    ),
  ];
}
