import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard remains count-only without polling or local persistence', () {
    final files = [
      File(
        'lib/features/admin_platform/infrastructure/dashboard/'
        'supabase_platform_dashboard_data_source.dart',
      ),
      File(
        'lib/features/admin_platform/infrastructure/dashboard/'
        'supabase_platform_dashboard_repository.dart',
      ),
      File(
        'lib/features/admin_platform/application/dashboard/'
        'platform_dashboard_controller.dart',
      ),
      File(
        'lib/features/admin_platform/application/dashboard/'
        'platform_dashboard_providers.dart',
      ),
    ];
    final source = files.map((file) => file.readAsStringSync()).join('\n');

    expect(
      RegExp(r'\.count\(CountOption\.exact\)').allMatches(source),
      hasLength(6),
    );
    expect(source, isNot(contains("select('*')")));
    expect(source, isNot(contains('.rpc(')));
    expect(source, isNot(contains('.channel(')));
    expect(source, isNot(contains('Realtime')));
    expect(source, isNot(contains('Timer(')));
    expect(source, isNot(contains('periodic')));
    expect(source, isNot(contains('flutter_secure_storage')));
    expect(source, isNot(contains('sqflite')));
    expect(source, isNot(contains('SQLite')));
    expect(source, isNot(contains('profit')));
    expect(source, isNot(contains('inventory')));
  });
}
