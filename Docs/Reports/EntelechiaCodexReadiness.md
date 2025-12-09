# Entelechia Codex Readiness Audit

## 1. Current State Summary
- Teleology composes a single assistant instance via `Teleology/AppEnvironment.swift:1-53`.
- Intelligence layer exposes value-only models and streaming state (see `Intelligence/Workspace/Faculties/WorkspaceViewModel.swift:48-424`).
- Accidental layer renders SwiftUI chat/navigator/inspector; Infrastructure hosts persistence and Codex clients.
- Codex transport (real + mock) is in place, yet several persistence/governance gaps block “Codex-ready” status.

## 2. Matched Components
- `Infrastructure/Persistence/FileStore.swift:16-89` handles atomic JSON IO under `~/Library/Application Support/Entelechia/Conversations`.
- `Infrastructure/Persistence/ConversationStore.swift:1-187` persists struct-based conversations and supports index migration.
- `Teleology/AppEnvironment.swift:1-53` injects exactly one assistant (Codex or mock).
- Streaming UI state flows from `WorkspaceViewModel.streamingMessages` down to `Accidents/ConversationUI/ChatView.swift:1-130`.
- Ontology artifacts (`Folder.ent`, `ProjectTopology.json`) remain project-local.

## 3. Partial Matches
- Conversation index lives outside the `Conversations` folder; `fatalError` occurs on corruption.
- ProjectStore writes a single `projects.json` under `EntelechiaOperator` instead of `recent.json`, `last_opened.json`, `project_settings.json`.
- Preferences persistence is missing; workspace selection state is mixed into ProjectStore.
- `.entelechia/context_preferences.json` does not exist, so file inclusion toggles are volatile.
- File persistence lacks os_log instrumentation; requirement #10 unmet.
- `CodexConfig` embeds Keychain access without an abstracted `KeychainService`.
- Multiple runtime `fatalError`s violate the “no fatal errors during valid operations” constraint.

## 4. Missing Components
- `.entelechia/context_preferences.json` per project plus a `ContextPreferencesStore`.
- Dedicated `PreferencesStore` for UI/global settings.
- `KeychainService` abstraction with logging for CODEX secrets.
- Split project persistence files under `~/Library/Application Support/Entelechia/Projects/`.
- Migration utilities moving existing `projects.json` and conversation `index.json` into their required locations.
- Logging utilities for all filesystem rewrites.
- README/docs covering Codex configuration, Keychain setup, `.entelechia` usage.
- Automated tests for new stores and migrations.

## 5. Gap Analysis Table

| Component | Issue (Formal Cause) | Effect (Final Cause Fails) | Required Teleological Fix |
| --- | --- | --- | --- |
| Conversation storage | `index.json` misplaced, `fatalError` on corruption | Durable persistence cannot be guaranteed | Move index into `Conversations/`, replace crashes with recoverable flows & logging |
| Project persistence | Single `projects.json` mixes concerns | Required per-file layout absent | Introduce `ProjectsDirectory` + split JSON files, migrate legacy data |
| Context preferences | `.entelechia` folder/store absent | File inclusion state lost | Create `.entelechia/context_preferences.json` and sync toggles |
| Preferences store | Nonexistent | UI/global settings lack persistence | Add dedicated `PreferencesStore` under `.entelechia/` |
| Keychain service | Embedded logic without logging | Secrets not testable/logged | Extract `KeychainService` with os_log |
| Logging | File writes silent | File rewrites untracked | Wrap FileStore/ProjectStore ops with logs |
| Fatal errors | Used for recoverable IO faults | Valid operations crash | Convert to thrown errors surfaced via UI |
| Documentation | No new persistence guidance | Devs can’t configure environment | Update README/scripts |

## 6. Transition Plan

### Safe Refactors
1. Introduce `KeychainService` protocol + implementation; inject into `CodexConfig`/`AppEnvironment`.
2. Refactor `FileStore` paths so `index.json` lives under `Conversations/`.
3. Replace `fatalError` with thrown errors + UI banners for all stores/workspace flows.
4. Add os_log instrumentation around every FileStore save/delete.

### New Components
5. Implement `ContextPreferencesStore` writing to `<ProjectRoot>/.entelechia/context_preferences.json`.
6. Add `PreferencesStore` for UI/project settings under `.entelechia/preferences.json`.
7. Create `ProjectsDirectory` struct exposing `recent.json`, `last_opened.json`, `project_settings.json`; update `ProjectStore`.

### Migration Steps
8. Migrate legacy `EntelechiaOperator/projects.json` into the new triplet with logging/backups.
9. Move conversation `index.json` into the `Conversations` folder.
10. On first launch, create `.entelechia/` folders and seed context preferences.

### Codex Configuration Steps
11. Document CLI steps for storing CODEX secrets via Keychain; add helper script/README section.
12. Surface configuration readiness banners inside the UI (Codex vs mock).

### Testing Steps
13. Unit-test `ContextPreferencesStore`, `KeychainService`, and all migration utilities.
14. Add integration tests for conversation/project persistence migrations.
15. Run `xcodebuild test -scheme "entelechia-chat"` and capture results.

### Verification Steps
16. Manually corrupt `index.json`; ensure the app rebuilds it without crashing.
17. Toggle context files and confirm `.entelechia/context_preferences.json` updates/respects relaunch.
18. Validate project files populate `~/Library/Application Support/Entelechia/Projects/`.
19. Confirm single assistant instance and optional Codex activation.

## 7. Final Readiness Verdict

- **Checklist**
  - [ ] Conversation index relocation + error handling
  - [ ] Projects split into required files
  - [ ] `.entelechia/context_preferences.json` implemented
  - [ ] Preferences/keychain services factored + logged
  - [ ] Fatal-error pathways removed
  - [ ] Documentation/scripts updated
  - [ ] Tests covering migrations/new stores

- **Verdict:** **Not Codex-ready**

- **Remaining Blockers**
  1. Context preferences not persisted under `.entelechia/`.
  2. Project persistence layout incorrect.
  3. Reliance on `fatalError` for recoverable conditions.
  4. Missing logging/observability for filesystem rewrites.

- **Developer Experience Outlook**
  Completing the plan delivers deterministic project/context storage, recoverable IO paths, explicit Codex configuration instructions, and improved diagnostics—streamlining local Codex testing and safeguarding ontology order.
