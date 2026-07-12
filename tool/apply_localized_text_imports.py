from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
TARGET = LIB / "core" / "localization" / "localized_text.dart"
MATERIAL_IMPORT = "import 'package:flutter/material.dart';"


def main() -> None:
    changed: list[Path] = []

    for path in sorted(LIB.rglob("*.dart")):
        if path == TARGET:
            continue

        source = path.read_text(encoding="utf-8")
        if "Text(" not in source and "Text.rich(" not in source:
            continue
        if "localized_text.dart" in source:
            continue
        if MATERIAL_IMPORT not in source:
            continue

        relative = os.path.relpath(TARGET, path.parent).replace(os.sep, "/")
        replacement = (
            "import 'package:flutter/material.dart' hide Text;\n\n"
            f"import '{relative}';"
        )
        updated = source.replace(MATERIAL_IMPORT, replacement, 1)
        path.write_text(updated, encoding="utf-8")
        changed.append(path.relative_to(ROOT))

    print(f"Updated {len(changed)} Dart files.")
    for path in changed:
        print(path.as_posix())


if __name__ == "__main__":
    main()
