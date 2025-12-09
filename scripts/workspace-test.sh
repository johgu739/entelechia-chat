#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Canonical, deterministic package order.
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
  "ArchitectureGuardian"
)

failures=0

for pkg in "${packages[@]}"; do
  echo "==> swift test --package-path ${pkg}"
  if (cd "${ROOT}/${pkg}" && swift test); then
    echo "✓ ${pkg}"
  else
    echo "✗ ${pkg}"
    failures=$((failures + 1))
  fi
done

if [[ "${failures}" -ne 0 ]]; then
  echo "Workspace tests failed in ${failures} package(s)." >&2
  exit 1
fi

echo "Workspace tests passed for all ${#packages[@]} packages."

