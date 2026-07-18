import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final productionFiles = <File>[
    ...Directory(
      'lib/features/admin_platform/application/games',
    ).listSync(recursive: true).whereType<File>(),
    ...Directory(
      'lib/features/admin_platform/infrastructure/games',
    ).listSync(recursive: true).whereType<File>(),
    ...Directory(
      'lib/features/admin_platform/presentation/games',
    ).listSync(recursive: true).whereType<File>(),
  ].where((file) => file.path.endsWith('.dart')).toList();

  test('games feature exposes no deletion, realtime, RPC, or SQLite', () {
    const forbidden = <String>[
      'deletegame',
      '.delete(',
      '.rpc(',
      '.channel(',
      'realtime',
      'package:sqflite',
      'databasehelper',
      'apprepository',
    ];

    for (final file in productionFiles) {
      final content = file.readAsStringSync().toLowerCase();
      for (final token in forbidden) {
        expect(
          content,
          isNot(contains(token)),
          reason: '${file.path} must not contain $token',
        );
      }
    }
  });

  test('widgets do not acquire Supabase clients directly', () {
    final files = Directory('lib/features/admin_platform/presentation/games')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in files) {
      final content = file.readAsStringSync().toLowerCase();
      expect(content, isNot(contains('supabase.instance.client')));
      expect(content, isNot(contains('package:supabase_flutter')));
    }
  });

  test('data source uses explicit selection and deterministic ordering', () {
    final content = File(
      'lib/features/admin_platform/infrastructure/games/'
      'supabase_games_data_source.dart',
    ).readAsStringSync();

    expect(content, contains('.select(selectedColumns)'));
    expect(content, isNot(contains("select('*')")));
    expect(content, contains(".order('sort_order', ascending: true)"));
    expect(content, contains(".order('id', ascending: true)"));
  });

  test('games code and tests contain no hosted project or secret material', () {
    final files = <File>[
      ...productionFiles,
      ...Directory('test/features/admin_platform')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.contains('games'))
          .where(
            (file) =>
                !file.path.endsWith('games_feature_architecture_test.dart'),
          ),
    ];
    const forbidden = <String>[
      'supabase.co',
      'sb_secret_',
      'service_role',
      'eyjhb',
      'android_keystore_base64',
    ];

    for (final file in files) {
      final content = file.readAsStringSync().toLowerCase();
      for (final token in forbidden) {
        expect(content, isNot(contains(token)), reason: file.path);
      }
    }
  });

  test('customer shell preserves all implemented destinations', () {
    final content = File(
      'lib/features/admin_platform/presentation/customer_platform_shell.dart',
    ).readAsStringSync();

    expect(
      RegExp(
        r'builder:\s*\(_\) => const PlatformDashboardScreen\(\)',
      ).allMatches(content),
      hasLength(1),
    );
    expect(
      RegExp(r'builder:\s*\(_\) => const GamesScreen\(\)').allMatches(content),
      hasLength(1),
    );
    expect(
      RegExp(r'builder:\s*\(_\) => const OffersScreen\(\)').allMatches(content),
      hasLength(1),
    );
    expect(
      RegExp(
        r'builder:\s*\(_\) => const CustomerOrdersScreen\(\)',
      ).allMatches(content),
      hasLength(1),
    );
  });
}
