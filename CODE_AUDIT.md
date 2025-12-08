# Kodgranskning - Entelechia Chat

**Datum:** 2024  
**Granskare:** AI Code Auditor  
**Metodologi:** Thomistisk metafysik + Stripe/Apple kvalitetsstandarder

---

## EXECUTIVE SUMMARY

Kodbasen visar tecken på snabb utveckling med flera hacklösningar och onödig komplexitet. Det finns två parallella applikationsstrukturer (`EntelechiaChatApp` och `EntelechiaOperatorApp`) som delar kod men inte är konsekvent integrerade. Många ViewModels har överlappande ansvar, och det finns betydande duplicering av markdown-parsing och filhantering.

**Kritiska problem:**
- Dubbel state management (WorkspaceViewModel + NavigatorViewModel)
- Duplicerad markdown-parsing kod
- Unsafe file I/O utan proper error handling
- Task-baserad async/await används inkonsekvent
- Många force unwraps och try? som döljer errors

---

## 1. ARKITEKTURPROBLEM

### 1.1 Dubbel Applikationsstruktur (KRITISKT)

**Problem:** Två separata `@main` applikationer i samma projekt:
- `EntelechiaChatApp.swift` - Chat-baserad UI
- `EntelechiaOperatorApp.swift` - Operator-baserad UI

**Location:**
- `entelechia-chat/EntelechiaChatApp.swift`
- `entelechia-chat/EntelechiaOperator/Sources/App/EntelechiaOperatorApp.swift`

**Issues:**
- Kommentar i `EntelechiaOperatorApp.swift` säger "remove @main from EntelechiaChatApp.swift" - detta är en hacklösning
- Två separata state management system som inte kommunicerar
- Delad kod men ingen tydlig separation of concerns

**Rekommendation:**
- Välj EN applikationsstruktur
- Om båda behövs, gör dem till olika targets eller använd en unified app med feature flags
- Refaktorera till en gemensam `AppState` eller `RootViewModel`

---

### 1.2 State Management Chaos

**Problem:** Flera ViewModels med överlappande ansvar och ingen tydlig hierarki:

**ViewModels:**
- `WorkspaceViewModel` - hanterar root directory, conversations, selected node
- `NavigatorViewModel` - hanterar project root, selected URL, expanded URLs
- `ChatViewModel` - hanterar conversations (men WorkspaceViewModel också gör detta!)
- `FileViewModel` - hanterar loaded files
- `FileMetadataViewModel` - hanterar metadata caching

**Location:**
- `ViewModels/WorkspaceViewModel.swift:7-143`
- `ViewModels/NavigatorViewModel.swift:24-66`
- `ViewModels/ChatViewModel.swift:6-99`

**Issues:**
1. **WorkspaceViewModel vs NavigatorViewModel:**
   - Båda hanterar root directory
   - Båda hanterar selected URL/node
   - Synkronisering sker via `onChange` modifiers (farlig!)
   - `XcodeNavigatorView.swift:47-53` synkar manuellt mellan dem

2. **WorkspaceViewModel vs ChatViewModel:**
   - Historically both owned `conversations`; now conversation access is async via engine actors and cached in `WorkspaceViewModel`.
   - `ChatViewModel` still has its own conversation management; evaluate consolidating on the engine-backed cache.

**Rekommendation:**
- Skapa en `AppState` eller `RootViewModel` som äger all global state
- ViewModels ska vara leaf-nodes som observerar state, inte äger den
- Använd `@Published` properties i en central state manager
- Eliminera synkronisering via `onChange` - använd en source of truth

---

### 1.3 Duplicerad Markdown Parsing (KRITISKT)

**Problem:** Samma markdown-parsing kod finns i MINST 3 olika filer:

**Locations:**
1. `Services/MarkdownRenderer.swift:6-113` - Static functions
2. `Views/MarkdownMessageView.swift:18` - Använder MarkdownRenderer
3. `EntelechiaOperator/Sources/Editor/MarkdownView.swift:83-189` - DUPLICERAD kod!

**Issues:**
- `MarkdownView.swift` har EXAKT samma parsing-logik som `MarkdownRenderer.swift`
- `parseInlineCode`, `parseBold`, `parseItalic`, `parseHeaders`, `parseLinks` - alla duplicerade
- Om en bugg fixas måste den fixas på två ställen
- Ingen single source of truth

**Rekommendation:**
- Ta bort all duplicerad kod från `MarkdownView.swift`
- Använd `MarkdownRenderer` överallt
- Om Operator-modulen inte kan importera Services-modulen, skapa en shared module

---

## 2. HACKLÖSNINGAR

### 2.1 Async conversation access (resolved)

**Status:** `WorkspaceViewModel.conversation(for:)` is now async via the engine actor; no Task hacks or race-prone dictionary writes remain. Callers await the engine and cache results locally for UI access.

---

### 2.2 DispatchQueue.main.async för att undvika Publishing Warnings

**Problem:** Flera ställen använder `DispatchQueue.main.async` för att undvika warnings:

**Locations:**
- `XcodeNavigatorRepresentable.swift:285-300` - Selection change
- `XcodeNavigatorRepresentable.swift:307-309` - Expand item
- `XcodeNavigatorRepresentable.swift:317-319` - Collapse item
- `ChatInputView.swift:85-87` - Focus state

**Issues:**
- Döljer verkliga problem med thread safety
- Kan skapa race conditions
- `@MainActor` borde hantera detta automatiskt

**Rekommendation:**
- Markera alla relevanta klasser med `@MainActor`
- Ta bort alla `DispatchQueue.main.async` wrappers
- Om warnings kvarstår, fixa root cause (troligen NSOutlineView callbacks som inte är på main thread)

---

### 2.3 NSApp.sendAction för Sidebar Toggle

**Problem:** `OperatorToolbar.swift:32` använder NSApp.sendAction:

```swift
NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
```

**Issues:**
- Magic selector som kan krascha om NSSplitViewController inte finns
- Inte SwiftUI-idiomatiskt
- Beroende på AppKit implementation details

**Rekommendation:**
- Använd `@Environment(\.dismiss)` eller state-baserad toggle
- Om HSplitView används, hantera visibility via state

---

### 2.4 Force Unwrap i FileNode.from()

**Problem:** `FileNode.swift:40` använder `startAccessingSecurityScopedResource()` utan att checka result:

```swift
let _ = url.startAccessingSecurityScopedResource()
defer { url.stopAccessingSecurityScopedResource() }
```

**Issues:**
- Return value ignoreras (kan vara false)
- `stopAccessingSecurityScopedResource()` anropas även om start misslyckades
- Kan orsaka memory leaks

**Rekommendation:**
```swift
let success = url.startAccessingSecurityScopedResource()
defer {
    if success {
        url.stopAccessingSecurityScopedResource()
    }
}
```

---

### 2.5 try? överallt döljer errors

**Problem:** Många ställen använder `try?` som döljer errors:

**Locations:**
- `FileNode.swift:43` - `try? url.resourceValues`
- `FileNode.swift:64` - `try? FileManager.default.contentsOfDirectory`
- `FileNode.swift:98` - `try? String(contentsOf:)`
- `WorkspaceViewModel.swift:80` - `try? String(contentsOf:)`
- `ContextInspector.swift:74` - `try? FileManager.default.attributesOfItem`
- `ContextInspector.swift:126` - `try? String(contentsOf:)`

**Issues:**
- Errors döljs helt
- Användare får ingen feedback när filer inte kan läsas
- Debugging blir svårt

**Rekommendation:**
- Använd `do-catch` blocks
- Logga errors till console
- Visa användarvänliga felmeddelanden
- Överväg en Error handling strategy (Result type eller throwing functions)

---

## 3. ONÖDIG KOMPLEXITET

### 3.1 FileNode Mutating loadChildrenIfNeeded()

**Problem:** `FileNode.swift:119-164` har en mutating method som kräver att man hittar noden i trädet först:

```swift
// FileNavigatorView.swift:42-45
if var mutableNode = findNode(node.id, in: fileTree) {
    mutableNode.loadChildrenIfNeeded()
    updateNode(mutableNode, in: &fileTree)
}
```

**Issues:**
- Kräver `findNode` och `updateNode` helper functions
- Mutating struct i en array är komplex
- `FileNode` är en struct, så mutating skapar kopior

**Rekommendation:**
- Gör `FileNode` till en class istället (reference semantics passar bättre för tree structures)
- Eller: gör `loadChildrenIfNeeded()` returnera en ny FileNode istället för mutating
- Eller: använd en ViewModel som hanterar tree state

---

### 3.2 Duplicerad ContentBlock Struct

**Problem:** `ContentBlock` struct definieras två gånger:

**Locations:**
- `Views/MarkdownMessageView.swift:137-147`
- `EntelechiaOperator/Sources/Editor/MarkdownView.swift:192-202`

**Issues:**
- Identisk kod på två ställen
- Om strukturen ändras måste båda uppdateras

**Rekommendation:**
- Flytta till Models/ eller en shared module
- Använd samma struct överallt

---

### 3.3 Komplex File Tree Loading Logic

**Problem:** File tree loading är spridd över flera ställen:

**Locations:**
- `FileNavigatorView.swift:84-101` - Loads tree
- `FileNode.swift:27-116` - Creates FileNode from URL
- `FileNode.swift:119-164` - Lazy loads children
- `XcodeNavigatorRepresentable.swift:135-140` - Reloads data
- `NavigatorItem.swift:411-458` - Loads children (duplicerad logik!)

**Issues:**
- `FileNode` och `NavigatorItem` har nästan identisk logik för att ladda children
- Två parallella tree structures (`FileNode` för SwiftUI, `NavigatorItem` för NSOutlineView)
- Ingen single source of truth

**Rekommendation:**
- Skapa en `FileTreeService` som hanterar all file tree logic
- Använd samma data structure för både SwiftUI och AppKit views
- Eller: välj EN approach (antingen SwiftUI OutlineGroup eller NSOutlineView, inte båda)

---

### 3.4 Color Extension Hack

**Problem:** `CodeBlockView.swift:67-95` har en custom Color initializer för hex:

```swift
extension Color {
    init(hex: String) {
        // Complex parsing logic
    }
    
    init(white: Double) {
        // Wrapper around existing initializer
    }
}
```

**Issues:**
- `init(white:)` är onödig wrapper (Color(white: 0.5) fungerar redan)
- Hex parsing är komplex och kan misslyckas tyst
- Används bara på ett ställe (`CodeBlockView.swift:43`)

**Rekommendation:**
- Ta bort `init(white:)` (onödig)
- För hex, använd `Color(red:green:blue:opacity:)` direkt eller använd en bättre hex parser
- Överväg att använda system colors istället

---

## 4. FARLIGA PATTERNS

### 4.1 Unsafe File I/O i Main Thread

**Problem:** Många file I/O operations körs på main thread utan async:

**Locations:**
- `WorkspaceViewModel.contextFiles(for:)` - Läser filer synkront
- `FileMetadataViewModel.folderStats(for:)` - Rekursivt läser alla filer
- `ContextInspector.fileMetadata(for:)` - Läser fil content för preview

**Issues:**
- Kan frysa UI för stora filer/mappar
- `folderStats` kan ta lång tid för stora projekt
- Ingen progress indication

**Rekommendation:**
- Använd `Task` för all file I/O
- Lägg till progress indicators
- Cache results aggressivt
- Överväg background queue för heavy operations

---

### 4.2 Memory Leaks i File Loading

**Problem:** `FileMetadataViewModel` cachar allt utan bounds:

```swift
// FileMetadataViewModel.swift:8-9
private var cachedLineCounts: [URL: Int] = [:]
private var cachedFolderStats: [URL: FolderStats] = [:]
```

**Issues:**
- Caches växer obegränsat
- Inga TTL eller LRU eviction
- Kan orsaka memory pressure

**Rekommendation:**
- Implementera LRU cache med max size
- Eller: TTL-baserad cache
- Eller: Clear cache när root directory ändras

---

### 4.3 Race Conditions i Conversation Management

**Problem:** `WorkspaceViewModel.conversation(for:)` kan skapa duplicates:

```swift
func conversation(for url: URL) -> Conversation {
    if let existing = conversations[url] {
        return existing
    }
    let new = Conversation(contextURL: url)
    Task { @MainActor in
        self.conversations[url] = new
    }
    return new
}
```

**Issues:**
- Om två threads anropar samtidigt kan båda skapa nya conversations
- Returnerar `new` innan den är i dictionary
- Ingen locking eller synchronization

**Rekommendation:**
- Använd `actor` för thread-safe access
- Eller: Använd `@MainActor` och se till att allt körs på main thread
- Eller: Använd en lock eller serial queue

---

### 4.4 Unsafe String Encoding Assumptions

**Problem:** Alla filer läses med `.utf8` encoding utan fallback:

```swift
// WorkspaceViewModel.swift:80
if let content = try? String(contentsOf: node.path, encoding: .utf8) {
```

**Issues:**
- Binary files kommer att crasha eller ge garbage
- Andra encodings (latin1, etc.) ignoreras
- Ingen detection av file type innan läsning

**Rekommendation:**
- Checka file type innan läsning
- Använd `String(data:encoding:)` med encoding detection
- Hantera binary files gracefully (visa "Binary file" meddelande)

---

## 5. SWIFTUI BEST PRACTICES VIOLATIONS

### 5.1 @StateObject vs @ObservedObject Confusion

**Problem:** Inkonsekvent användning av `@StateObject` och `@ObservedObject`:

**Locations:**
- `MainView.swift:4` - `@StateObject private var workspaceViewModel`
- `ChatView.swift:5` - `@ObservedObject var conversation`
- `ContextInspector.swift:7` - `@StateObject private var metadataViewModel`
- `XcodeNavigatorView.swift:6` - `@StateObject private var navigatorViewModel`

**Issues:**
- `@StateObject` ska användas när view äger ViewModel
- `@ObservedObject` ska användas när ViewModel kommer från parent
- `conversation` i `ChatView` kommer från parent, så `@ObservedObject` är korrekt
- Men `metadataViewModel` i `ContextInspector` skapas i view, så `@StateObject` är korrekt

**Rekommendation:**
- Följ SwiftUI best practices konsekvent
- Dokumentera varför val görs om det är ovanligt

---

### 5.2 EnvironmentObject Dependency Hell

**Problem:** Många views är beroende av flera EnvironmentObjects:

**Locations:**
- `XcodeNavigatorView.swift:5-6` - Både `workspaceViewModel` och `navigatorViewModel`
- `ProjectRootBar.swift:5-6` - Både `navigatorViewModel` och `workspaceViewModel`
- `XcodeNavigatorRepresentable.swift:6-7` - Både ViewModels

**Issues:**
- Views kan inte testas isolerat
- Tight coupling mellan komponenter
- Svårt att förstå dependencies

**Rekommendation:**
- Skapa en unified state manager
- Eller: Använd dependency injection istället för EnvironmentObject
- Eller: Skapa protocols för att göra testing möjligt

---

### 5.3 NSViewRepresentable utan Proper Lifecycle Management

**Problem:** `XcodeNavigatorRepresentable` skapar NSOutlineView men hanterar inte cleanup:

**Location:** `XcodeNavigatorRepresentable.swift:5-120`

**Issues:**
- `NavigatorDataSource` hålls i Coordinator men kan leak
- NSOutlineView delegate/dataSource kan orsaka retain cycles
- Inga cleanup methods

**Rekommendation:**
- Använd `weak` references där möjligt
- Implementera proper cleanup i `updateNSView`
- Överväg att använda `NSViewRepresentable` med `Coordinator` pattern korrekt

---

## 6. KODKVALITET

### 6.1 Magic Numbers

**Problem:** Många magic numbers utan konstanter:

**Locations:**
- `ChatInputView.swift:47` - `maxHeight: 120`
- `CodeBlockView.swift:59` - `deadline: .now() + 1.5`
- `MessageBubbleView.swift:79` - `deadline: .now() + 1.0`
- `MarkdownMessageView.swift:73` - `deadline: .now() + 1.0`
- `FileNavigatorView.swift:38` - `minHeight: 400`

**Rekommendation:**
- Skapa en `AppConstants` eller `DesignTokens` struct
- Definiera alla magic numbers där
- Använd namngivna konstanter

---

### 6.2 Inconsistent Error Handling

**Problem:** Vissa ställen använder `print()`, andra ignorerar errors helt:

**Locations:**
- `FilesSidebarView.swift:99` - `print("Failed to load file: \(error)")`
- `FilesSidebarView.swift:104` - `print("File selection failed: \(error)")`
- Många ställen använder `try?` och ignorerar errors

**Rekommendation:**
- Använd en centraliserad logging system
- Eller: Använd `os.log` för structured logging
- Visa användarvänliga felmeddelanden för kritiska errors

---

### 6.3 Dead Code / Unused Code

**Problem:** Flera ställen har kod som inte används:

**Locations:**
- `ChatViewModel.swift` - Hela klassen verkar inte användas (WorkspaceViewModel används istället)
- `ConversationsListView.swift` - Verkar inte användas i MainView
- `FileViewModel` - Används bara i FilesSidebarView som inte verkar vara i MainView
- `NavigatorViewModel.rowForURL()` - Definierad men aldrig anropad

**Rekommendation:**
- Ta bort oanvänd kod
- Eller: Dokumentera varför den finns (framtida feature?)

---

### 6.4 Inconsistent Naming

**Problem:** Inkonsekvent naming conventions:

**Examples:**
- `WorkspaceViewModel` vs `NavigatorViewModel` (båda hanterar workspace/navigation)
- `FileNode` vs `NavigatorItem` (båda representerar samma sak)
- `MarkdownRenderer` vs `MarkdownDocumentView` (båda hanterar markdown)

**Rekommendation:**
- Etablera naming conventions
- Refaktorera för konsistens
- Använd tydliga, beskrivande namn

---

## 7. PERFORMANCE ISSUES

### 7.1 Inefficient File Tree Filtering

**Problem:** `NavigatorDataSource.filterItems()` skapar nya NavigatorItem instances:

```swift
// XcodeNavigatorRepresentable.swift:158-176
private func filterItems(_ items: [NavigatorItem], filter: String) -> [NavigatorItem] {
    // Creates new NavigatorItem instances
    let filteredItem = NavigatorItem(url: item.url, ...)
}
```

**Issues:**
- Skapar nya objects vid varje filter change
- Kan orsaka memory churn
- Inefficient för stora trees

**Rekommendation:**
- Använd en filter predicate istället
- Eller: Cache filtered results
- Eller: Använd lazy filtering

---

### 7.2 Synchronous File Reading i UI

**Problem:** `ContextInspector.fileMetadata()` läser fil content synkront:

```swift
// ContextInspector.swift:126-133
if let content = try? String(contentsOf: node.path, encoding: .utf8) {
    ScrollView {
        Text(content)
```

**Issues:**
- Kan frysa UI för stora filer
- Ingen loading state
- Blocking operation

**Rekommendation:**
- Använd `Task` för async loading
- Visa loading indicator
- Limit preview size (t.ex. första 1000 raderna)

---

## 8. SPECIFIKA FIXES

### 8.1 WorkspaceViewModel.conversation(for:)

**Current:**
```swift
func conversation(for url: URL) -> Conversation {
    if let existing = conversations[url] {
        return existing
    }
    let new = Conversation(contextURL: url)
    Task { @MainActor in
        self.conversations[url] = new
    }
    return new
}
```

**Fixed:**
```swift
func conversation(for url: URL) -> Conversation {
    if let existing = conversations[url] {
        return existing
    }
    let new = Conversation(contextURL: url)
    conversations[url] = new  // Direct assignment, class is @MainActor
    return new
}
```

---

### 8.2 MarkdownView Duplication

**Action:** Ta bort all duplicerad markdown parsing från `MarkdownView.swift` och använd `MarkdownRenderer` istället.

---

### 8.3 FileNode vs NavigatorItem Unification

**Action:** Välj EN data structure för file tree. Rekommendation: Använd `FileNode` överallt och skapa en adapter för NSOutlineView om nödvändigt.

---

### 8.4 Error Handling Strategy

**Action:** Implementera en konsekvent error handling strategy:
- Använd `Result` type för operations som kan misslyckas
- Logga errors till console
- Visa användarvänliga felmeddelanden
- Hantera edge cases gracefully

---

## 9. PRIORITERING

### KRITISKT (Fixas omedelbart)
1. ✅ Ta bort duplicerad markdown parsing kod
2. ✅ Fixa race conditions i `conversation(for:)`
3. ✅ Implementera proper error handling (ta bort `try?` överallt)
4. ✅ Fixa memory leaks i caches

### HÖG PRIORITET (Fixas snart)
1. ✅ Unifiera state management (WorkspaceViewModel + NavigatorViewModel)
2. ✅ Ta bort Task-wrappers för publishing warnings
3. ✅ Implementera async file I/O
4. ✅ Ta bort dead code

### MEDEL PRIORITET (Fixas när tid finns)
1. ✅ Refaktorera FileNode/NavigatorItem duplication
2. ✅ Implementera proper caching strategy
3. ✅ Förbättra error messages
4. ✅ Konsistenta naming conventions

### LÅG PRIORITET (Nice to have)
1. ✅ Magic numbers till konstanter
2. ✅ Förbättra code documentation
3. ✅ Unit tests för kritiska paths

---

## 10. SLUTSATS

Kodbasen har många tecken på snabb utveckling med pragmatiska lösningar som behöver refaktoreras. De största problemen är:

1. **Duplicerad kod** - Markdown parsing, ContentBlock, File tree loading
2. **State management chaos** - Flera ViewModels med överlappande ansvar
3. **Hacklösningar** - Task-wrappers, DispatchQueue.main.async, try? överallt
4. **Saknad error handling** - Errors döljs eller ignoreras
5. **Performance issues** - Synkron file I/O, obegränsade caches

Med fokus på att eliminera duplicering, unifiera state management, och implementera proper error handling kommer kodbasen att bli betydligt mer maintainable och robust.

