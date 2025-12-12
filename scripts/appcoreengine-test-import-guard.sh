#!/bin/bash
# Guard: AppCoreEngine Test Import Scanner
# Blocks: AppCoreEngine test files importing anything other than AppCoreEngine
# Failure: Any import in AppCoreEngine test files other than AppCoreEngine

set -e

VIOLATIONS=0
APPCOREENGINE_TEST_SOURCES="AppCoreEngine/Tests"

echo "🔍 Scanning AppCoreEngine test files for forbidden imports..."

# Check for forbidden imports in test files
# AppCoreEngine tests may only import: XCTest, Foundation, AppCoreEngine

while IFS= read -r file; do
    echo "❌ VIOLATION: $file contains forbidden import"

    # Show the forbidden import lines
    grep -n "^import " "$file" | grep -v "import XCTest" | grep -v "import Foundation" | grep -v "import AppCoreEngine" | sed 's/^/   /'

    VIOLATIONS=$((VIOLATIONS + 1))
done < <(find "$APPCOREENGINE_TEST_SOURCES" -name "*.swift" | xargs grep -l "^import UIConnections\|^import ChatUI\|^import UIContracts\|^import UI" || true)

if [ $VIOLATIONS -eq 0 ]; then
    echo "✅ PASS: AppCoreEngine test files contain only allowed imports (XCTest, Foundation, AppCoreEngine)"
    exit 0
else
    echo "❌ FAIL: Found $VIOLATIONS AppCoreEngine test file(s) with forbidden imports"
    echo "   AppCoreEngine test files may only import: XCTest, Foundation, AppCoreEngine"
    exit 1
fi
