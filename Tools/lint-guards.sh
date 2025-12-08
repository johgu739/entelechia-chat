#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Running guard checks..."

fail=0

guard() {
  local name="$1"; shift
  local cmd=("$@")
  if output=$("${cmd[@]}"); then
    if [[ -n "${output}" ]]; then
      echo "::error ::${name} violations found"
      echo "${output}"
      fail=1
    else
      echo "✔ ${name} — ok"
    fi
  else
    # if ripgrep returns non-zero for no matches, treat that as success
    if [[ $? -eq 1 ]]; then
      echo "✔ ${name} — ok"
    else
      echo "::error ::${name} check failed to run"
      fail=1
    fi
  fi
}

# Block unchecked sendable outside tests
guard "Unchecked Sendable (non-test)" \
  rg --fixed-strings "@unchecked Sendable" \
     "${ROOT_DIR}/CoreEngine" "${ROOT_DIR}/ChatUI" "${ROOT_DIR}/AppAdapters" \
     --glob '!**/Tests/**' --glob '!**/*Tests.swift' --glob '!**/*.ent' || true

# Block DispatchSemaphore usage in engine/app code
guard "DispatchSemaphore usage" \
  rg "DispatchSemaphore" \
     "${ROOT_DIR}/CoreEngine/Sources" "${ROOT_DIR}/ChatUI" "${ROOT_DIR}/AppAdapters" \
     --glob '!**/Tests/**' --glob '!**/*.ent' || true

if [[ $fail -ne 0 ]]; then
  echo "Guard checks failed."
  exit 1
fi

echo "All guard checks passed."

