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
