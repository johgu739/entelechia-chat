#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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
  echo "==> Checking $pkg"
  (cd "$ROOT/$pkg" && swift build)
done


