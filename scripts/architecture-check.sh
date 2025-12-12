#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Running architecture layering guard"
"$ROOT/scripts/layering-guard.sh"

# Fail if ArchitectureGuardian found violations
if [ -d "$ROOT/.architecture-logs" ]; then
  for logfile in "$ROOT/.architecture-logs"/*-archguard.txt; do
    if [ -f "$logfile" ] && [ -s "$logfile" ]; then
      echo "ERROR: Architecture violations detected in $(basename "$logfile")"
      cat "$logfile"
      exit 1
    fi
  done
fi

echo "==> Building all packages after guardrail check"
packages=(
  "AppCoreEngine"
  "AppAdapters"
  "UIConnections"
  "AppComposition"
  "ChatUI"
  "OntologyCore"
  "OntologyAct"
  "OntologyState"
  "OntologyTeleology"
  "OntologyIntelligence"
  "OntologyFractal"
  "OntologyIntegration"
  "OntologyDomain"
)

for pkg in "${packages[@]}"; do
  echo "==> swift build --package-path $pkg"
  (cd "$ROOT/$pkg" && swift build)
done



