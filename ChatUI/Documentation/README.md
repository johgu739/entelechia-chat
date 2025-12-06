# Entelechia Chat UI

A premium macOS SwiftUI chat application with a clean, Apple-quality interface.

## Features

- **Three-Column Layout**: Conversations list (left), chat interface (center), and context files sidebar (right)
- **Premium Design**: Cleaner than ChatGPT, more elegant than Cursor's Codex sidebar
- **Markdown Rendering**: Full markdown support for AI responses with syntax highlighting
- **File Attachments**: Drag-and-drop or pick files to include as context
- **Code Blocks**: Beautiful code blocks with copy functionality
- **Smooth Animations**: Soft fade/slide animations for new messages

## Architecture

- **MVVM Structure**: Clean separation of Models, ViewModels, and Views
- **SwiftUI Only**: No Storyboards, minimal AppKit usage
- **Protocol-Based**: ModelClient protocol for easy LLM integration

## Project Structure (UI-only)

- `Teleology/`: app entry and composition
- `Intelligence/`: view models (UI-facing adapters over Engine protocols)
- `Accidents/`: SwiftUI views
- `Infrastructure/`: UI-only helpers (logging, rendering, security glue)
- Engine lives in `Engine/` (SPM); adapters in `UIConnections/` (SPM).

## Setup

1. Open the project in Xcode
2. Build and run (⌘R)

## Keyboard Shortcuts

- **⌘↩**: Send message
- **⌘N**: New conversation

## Model Client Integration

The app uses a `ModelClient` protocol. Currently, a `StubModelClient` is provided for testing. To integrate with a real LLM:

1. Implement the `ModelClient` protocol
2. Provide a `CodeAssistant` through `AppEnvironment` (defaults to `MockCodeAssistant` when no Codex config is present)
3. The protocol expects:
   - User message text
   - Array of context files (with content)
   - Returns a `ModelResponse` with content or error

## Persistence Layout & `.entelechia/` folders

The runtime now maintains deterministic folders for every project and for global state:

| Location | Purpose |
| --- | --- |
| `~/Library/Application Support/Entelechia/Conversations/` | One JSON file per conversation + `index.json` |
| `~/Library/Application Support/Entelechia/Projects/` | `recent.json`, `last_opened.json`, `project_settings.json` |
| `<ProjectRoot>/.entelechia/context_preferences.json` | File inclusion toggles & trim metadata |
| `<ProjectRoot>/.entelechia/preferences.json` | UI/inspector preferences specific to that project |

The `.entelechia` folder is created automatically the first time you open a project. You can inspect or edit the JSON by hand if needed:

```bash
cat /path/to/project/.entelechia/context_preferences.json | jq
```

Deleting these files is safe; the app will regenerate them with defaults on launch.

## Codex Configuration

Codex credentials are loaded through the configuration scaffolding. Pick **one** of the following:

1. **Secrets plist**  
   - Copy `ChatUI/Configuration/CodexSecrets.example.plist` to `CodexSecrets.plist`.  
   - Fill in `CODEX_API_KEY`, `CODEX_BASE_URL`, and (optionally) `CODEX_ORG`.  
   - Keep the file out of source control; `.gitignore` already excludes it.

2. **Environment variables**  
   ```bash
   export CODEX_API_KEY="sk-..."
   export CODEX_BASE_URL="https://api.openai.com/v1"
   export CODEX_ORG="your-org-id"   # optional
   ```

3. **Keychain (recommended)**  
   Store secrets once and keep them off disk:  
   ```bash
   security add-generic-password -a CODEX_API_KEY \
     -s chat.entelechia.codex \
     -w "sk-..." \
     -U

   security add-generic-password -a CODEX_BASE_URL \
     -s chat.entelechia.codex \
     -w "https://api.openai.com/v1" \
     -U
   ```
   Verify or delete entries with:
   ```bash
   security find-generic-password -s chat.entelechia.codex -a CODEX_API_KEY -w
   security delete-generic-password -s chat.entelechia.codex -a CODEX_API_KEY
   ```

When no credentials are present the app logs a warning and composes `MockCodeAssistant`, so you can develop safely without the live Codex API.

## Context Preferences & Budgeting

Context files are budgeted before every Codex call. Toggle inclusion per file from the inspector; the decisions persist inside `.entelechia/context_preferences.json`. A sample entry:

```json
{
  "files": {
    "Sources/App/WorkspaceViewModel.swift": {
      "isIncluded": true,
      "trimmedBytes": 16384,
      "reason": "Trimmed to 16 KB budget"
    }
  }
}
```

Deleting the file resets toggles to their defaults. When the project contains more than 220 KB of selected context, exclusions are logged via `Logger.persistence` and surfaced in the inspector UI.

## Codex Readiness Checklist

Before switching to the production Codex assistant ensure:

1. **Persistence OK** – conversations index rebuilds cleanly and `.entelechia/` exists in your project.
2. **Credentials OK** – `security find-generic-password -s chat.entelechia.codex -a CODEX_API_KEY -w` returns a key or your plist/env vars are set.
3. **UI Banner** – the workspace shell shows a Codex readiness banner if configuration fails; resolve it before relying on real completions.
4. **Tests** – run `xcodebuild test -scheme "entelechia-chat"` to validate migrations and the new stores.

Once all four pass, the teleology composes the Codex-backed assistant automatically; otherwise it remains in mock mode and logs the reason.

## Design Philosophy

- **Apple Notes typography**: Clean, readable text rendering
- **Stripe documentation spacing**: Generous whitespace and clear hierarchy
- **Cursor Codex codeblocks**: Beautiful syntax-highlighted code blocks
- **SF Pro font**: System font throughout for native feel
- **Soft neutral palette**: Subtle grays, no bright backgrounds

## Ontology utilities

Run the Thomistic ontology scan (generates topology JSONs and inserts TODO headers if missing):

```
make ontology
```

The target uses a sandboxed HOME/cache to avoid permissions issues:

- Outputs: `ProjectTopology.json`, `Topology.json`, and `Folder.topology.json` files.
- Temporary caches: `.tmp_home/`, `.swift_module_cache/` (ignored).
- Script lives at `Scripts/generateOntology.swift`; keep it executable (`chmod +x` if needed).
