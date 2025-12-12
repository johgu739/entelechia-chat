#!/bin/bash
# Guard: UIConnections Test Import Scanner
# Blocks: UIConnections test files importing anything other than UIConnections, AppCoreEngine, or UIContracts
# Failure: Any import in UIConnections test files other than UIConnections, AppCoreEngine, or UIContracts

set -e

VIOLATIONS=0
UICONNECTIONS_TEST_SOURCES="UIConnections/Tests"

echo "🔍 Scanning UIConnections test files for forbidden imports..."

# Check for forbidden imports in test files
# UIConnections tests may only import: XCTest, Combine, Foundation, CryptoKit, UIConnections, AppCoreEngine, UIContracts
# (Foundation and CryptoKit allowed for test infrastructure, but not AppAdapters/ChatUI/SwiftUI)

while IFS= read -r file; do
    echo "❌ VIOLATION: $file contains forbidden import"

    # Show the forbidden import lines
    grep -n "^import " "$file" | grep -v "import XCTest" | grep -v "import Combine" | grep -v "import Foundation" | grep -v "import CryptoKit" | grep -v "import UIConnections" | grep -v "import AppCoreEngine" | grep -v "import UIContracts" | sed 's/^/   /'

    VIOLATIONS=$((VIOLATIONS + 1))
done < <(find "$UICONNECTIONS_TEST_SOURCES" -name "*.swift" | grep -v "TestDoubles.swift" | xargs grep -l "^import ChatUI\|^import SwiftUI\|^import AppAdapters" || true)

if [ $VIOLATIONS -eq 0 ]; then
    echo "✅ PASS: UIConnections test files contain only allowed imports (XCTest, Combine, Foundation, CryptoKit, UIConnections, AppCoreEngine, UIContracts)"
    exit 0
else
    echo "❌ FAIL: Found $VIOLATIONS UIConnections test file(s) with forbidden imports"
    echo "   UIConnections test files may only import: XCTest, Combine, Foundation, CryptoKit, UIConnections, AppCoreEngine, UIContracts"
    exit 1
fi
