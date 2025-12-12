#!/bin/bash
# Guard 5: Forbidden Symbol List Scanner
# Blocks: Specific domain symbols appearing in public UIConnections APIs
# Failure: Public API contains domain type names

set -e

VIOLATIONS=0
UICONNECTIONS_SOURCES="UIConnections/Sources/UIConnections"

echo "🔍 Scanning UIConnections public APIs for forbidden domain symbols..."

# Forbidden symbols (domain types that must not appear in public APIs)
FORBIDDEN_SYMBOLS=(
    "Conversation"  # AppCoreEngine.Conversation
    "FileID"        # Unqualified, resolves to AppCoreEngine.FileID
    "ContextBuildResult"  # AppCoreEngine.ContextBuildResult
    "WorkspaceTreeProjection"  # AppCoreEngine.WorkspaceTreeProjection
    "ConversationContextRequest"  # AppCoreEngine.ConversationContextRequest
    "ConversationDelta"  # AppCoreEngine.ConversationDelta
)

for symbol in "${FORBIDDEN_SYMBOLS[@]}"; do
    while IFS= read -r file; do
        # Check if symbol appears in public API (public keyword before it)
        if grep -q "public.*$symbol\|:$symbol\|$symbol:" "$file"; then
            # Exclude if it's qualified with UIContracts
            if ! grep -q "UIContracts\.$symbol\|UIContracts\.\($symbol\)" "$file"; then
                echo "❌ VIOLATION: $file contains forbidden domain symbol '$symbol' in public API"
                grep -n "$symbol" "$file" | grep -E "public|:" | sed 's/^/   /'
                VIOLATIONS=$((VIOLATIONS + 1))
            fi
        fi
    done < <(find "$UICONNECTIONS_SOURCES" -name "*.swift" -exec grep -l "$symbol" {} \; 2>/dev/null || true)
done

if [ $VIOLATIONS -eq 0 ]; then
    echo "✅ PASS: No forbidden domain symbols in public APIs"
    exit 0
else
    echo "❌ FAIL: Found $VIOLATIONS violation(s)"
    exit 1
fi

