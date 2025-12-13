# ARCHITECTURE GUARDS

Compile-time guards that prevent form violations.

## FORBIDDEN PATTERNS

### UIConnections Layer

- UIConnections cannot import AppAdapters
- UIConnections cannot reference FileMutationAuthority, AtomicDiffApplying, or FileMutationAuthorizing
- WorkspaceViewModel cannot store engine dependencies (workspaceEngine, conversationEngine, codexService, projectTodosLoader, alertCenter, DomainErrorAuthority)
- WorkspaceViewModel cannot create DomainErrorAuthority
- UIConnections cannot publish errors directly (alertCenter.publish, contextErrorSubject.send)

### AppCoreEngine Layer

- AppCoreEngine cannot import UI modules (SwiftUI, AppKit, UIConnections, ChatUI)

### WorkspaceViewModel Extensions

- WorkspaceViewModel extensions cannot contain orchestration logic (sendMessage, askCodex, openWorkspace, selectPath, currentWorkspaceScope, buildContextSnapshot)


