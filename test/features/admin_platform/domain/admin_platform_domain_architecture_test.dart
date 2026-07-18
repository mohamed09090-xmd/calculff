import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Admin platform domain architecture', () {
    test('domain files remain independent from infrastructure and Flutter', () {
      final files = Directory('lib/features/admin_platform/domain')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      const forbiddenReferences = <String>[
        'package:supabase_flutter',
        'package:postgrest',
        'package:sqflite',
        'package:flutter/',
        'apprepository',
        'databasehelper',
        'features/admin_platform/infrastructure',
        '../infrastructure',
        '/infrastructure/',
      ];

      for (final file in files) {
        final content = file.readAsStringSync().toLowerCase();
        for (final reference in forbiddenReferences) {
          expect(
            content,
            isNot(contains(reference)),
            reason: '${file.path} must not reference $reference',
          );
        }
      }
    });

    test('catalog repositories expose no destructive or order mutations', () {
      final repositoryFiles = <File>[
        File('lib/features/admin_platform/domain/games/games_repository.dart'),
        File(
          'lib/features/admin_platform/domain/offers/'
          'public_offers_repository.dart',
        ),
      ];
      const forbiddenOperations = <String>[
        'deletegame',
        'deleteoffer',
        'harddelete',
        'updateorder',
        'createorder',
        'setorder',
        'payment',
      ];

      for (final file in repositoryFiles) {
        final content = file.readAsStringSync().toLowerCase();
        for (final operation in forbiddenOperations) {
          expect(
            content,
            isNot(contains(operation)),
            reason: '${file.path} must not expose $operation',
          );
        }
      }
    });

    test('customer orders repository remains read-only', () {
      final file = File(
        'lib/features/admin_platform/domain/orders/'
        'customer_orders_repository.dart',
      );
      final content = file.readAsStringSync().toLowerCase();
      const forbiddenOperations = <String>[
        'updateorder',
        'createorder',
        'deleteorder',
        'setorderstatus',
        'setpaymentstatus',
        'markrefunded',
        'addinternalnote',
        'downloadproof',
      ];

      for (final operation in forbiddenOperations) {
        expect(
          content,
          isNot(contains(operation)),
          reason: '${file.path} must not expose $operation',
        );
      }
    });

    test('order domain omits private persistence identifiers and paths', () {
      final files = Directory('lib/features/admin_platform/domain/orders')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      const forbiddenFields = <String>[
        'paymentproofpath',
        'changedby',
        'userid',
        'clientrequestid',
        'internalnote',
      ];

      for (final file in files) {
        final content = file.readAsStringSync().toLowerCase();
        for (final field in forbiddenFields) {
          expect(
            content,
            isNot(contains(field)),
            reason: '${file.path} must not contain $field',
          );
        }
      }
    });

    test('order filters contain no PostgREST query syntax', () {
      final file = File(
        'lib/features/admin_platform/domain/orders/order_filters.dart',
      );
      final content = file.readAsStringSync().toLowerCase();

      expect(content, isNot(contains('postgrest')));
      expect(content, isNot(contains('.or(')));
      expect(content, isNot(contains('select(')));
    });

    test('domain tests do not connect to hosted Supabase', () {
      final files = Directory('test/features/admin_platform/domain')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where(
            (file) => !file.path.endsWith(
              'admin_platform_domain_architecture_test.dart',
            ),
          );

      for (final file in files) {
        final content = file.readAsStringSync().toLowerCase();
        expect(content, isNot(contains('supabase.co')));
        expect(content, isNot(contains('http://')));
        expect(content, isNot(contains('https://')));
      }
    });

    test('dashboard summary does not merge accepted into processing', () {
      final file = File(
        'lib/features/admin_platform/domain/dashboard/'
        'platform_dashboard_summary.dart',
      );
      final content = file.readAsStringSync().toLowerCase();

      expect(content, isNot(contains('accepted')));
    });
  });
}
