import os

// MARK: - Log Level

public enum LogLevel: Equatable, Sendable {
    case debug
    case info
    case warning
    case error
}

// MARK: - Handler Protocol

public protocol LogHandler: Sendable {
    func log(level: LogLevel, message: String)
}

// MARK: - Production Handler

public struct OSLogHandler: LogHandler {
    private let logger: os.Logger

    public init(subsystem: String, category: String) {
        self.logger = os.Logger(subsystem: subsystem, category: category)
    }

    public func log(level: LogLevel, message: String) {
        switch level {
        case .debug:   logger.debug("\(message, privacy: .public)")
        case .info:    logger.info("\(message, privacy: .public)")
        case .warning: logger.warning("\(message, privacy: .public)")
        case .error:   logger.error("\(message, privacy: .public)")
        }
    }
}

// MARK: - JARVISLogger

public struct JARVISLogger: Sendable {
    public let subsystem: String
    public let category: String
    private let handler: any LogHandler

    /// Production init — uses OSLogHandler by default.
    public init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
        self.handler = OSLogHandler(subsystem: subsystem, category: category)
    }

    /// Test init — accepts an injected handler (e.g. MockLogHandler).
    public init(subsystem: String, category: String, handler: any LogHandler) {
        self.subsystem = subsystem
        self.category = category
        self.handler = handler
    }

    public func debug(_ message: String) {
        handler.log(level: .debug, message: message)
    }

    public func info(_ message: String) {
        handler.log(level: .info, message: message)
    }

    public func warning(_ message: String) {
        handler.log(level: .warning, message: message)
    }

    public func error(_ message: String) {
        handler.log(level: .error, message: message)
    }
}

// MARK: - Logger Namespace
//
// This enum shadows os.Logger inside the JARVIS module intentionally.
// Use `os.Logger` when referring to Apple's type within this file.

public enum Logger {
    public static let orchestrator = JARVISLogger(subsystem: "com.aidaemon", category: "orchestrator")
    public static let tools        = JARVISLogger(subsystem: "com.aidaemon", category: "tools")
    public static let api          = JARVISLogger(subsystem: "com.aidaemon", category: "api")
    public static let policy       = JARVISLogger(subsystem: "com.aidaemon", category: "policy")
    public static let voice        = JARVISLogger(subsystem: "com.aidaemon", category: "voice")
    public static let memory       = JARVISLogger(subsystem: "com.aidaemon", category: "memory")
    public static let ui           = JARVISLogger(subsystem: "com.aidaemon", category: "ui")
    public static let keychain       = JARVISLogger(subsystem: "com.aidaemon", category: "keychain")
    public static let app            = JARVISLogger(subsystem: "com.aidaemon", category: "app")
    public static let accessibility  = JARVISLogger(subsystem: "com.aidaemon", category: "accessibility")
    public static let input          = JARVISLogger(subsystem: "com.aidaemon", category: "input")
    public static let screenshot     = JARVISLogger(subsystem: "com.aidaemon", category: "screenshot")
    public static let browser        = JARVISLogger(subsystem: "com.aidaemon", category: "browser")
    public static let cdp            = JARVISLogger(subsystem: "com.aidaemon", category: "cdp")
    public static let session        = JARVISLogger(subsystem: "com.aidaemon", category: "session")
    public static let wakeWord       = JARVISLogger(subsystem: "com.aidaemon", category: "wakeWord")
    public static let settings       = JARVISLogger(subsystem: "com.aidaemon", category: "settings")
}
