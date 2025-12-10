import os.log

public extension Logger {
    static let persistence = Logger(subsystem: "chat.entelechia", category: "Persistence")
    static let security = Logger(subsystem: "chat.entelechia", category: "Security")
    static let preferences = Logger(subsystem: "chat.entelechia", category: "Preferences")
}



