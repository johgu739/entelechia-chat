#!/bin/bash
# Guard 1: ArchitectureGuardian — Public API Scanner
# Blocks: Public symbols in UIConnections that expose AppCoreEngine types
# Failure: Any public struct/enum/class/protocol/function with AppCoreEngine types

set -e

VIOLATIONS=0
UICONNECTIONS_SOURCES="UIConnections/Sources/UIConnections"

echo "🔍 Scanning UIConnections public APIs for AppCoreEngine type exposure..."

# Check for explicit AppCoreEngine. type references in public APIs
# This is the actual violation - public APIs exposing domain types
while IFS= read -r file; do
    # Check for explicit AppCoreEngine. type references in public APIs
    if grep -q "public.*AppCoreEngine\." "$file"; then
        echo "❌ VIOLATION: $file contains public API with AppCoreEngine type reference"
        grep -n "public.*AppCoreEngine\." "$file" | sed 's/^/   /'
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
    
    # Check for unqualified domain type names in public APIs (FileID, Conversation, etc.)
    # that would resolve to AppCoreEngine types
    # Exclude UIContracts-qualified types and internal symbols
    if grep -qE "^public (struct|enum|class|protocol|func|var|let|typealias).*[^.]\b(FileID|Conversation|ContextBuildResult|WorkspaceTreeProjection|ConversationContextRequest|ConversationDelta)\b" "$file"; then
        # Check each match to exclude UIContracts-qualified types
        while IFS= read -r line; do
            # Skip if line contains UIContracts qualification
            if ! echo "$line" | grep -q "UIContracts\.(FileID|Conversation|ContextBuildResult|UIContextBuildResult|UIConversation)"; then
                echo "❌ VIOLATION: $file contains public API with unqualified domain type"
                echo "   $line" | sed 's/^/   /'
                VIOLATIONS=$((VIOLATIONS + 1))
            fi
        done < <(grep -nE "^public (struct|enum|class|protocol|func|var|let|typealias).*[^.]\b(FileID|Conversation|ContextBuildResult|WorkspaceTreeProjection|ConversationContextRequest|ConversationDelta)\b" "$file" || true)
    fi
done < <(find "$UICONNECTIONS_SOURCES" -name "*.swift")

if [ $VIOLATIONS -eq 0 ]; then
    echo "✅ PASS: No public APIs expose AppCoreEngine types"
    exit 0
else
    echo "❌ FAIL: Found $VIOLATIONS violation(s)"
    exit 1
fi

