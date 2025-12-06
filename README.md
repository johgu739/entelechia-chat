# Entelechia Ontology Utilities

Run the Thomistic ontology scan from the repo root:

```
make ontology
```

What happens:
- Inserts canonical TODO headers into any Swift file missing them.
- Ensures every folder has `Folder.ent` (never overwrites existing).
- Writes per-folder `Folder.topology.json` and a root `ProjectTodos.ent.json`.
- Uses sandboxed HOME/cache (`.tmp_home/`, `.swift_module_cache/`) to avoid permission issues.

Script location: `entelechia-chat/Scripts/generateOntology.swift` (kept executable).

Generated artifacts and caches are ignored via `.gitignore`.

## Canonical project layout (post-package split)

- App (UI) target lives under `ChatUI/`  
  - UI views in `ChatUI/UI/`  
  - View models/adapters in `ChatUI/ViewModels/`  
  - App composition in `ChatUI/AppComposition/`  
  - UI-only helpers in `ChatUI/Support/`
- Engine package (pure domain + services) in `CoreEngine/`
- Adapter package (platform/persistence/Codex adapters) in `AppAdapters/`
- Operator tool target in `ChatUI/Tools/Operator/`
- Ontology generator SPM tool in `Tools/OntologyGenerator/`

Xcode uses the synchronized root group pointing at `ChatUI/`; there are no parallel shadow trees anymore.
