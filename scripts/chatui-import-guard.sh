#!/bin/bash
# Guard 2: ChatUI Import Scanner
# Blocks: ChatUI importing UIConnections or AppCoreEngine
# Failure: Any import of UIConnections or AppCoreEngine in ChatUI

set -e

VIOLATIONS=0
CHATUI_SOURCES="ChatUI/Sources"

echo "🔍 Scanning ChatUI for forbidden imports..."

# Check for forbidden imports
FORBIDDEN_IMPORTS=("import UIConnections" "import AppCoreEngine")

for import_pattern in "${FORBIDDEN_IMPORTS[@]}"; do
    while IFS= read -r file; do
        echo "❌ VIOLATION: $file contains forbidden import: $import_pattern"
        grep -n "$import_pattern" "$file" | sed 's/^/   /'
        VIOLATIONS=$((VIOLATIONS + 1))
    done < <(grep -r "$import_pattern" "$CHATUI_SOURCES" -l 2>/dev/null || true)
done

if [ $VIOLATIONS -eq 0 ]; then
    echo "✅ PASS: ChatUI contains no forbidden imports"
    exit 0
else
    echo "❌ FAIL: Found $VIOLATIONS violation(s)"
    exit 1
fi

