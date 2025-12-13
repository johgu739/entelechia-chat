# UIContracts Discovery Inventory

## A) Candidate ViewState Shapes

### 1. WorkspaceViewState
- **File**: `UIConnections/Sources/UIConnections/WorkspaceViewState.swift`
- **Fields**: 
  - `rootPath: String?`
  - `selectedDescriptorID: FileID?` → **MIRROR**: `UUID?`
  - `selectedPath: String?`
  - `projection: WorkspaceTreeProjection?` → **MIRROR**: `UIWorkspaceTree?`
  - `contextInclusions: [FileID: ContextInclusionState]` → **MIRROR**: `[UUID: UIContextInclusionState]`
  - `watcherError: String?`
- **Mutability**: Immutable (all `let`)
- **Action**: Extract to `UIContracts/Workspace/WorkspaceViewState.swift` using mirrored types

### 2. ConversationViewState
- **File**: `UIConnections/Sources/UIConnections/ConversationViewState.swift`
- **Fields**:
  - `id: UUID`
  - `messages: [Message]` → **MIRROR**: `[UIMessage]`
  - `streamingText: String`
  - `lastContext: ContextBuildResult?` → **MIRROR**: `UIContextBuildResult?`
- **Mutability**: Immutable (all `let`)
- **Action**: Extract to `UIContracts/Chat/ConversationViewState.swift` using mirrored types

### 3. ContextSnapshot
- **File**: `UIConnections/Sources/UIConnections/Codex/ContextSnapshot.swift`
- **Fields**:
  - `scope: ContextScopeChoice`
  - `snapshotHash: String?`
  - `segments: [ContextSegmentDescriptor]`
  - `includedFiles: [ContextFileDescriptor]`
  - `truncatedFiles: [ContextFileDescriptor]`
  - `excludedFiles: [ContextFileDescriptor]`
  - `totalTokens: Int`
  - `totalBytes: Int`
- **Mutability**: Immutable (all `let`)
- **Action**: Extract as-is to `UIContracts/Context/ContextSnapshot.swift`

### 4. ContextSegmentDescriptor
- **File**: `UIConnections/Sources/UIConnections/Codex/ContextSnapshot.swift`
- **Fields**:
  - `id: UUID`
  - `totalTokens: Int`
  - `totalBytes: Int`
  - `files: [ContextFileDescriptor]`
- **Mutability**: Immutable (all `let`)
- **Action**: Extract as-is to `UIContracts/Context/ContextSegmentDescriptor.swift`

### 5. ContextFileDescriptor
- **File**: `UIConnections/Sources/UIConnections/Codex/ContextSnapshot.swift`
- **Fields**:
  - `id: UUID`
  - `path: String`
  - `language: String?`
  - `size: Int`
  - `hash: String`
  - `isIncluded: Bool`
  - `isTruncated: Bool`
- **Mutability**: Immutable (all `let`)
- **Action**: Extract as-is to `UIContracts/Context/ContextFileDescriptor.swift`

## B) Domain Types to Mirror (NOT Import)

### 1. Conversation → UIConversation
- **Source**: `AppCoreEngine/Sources/CoreEngine/Domain/Conversations/Conversation.swift`
- **Fields to mirror**:
  - `id: UUID`
  - `title: String`
  - `createdAt: Date`
  - `updatedAt: Date`
  - `messages: [UIMessage]` (mirror of Message)
  - `contextFilePaths: [String]`
  - `contextDescriptorIDs: [UUID]?` (mirror of FileID)
- **Strip**: `summaryTitle`, `contextURL` (computed properties), Codable conformance
- **Action**: Create `UIContracts/Chat/UIConversation.swift`

### 2. Message → UIMessage
- **Source**: `AppCoreEngine/Sources/CoreEngine/Domain/Conversations/Message.swift`
- **Fields to mirror**:
  - `id: UUID`
  - `role: UIMessageRole` (mirror of MessageRole)
  - `text: String`
  - `createdAt: Date`
  - `attachments: [UIAttachment]` (mirror of Attachment)
- **Strip**: Codable conformance
- **Action**: Create `UIContracts/Chat/UIMessage.swift`

### 3. MessageRole → UIMessageRole
- **Source**: `AppCoreEngine/Sources/CoreEngine/Domain/Conversations/Message.swift`
- **Cases**: `user`, `assistant`, `system`
- **Action**: Create `UIContracts/Chat/UIMessageRole.swift`

### 4. Attachment → UIAttachment
- **Source**: `AppCoreEngine/Sources/CoreEngine/Domain/Conversations/Attachment.swift`
- **Cases**: `file(path: String)`, `code(language: String, content: String)`
- **Strip**: Codable conformance
- **Action**: Create `UIContracts/Chat/UIAttachment.swift`

### 5. ContextBuildResult → UIContextBuildResult
- **Source**: `AppCoreEngine/Sources/CoreEngine/Conversations/ContextBuilder.swift`
- **Fields to mirror**:
  - `attachments: [UILoadedFile]` (simplified mirror)
  - `truncatedFiles: [UILoadedFile]`
  - `excludedFiles: [UIContextExclusion]` (simplified mirror)
  - `totalBytes: Int`
  - `totalTokens: Int`
  - `encodedSegments: [UIContextSegment]` (simplified mirror)
- **Strip**: `budget`, `attachmentCount` (domain concerns)
- **Action**: Create `UIContracts/Context/UIContextBuildResult.swift`

### 6. WorkspaceTreeProjection → UIWorkspaceTree
- **Source**: `AppCoreEngine/Sources/CoreEngine/Workspace/WorkspaceTreeProjection.swift`
- **Fields to mirror**:
  - `id: UUID` (mirror of FileID)
  - `name: String`
  - `path: String`
  - `isDirectory: Bool`
  - `children: [UIWorkspaceTree]`
- **Action**: Create `UIContracts/Context/UIWorkspaceTree.swift`

### 7. ProjectTodos → UIProjectTodos
- **Source**: `AppCoreEngine/Sources/CoreEngine/Domain/Projects/ProjectTodos.swift`
- **Fields to mirror**:
  - `generatedAt: String?`
  - `missingHeaders: [String]`
  - `missingFolderTelos: [String]`
  - `filesWithIncompleteHeaders: [String]`
  - `foldersWithIncompleteTelos: [String]`
  - `allTodos: [String]`
- **Strip**: `totalCount`, `flatTodos` (computed properties), Decodable conformance
- **Action**: Create `UIContracts/Shared/UIProjectTodos.swift`

### 8. FileID → UUID
- **Source**: `AppCoreEngine/Sources/CoreEngine/Domain/Workspace/FileDescriptor.swift`
- **Action**: Use `UUID` directly in UIContracts (no mirror needed)

### 9. ContextInclusionState → UIContextInclusionState
- **Source**: `AppCoreEngine/Sources/CoreEngine/Domain/Workspace/WorkspacePreferences.swift`
- **Cases**: `included`, `excluded`, `neutral`
- **Action**: Create `UIContracts/Shared/UIContextInclusionState.swift`

### 10. LoadedFile → UILoadedFile (simplified)
- **Source**: `AppCoreEngine/Sources/CoreEngine/Domain/Workspace/LoadedFile.swift`
- **Fields to mirror** (simplified for UI):
  - `path: String`
  - `language: String?`
  - `size: Int`
  - `hash: String?`
- **Strip**: All domain-specific fields
- **Action**: Create `UIContracts/Context/UILoadedFile.swift` if needed for UIContextBuildResult

### 11. ContextExclusion → UIContextExclusion (simplified)
- **Source**: `AppCoreEngine/Sources/CoreEngine/Conversations/ContextBuilder.swift`
- **Fields to mirror** (simplified):
  - `file: UILoadedFile`
  - `reason: String` (simplified from enum)
- **Action**: Create `UIContracts/Context/UIContextExclusion.swift` if needed

### 12. ContextSegment → UIContextSegment (simplified)
- **Source**: `AppCoreEngine/Sources/CoreEngine/Conversations/WorkspaceContextEncoding.swift`
- **Fields to mirror** (simplified):
  - `files: [UILoadedFile]`
  - `totalTokens: Int`
  - `totalBytes: Int`
- **Action**: Create `UIContracts/Context/UIContextSegment.swift` if needed

## C) Intent Shapes

### WorkspaceIntent
From `WorkspaceViewModel` public methods:
- `setRootDirectory(URL)` → `openWorkspace(URL)`
- `setSelectedURL(URL?)` → `selectPath(URL?)`
- `setSelectedDescriptorID(FileID?)` → `selectDescriptor(UUID?)`
- `toggleExpanded(FileID)` → `toggleExpanded(UUID)`
- `setContextInclusion(Bool, URL)` → `setContextInclusion(Bool, URL)`

### ChatIntent
From `WorkspaceViewModel` and `ChatViewModel` public methods:
- `sendMessage(String, Conversation)` → `sendMessage(String, UUID)`
- `askCodex(String, Conversation)` → `askCodex(String, UUID)`
- `setContextScope(ContextScopeChoice)` → `setContextScope(ContextScopeChoice)`
- `setModelChoice(ModelChoice)` → `setModelChoice(ModelChoice)`

## D) Enums and Value Types to Extract

### From UIConnections:
1. **NavigatorMode** - `UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewModel.swift`
   - Extract as-is to `UIContracts/Workspace/NavigatorMode.swift`

2. **ContextScopeChoice** - `UIConnections/Sources/UIConnections/Workspaces/ContextScopeChoice.swift`
   - Extract to `UIContracts/Shared/ContextScopeChoice.swift`
   - Strip: `displayName` computed property

3. **ModelChoice** - `UIConnections/Sources/UIConnections/Workspaces/ContextScopeChoice.swift`
   - Extract to `UIContracts/Shared/ModelChoice.swift`
   - Strip: `displayName` computed property

4. **WorkspaceScope** - `UIConnections/Sources/UIConnections/CodexContracts.swift`
   - Extract to `UIContracts/Shared/WorkspaceScope.swift`
   - Change: Use `UUID` instead of `FileID` for descriptor case

5. **RecentProject** - `UIConnections/Sources/UIConnections/Projects/ProjectCoordinator.swift`
   - Extract to `UIContracts/Workspace/RecentProject.swift`
   - Note: May need to mirror `ProjectRepresentation` if it contains domain types

### From ChatUI:
6. **InspectorTab** - `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspector.swift`
   - Extract to `UIContracts/Chat/InspectorTab.swift`
   - Strip: `title` computed property

## E) Mapping Responsibility

UIConnections will provide mapping functions:
- `AppCoreEngine.Conversation` → `UIContracts.UIConversation`
- `AppCoreEngine.Message` → `UIContracts.UIMessage`
- `AppCoreEngine.MessageRole` → `UIContracts.UIMessageRole`
- `AppCoreEngine.Attachment` → `UIContracts.UIAttachment`
- `AppCoreEngine.ContextBuildResult` → `UIContracts.UIContextBuildResult`
- `AppCoreEngine.WorkspaceTreeProjection` → `UIContracts.UIWorkspaceTree`
- `AppCoreEngine.ProjectTodos` → `UIContracts.UIProjectTodos`
- `AppCoreEngine.FileID` → `UUID`
- `AppCoreEngine.ContextInclusionState` → `UIContracts.UIContextInclusionState`
- `AppCoreEngine.LoadedFile` → `UIContracts.UILoadedFile` (if needed)
- `AppCoreEngine.ContextExclusion` → `UIContracts.UIContextExclusion` (if needed)
- `AppCoreEngine.ContextSegment` → `UIContracts.UIContextSegment` (if needed)


