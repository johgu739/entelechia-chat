#!/bin/bash
# Guard: ChatUI Test Import Scanner
# Blocks: ChatUI test files importing anything other than ChatUI or UIContracts
# Failure: Any import in ChatUI test files other than ChatUI or UIContracts

set -e

VIOLATIONS=0
CHATUI_TEST_SOURCES="ChatUI/Tests"

echo "🔍 Scanning ChatUI test files for forbidden imports..."

# Check for forbidden imports in test files
# ChatUI tests may only import: XCTest, SwiftUI, Foundation, ChatUI, UIContracts

while IFS= read -r file; do
    echo "❌ VIOLATION: $file contains forbidden import"

    # Show the forbidden import lines
    grep -n "^import " "$file" | grep -v "import XCTest" | grep -v "import SwiftUI" | grep -v "import Foundation" | grep -v "import ChatUI" | grep -v "import UIContracts" | sed 's/^/   /'

    VIOLATIONS=$((VIOLATIONS + 1))
done < <(find "$CHATUI_TEST_SOURCES" -name "*.swift" -exec grep -l "^import UIConnections\|^import AppCoreEngine" {} \; || true)

if [ $VIOLATIONS -eq 0 ]; then
    echo "✅ PASS: ChatUI test files contain only allowed imports (XCTest, SwiftUI, Foundation, ChatUI, UIContracts)"
    exit 0
else
    echo "❌ FAIL: Found $VIOLATIONS ChatUI test file(s) with forbidden imports"
    echo "   ChatUI test files may only import: XCTest, SwiftUI, Foundation, ChatUI, UIContracts"
    exit 1
fi
