from __future__ import annotations

import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
TEXT_TARGET = LIB / "core" / "localization" / "localized_text.dart"
TRANSLATOR_TARGET = LIB / "core" / "localization" / "app_translator.dart"
CATALOG_TARGET = LIB / "core" / "localization" / "french_catalog.dart"
MATERIAL_IMPORT = "import 'package:flutter/material.dart';"
MATERIAL_HIDDEN_IMPORT = "import 'package:flutter/material.dart' hide Text;"

DART_STRING = r"'(?:\\.|[^'\n])*'|\"(?:\\.|[^\"\n])*\""
STRING_PROPERTY_PATTERN = re.compile(
    r"(?m)^(?P<indent>\s*)"
    r"(?P<name>labelText|hintText|helperText|errorText|counterText|label|"
    r"semanticCounterText|tooltip|message|dialogTitle|subject|semanticsLabel)"
    rf":\s*(?P<literal>{DART_STRING}),\s*$"
)
INLINE_DECORATION_PATTERN = re.compile(
    rf"InputDecoration\((?P<name>labelText|hintText):\s*"
    rf"(?P<value>(?!AppTranslator\.translate\(context,)(?:{DART_STRING}|[A-Za-z_][A-Za-z0-9_\.]*))\)"
)
VALIDATION_TERNARY_PATTERN = re.compile(
    rf"(?P<prefix>\?\s*)(?P<literal>{DART_STRING})(?P<suffix>\s*:\s*null)"
)


def _relative_import(path: Path, target: Path) -> str:
    relative = os.path.relpath(target, path.parent).replace(os.sep, "/")
    return f"import '{relative}';"


def _insert_relative_import(source: str, import_line: str) -> str:
    if import_line in source:
        return source

    lines = source.splitlines()
    relative_import_indexes = [
        index
        for index, line in enumerate(lines)
        if line.startswith("import '")
        and not line.startswith("import 'dart:")
        and not line.startswith("import 'package:")
    ]
    package_import_indexes = [
        index for index, line in enumerate(lines) if line.startswith("import 'package:")
    ]

    if relative_import_indexes:
        insert_at = relative_import_indexes[0]
    elif package_import_indexes:
        insert_at = package_import_indexes[-1] + 1
    else:
        return source

    if insert_at > 0 and lines[insert_at - 1] != "":
        lines.insert(insert_at, "")
        insert_at += 1
    lines.insert(insert_at, import_line)
    insert_at += 1
    if insert_at < len(lines) and lines[insert_at] != "":
        lines.insert(insert_at, "")

    return "\n".join(lines).rstrip() + "\n"


def _normalize_text_import(path: Path, source: str) -> str:
    if path == TEXT_TARGET:
        return source
    if "Text(" not in source and "Text.rich(" not in source:
        return source
    if MATERIAL_IMPORT not in source and MATERIAL_HIDDEN_IMPORT not in source:
        return source

    localized_import = _relative_import(path, TEXT_TARGET)
    source = source.replace(MATERIAL_IMPORT, MATERIAL_HIDDEN_IMPORT, 1)
    source = re.sub(
        r"\n?import '[^']*localized_text\.dart';\n?",
        "\n",
        source,
        count=1,
    )
    return _insert_relative_import(source, localized_import)


def _wire_french_catalog(source: str) -> str:
    import_line = "import 'french_catalog.dart';"
    if import_line not in source:
        source = source.replace(
            "import 'package:flutter/widgets.dart';",
            "import 'package:flutter/widgets.dart';\n\nimport 'french_catalog.dart';",
            1,
        )

    source = source.replace(
        "    final exact = _exactFrench[source];",
        "    final exact = _exactFrench[source] ?? additionalFrenchTranslations[source];",
        1,
    )

    old_loop = """    for (final entry in _phraseFrench.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }"""
    new_loop = """    final phrases = <MapEntry<String, String>>[
      ...additionalFrenchPhrases.entries,
      ..._phraseFrench.entries,
    ]..sort(
        (first, second) => second.key.length.compareTo(first.key.length),
      );
    for (final entry in phrases) {
      result = result.replaceAll(entry.key, entry.value);
    }"""
    source = source.replace(old_loop, new_loop, 1)
    return source


def _localize_string_properties(path: Path, source: str) -> str:
    if path in {TEXT_TARGET, TRANSLATOR_TARGET, CATALOG_TARGET}:
        return source
    if "BuildContext context" not in source:
        return source

    def replace_property(match: re.Match[str]) -> str:
        return (
            f"{match.group('indent')}{match.group('name')}: "
            f"AppTranslator.translate(context, {match.group('literal')}),"
        )

    def replace_inline_decoration(match: re.Match[str]) -> str:
        return (
            f"InputDecoration({match.group('name')}: "
            f"AppTranslator.translate(context, {match.group('value')}))"
        )

    def replace_validation(match: re.Match[str]) -> str:
        return (
            f"{match.group('prefix')}AppTranslator.translate("
            f"context, {match.group('literal')}){match.group('suffix')}"
        )

    updated = STRING_PROPERTY_PATTERN.sub(replace_property, source)
    updated = INLINE_DECORATION_PATTERN.sub(replace_inline_decoration, updated)
    updated = VALIDATION_TERNARY_PATTERN.sub(replace_validation, updated)

    calculator_path = (
        LIB / "features" / "calculator" / "presentation" / "calculator_screen.dart"
    )
    if path == calculator_path:
        updated = updated.replace(
            "labelText: _inputLabel,",
            "labelText: AppTranslator.translate(context, _inputLabel),",
        )
        old_dropdown = """labelText: _mode == CalculationMode.directProduct
                                ? 'المنتج المباشر'
                                : 'منتج الجواهر',"""
        new_dropdown = """labelText: AppTranslator.translate(
                              context,
                              _mode == CalculationMode.directProduct
                                  ? 'المنتج المباشر'
                                  : 'منتج الجواهر',
                            ),"""
        updated = updated.replace(old_dropdown, new_dropdown)

    if updated == source:
        return source

    updated = updated.replace("const InputDecoration(", "InputDecoration(")
    updated = updated.replace("const Tooltip(", "Tooltip(")
    updated = updated.replace("const IconButton(", "IconButton(")
    updated = updated.replace("const SnackBarAction(", "SnackBarAction(")
    return _insert_relative_import(
        updated,
        _relative_import(path, TRANSLATOR_TARGET),
    )


def _add_language_settings(source: str) -> str:
    language_import = (
        "import '../../../shared/providers/app_language_provider.dart';"
    )
    theme_import = "import '../../../shared/providers/theme_mode_provider.dart';"
    if language_import not in source and theme_import in source:
        source = source.replace(
            theme_import,
            f"{language_import}\n{theme_import}",
            1,
        )

    language_state = (
        "    final languagePreference =\n"
        "        ref.watch(appLanguageProvider).valueOrNull ??\n"
        "            AppLanguagePreference.arabic;\n"
    )
    state_marker = (
        "    final platformBrightness = MediaQuery.platformBrightnessOf(context);\n"
    )
    if "final languagePreference =" not in source and state_marker in source:
        source = source.replace(
            state_marker,
            f"{language_state}{state_marker}",
            1,
        )

    section_marker = (
        "            const SizedBox(height: 12),\n"
        "            SectionCard(\n"
        "              title: 'المظهر وطريقة العرض',"
    )
    if "SegmentedButton<AppLanguagePreference>" not in source and section_marker in source:
        language_section = """            const SizedBox(height: 12),
            SectionCard(
              title: 'اللغة',
              icon: Icons.language_outlined,
              accent: Theme.of(context).colorScheme.secondary,
              child: SegmentedButton<AppLanguagePreference>(
                segments: const [
                  ButtonSegment(
                    value: AppLanguagePreference.arabic,
                    label: Text('العربية'),
                    icon: Icon(Icons.format_textdirection_r_to_l),
                  ),
                  ButtonSegment(
                    value: AppLanguagePreference.french,
                    label: Text('الفرنسية'),
                    icon: Icon(Icons.format_textdirection_l_to_r),
                  ),
                ],
                selected: {languagePreference},
                showSelectedIcon: false,
                onSelectionChanged: (selection) => ref
                    .read(appLanguageProvider.notifier)
                    .setLanguage(selection.first),
              ),
            ),
"""
        source = source.replace(
            section_marker,
            language_section + section_marker,
            1,
        )

    return source


def main() -> None:
    changed: list[Path] = []

    for path in sorted(LIB.rglob("*.dart")):
        source = path.read_text(encoding="utf-8")
        updated = _normalize_text_import(path, source)
        if path == TRANSLATOR_TARGET:
            updated = _wire_french_catalog(updated)
        updated = _localize_string_properties(path, updated)
        if path == LIB / "features" / "settings" / "presentation" / "settings_screen.dart":
            updated = _add_language_settings(updated)

        if updated == source:
            continue
        path.write_text(updated, encoding="utf-8")
        changed.append(path.relative_to(ROOT))

    print(f"Updated {len(changed)} Dart files.")
    for path in changed:
        print(path.as_posix())


if __name__ == "__main__":
    main()
