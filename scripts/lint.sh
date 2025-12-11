#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RG_BIN="${RG_BIN:-$(command -v rg || true)}"
SWIFTLINT_BIN="${SWIFTLINT_BIN:-$(command -v swiftlint || true)}"

if [[ -z "${RG_BIN}" ]]; then
  echo "ripgrep (rg) is required for lint.sh" >&2
  exit 1
fi

if [[ -z "${SWIFTLINT_BIN}" ]]; then
  echo "SwiftLint is required for lint.sh" >&2
  exit 1
fi

echo "==> SwiftLint (strict)"
"${SWIFTLINT_BIN}" --strict --config "${ROOT}/.swiftlint.yml"

# Ensure generated folders are ignored/clean for lint
CHATUI_ROOT="${ROOT}/ChatUI"
if [[ -d "${CHATUI_ROOT}/.build" ]]; then
  echo "Cleaning ChatUI/.build to avoid linting generated output"
  rm -rf "${CHATUI_ROOT}/.build"
fi

search_forbidden() {
  local name="$1"
  local pattern="$2"
  local paths=("${@:3}")
  if "${RG_BIN}" --glob '!**/.build/**' --glob '!**/.derived/**' -n -e "${pattern}" "${paths[@]}" | grep .; then
    echo "✗ Forbidden pattern (${name}) detected" >&2
    exit 1
  else
    echo "✓ ${name}"
  fi
}

echo "==> ChatUI forbidden API grep checks"
search_forbidden "NSApp/NSEvent/NotificationCenter" "(NSApp|NSEvent|NotificationCenter)" "${CHATUI_ROOT}"
search_forbidden "Concurrency primitives (Task/DispatchQueue/Timer)" "\\bTask\\s*\\{|DispatchQueue|\\bTimer\\b" "${CHATUI_ROOT}"
search_forbidden "onReceive usage" "\\.onReceive\\s*\\(" "${CHATUI_ROOT}"
search_forbidden "fixedSize usage" "\\.fixedSize\\s*\\(" "${CHATUI_ROOT}"
if "${RG_BIN}" --glob '!**/.build/**' --glob '!**/.derived/**' --glob '!ChatUI/Sources/ChatUI/Shared/SizeReader.swift' -n -e "\\bGeometryReader\\b" "${CHATUI_ROOT}" | grep .; then
  echo "✗ Forbidden pattern (GeometryReader) detected outside Shared/SizeReader.swift" >&2
  exit 1
else
  echo "✓ GeometryReader usage (except Shared/SizeReader.swift)"
fi
search_forbidden "print/debugPrint usage" "\\b(print|debugPrint)\\s*\\(" "${CHATUI_ROOT}"
search_forbidden "File and JSON APIs" "FileManager|JSONEncoder|JSONDecoder" "${CHATUI_ROOT}"
search_forbidden "Workspace/Project/Codex domain types" "WorkspaceEngine|ProjectEngine|ConversationEngine|CodexService|CodexMutationPipeline|ContextSnapshot|FileDescriptor" "${CHATUI_ROOT}"
search_forbidden "AppKit imports outside bridge" "^import +AppKit" "${CHATUI_ROOT}/Sources/ChatUI" | grep -v "ChatUI/Sources/ChatUI/Shared/AppKitBridge" || true
if "${RG_BIN}" --glob '!**/.build/**' --glob '!**/.derived/**' --glob '!ChatUI/Sources/ChatUI/Shared/AppKitBridge/**' -n -e "^import +AppKit" "${CHATUI_ROOT}/Sources/ChatUI" | grep .; then
  echo "✗ AppKit import outside ChatUI/Shared/AppKitBridge" >&2
  exit 1
else
  echo "✓ AppKit only in ChatUI/Shared/AppKitBridge"
fi
search_forbidden "fatalError usage" "\\bfatalError\\s*\\(" "${CHATUI_ROOT}"
search_forbidden "try? usage" "try\\?" "${CHATUI_ROOT}"
search_forbidden "empty catch blocks" "catch\\s*\\{\\s*\\}" "${CHATUI_ROOT}"

echo "==> Architecture layering guard"
"${ROOT}/scripts/layering-guard.sh"

echo "==> Workspace tests"
"${ROOT}/scripts/workspace-test.sh"

echo "lint.sh completed."
