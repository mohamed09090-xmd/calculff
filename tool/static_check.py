#!/usr/bin/env python3
"""Offline structural checks for the Flutter source tree.

This does not replace `flutter analyze` or `flutter test`; it catches damaged
archives, unresolved relative imports, malformed XML/YAML, accidental secrets,
and missing mandatory implementation files.
"""
from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []
notes: list[str] = []

try:
    import yaml  # type: ignore
except ImportError:
    yaml = None

try:
    from tree_sitter import Language, Parser  # type: ignore
    import tree_sitter_dart  # type: ignore
except ImportError:
    Language = Parser = tree_sitter_dart = None


def fail(message: str) -> None:
    errors.append(message)


# 1. Required files and directories.
required = [
    'pubspec.yaml',
    'lib/main.dart',
    'lib/app/app.dart',
    'lib/app/router.dart',
    'lib/core/database/app_database.dart',
    'lib/features/calculator/application/package_optimizer.dart',
    'lib/features/calculator/application/calculation_engine.dart',
    'lib/features/inventory/application/fefo_allocator.dart',
    'lib/shared/repositories/app_repository.dart',
    'test/package_optimizer_test.dart',
    'test/calculation_engine_test.dart',
    'test/fefo_allocator_test.dart',
    'android/app/src/main/AndroidManifest.xml',
    '.github/workflows/build-apk.yml',
]
for relative in required:
    if not (ROOT / relative).is_file():
        fail(f'missing required file: {relative}')

# 2. YAML and XML integrity.
if yaml is not None:
    for relative in ['pubspec.yaml', '.github/workflows/build-apk.yml']:
        try:
            yaml.safe_load((ROOT / relative).read_text(encoding='utf-8'))
        except Exception as exc:  # noqa: BLE001
            fail(f'invalid YAML {relative}: {exc}')
else:
    notes.append('PyYAML unavailable; YAML parse skipped')

for path in (ROOT / 'android').rglob('*.xml'):
    try:
        ET.parse(path)
    except ET.ParseError as exc:
        fail(f'invalid XML {path.relative_to(ROOT)}: {exc}')

# 3. Dart syntax (tree-sitter when available).
dart_files = sorted([*(ROOT / 'lib').rglob('*.dart'), *(ROOT / 'test').rglob('*.dart')])
if Language is not None and Parser is not None and tree_sitter_dart is not None:
    parser = Parser(Language(tree_sitter_dart.language()))
    for path in dart_files:
        tree = parser.parse(path.read_bytes())
        if tree.root_node.has_error:
            fail(f'Dart syntax error: {path.relative_to(ROOT)}')
else:
    notes.append('tree-sitter-dart unavailable; exact Dart parse skipped')

# 4. Resolve relative Dart imports.
import_pattern = re.compile(r"^import\s+['\"]([^'\"]+)['\"];", re.MULTILINE)
for path in dart_files:
    source = path.read_text(encoding='utf-8')
    for target in import_pattern.findall(source):
        if target.startswith(('dart:', 'package:')):
            continue
        resolved = (path.parent / target).resolve()
        try:
            resolved.relative_to(ROOT.resolve())
        except ValueError:
            fail(f'import escapes project: {path.relative_to(ROOT)} -> {target}')
            continue
        if not resolved.is_file():
            fail(f'unresolved import: {path.relative_to(ROOT)} -> {target}')

# 5. Mandatory screens, services, schema, and tests.
router = (ROOT / 'lib/app/router.dart').read_text(encoding='utf-8')
for route in [
    '/dashboard', '/calculate', '/products', '/packages', '/inventory',
    '/transactions', '/settings', '/backup',
]:
    if route not in router:
        fail(f'missing route: {route}')

schema = (ROOT / 'lib/core/database/app_database.dart').read_text(encoding='utf-8')
for table in [
    'packages', 'products', 'inventory_lots', 'sales_transactions',
    'transaction_items', 'inventory_movements', 'app_settings',
]:
    if f'CREATE TABLE {table}' not in schema:
        fail(f'missing SQLite table: {table}')

optimizer = (ROOT / 'lib/features/calculator/application/package_optimizer.dart').read_text(encoding='utf-8')
if 'class PackageOptimizer' not in optimizer:
    fail('PackageOptimizer class missing')
if 'List<_Candidate?>.filled' not in optimizer:
    fail('dynamic-programming optimizer state missing')

repo = (ROOT / 'lib/shared/repositories/app_repository.dart').read_text(encoding='utf-8')
for marker in ['_consumeCredit', '_rebuildInventory', 'orderBy: \'expires_at ASC']:
    if marker not in repo:
        fail(f'inventory/rebuild marker missing: {marker}')

all_tests = '\n'.join(p.read_text(encoding='utf-8') for p in (ROOT / 'test').glob('*.dart'))
for expectation in ['6000', '2400', '349', 'FEFO', 'تعديل أسعار الباقات', 'إعادة المخزون']:
    if expectation not in all_tests:
        fail(f'required test scenario marker missing: {expectation}')

# 6. Secret and generated-output scan.
for forbidden in ['.env', '.env.local', 'key.properties', 'local.properties']:
    if (ROOT / forbidden).exists():
        fail(f'forbidden local/secret file present: {forbidden}')
for forbidden_dir in ['build', '.dart_tool']:
    if (ROOT / forbidden_dir).exists():
        fail(f'generated directory should not be shipped: {forbidden_dir}')

secret_patterns = [
    re.compile(r'AIza[0-9A-Za-z_-]{30,}'),
    re.compile(r'gh[pousr]_[0-9A-Za-z]{20,}'),
    re.compile(r'sk-[0-9A-Za-z]{20,}'),
    re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
]
for path in ROOT.rglob('*'):
    if not path.is_file() or path.suffix.lower() in {'.png', '.jpg', '.jpeg', '.zip', '.jar'}:
        continue
    try:
        text = path.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        continue
    for pattern in secret_patterns:
        if pattern.search(text):
            fail(f'possible secret in {path.relative_to(ROOT)}')

print(f'Checked {len(dart_files)} Dart files.')
for note in notes:
    print(f'NOTE: {note}')
if errors:
    for item in errors:
        print(f'ERROR: {item}')
    sys.exit(1)
print('PASS: source structure, syntax, imports, YAML/XML, schema, tests, and secret scan.')
