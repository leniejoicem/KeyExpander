#!/bin/bash
# Runs Tests/main.swift against the app's real source files.
# Usage: Tests/run-tests.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Building SQLite.swift dependency..."
if ! xcodebuild -project "$ROOT/KeyExpander.xcodeproj" -scheme KeyExpander -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath "$WORK/dd" CODE_SIGNING_ALLOWED=NO build \
  >"$WORK/build.log" 2>&1; then
  tail -50 "$WORK/build.log"
  exit 1
fi
PRODUCTS="$WORK/dd/Build/Products/Debug"

# A pre-migration database with a snippet pointing at a category that doesn't exist.
HOME_DIR="$WORK/home"
mkdir -p "$HOME_DIR/Library/Application Support"
sqlite3 "$HOME_DIR/Library/Application Support/keyexpander.sqlite" \
  "CREATE TABLE snippets(id INTEGER PRIMARY KEY AUTOINCREMENT, trigger TEXT UNIQUE NOT NULL, content TEXT NOT NULL, category_id INTEGER);
   INSERT INTO snippets(trigger, content, category_id) VALUES ('legacy', 'L', 999);"

echo "Compiling tests..."
swiftc -o "$WORK/tests" \
  "$ROOT/Engine/TextEngine.swift" \
  "$ROOT/Listener/GlobalKeyListener.swift" \
  "$ROOT"/Models/*.swift \
  "$ROOT"/Repositories/*.swift \
  "$ROOT/Database/DatabaseManager.swift" \
  "$ROOT/ViewModels/AppViewModel.swift" \
  "$ROOT/Tests/main.swift" \
  -I "$PRODUCTS" -L "$PRODUCTS" "$PRODUCTS/SQLite.o" -lsqlite3 -suppress-warnings

CFFIXED_USER_HOME="$HOME_DIR" HOME="$HOME_DIR" KE_TEST_HOME="$HOME_DIR" "$WORK/tests"
