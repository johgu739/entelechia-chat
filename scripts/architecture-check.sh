#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Running architecture layering guard"
"$ROOT/scripts/layering-guard.sh"

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



