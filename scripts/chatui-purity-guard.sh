#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHATUI_DIR="$ROOT/ChatUI/Sources/ChatUI"

echo "==> Checking ChatUI for purity violations"

VIOLATIONS=0

# Check for illegal imports
echo "  Checking for illegal imports..."
if grep -r "^import UIConnections\|^import AppComposition" "$CHATUI_DIR" --include="*.swift"; then
    echo "  ❌ Found illegal import (UIConnections or AppComposition) in ChatUI"
    VIOLATIONS=$((VIOLATIONS + 1))
fi

# Check for @ObservedObject, @StateObject, @EnvironmentObject
echo "  Checking for ObservableObject property wrappers..."
if grep -r "@ObservedObject\|@StateObject\|@EnvironmentObject" "$CHATUI_DIR" --include="*.swift" | grep -v "//.*@ObservedObject\|//.*@StateObject\|//.*@EnvironmentObject"; then
    echo "  ❌ Found @ObservedObject, @StateObject, or @EnvironmentObject in ChatUI"
    VIOLATIONS=$((VIOLATIONS + 1))
fi

# Check for ObservableObject imports
echo "  Checking for ObservableObject imports..."
if grep -r "import.*ObservableObject\|: ObservableObject" "$CHATUI_DIR" --include="*.swift"; then
    echo "  ❌ Found ObservableObject imports or conformance in ChatUI"
    VIOLATIONS=$((VIOLATIONS + 1))
fi

# Check for Combine subscriptions
echo "  Checking for Combine subscriptions..."
if grep -r "\.sink\|\.assign\|AnyCancellable" "$CHATUI_DIR" --include="*.swift" | grep -v "//.*\.sink\|//.*\.assign"; then
    echo "  ❌ Found Combine subscriptions in ChatUI"
    VIOLATIONS=$((VIOLATIONS + 1))
fi

# Check for async/await (except in comments)
echo "  Checking for async/await..."
if grep -r "Task\s*{" "$CHATUI_DIR" --include="*.swift" | grep -v "//.*Task\|ChatInputView"; then
    echo "  ❌ Found Task {} blocks in ChatUI (except ephemeral UI state)"
    VIOLATIONS=$((VIOLATIONS + 1))
fi

# Check for .onChange (except ephemeral UI state in ChatInputView)
echo "  Checking for .onChange..."
if grep -r "\.onChange" "$CHATUI_DIR" --include="*.swift" | grep -v "//.*\.onChange\|ChatInputView"; then
    echo "  ❌ Found .onChange in ChatUI (except ephemeral UI state)"
    VIOLATIONS=$((VIOLATIONS + 1))
fi

# Check for class declarations (ChatUI should only have structs and enums, except NSObject subclasses and Coordinator for AppKit interop)
echo "  Checking for class declarations..."
if grep -r "^\s*class\s" "$CHATUI_DIR" --include="*.swift" | grep -v "//.*class\|NSObject\|NSOutlineView\|Coordinator"; then
    echo "  ❌ Found class declarations in ChatUI (should only have structs and enums, except NSObject subclasses and Coordinator for AppKit interop)"
    VIOLATIONS=$((VIOLATIONS + 1))
fi

# Check for ViewModel type references (common ViewModel types from UIConnections)
echo "  Checking for ViewModel type references..."
VIEWMODEL_TYPES=(
    "ChatViewModel"
    "WorkspaceStateViewModel"
    "WorkspaceActivityViewModel"
    "WorkspaceConversationBindingViewModel"
    "FileViewModel"
    "FilePreviewViewModel"
    "FileStatsViewModel"
    "FolderStatsViewModel"
    "ProjectCoordinator"
    "AlertCenter"
    "IntentController"
)

for vm_type in "${VIEWMODEL_TYPES[@]}"; do
    if grep -r "\b$vm_type\b" "$CHATUI_DIR" --include="*.swift" | grep -v "//.*$vm_type"; then
        echo "  ❌ Found $vm_type reference in ChatUI"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done

if [ $VIOLATIONS -eq 0 ]; then
    echo "  ✅ ChatUI is pure (no violations)"
    exit 0
else
    echo "  ❌ Found $VIOLATIONS violation(s) in ChatUI"
    echo "  ChatUI MUST be a pure projection layer. All state must flow through ViewState structs and intent closures."
    exit 1
fi


