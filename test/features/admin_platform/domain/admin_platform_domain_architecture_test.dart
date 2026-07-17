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
        File(
          'lib/features/admin_platform/domain/games/games_repository.dart',
        ),
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
  });
}
