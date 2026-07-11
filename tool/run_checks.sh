#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
python3 tool/static_check.py
python3 tool/verify_logic.py
if command -v flutter >/dev/null 2>&1; then
  flutter pub get
  flutter analyze
  flutter test
else
  echo "Flutter SDK is not installed; Flutter-native checks were skipped." >&2
  exit 2
fi
