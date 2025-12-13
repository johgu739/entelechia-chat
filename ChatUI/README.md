# ChatUI Package

## Architectural Invariants

ChatUI is a **pure projection layer**. It must not participate in cognition or causation.

### Non-Negotiable Rules

1. **ChatUI MUST NOT hold ViewModels**
   - No `@ObservedObject` ViewModels
   - No `@StateObject` ViewModels
   - No `@EnvironmentObject` ViewModels
   - No ViewModel type imports or references

2. **ChatUI only receives value types**
   - Immutable structs (ViewState types)
   - Enums (Intent types)
   - Closures: `(Intent) -> Void`

3. **ChatUI only emits intents**
   - All mutations become intent dispatches
   - No direct method calls on ViewModels
   - No property mutations

4. **ChatUI is blind to domain logic**
   - Does not know what ViewModels are
   - Does not know what Combine is
   - Does not know what async operations are
   - Only sees state handed to it

### What ChatUI May Contain

- `struct View` (SwiftUI views)
- Value types (`struct`, `enum`)
- Intent closures: `(ChatIntent) -> Void`, `(WorkspaceIntent) -> Void`
- Local ephemeral UI state only (`@State` for focus, animation flags)

### What ChatUI May NOT Contain

- `ObservableObject`
- `@ObservedObject`
- `@StateObject`
- `@EnvironmentObject`
- Combine subscriptions
- Async calls
- Mutation logic
- "Presentation view models"

### Layer Responsibilities

- **ChatUI**: Pure sensible form (projection + intent emission)
- **UIConnections**: Practical intellect (state, mutation, coordination)
- **AppComposition**: Efficient cause (wiring, lifetime, ownership)

### Enforcement

CI guardrails in `scripts/chatui-purity-guard.sh` enforce these invariants. The build will fail if violations are detected.



