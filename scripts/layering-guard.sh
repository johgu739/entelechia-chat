#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULES="$ROOT/ArchitectureGuardian/ArchitectureRules.json"
OUT_DIR="$ROOT/.architecture-logs"
TOOL_PKG="$ROOT/ArchitectureGuardian"

mkdir -p "$OUT_DIR"

run_guard() {
  local target="$1"; shift
  local sources=("$@")
  if [ "${#sources[@]}" -eq 0 ]; then
    echo "ArchitectureGuardian: warning – no sources for target ${target}" >&2
    return 0
  fi
  echo "ArchitectureGuardian: checking ${target}"
  TARGET_NAME="${target}" swift run --package-path "$TOOL_PKG" ArchitectureGuardianTool \
    --rules-hint "$RULES" \
    --output "$OUT_DIR/${target}-archguard.txt" \
    "${sources[@]}"
}

collect_and_check() {
  local target="$1"
  local dir="$2"
  if [ ! -d "$dir" ]; then
    echo "ArchitectureGuardian: skip ${target}, missing ${dir}" >&2
    return
  fi
  local files=()
  while IFS= read -r file; do
    files+=("$file")
  done < <(find "$dir" -name "*.swift" -print | sort)
  run_guard "$target" "${files[@]:-}"
}

# Target -> directory mapping (Sources/ and Tests/ layouts)
collect_and_check "ChatUI" "$ROOT/ChatUI/Sources"
collect_and_check "ChatUITests" "$ROOT/ChatUI/Tests"
collect_and_check "UIConnections" "$ROOT/UIConnections/Sources"
collect_and_check "UIConnectionsTests" "$ROOT/UIConnections/Tests"
collect_and_check "AppComposition" "$ROOT/AppComposition/Sources"
collect_and_check "AppCompositionTests" "$ROOT/AppComposition/Tests"
collect_and_check "AppAdapters" "$ROOT/AppAdapters/Sources"
collect_and_check "AppAdaptersTests" "$ROOT/AppAdapters/Tests"
collect_and_check "AppCoreEngine" "$ROOT/AppCoreEngine/Sources"
collect_and_check "AppCoreEngineTests" "$ROOT/AppCoreEngine/Tests"
collect_and_check "OntologyCore" "$ROOT/OntologyCore/Sources"
collect_and_check "OntologyAct" "$ROOT/OntologyAct/Sources"
collect_and_check "OntologyState" "$ROOT/OntologyState/Sources"
collect_and_check "OntologyTeleology" "$ROOT/OntologyTeleology/Sources"
collect_and_check "OntologyIntelligence" "$ROOT/OntologyIntelligence/Sources"
collect_and_check "OntologyFractal" "$ROOT/OntologyFractal/Sources"
collect_and_check "OntologyIntegration" "$ROOT/OntologyIntegration/Sources"
collect_and_check "OntologyDomain" "$ROOT/OntologyDomain/Sources"

echo "ArchitectureGuardian: all targets checked"

