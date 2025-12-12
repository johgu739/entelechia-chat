#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UICONTRACTS_DIR="$ROOT/UIContracts/Sources/UIContracts"

echo "==> Checking UIContracts for purity violations"

VIOLATIONS=0

# Check for imports other than Foundation
echo "  Checking for non-Foundation imports..."
ALLOWED_IMPORTS=("Foundation" "SwiftUI")
for file in "$UICONTRACTS_DIR"/*.swift; do
    if [ -f "$file" ]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^import\  ]]; then
                import_name=$(echo "$line" | sed 's/^import //' | sed 's/^public //')
                if [[ ! " ${ALLOWED_IMPORTS[@]} " =~ " ${import_name} " ]]; then
                    echo "  ❌ Found illegal import '$import_name' in $(basename "$file")"
                    echo "     UIContracts may only import Foundation (and SwiftUI if needed for previews)"
                    VIOLATIONS=$((VIOLATIONS + 1))
                fi
            fi
        done < "$file"
    fi
done

# Check for class declarations
echo "  Checking for class declarations..."
if grep -r "^\s*class\s\|^\s*public\s*class\s" "$UICONTRACTS_DIR" --include="*.swift" | grep -v "//.*class"; then
    echo "  ❌ Found class declarations in UIContracts (should only have structs and enums)"
    VIOLATIONS=$((VIOLATIONS + 1))
fi

# Check for ObservableObject
echo "  Checking for ObservableObject..."
if grep -r "ObservableObject\|@Published" "$UICONTRACTS_DIR" --include="*.swift" | grep -v "//.*ObservableObject"; then
    echo "  ❌ Found ObservableObject or @Published in UIContracts"
    VIOLATIONS=$((VIOLATIONS + 1))
fi

# Check for Combine
echo "  Checking for Combine..."
if grep -r "import Combine\|Combine\." "$UICONTRACTS_DIR" --include="*.swift" | grep -v "//.*Combine"; then
    echo "  ❌ Found Combine in UIContracts"
    VIOLATIONS=$((VIOLATIONS + 1))
fi

# Check for async/await
echo "  Checking for async/await..."
if grep -r "async\|await" "$UICONTRACTS_DIR" --include="*.swift" | grep -v "//.*async\|//.*await"; then
    echo "  ❌ Found async/await in UIContracts"
    VIOLATIONS=$((VIOLATIONS + 1))
fi

# Check for ViewModel references
echo "  Checking for ViewModel references..."
if grep -r "ViewModel" "$UICONTRACTS_DIR" --include="*.swift" | grep -v "//.*ViewModel"; then
    echo "  ❌ Found ViewModel reference in UIContracts"
    VIOLATIONS=$((VIOLATIONS + 1))
fi

# Check for domain module imports
echo "  Checking for domain module imports..."
DOMAIN_MODULES=("AppCoreEngine" "AppAdapters" "UIConnections" "AppComposition")
for module in "${DOMAIN_MODULES[@]}"; do
    if grep -r "import $module" "$UICONTRACTS_DIR" --include="*.swift"; then
        echo "  ❌ Found import $module in UIContracts"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done

if [ $VIOLATIONS -eq 0 ]; then
    echo "  ✅ UIContracts is pure (no violations)"
    exit 0
else
    echo "  ❌ Found $VIOLATIONS violation(s) in UIContracts"
    echo "  UIContracts MUST contain only value types (struct, enum) with Foundation-only imports."
    exit 1
fi

