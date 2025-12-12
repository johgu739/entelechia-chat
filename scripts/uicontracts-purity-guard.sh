#!/bin/bash
# Guard 3: UIContracts Purity Scanner
# Blocks: Computed properties, functions, SwiftUI/Combine imports in UIContracts
# Failure: Any file with computed properties, functions (except init), or UI framework imports

set -e

VIOLATIONS=0
UICONTRACTS_SOURCES="UIContracts/Sources/UIContracts"

echo "🔍 Scanning UIContracts for purity violations..."

# Check for computed properties with logic (var ... {)
while IFS= read -r file; do
    if grep -q "var .*{" "$file"; then
        # Check if it's not just a simple stored property
        if grep -q "var .*\{[^}]*\}" "$file"; then
            echo "❌ VIOLATION: $file contains computed property with logic"
            grep -n "var .*{" "$file" | sed 's/^/   /'
            VIOLATIONS=$((VIOLATIONS + 1))
        fi
    fi
done < <(find "$UICONTRACTS_SOURCES" -name "*.swift")

# Check for functions (except init)
while IFS= read -r file; do
    if grep -q "func .*{" "$file"; then
        # Allow init functions
        if ! grep -q "func init" "$file"; then
            echo "❌ VIOLATION: $file contains function (only init allowed)"
            grep -n "func .*{" "$file" | grep -v "func init" | sed 's/^/   /'
            VIOLATIONS=$((VIOLATIONS + 1))
        fi
    fi
done < <(find "$UICONTRACTS_SOURCES" -name "*.swift")

# Check for forbidden imports
FORBIDDEN_IMPORTS=("import SwiftUI" "import Combine" "import UIConnections" "import AppCoreEngine")

for import_pattern in "${FORBIDDEN_IMPORTS[@]}"; do
    while IFS= read -r file; do
        echo "❌ VIOLATION: $file contains forbidden import: $import_pattern"
        grep -n "$import_pattern" "$file" | sed 's/^/   /'
        VIOLATIONS=$((VIOLATIONS + 1))
    done < <(grep -r "$import_pattern" "$UICONTRACTS_SOURCES" -l 2>/dev/null || true)
done

if [ $VIOLATIONS -eq 0 ]; then
    echo "✅ PASS: UIContracts maintains purity (no computed properties, functions, or UI imports)"
    exit 0
else
    echo "❌ FAIL: Found $VIOLATIONS violation(s)"
    exit 1
fi
