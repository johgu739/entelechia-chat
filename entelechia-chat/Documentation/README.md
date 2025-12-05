# Entelechia Chat

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

## Project Structure

```
├── Models/
│   ├── Message.swift
│   ├── LoadedFile.swift
│   ├── ModelResponse.swift
│   └── Conversation.swift
├── ViewModels/
│   ├── ChatViewModel.swift
│   └── FileViewModel.swift
├── Views/
│   ├── MainView.swift
│   ├── ChatView.swift
│   ├── ConversationsListView.swift
│   ├── FilesSidebarView.swift
│   ├── MessageBubbleView.swift
│   ├── MarkdownMessageView.swift
│   ├── CodeBlockView.swift
│   └── ChatInputView.swift
├── Services/
│   ├── ModelClient.swift
│   └── MarkdownRenderer.swift
└── EntelechiaChatApp.swift
```

## Setup

1. Open the project in Xcode
2. Build and run (⌘R)

## Keyboard Shortcuts

- **⌘↩**: Send message
- **⌘N**: New conversation

## Model Client Integration

The app uses a `ModelClient` protocol. Currently, a `StubModelClient` is provided for testing. To integrate with a real LLM:

1. Implement the `ModelClient` protocol
2. Replace `StubModelClient()` in `ChatViewModel` initialization
3. The protocol expects:
   - User message text
   - Array of context files (with content)
   - Returns a `ModelResponse` with content or error

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
