import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Platform session architecture', () {
    test('new production files avoid SQLite and legacy repositories', () {
      const forbiddenReferences = <String>[
        'package:sqflite',
        'apprepository',
        'databasehelper',
        'customer_platform_shell.dart',
        '/presentation/',
      ];

      for (final file in _newProductionFiles()) {
        final content = file.readAsStringSync().toLowerCase();
        for (final reference in forbiddenReferences) {
          expect(
            content,
            isNot(contains(reference)),
            reason: '${file.path} must not contain $reference',
          );
        }
      }
    });

    test('Domain contains no Supabase or PostgREST types', () {
      const forbiddenReferences = <String>[
        'package:supabase_flutter',
        'package:postgrest',
        'supabaseclient',
        'postgrestexception',
        'authexception',
      ];
      final files = Directory('lib/features/admin_platform/domain')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in files) {
        final content = file.readAsStringSync().toLowerCase();
        for (final reference in forbiddenReferences) {
          expect(
            content,
            isNot(contains(reference)),
            reason: '${file.path} must not contain $reference',
          );
        }
      }
    });

    test('Presentation contains no PostgREST errors', () {
      final files = Directory('lib/features/admin_platform/presentation')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in files) {
        final content = file.readAsStringSync().toLowerCase();
        expect(
          content,
          isNot(contains('postgrestexception')),
          reason: '${file.path} must not depend on PostgREST errors',
        );
      }
    });

    test('PlatformFailure stores no raw exception or response', () {
      final content = File(
        'lib/features/admin_platform/domain/common/platform_failure.dart',
      ).readAsStringSync().toLowerCase();
      const forbiddenFields = <String>[
        'rawexception',
        'originalerror',
        'stacktrace',
        'httpbody',
        'sqlstate',
        'object error',
      ];

      for (final field in forbiddenFields) {
        expect(content, isNot(contains(field)));
      }
    });

    test('new production files contain no queries or mutations', () {
      const forbiddenOperations = <String>[
        '.select(',
        '.insert(',
        '.update(',
        '.delete(',
        '.rpc(',
        ".from('games'",
        '.from("games"',
        ".from('public_offers'",
        '.from("public_offers"',
        ".from('orders'",
        '.from("orders"',
        'supabase.instance.client',
      ];

      for (final file in _newProductionFiles()) {
        final content = file.readAsStringSync().toLowerCase();
        for (final operation in forbiddenOperations) {
          expect(
            content,
            isNot(contains(operation)),
            reason: '${file.path} must not contain $operation',
          );
        }
      }
    });

    test('new production code uses no user metadata authorization', () {
      for (final file in _newProductionFiles()) {
        final content = file.readAsStringSync().toLowerCase();
        expect(content, isNot(contains('usermetadata')));
        expect(content, isNot(contains('user_metadata')));
      }
    });

    test('new tests contain no hosted project URL or secret material', () {
      const forbiddenReferences = <String>[
        'supabase.co',
        'zegjqwsvsaprnguvxuwk',
        'txxokpovdbvsvnkpbrrp',
        'service_role',
        'sb_secret_',
        'github_pat_',
        '-----begin private key-----',
      ];

      for (final file in _newTestFiles()) {
        final content = file.readAsStringSync().toLowerCase();
        for (final reference in forbiddenReferences) {
          expect(
            content,
            isNot(contains(reference)),
            reason: '${file.path} must not contain $reference',
          );
        }
      }
    });

    test('admin platform owns only one Supabase auth listener', () {
      final files = Directory('lib/features/admin_platform')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      var listenerCount = 0;

      for (final file in files) {
        final content = file.readAsStringSync();
        listenerCount += RegExp(
          r'\.auth\.onAuthStateChange',
        ).allMatches(content).length;
      }

      expect(listenerCount, 1);
    });
  });
}

List<File> _newProductionFiles() {
  return <File>[
    File(
      'lib/features/admin_platform/infrastructure/common/'
      'supabase_platform_error_mapper.dart',
    ),
    File(
      'lib/features/admin_platform/application/common/'
      'platform_session_coordinator.dart',
    ),
    File(
      'lib/features/admin_platform/application/common/'
      'platform_data_scope.dart',
    ),
    File(
      'lib/features/admin_platform/application/common/'
      'platform_common_providers.dart',
    ),
  ];
}

List<File> _newTestFiles() {
  return <File>[
    File(
      'test/features/admin_platform/infrastructure/'
      'supabase_platform_error_mapper_test.dart',
    ),
    File(
      'test/features/admin_platform/application/'
      'platform_session_coordinator_test.dart',
    ),
    File(
      'test/features/admin_platform/application/'
      'platform_common_providers_test.dart',
    ),
  ];
}
