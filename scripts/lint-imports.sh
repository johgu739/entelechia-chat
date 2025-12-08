#!/usr/bin/env bash
set -euo pipefail

RG_BIN="${RG_BIN:-$(command -v rg || true)}"

search() {
  local pattern=$1
  shift
  if [[ -n "${RG_BIN}" ]]; then
    ${RG_BIN} --glob '!.build/**' --files-with-matches "${pattern}" "$@" || true
  else
    grep -R -l -E --exclude-dir='.build' "${pattern}" "$@" || true
  fi
}

# Forbid SwiftUI/AppKit in CoreEngine or AppAdapters
if search 'import +(SwiftUI|AppKit)' CoreEngine AppAdapters | grep .; then
  echo "Forbidden UI imports found in CoreEngine/AppAdapters"
  exit 1
fi

# Forbid ChatUI importing AppAdapters concretes (allow in ChatUI/AppComposition composition root only)
if search 'import +AppAdapters' ChatUI | grep -v 'ChatUI/AppComposition/' | grep .; then
  echo "Forbidden AppAdapters imports in ChatUI (outside composition root)"
  exit 1
fi

# Forbid UIConnections importing anything but CoreEngine/Foundation
if search 'import +(AppAdapters|SwiftUI|AppKit)' UIConnections | grep .; then
  echo "Forbidden imports in UIConnections"
  exit 1
fi

# Forbid @unchecked Sendable in production code (allow in Tests)
if search '@unchecked +Sendable' CoreEngine AppAdapters UIConnections ChatUI | grep -v '/Tests/' | grep .; then
  echo "@unchecked Sendable is forbidden"
  exit 1
fi

# Forbid NotificationCenter in CoreEngine
if search 'NotificationCenter' CoreEngine | grep .; then
  echo "NotificationCenter is forbidden in CoreEngine"
  exit 1
fi

echo "Import lint passed."

