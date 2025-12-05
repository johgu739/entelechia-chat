# Entelechia Thomistic Ontology Audit

This report applies Thomistic metaphysical ordering to the project. No code was changed; only analysis and proposed headers/structure.

## Phase 1 — Structural Audit (per file)

Category legend: Substance (S), Faculty (F), Instrumental Cause (I), Accident/UI (A), Power/Operation (P).

| Path | Category | Notes / Correct Home | Naming tweak? |
| --- | --- | --- | --- |
| EntelechiaChatApp.swift | S (teleological entry) | App telos; keep at top-level under Teleology | Keep |
| Services/Services.swift | A (accidental helper) | Should be dissolved; compose where used (no standalone registry) | Remove |
| Services/ModelClient.swift | I (infrastructure client) | Model API client; Infrastructure/AI | Keep |
| Services/MockCodeAssistant.swift | I | Test/dummy assistant; Infrastructure/AI/Mocks | Keep |
| Services/ConversationService.swift | F | Domain faculty for conversations; Domain/Conversations | Keep |
| Services/MarkdownRenderer.swift | I | Infra formatter; Infrastructure/Rendering | Keep |
| Services/FileContentService.swift | F | Domain faculty to collect files; Domain/Workspace | Keep |
| Services/WorkspaceFileSystemService.swift | F | Domain faculty for file tree; Domain/Workspace | Keep |
| Services/ProjectCoordinator.swift | F | Application coordination; Application/Project | Keep |
| Services/ProjectSession.swift | F | Runtime project session; Application/Project | Keep |
| Services/ProjectStore.swift | I | Persistence of project metadata; Infrastructure/Persistence | Keep |
| Views/AppTheme.swift | A | UI styling; Accidents/Theme | Keep |
| Views/RootView.swift | A | UI root switcher; Accidents/AppShell | Keep |
| Views/MainView.swift | A | UI workspace shell; Accidents/Workspace | Keep |
| Views/NoFileSelectedView.swift | A | UI placeholder; Accidents/Workspace | Keep |
| Views/ChatView.swift | A | UI conversation; Accidents/Conversation | Keep |
| Views/ChatInputView.swift | A | UI input; Accidents/Conversation | Keep |
| Views/MessageBubbleView.swift | A | UI message bubble; Accidents/Conversation | Keep |
| Views/MarkdownMessageView.swift | A | UI markdown; Accidents/Conversation | Keep |
| Views/CodeBlockView.swift | A | UI code block; Accidents/Conversation | Keep |
| Views/ContextInspector.swift | A | UI inspector; Accidents/Inspector | Keep |
| Views/FilesSidebarView.swift | A | UI sidebar; Accidents/Workspace | Keep |
| Views/OnboardingSelectProjectView.swift | A | UI onboarding; Accidents/Onboarding | Keep |
| Views/XcodeNavigator/XcodeNavigatorView.swift | A | UI navigator shell; Accidents/Navigator | Keep |
| Views/XcodeNavigator/XcodeNavigatorRepresentable.swift | A | UI AppKit bridge; Accidents/Navigator | Keep |
| Views/XcodeNavigator/VisualEffectView.swift | A | UI effect wrapper; Accidents/Navigator | Keep |
| Views/FileIconView.swift | A | UI icon; Accidents/Workspace | Keep |
| Persistence/FileStore.swift | I | Persistence helper; Infrastructure/Persistence | Keep |
| Persistence/ConversationStore.swift | I | Persistence store; Infrastructure/Persistence | Keep |
| Persistence/Models/Attachment.swift | S | Data model; Domain/Conversations | Keep |
| Models/Message.swift | S | Data model; Domain/Conversations | Keep |
| Models/Conversation.swift | S | Data model; Domain/Conversations | Keep |
| Models/ContentBlock.swift | S | Data model; Domain/Conversations | Keep |
| Models/ModelResponse.swift | S | Data model; Domain/Conversations | Keep |
| Models/LoadedFile.swift | S | Data model; Domain/Workspace | Keep |
| Models/FileNode.swift | S | Data model; Domain/Workspace | Keep |
| ViewModels/WorkspaceViewModel.swift | F | UI-facing faculty over workspace; Application/Workspace | Keep |
| ViewModels/FileViewModel.swift | F | UI-facing file; Application/Workspace | Keep |
| ViewModels/FileMetadataViewModel.swift | F | UI-facing metadata; Application/Workspace | Keep |
| ViewModels/ChatViewModel.swift | F | UI-facing chat; Application/Conversation | Keep |
| Assets.xcassets/... | A | UI assets; Accidents/Assets | Keep |
| README.md | A (accident/doc) | Docs; Documentation | Keep |
| EntelechiaOperator/... (all) | A/I | Separate operator tooling; place under Tools/Operator/... | Keep |

## Phase 2 — Proposed Thomistic Folder Hierarchy (participation chain explicit)

```
Teleology/
  EntelechiaChatApp.swift
  Intelligence/           (formal causes for domains; superior to application/UI)
    Conversations/
      Models/
        Conversation.swift
        Message.swift
        ContentBlock.swift
        ModelResponse.swift
        Attachment.swift
      Services/
        ConversationService.swift
      Faculties/
        ChatViewModel.swift
    Workspace/
      Models/
        FileNode.swift
        LoadedFile.swift
      Services/
        WorkspaceFileSystemService.swift
        FileContentService.swift
      Faculties/
        WorkspaceViewModel.swift
        FileViewModel.swift
        FileMetadataViewModel.swift
    Projects/
      Services/
        ProjectSession.swift
        ProjectCoordinator.swift
  Application/            (optional shell composition; participates in Intelligence)
    (empty or hosts only composition glue)
  Accidents/              (UI)
    Theme/AppTheme.swift
    Shell/
      RootView.swift
      MainView.swift
      NoFileSelectedView.swift
    ConversationUI/
      ChatView.swift
      ChatInputView.swift
      MessageBubbleView.swift
      MarkdownMessageView.swift
      CodeBlockView.swift
      ContextInspector.swift
    WorkspaceUI/
      FilesSidebarView.swift
      FileIconView.swift
      OnboardingSelectProjectView.swift
      XcodeNavigator/
        XcodeNavigatorView.swift
        XcodeNavigatorRepresentable.swift
        VisualEffectView.swift
  Infrastructure/         (instrumental causes)
    Persistence/
      FileStore.swift
      ConversationStore.swift
      ProjectStore.swift
    Rendering/MarkdownRenderer.swift
    AI/
      ModelClient.swift
      MockCodeAssistant.swift
    (Service registry dissolved; compose directly)
Documentation/
  README.md
Assets/
  Assets.xcassets/...
Tools/
  Operator/ (all EntelechiaOperator files)
```

## Phase 3 — Mapping Table (representative; all files mapped)

| Original Path | Proposed Path | Improved File Name? | Formal Cause | Final Cause | Reasoning |
| --- | --- | --- | --- | --- | --- |
| EntelechiaChatApp.swift | Teleology/EntelechiaChatApp.swift | Keep | App entry orchestration | Launch and compose entire system | Top-level telos orchestrator |
| Services/ConversationService.swift | Intelligence/Conversations/Services/ConversationService.swift | Keep | Conversation business rules | Conduct chat flows with persistence | Faculty over conversation acts |
| Services/WorkspaceFileSystemService.swift | Intelligence/Workspace/Services/WorkspaceFileSystemService.swift | Keep | Tree building logic | Provide file nodes for workspace | Faculty for file domain |
| Services/FileContentService.swift | Intelligence/Workspace/Services/FileContentService.swift | Keep | Collect file contents | Supply context files | Domain operation over files |
| Services/ProjectSession.swift | Intelligence/Projects/Services/ProjectSession.swift | Keep | Session state rules | Manage active project state | Faculty guiding project runtime |
| Services/ProjectCoordinator.swift | Intelligence/Projects/Services/ProjectCoordinator.swift | Keep | Coordination rules | Open/close projects | Faculty coordinating persistence/session |
| Services/ProjectStore.swift | Infrastructure/Persistence/ProjectStore.swift | Keep | JSON encode/decode | Persist project metadata | Instrument for storage |
| Services/ModelClient.swift | Infrastructure/AI/ModelClient.swift | Keep | Network/model client | Call model endpoint | Instrumental cause for AI |
| Services/MockCodeAssistant.swift | Infrastructure/AI/MockCodeAssistant.swift | Keep | Mock logic | Test conversations | Instrument for testing |
| Services/MarkdownRenderer.swift | Infrastructure/Rendering/MarkdownRenderer.swift | Keep | Render rules | Produce markdown NSAttributedString | Instrumental renderer |
| Services/Services.swift | Infrastructure/Composition/ServiceRegistry.swift | Yes | Registration map | Provide shared singletons | Composition helper |
| Views/AppTheme.swift | Accidents/Theme/AppTheme.swift | Keep | Style constants | Color/typography | UI accident styling |
| Views/RootView.swift | Accidents/Shell/RootView.swift | Keep | View switching rules | Route onboarding/workspace | UI shell |
| Views/MainView.swift | Accidents/Shell/MainView.swift | Keep | Layout rules | Arrange navigator/chat/inspector | UI composition |
| Views/NoFileSelectedView.swift | Accidents/Shell/NoFileSelectedView.swift | Keep | Empty-state view | Inform no selection | UI accident |
| Views/ChatView.swift | Accidents/ConversationUI/ChatView.swift | Keep | Chat UI | Display conversation | UI accident |
| Views/ChatInputView.swift | Accidents/ConversationUI/ChatInputView.swift | Keep | Input UI | Enter messages | UI accident |
| Views/MessageBubbleView.swift | Accidents/ConversationUI/MessageBubbleView.swift | Keep | Bubble layout | Render message bubble | UI accident |
| Views/MarkdownMessageView.swift | Accidents/ConversationUI/MarkdownMessageView.swift | Keep | Markdown rendering UI | Show markdown text | UI accident |
| Views/CodeBlockView.swift | Accidents/ConversationUI/CodeBlockView.swift | Keep | Code block UI | Show code sections | UI accident |
| Views/ContextInspector.swift | Accidents/ConversationUI/ContextInspector.swift | Keep | Inspector UI | Show file context metadata | UI accident |
| Views/FilesSidebarView.swift | Accidents/WorkspaceUI/FilesSidebarView.swift | Keep | Sidebar UI | Display file tree | UI accident |
| Views/OnboardingSelectProjectView.swift | Accidents/WorkspaceUI/OnboardingSelectProjectView.swift | Keep | Onboarding UI | Pick project | UI accident |
| Views/XcodeNavigator/XcodeNavigatorView.swift | Accidents/WorkspaceUI/XcodeNavigator/XcodeNavigatorView.swift | Keep | Navigator UI | Present outline | UI accident |
| Views/XcodeNavigator/XcodeNavigatorRepresentable.swift | Accidents/WorkspaceUI/XcodeNavigator/XcodeNavigatorRepresentable.swift | Keep | AppKit bridge rules | Host NSOutlineView | UI accident |
| Views/XcodeNavigator/VisualEffectView.swift | Accidents/WorkspaceUI/XcodeNavigator/VisualEffectView.swift | Keep | Effect wrapper | Background blur | UI accident |
| Views/FileIconView.swift | Accidents/WorkspaceUI/FileIconView.swift | Keep | Icon UI | Render file icons | UI accident |
| Persistence/FileStore.swift | Infrastructure/Persistence/FileStore.swift | Keep | File IO rules | Persist/load JSON | Instrumental |
| Persistence/ConversationStore.swift | Infrastructure/Persistence/ConversationStore.swift | Keep | Store rules | Persist conversations | Instrumental |
| Persistence/Models/Attachment.swift | Intelligence/Conversations/Models/Attachment.swift | Keep | Data schema | Represent attachment | Substance |
| Models/Conversation.swift | Intelligence/Conversations/Models/Conversation.swift | Keep | Data schema | Represent conversation | Substance |
| Models/Message.swift | Intelligence/Conversations/Models/Message.swift | Keep | Data schema | Represent message | Substance |
| Models/ContentBlock.swift | Intelligence/Conversations/Models/ContentBlock.swift | Keep | Data schema | Represent content chunk | Substance |
| Models/ModelResponse.swift | Intelligence/Conversations/Models/ModelResponse.swift | Keep | Data schema | Represent model reply | Substance |
| Models/FileNode.swift | Intelligence/Workspace/Models/FileNode.swift | Keep | Data schema | Represent file tree node | Substance |
| Models/LoadedFile.swift | Intelligence/Workspace/Models/LoadedFile.swift | Keep | Data schema | Represent collected file | Substance |
| ViewModels/WorkspaceViewModel.swift | Intelligence/Workspace/Faculties/WorkspaceViewModel.swift | Keep | Workspace mediation rules | Drive workspace selection/tree | Faculty (participates in workspace form) |
| ViewModels/FileViewModel.swift | Intelligence/Workspace/Faculties/FileViewModel.swift | Keep | File mediation rules | Present file info | Faculty |
| ViewModels/FileMetadataViewModel.swift | Intelligence/Workspace/Faculties/FileMetadataViewModel.swift | Keep | Metadata rules | Present metadata | Faculty |
| ViewModels/ChatViewModel.swift | Intelligence/Conversations/Faculties/ChatViewModel.swift | Keep | Conversation mediation rules | Drive chat UI state | Faculty |
| README.md | Documentation/README.md | Keep | Doc | Guide | Accident/doc |
| Assets.xcassets/... | Assets/... | Keep | Asset data | UI visuals | Accident |
| EntelechiaOperator/... | Tools/Operator/... | Keep | Operator app | Dev tool | Separate tool chain |

(All remaining asset JSON files follow same mapping into Assets.)

## Phase 4 — Proposed Metaphysical Headers (all Swift files, with Genus/Differentia/Causality Type)

### EntelechiaChatApp.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        App telos orchestrator
// Form:             Composition of environment objects and scene setup
// Matter:           App state objects, stores, windows
// Powers (Acts):    Launch, inject dependencies, present root scene
// Final Cause:      To bring the application into act and order its parts toward chat work
// Relations:        Participates in teleology; governs lower faculties (stores, coordinators, UI)
// ======================================================
```

### Services/Services.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Genus:           Composition helper (registry)
// Differentia:     Provides shared assistant/client instances statically
// Causality Type:   Accidental/Instrumental
// Substance:        Service registry (composition helper)
// Form:             Static references to shared assistants/clients
// Matter:           Singleton instances (assistant, model client)
// Powers (Acts):    Provide shared service instances
// Final Cause:      To compose dependent parts without scattering creation logic
// Relations:        Serves higher teleology by supplying instrumental causes (clients)
// ======================================================
```

### Services/ModelClient.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        AI model client (instrumental cause)
// Form:             Networking/model invocation logic
// Matter:           Requests/responses to external model
// Powers (Acts):    Send prompts, receive completions
// Final Cause:      To supply model outputs for conversations
// Relations:        Serves conversation faculty; depends on infrastructure
// ======================================================
```

### Services/MockCodeAssistant.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Mock assistant (instrumental test double)
// Form:             Stubbed responses
// Matter:           Hardcoded messages
// Powers (Acts):    Return predictable replies
// Final Cause:      To enable testing without real model calls
// Relations:        Substitutes for model client; serves conversation workflows
// ======================================================
```

### Services/ConversationService.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Conversation faculty
// Form:             Rules for sending messages, streaming responses, persistence hookup
// Matter:           Conversation aggregates, messages, context files
// Powers (Acts):    Validate input, stream model output, append/persist messages
// Final Cause:      To conduct meaningful dialogues tied to files
// Relations:        Participates in conversation domain; governs persistence and model calls
// ======================================================
```

### Services/MarkdownRenderer.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Markdown rendering instrument
// Form:             Conversion rules to attributed text
// Matter:           Markdown strings, attributed output
// Powers (Acts):    Render markdown safely
// Final Cause:      To present rich text for messages
// Relations:        Serves UI accidents; depends on formatting libs
// ======================================================
```

### Services/FileContentService.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Workspace content faculty
// Form:             Recursive file collection and inclusion rules
// Matter:           File nodes, loaded files, context flags
// Powers (Acts):    Traverse tree, read contents, filter inclusion
// Final Cause:      To supply contextual files for conversations
// Relations:        Serves conversation faculty; depends on file models
// ======================================================
```

### Services/WorkspaceFileSystemService.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        File tree faculty
// Form:             Tree construction and lookup rules
// Matter:           URLs, FileNode graph
// Powers (Acts):    Build tree, find nodes, create nodes
// Final Cause:      To represent workspace structure intelligibly
// Relations:        Serves workspace VM; depends on FileNode
// ======================================================
```

### Services/ProjectCoordinator.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Project coordination faculty
// Form:             Rules for opening/closing projects, persisting recents
// Matter:           Project paths, bookmarks, store updates
// Powers (Acts):    Validate, bookmark, update store, open sessions
// Final Cause:      To manage lifecycle of projects coherently
// Relations:        Governs ProjectSession; depends on ProjectStore
// ======================================================
```

### Services/ProjectSession.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Project runtime faculty
// Form:             State for active project, name, reload
// Matter:           Active URL, project name
// Powers (Acts):    Open/close project, reload files
// Final Cause:      To hold current project context for the app
// Relations:        Serves workspace UI; depends on file system service
// ======================================================
```

### Services/ProjectStore.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Project metadata store (instrumental cause)
// Form:             JSON encode/decode, recents management
// Matter:           StoredProject records, JSON file
// Powers (Acts):    Load/save recents, last opened, names
// Final Cause:      To persist project history and names
// Relations:        Serves coordinator/session; depends on FileManager
// ======================================================
```

### Views/AppTheme.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        UI accident palette
// Form:             Color and style definitions
// Matter:           Color values, gradients
// Powers (Acts):    Provide consistent theming
// Final Cause:      To beautify and unify UI appearance
// Relations:        Serves all UI views
// ======================================================
```

### Views/RootView.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        UI shell switcher
// Form:             Conditional routing onboarding vs workspace
// Matter:           Environment objects, project session state
// Powers (Acts):    Present appropriate root view
// Final Cause:      To direct the user to correct UI state
// Relations:        Participates in UI shell; depends on session/store
// ======================================================
```

### Views/MainView.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Workspace layout view
// Form:             Split view composition of navigator/chat/inspector
// Matter:           Workspace VM, session, conversation store
// Powers (Acts):    Arrange columns, propagate selections
// Final Cause:      To provide primary working surface
// Relations:        Serves UI; depends on WorkspaceViewModel
// ======================================================
```

### Views/NoFileSelectedView.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Empty-state view
// Form:             Static UI copy
// Matter:           Text, layout
// Powers (Acts):    Inform user nothing is selected
// Final Cause:      To gracefully handle idle state
// Relations:        Serves workspace UI
// ======================================================
```

### Views/ChatView.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Conversation UI surface
// Form:             Composition of messages and input
// Matter:           Conversation model, chat VM
// Powers (Acts):    Display messages, send interactions
// Final Cause:      To let user converse within file context
// Relations:        Serves conversation faculty; depends on VM
// ======================================================
```

### Views/ChatInputView.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Input accident
// Form:             TextField, send button handling
// Matter:           User text, send actions
// Powers (Acts):    Capture and dispatch user messages
// Final Cause:      To initiate conversation acts
// Relations:        Serves ChatView; depends on VM
// ======================================================
```

### Views/MessageBubbleView.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Message bubble UI
// Form:             Bubble layout and styling
// Matter:           Message content, role styling
// Powers (Acts):    Render single message appropriately
// Final Cause:      To visually differentiate messages
// Relations:        Serves ChatView
// ======================================================
```

### Views/MarkdownMessageView.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Markdown message UI
// Form:             Markdown rendering and layout
// Matter:           Message text, attributed markdown
// Powers (Acts):    Render markdown safely
// Final Cause:      To present rich message text
// Relations:        Serves ChatView
// ======================================================
```

### Views/CodeBlockView.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Code block UI
// Form:             Monospaced styling, copy affordance
// Matter:           Code strings
// Powers (Acts):    Render code segments
// Final Cause:      To display code outputs clearly
// Relations:        Serves MarkdownMessageView/ChatView
// ======================================================
```

### Views/ContextInspector.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Context inspector UI
// Form:             Metadata display rules
// Matter:           FileNode metadata, counts
// Powers (Acts):    Show context info for selection
// Final Cause:      To keep user aware of file context
// Relations:        Serves workspace UI; depends on WorkspaceViewModel
// ======================================================
```

### Views/FilesSidebarView.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Sidebar UI
// Form:             Layout of file list and controls
// Matter:           File nodes, selection bindings
// Powers (Acts):    Present tree, handle selection
// Final Cause:      To navigate project files
// Relations:        Serves workspace UI
// ======================================================
```

### Views/OnboardingSelectProjectView.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Onboarding UI
// Form:             Folder picker and naming flow
// Matter:           Project URL, name input
// Powers (Acts):    Collect project selection, open recent
// Final Cause:      To admit user into a valid project workspace
// Relations:        Serves project coordinator/session
// ======================================================
```

### Views/XcodeNavigator/XcodeNavigatorView.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Navigator container UI
// Form:             Stack of mode bar and outline bridge
// Matter:           Workspace VM state
// Powers (Acts):    Present navigator modes and outline view
// Final Cause:      To mirror Xcode-like navigation
// Relations:        Serves workspace UI; depends on representable
// ======================================================
```

### Views/XcodeNavigator/XcodeNavigatorRepresentable.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        AppKit outline bridge
// Form:             NSOutlineView data source/delegate wiring
// Matter:           FileNode tree, selection/expansion sets
// Powers (Acts):    Populate rows, sync selection, apply diffs
// Final Cause:      To render the file tree via AppKit within SwiftUI
// Relations:        Serves workspace UI; depends on WorkspaceViewModel and FileNode
// ======================================================
```

### Views/XcodeNavigator/VisualEffectView.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Visual effect wrapper
// Form:             NSVisualEffectView bridge
// Matter:           Material/blending params
// Powers (Acts):    Provide blurred backgrounds
// Final Cause:      To supply macOS visual style in SwiftUI
// Relations:        Serves UI containers
// ======================================================
```

### Views/FileIconView.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        File icon UI
// Form:             Icon selection by file type
// Matter:           FileNode/URL extensions
// Powers (Acts):    Render appropriate file symbol
// Final Cause:      To visually cue file types in lists
// Relations:        Serves navigator/sidebar UI
// ======================================================
```

### Persistence/FileStore.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        File persistence instrument
// Form:             Atomic read/write helpers
// Matter:           JSON data on disk
// Powers (Acts):    Ensure directories, load/save/delete files
// Final Cause:      To store domain records reliably
// Relations:        Serves ConversationStore/ProjectStore
// ======================================================
```

### Persistence/ConversationStore.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Conversation persistence instrument
// Form:             Index + file read/write logic
// Matter:           Conversations, index JSON
// Powers (Acts):    Load all, import orphans, save, delete
// Final Cause:      To durably persist conversations
// Relations:        Serves ConversationService/UI
// ======================================================
```

### Persistence/Models/Attachment.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Attachment model
// Form:             Codable fields describing an attachment
// Matter:           Attachment metadata
// Powers (Acts):    Represent attachment data
// Final Cause:      To carry attachment info within messages
// Relations:        Participates in conversations; used by stores/services
// ======================================================
```

### Models/Conversation.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Conversation aggregate
// Form:             Messages + metadata + context paths
// Matter:           Message list, title, timestamps, paths
// Powers (Acts):    Encapsulate dialogue state
// Final Cause:      To represent and persist a dialogue tied to files
// Relations:        Used by services/stores/UI
// ======================================================
```

### Models/Message.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Message entity
// Form:             Role + text/content blocks
// Matter:           Text, role, content blocks
// Powers (Acts):    Represent a single utterance
// Final Cause:      To carry user/assistant communication
// Relations:        Part of Conversation; used by services/UI
// ======================================================
```

### Models/ContentBlock.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Content block value
// Form:             Type + content
// Matter:           Block payload (text/code/etc.)
// Powers (Acts):    Represent structured parts of messages
// Final Cause:      To structure message content
// Relations:        Part of Message; used in rendering
// ======================================================
```

### Models/ModelResponse.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Model response envelope
// Form:             Output payload fields
// Matter:           Model output data
// Powers (Acts):    Convey model-generated results
// Final Cause:      To capture assistant outputs
// Relations:        Used by ConversationService/UI
// ======================================================
```

### Models/FileNode.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        File tree node
// Form:             URL + children + directory flags
// Matter:           Paths, icons, children arrays
// Powers (Acts):    Represent and load directory structures
// Final Cause:      To model the workspace file hierarchy
// Relations:        Used by workspace services/viewmodels/UI
// ======================================================
```

### Models/LoadedFile.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Loaded file value
// Form:             Path + content + inclusion flag
// Matter:           File text data, URL
// Powers (Acts):    Hold file content for context
// Final Cause:      To pass file data into conversations
// Relations:        Used by FileContentService/ConversationService
// ======================================================
```

### ViewModels/WorkspaceViewModel.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Workspace UI faculty
// Form:             State for selection, root, expansion, conversations
// Matter:           URLs, FileNode tree, selection sets
// Powers (Acts):    Load tree, manage selection, map conversations
// Final Cause:      To mediate between domain services and UI
// Relations:        Participates in application layer; depends on services/stores
// ======================================================
```

### ViewModels/FileViewModel.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        File UI faculty
// Form:             File-specific state/logic
// Matter:           File metadata/contents bindings
// Powers (Acts):    Provide file info to UI
// Final Cause:      To render a file view coherently
// Relations:        Serves UI; depends on file models
// ======================================================
```

### ViewModels/FileMetadataViewModel.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        File metadata UI faculty
// Form:             Metadata derivation rules
// Matter:           File properties
// Powers (Acts):    Present metadata to inspector
// Final Cause:      To inform user about file attributes
// Relations:        Serves ContextInspector
// ======================================================
```

### ViewModels/ChatViewModel.swift
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Chat UI faculty
// Form:             Observable chat state
// Matter:           Messages, loading flags
// Powers (Acts):    Bind messages to UI, send via service
// Final Cause:      To drive chat UI interactions
// Relations:        Serves ChatView; depends on ConversationService/Store
// ======================================================
```

### Assets.xcassets/Contents.json (and sub JSON)
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Asset catalog manifest
// Form:             Describes image/color assets
// Matter:           Asset metadata entries
// Powers (Acts):    Register assets for UI use
// Final Cause:      To supply visual resources
// Relations:        Serves UI accidents
// ======================================================
```

### README.md
```swift
// ======================================================
// ENTELECHIA METAPHYSICAL HEADER
// Substance:        Project documentation (accident)
// Form:             Expository text
// Matter:           Instructions, descriptions
// Powers (Acts):    Inform contributors
// Final Cause:      To guide understanding and setup
// Relations:        Serves human readers; no code dependency
// ======================================================
```

### EntelechiaOperator/... (apply same template per file adjusting substance/form/matter/powers/final cause to their operator roles; kept conceptually under Tools/Operator)

## Phase 5 — Final Coherent Ontology

- **Hierarchy**: as proposed in Phase 2.
- **Placement**: All files mapped accordingly (table above).
- **Naming**: Only suggested rename is `Services.swift -> ServiceRegistry.swift`; others can keep.
- **Metaphysical Headers**: Provided for all Swift files (apply to Operator files analogously).

This structure separates teleology, domain intelligence (faculties), application view-model layer, UI accidents, and instrumental infrastructure, honoring participation and non-mixing of genera.***
