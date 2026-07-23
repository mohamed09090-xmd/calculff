import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Admin platform infrastructure architecture', () {
    test('production DTOs stay independent from UI and data clients', () {
      final files = _dtoProductionFiles();
      const forbiddenReferences = <String>[
        'package:flutter/',
        'widgets.dart',
        'package:supabase_flutter',
        'package:postgrest',
        'postgrestfilterbuilder',
        'supabaseclient',
        'package:sqflite',
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

    test('production DTOs expose no query or mutation operations', () {
      final files = _dtoProductionFiles();
      const forbiddenOperations = <String>[
        '.select(',
        '.insert(',
        '.update(',
        '.delete(',
        '.rpc(',
        '.auth.',
      ];

      for (final file in files) {
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

    test('production DTOs contain no hosted project references', () {
      final files = _dtoProductionFiles();
      const forbiddenReferences = <String>[
        'supabase.co',
        'zegjqwsvsaprnguvxuwk',
        'txxokpovdbvsvnkpbrrp',
      ];

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

    test('summary DTO stores no contact or persistence-only fields', () {
      final content = File(
        'lib/features/admin_platform/infrastructure/orders/'
        'customer_order_summary_dto.dart',
      ).readAsStringSync();
      const forbiddenFields = <String>[
        'customerEmail',
        'customerPhone',
        'customer_email_snapshot',
        'customer_phone_snapshot',
        'paymentProofPath',
        'changedBy',
        'userId',
        'clientRequestId',
      ];

      for (final field in forbiddenFields) {
        expect(content, isNot(contains(field)));
      }
    });

    test('details and timeline DTOs omit private operational fields', () {
      final files = <File>[
        File(
          'lib/features/admin_platform/infrastructure/orders/'
          'customer_order_details_dto.dart',
        ),
        File(
          'lib/features/admin_platform/infrastructure/orders/'
          'order_timeline_event_dto.dart',
        ),
      ];
      const forbiddenFields = <String>[
        'paymentProofPath',
        'changedBy',
        'userId',
        'clientRequestId',
        'internalNote',
        'changed_by',
        'user_id',
        'client_request_id',
        'internal_note',
        'order_id',
      ];

      for (final file in files) {
        final content = file.readAsStringSync();
        for (final field in forbiddenFields) {
          expect(
            content,
            isNot(contains(field)),
            reason: '${file.path} must not contain $field',
          );
        }
      }
    });

    test('production DTOs do not log raw payloads or responses', () {
      final files = _dtoProductionFiles();
      const forbiddenLogging = <String>[
        'print(',
        'debugprint(',
        'logger.',
        'payload.tostring(',
        'jsonencode(payload',
        'rawresponse',
      ];

      for (final file in files) {
        final content = file.readAsStringSync().toLowerCase();
        for (final logging in forbiddenLogging) {
          expect(
            content,
            isNot(contains(logging)),
            reason: '${file.path} must not contain $logging',
          );
        }
      }
    });
  });
}

List<File> _dtoProductionFiles() {
  return <File>[
    File(
      'lib/features/admin_platform/infrastructure/common/'
      'platform_payload_reader.dart',
    ),
    File('lib/features/admin_platform/infrastructure/games/game_dto.dart'),
    File(
      'lib/features/admin_platform/infrastructure/games/'
      'game_input_mapper.dart',
    ),
    File(
      'lib/features/admin_platform/infrastructure/offers/'
      'public_offer_dto.dart',
    ),
    File(
      'lib/features/admin_platform/infrastructure/offers/'
      'public_offer_input_mapper.dart',
    ),
    File(
      'lib/features/admin_platform/infrastructure/orders/'
      'order_payload_parsers.dart',
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
      'lib/features/admin_platform/infrastructure/orders/'
      'order_internal_note_dto.dart',
    ),
    File(
      'lib/features/admin_platform/infrastructure/dashboard/'
      'platform_dashboard_summary_dto.dart',
    ),
  ];
}
