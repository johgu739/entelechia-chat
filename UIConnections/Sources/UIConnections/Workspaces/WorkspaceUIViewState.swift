import Foundation
import UIContracts

/// Immutable view state for workspace UI (pure form, no power).
/// Derived from WorkspaceStateViewModel and WorkspaceActivityViewModel, never mutated directly.
/// This is a typealias to UIContracts.WorkspaceUIViewState for backward compatibility.
/// New code should use UIContracts.WorkspaceUIViewState directly.
@available(*, deprecated, message: "Use UIContracts.WorkspaceUIViewState directly")
public typealias WorkspaceUIViewState = UIContracts.WorkspaceUIViewState

