// @EntelechiaHeaderStart
// Signifier: Logger+Subsystem
// Substance: Logging utilities
// Genus: Infrastructure logging helper
// Differentia: Provides canonical logger categories
// Form: OSLog-backed static factories
// Matter: Logger instances scoped to subsystems
// Powers: Ensure consistent logging throughout persistence and security layers
// FinalCause: Deliver observability for Codex readiness operations
// Relations: Serves persistence, security, and configuration services
// CausalityType: Instrumental
// @EntelechiaHeaderEnd

import os.log

extension Logger {
    static let persistence = Logger(subsystem: "chat.entelechia", category: "Persistence")
    static let security = Logger(subsystem: "chat.entelechia", category: "Security")
    static let preferences = Logger(subsystem: "chat.entelechia", category: "Preferences")
}
