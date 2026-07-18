import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Offers management architecture', () {
    test(
      'production files avoid SQLite, hosted refs, and forbidden scopes',
      () {
        const forbidden = <String>[
          'package:sqflite',
          'databasehelper',
          'apprepository',
          'supabase.co',
          'zegjqwsvsaprnguvxuwk',
          'txxokpovdbvsvnkpbrrp',
          '.rpc(',
          '.delete(',
          '.stream(',
          'realtime',
          ".from('orders'",
          '.from("orders"',
          'customer_order',
          'payment_proof',
          '_snapshot',
          'cost_',
          'profit',
          'inventory',
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

    test('datasource uses explicit offer and game projections', () {
      final content = File(
        'lib/features/admin_platform/infrastructure/offers/'
        'supabase_offers_datasource.dart',
      ).readAsStringSync();

      expect(content, isNot(contains("select('*')")));
      expect(content, isNot(contains('select("*")')));
      for (final column in <String>[
        'id',
        'game_id',
        'name_ar',
        'name_fr',
        'reward_quantity',
        'sale_price_dzd',
        'is_published',
        'sort_order',
        'created_at',
        'updated_at',
        'reward_unit_name_ar',
        'reward_unit_name_fr',
        'is_active',
      ]) {
        expect(content, contains(column));
      }
    });

    test('write payload contains no financial or inventory internals', () {
      final content = File(
        'lib/features/admin_platform/infrastructure/offers/'
        'public_offer_input_mapper.dart',
      ).readAsStringSync().toLowerCase();

      expect(content, isNot(contains('cost')));
      expect(content, isNot(contains('profit')));
      expect(content, isNot(contains('inventory')));
      expect(content, isNot(contains('snapshot')));
    });

    test('shell integrates offers and preserves the games builder', () {
      final content = File(
        'lib/features/admin_platform/presentation/'
        'customer_platform_shell.dart',
      ).readAsStringSync();

      expect(content, contains("import 'offers/offers_screen.dart';"));
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
    });

    test(
      'offers reuse gamesRepositoryProvider without a second repository',
      () {
        final content = File(
          'lib/features/admin_platform/application/offers/'
          'offers_providers.dart',
        ).readAsStringSync();

        expect(content, contains("import '../games/games_providers.dart';"));
        expect(content, contains('ref.watch(gamesRepositoryProvider)'));
        expect(content, isNot(contains('SupabaseGamesRepository')));
        expect(content, isNot(contains('SupabaseGamesDataSource')));
      },
    );

    test('offer implementation tests contain no hosted credentials', () {
      const forbidden = <String>[
        'supabase.co',
        'service_role',
        'sb_secret_',
        'github_pat_',
        '-----begin private key-----',
      ];
      for (final file in _implementationTestFiles()) {
        final content = file.readAsStringSync().toLowerCase();
        for (final value in forbidden) {
          expect(
            content,
            isNot(contains(value)),
            reason: '${file.path} must not contain $value',
          );
        }
      }
    });
  });
}

List<File> _productionFiles() {
  return <File>[
    File(
      'lib/features/admin_platform/infrastructure/offers/'
      'supabase_offers_datasource.dart',
    ),
    File(
      'lib/features/admin_platform/infrastructure/offers/'
      'supabase_public_offers_repository.dart',
    ),
    File(
      'lib/features/admin_platform/application/offers/'
      'offers_controller.dart',
    ),
    File(
      'lib/features/admin_platform/application/offers/'
      'offers_providers.dart',
    ),
    File(
      'lib/features/admin_platform/presentation/offers/'
      'offers_ui_text.dart',
    ),
    File(
      'lib/features/admin_platform/presentation/offers/'
      'offers_screen.dart',
    ),
  ];
}

List<File> _implementationTestFiles() {
  return <File>[
    File('test/features/admin_platform/offers/offers_test_fakes.dart'),
    File('test/features/admin_platform/offers/offers_controller_test.dart'),
    File(
      'test/features/admin_platform/offers/'
      'supabase_public_offers_repository_test.dart',
    ),
    File(
      'test/features/admin_platform/offers/'
      'offers_screen_widget_test.dart',
    ),
    File(
      'test/features/admin_platform/offers/'
      'offers_shell_integration_test.dart',
    ),
  ];
}
